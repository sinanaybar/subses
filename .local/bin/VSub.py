#!/usr/bin/env python3
"""
video2altyazi.py
-----------------
Bir video dosyasındaki konuşmayı otomatik olarak metne çevirip
zaman kodlu (senkronize) bir .srt altyazı dosyası üretir.

Whisper yerine "faster-whisper" kullanır:
- Aynı doğruluk, CTranslate2 tabanlı olduğu için 4-8x daha hızlı
- Daha az RAM/VRAM kullanır
- CPU'da bile makul hızda çalışır (GPU varsa otomatik kullanır)

KURULUM (Linux):
    sudo apt install ffmpeg          # ses/video işleme için şart
    python3 -m venv venv
    source venv/bin/activate
    pip install faster-whisper

KULLANIM:
    python3 video2altyazi.py video.mp4
    python3 video2altyazi.py video.mp4 --model medium --dil tr
    python3 video2altyazi.py video.mp4 --model large-v3 --cihaz cuda
    python3 video2altyazi.py video.mp4 --format vtt

    # Aynı anda birden fazla dosya:
    python3 video2altyazi.py *.mp4 --model small

    # Klasördeki tüm videoları izleyip yeni eklenenleri otomatik işle:
    python3 video2altyazi.py --izle /home/kullanici/Videolar
"""

import argparse
import subprocess
import sys
import time
from pathlib import Path

DESTEKLENEN_VIDEO_UZANTILARI = {".mp4", ".mkv", ".mov", ".avi", ".webm", ".m4v", ".ts"}


def ffmpeg_var_mi() -> bool:
    try:
        subprocess.run(
            ["ffmpeg", "-version"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True,
        )
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def sesi_cikar(video_yolu: Path, gecici_klasor: Path) -> Path:
    """Videodan 16kHz mono WAV çıkarır (Whisper'ın beklediği format)."""
    hedef = gecici_klasor / (video_yolu.stem + "_ses.wav")
    komut = [
        "ffmpeg", "-y", "-i", str(video_yolu),
        "-vn",                # video akışını atla
        "-acodec", "pcm_s16le",
        "-ar", "16000",
        "-ac", "1",
        str(hedef),
    ]
    sonuc = subprocess.run(komut, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if sonuc.returncode != 0:
        raise RuntimeError(
            f"ffmpeg ses çıkarma hatası ({video_yolu.name}):\n"
            f"{sonuc.stderr.decode(errors='ignore')}"
        )
    return hedef


def zaman_bicimi_srt(saniye: float) -> str:
    saat = int(saniye // 3600)
    dakika = int((saniye % 3600) // 60)
    sn = int(saniye % 60)
    ms = int((saniye - int(saniye)) * 1000)
    return f"{saat:02d}:{dakika:02d}:{sn:02d},{ms:03d}"


def zaman_bicimi_vtt(saniye: float) -> str:
    return zaman_bicimi_srt(saniye).replace(",", ".")


def altyazi_yaz(segmentler, hedef_yol: Path, format_: str):
    with open(hedef_yol, "w", encoding="utf-8") as f:
        if format_ == "vtt":
            f.write("WEBVTT\n\n")
        for i, seg in enumerate(segmentler, start=1):
            baslangic = seg.start
            bitis = seg.end
            metin = seg.text.strip()
            if format_ == "srt":
                f.write(f"{i}\n")
                f.write(f"{zaman_bicimi_srt(baslangic)} --> {zaman_bicimi_srt(bitis)}\n")
                f.write(f"{metin}\n\n")
            else:  # vtt
                f.write(f"{zaman_bicimi_vtt(baslangic)} --> {zaman_bicimi_vtt(bitis)}\n")
                f.write(f"{metin}\n\n")


def video_isle(video_yolu: Path, model, args, gecici_klasor: Path):
    print(f"\n📹  İşleniyor: {video_yolu.name}")

    if video_yolu.suffix.lower() in {".wav", ".mp3", ".flac", ".m4a", ".aac", ".ogg"}:
        ses_yolu = video_yolu
        temizle = False
    else:
        print("   🎧  Ses çıkarılıyor (ffmpeg)...")
        ses_yolu = sesi_cikar(video_yolu, gecici_klasor)
        temizle = True

    print(f"   🧠  Model çalışıyor: {args.model} (cihaz={args.cihaz}, hesap_tipi={args.hesap_tipi})")
    baslangic_zamani = time.time()

    segmentler, bilgi = model.transcribe(
        str(ses_yolu),
        language=None if args.dil == "auto" else args.dil,
        vad_filter=not args.vad_kapali,   # sessizlikleri/gürültüyü otomatik atla
        beam_size=args.beam_size,
        word_timestamps=args.kelime_zamani,
    )

    algilanan_dil = bilgi.language
    print(f"   🌐  Algılanan dil: {algilanan_dil} (güven: {bilgi.language_probability:.2f})")

    segment_listesi = []
    for seg in segmentler:  # generator'dan geldikçe hemen yazdır (canlı ilerleme)
        print(f"   [{zaman_bicimi_srt(seg.start)} -> {zaman_bicimi_srt(seg.end)}] {seg.text.strip()}", flush=True)
        segment_listesi.append(seg)

    hedef_yol = video_yolu.with_suffix(f".{args.format}")
    altyazi_yaz(segment_listesi, hedef_yol, args.format)

    gecen = time.time() - baslangic_zamani
    print(f"   ✅  Bitti ({gecen:.1f} sn) -> {hedef_yol}")

    if temizle and not args.gecici_dosyayi_sakla:
        ses_yolu.unlink(missing_ok=True)


def izleme_modu(klasor: Path, model, args, gecici_klasor: Path):
    """Belirtilen klasörü periyodik tarar, altyazısı olmayan yeni videoları işler."""
    print(f"👀  Klasör izleniyor: {klasor}  (Ctrl+C ile çık)")
    islenenler = set()
    try:
        while True:
            for dosya in sorted(klasor.iterdir()):
                if dosya.suffix.lower() not in DESTEKLENEN_VIDEO_UZANTILARI:
                    continue
                altyazi = dosya.with_suffix(f".{args.format}")
                if dosya in islenenler or altyazi.exists():
                    continue
                try:
                    video_isle(dosya, model, args, gecici_klasor)
                except Exception as e:
                    print(f"   ⚠️  Hata ({dosya.name}): {e}")
                islenenler.add(dosya)
            time.sleep(args.tarama_araligi)
    except KeyboardInterrupt:
        print("\n⏹  İzleme durduruldu.")


MODEL_BILGISI = {
    "tiny":     ("~75 MB",  "En hızlı, doğruluk düşük"),
    "base":     ("~150 MB", "Hızlı, temel doğruluk"),
    "small":    ("~500 MB", "Hız/doğruluk dengesi iyi"),
    "medium":   ("~1.5 GB", "Yüksek doğruluk, orta hız"),
    "large-v2": ("~3 GB",   "Çok yüksek doğruluk, yavaş"),
    "large-v3": ("~3 GB",   "En yüksek doğruluk, yavaş (önerilen)"),
}


def model_sec_interaktif() -> str:
    siralama = ["tiny", "base", "small", "medium", "large-v2", "large-v3"]
    print("\n🧠  Hangi Whisper modeli kullanılsın?\n")
    for i, isim in enumerate(siralama, start=1):
        boyut, aciklama = MODEL_BILGISI[isim]
        print(f"   {i}) {isim:<10} ({boyut:<8}) - {aciklama}")
    print()
    while True:
        secim = input(f"Seçiminiz [1-{len(siralama)}] (varsayılan: small): ").strip()
        if secim == "":
            return "small"
        if secim.isdigit() and 1 <= int(secim) <= len(siralama):
            return siralama[int(secim) - 1]
        # Kullanıcı doğrudan model adı da yazmış olabilir
        if secim in siralama:
            return secim
        print("   ⚠️  Geçersiz seçim, tekrar deneyin.")


def main():
    ap = argparse.ArgumentParser(
        description="Video/ses dosyalarından zaman kodlu (senkronize) altyazı üretir."
    )
    ap.add_argument("dosyalar", nargs="*", help="Video/ses dosyası yolları (joker karakter desteklenir)")
    ap.add_argument("--izle", metavar="KLASOR", help="Bu klasörü sürekli izleyip yeni videoları otomatik işle")
    ap.add_argument("--tarama-araligi", type=int, default=30, help="İzleme modunda tarama sıklığı (sn, varsayılan: 30)")
    ap.add_argument("--model", default=None,
                    choices=["tiny", "base", "small", "medium", "large-v2", "large-v3"],
                    help="Whisper model boyutu. Belirtilmezse çalışırken interaktif olarak sorulur.")
    ap.add_argument("--dil", default="auto", help="Ses dili (örn: tr, en). Varsayılan: otomatik algıla")
    ap.add_argument("--format", default="srt", choices=["srt", "vtt"], help="Çıktı altyazı formatı")
    ap.add_argument("--cihaz", default="auto", choices=["auto", "cpu", "cuda"], help="İşlem birimi")
    ap.add_argument("--hesap-tipi", default="auto",
                    help="Hesaplama hassasiyeti (int8, int8_float16, float16, float32). Varsayılan: auto")
    ap.add_argument("--beam-size", type=int, default=5, help="Beam search genişliği (varsayılan: 5)")
    ap.add_argument("--vad-kapali", action="store_true", help="Sessizlik filtrelemeyi (VAD) kapat")
    ap.add_argument("--kelime-zamani", action="store_true", help="Kelime bazlı zaman damgası da hesapla (daha yavaş)")
    ap.add_argument("--gecici-dosyayi-sakla", action="store_true", help="Çıkarılan ara WAV dosyasını silme")
    args = ap.parse_args()

    if not args.dosyalar and not args.izle:
        ap.error("En az bir dosya belirtmelisiniz ya da --izle KLASOR kullanmalısınız.")

    if not ffmpeg_var_mi():
        print("❌  ffmpeg bulunamadı. Kurmak için: sudo apt install ffmpeg", file=sys.stderr)
        sys.exit(1)

    if args.model is None:
        args.model = model_sec_interaktif()

    try:
        from faster_whisper import WhisperModel
    except ImportError:
        print("❌  faster-whisper kurulu değil. Kurmak için:\n"
              "    pip install faster-whisper", file=sys.stderr)
        sys.exit(1)

    cihaz = args.cihaz
    if cihaz == "auto":
        try:
            import ctranslate2
            cihaz = "cuda" if ctranslate2.get_cuda_device_count() > 0 else "cpu"
        except Exception:
            cihaz = "cpu"

    hesap_tipi = args.hesap_tipi
    if hesap_tipi == "auto":
        hesap_tipi = "float16" if cihaz == "cuda" else "int8"

    # Bazı GPU'lar / eksik cuDNN kurulumları float16'yı verimli desteklemiyor.
    # Kullanıcı --hesap-tipi ile elle bir şey belirtmediyse (yani "auto" ise),
    # sırayla daha uyumlu seçeneklere düşerek deniyoruz.
    denenecekler = [hesap_tipi]
    if args.hesap_tipi == "auto" and cihaz == "cuda":
        denenecekler = ["float16", "int8_float16", "int8"]

    model = None
    son_hata = None
    for i, deneme_tipi in enumerate(denenecekler):
        print(f"⏳  Model yükleniyor: {args.model} ({cihaz}/{deneme_tipi})...")
        try:
            model = WhisperModel(args.model, device=cihaz, compute_type=deneme_tipi)
            hesap_tipi = deneme_tipi
            break
        except ValueError as e:
            son_hata = e
            if i < len(denenecekler) - 1:
                print(f"   ⚠️  {deneme_tipi} desteklenmiyor, sıradaki deneniyor...")
            continue

    if model is None:
        # CUDA'nın tamamı başarısız olduysa son çare olarak CPU'ya düş
        if cihaz == "cuda":
            print("   ⚠️  CUDA üzerinde hiçbir hesap tipi çalışmadı, CPU'ya geçiliyor...")
            cihaz = "cpu"
            hesap_tipi = "int8"
            print(f"⏳  Model yükleniyor: {args.model} ({cihaz}/{hesap_tipi})...")
            model = WhisperModel(args.model, device=cihaz, compute_type=hesap_tipi)
        else:
            raise son_hata

    args.cihaz, args.hesap_tipi = cihaz, hesap_tipi

    gecici_klasor = Path("/tmp/video2altyazi")
    gecici_klasor.mkdir(parents=True, exist_ok=True)

    if args.izle:
        izleme_modu(Path(args.izle), model, args, gecici_klasor)
        return

    for dosya_str in args.dosyalar:
        dosya = Path(dosya_str)
        if not dosya.exists():
            print(f"⚠️  Bulunamadı, atlanıyor: {dosya}", file=sys.stderr)
            continue
        try:
            video_isle(dosya, model, args, gecici_klasor)
        except Exception as e:
            hata_metni = str(e)
            # CUDA kütüphaneleri (libcublas, libcudnn vb.) sistemde eksikse
            # bir kerelik CPU'ya düşüp aynı dosyayı yeniden dene.
            if args.cihaz == "cuda" and ("libcublas" in hata_metni or "libcudnn" in hata_metni or "cuda" in hata_metni.lower()):
                print(f"   ⚠️  CUDA kütüphane hatası, CPU'ya geçilip yeniden deneniyor: {hata_metni}")
                print("⏳  Model yükleniyor: {} (cpu/int8)...".format(args.model))
                model = WhisperModel(args.model, device="cpu", compute_type="int8")
                args.cihaz, args.hesap_tipi = "cpu", "int8"
                try:
                    video_isle(dosya, model, args, gecici_klasor)
                except Exception as e2:
                    print(f"❌  Hata ({dosya.name}): {e2}", file=sys.stderr)
            else:
                print(f"❌  Hata ({dosya.name}): {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
