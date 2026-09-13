#!/usr/bin/env bash
#
# vsub-arayuz.sh
# ---------------
# VSub.py için terminalden bağımsız, "yad" tabanlı grafiksel arayüz.
#
# Bu betik kendi kendine kurulum yapar:
#   - Çalıştığı Linux dağıtımını algılar (Arch tabanlı / Debian-Ubuntu tabanlı)
#   - Eksik sistem paketlerini (yad, ffmpeg, python3, venv, pip) kurar
#   - Kendi Python sanal ortamını (.venv) oluşturur ve içine girip çıkar
#   - faster-whisper'ı bu sanal ortama kurar
#   - Tüm bu adımları (mümkün olduğunda) yad penceresinde anlık gösterir
#
# Farklı bir yerdeyse VSUB_PY ortam değişkenini elle ayarlayın.

set -o pipefail
set +H
# =============================================================================
# Ayarlar
# =============================================================================
BETIK_KLASORU="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VSUB_PY="${VSUB_PY:-$BETIK_KLASORU/VSub.py}"
VENV_DIZIN="$BETIK_KLASORU/.venv"
UYGULAMA_ADI="SUBSES - Video Altyazı Oluşturucu"
YAD_GENISLIK=560

PYTHON_BIN_KULLANICI_VERDI=0
[[ -n "${PYTHON_BIN:-}" ]] && PYTHON_BIN_KULLANICI_VERDI=1

# =============================================================================
# Dağıtım tespiti
# =============================================================================
dagitim_tespit_et() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        local kimlik="${ID:-}" benzer="${ID_LIKE:-}"
        case "$kimlik $benzer" in
            *arch*|*manjaro*|*endeavouros*|*garuda*) echo "arch"; return ;;
        esac
        case "$kimlik $benzer" in
            *debian*|*ubuntu*) echo "debian"; return ;;
        esac
    fi
    if command -v pacman >/dev/null 2>&1; then echo "arch"; return; fi
    if command -v apt-get >/dev/null 2>&1; then echo "debian"; return; fi
    echo "bilinmeyen"
}

DAGITIM="$(dagitim_tespit_et)"

# Yetki yükseltme aracı: grafik ortamda pkexec (kendi parola penceresini açar),
# yoksa sudo (yalnızca terminalden çalıştırılırsa parola sorabilir).
if command -v pkexec >/dev/null 2>&1; then
    YUKSELT=(pkexec env DEBIAN_FRONTEND=noninteractive)
elif command -v sudo >/dev/null 2>&1; then
    YUKSELT=(sudo env DEBIAN_FRONTEND=noninteractive)
else
    YUKSELT=()
fi

# Dağıtıma göre kurulum komutunu metin olarak üretir (bash -c ile çalıştırılır)
sistem_kurulum_komutu() {
    local paketler="$1"
    case "$DAGITIM" in
        debian) echo "apt-get update && apt-get install -y $paketler" ;;
        arch)   echo "pacman -Sy --noconfirm --needed $paketler" ;;
        *)      echo "" ;;
    esac
}

# Eksik sistem paketlerini (komut adlarına bakarak) belirler, paket adı listesi döndürür
eksik_sistem_paketlerini_belirle() {
    local eksikler=()

    command -v yad    >/dev/null 2>&1 || eksikler+=("yad")
    command -v ffmpeg >/dev/null 2>&1 || eksikler+=("ffmpeg")

    if [[ "$DAGITIM" == "arch" ]]; then
        command -v python3 >/dev/null 2>&1 || eksikler+=("python")
        command -v pip3    >/dev/null 2>&1 || eksikler+=("python-pip")
    else
        command -v python3 >/dev/null 2>&1 || eksikler+=("python3")
        python3 -c "import venv" >/dev/null 2>&1 || eksikler+=("python3-venv")
        command -v pip3    >/dev/null 2>&1 || eksikler+=("python3-pip")
    fi

    echo "${eksikler[*]}"
}

# =============================================================================
# AŞAMA 0 — "yad" kurulu değilse: henüz grafik pencere gösteremeyiz.
# Bildirimle (varsa) haber verip sessizce kurmayı dener, sonra devam eder.
# =============================================================================
if ! command -v yad >/dev/null 2>&1; then
    command -v notify-send >/dev/null 2>&1 && \
        notify-send -i system-software-install "$UYGULAMA_ADI" \
            "Gerekli bileşenler kuruluyor, lütfen bekleyin..."

    if [[ -n "${YUKSELT[*]:-}" ]]; then
        ILK_KOMUT="$(sistem_kurulum_komutu "yad")"
        [[ -n "$ILK_KOMUT" ]] && "${YUKSELT[@]}" bash -c "$ILK_KOMUT" >/tmp/vsub-kurulum-baslangic.log 2>&1
    fi

    if ! command -v yad >/dev/null 2>&1; then
        MESAJ="'yad' otomatik kurulamadı.\n\nTerminalde şunu çalıştırıp tekrar deneyin:\n"
        case "$DAGITIM" in
            debian) MESAJ+="  sudo apt install yad" ;;
            arch)   MESAJ+="  sudo pacman -S yad" ;;
            *)      MESAJ+="  (dağıtımınızın paket yöneticisiyle 'yad' paketini kurun)" ;;
        esac
        if command -v zenity >/dev/null 2>&1; then
            zenity --error --title="$UYGULAMA_ADI" --text="$MESAJ"
        else
            echo -e "$MESAJ" >&2
        fi
        exit 1
    fi

    command -v notify-send >/dev/null 2>&1 && \
        notify-send -i system-software-install "$UYGULAMA_ADI" "'yad' kuruldu, devam ediliyor..."
fi

# =============================================================================
# AŞAMA 1 — Geri kalan her şey için kurulum gerekiyor mu, kontrol et.
# Hiçbir şey eksik değilse bu aşama tamamen atlanır (hızlı açılış).
# =============================================================================
EKSIK_SISTEM_PAKETLERI="$(eksik_sistem_paketlerini_belirle)"

VENV_KURULUM_GEREKLI=0
if [[ "$PYTHON_BIN_KULLANICI_VERDI" -eq 0 ]]; then
    if [[ ! -x "$VENV_DIZIN/bin/python3" ]]; then
        VENV_KURULUM_GEREKLI=1
    elif ! "$VENV_DIZIN/bin/python3" -c "import faster_whisper" >/dev/null 2>&1; then
        VENV_KURULUM_GEREKLI=1
    fi
fi

if [[ -n "$EKSIK_SISTEM_PAKETLERI" || "$VENV_KURULUM_GEREKLI" -eq 1 ]]; then
    {
        echo "🖥  Tespit edilen dağıtım: $DAGITIM"
        echo "----------------------------------------------------------------"

        if [[ -n "$EKSIK_SISTEM_PAKETLERI" ]]; then
            echo "📦  Eksik sistem paketleri kuruluyor: $EKSIK_SISTEM_PAKETLERI"
            KOMUT_METNI="$(sistem_kurulum_komutu "$EKSIK_SISTEM_PAKETLERI")"
            if [[ -z "$KOMUT_METNI" ]]; then
                echo "❌  Bu dağıtım otomatik olarak tanınamadı, elle kurun: $EKSIK_SISTEM_PAKETLERI"
            elif [[ -z "${YUKSELT[*]:-}" ]]; then
                echo "❌  Yetkilendirme aracı (pkexec/sudo) bulunamadı, elle kurun: $EKSIK_SISTEM_PAKETLERI"
            else
                stdbuf -oL -eL "${YUKSELT[@]}" bash -c "$KOMUT_METNI" 2>&1
                if [[ $? -eq 0 ]]; then
                    echo "   ✅  Sistem paketleri kuruldu."
                else
                    echo "   ❌  Sistem paketleri kurulurken hata oluştu (yukarıya bakın)."
                fi
            fi
        else
            echo "📦  Sistem paketleri zaten tamam."
        fi

        echo "----------------------------------------------------------------"

        if [[ "$PYTHON_BIN_KULLANICI_VERDI" -eq 1 ]]; then
            echo "🐍  PYTHON_BIN elle verilmiş ($PYTHON_BIN), dahili sanal ortam adımı atlanıyor."
        else
            if [[ ! -d "$VENV_DIZIN" ]]; then
                echo "🐍  Python sanal ortamı oluşturuluyor: $VENV_DIZIN"
                python3 -m venv "$VENV_DIZIN" 2>&1
                if [[ $? -eq 0 ]]; then
                    echo "   ✅  Sanal ortam oluşturuldu."
                else
                    echo "   ❌  Sanal ortam oluşturulamadı."
                fi
            else
                echo "🐍  Sanal ortam zaten mevcut: $VENV_DIZIN"
            fi

            echo "----------------------------------------------------------------"

            if [[ -x "$VENV_DIZIN/bin/python3" ]]; then
                if "$VENV_DIZIN/bin/python3" -c "import faster_whisper" >/dev/null 2>&1; then
                    echo "⬇️  faster-whisper zaten kurulu."
                else
                    echo "⬇️  faster-whisper kuruluyor (ilk kurulumda biraz zaman alabilir)..."
                    stdbuf -oL -eL "$VENV_DIZIN/bin/python3" -m pip install --upgrade pip 2>&1
                    stdbuf -oL -eL "$VENV_DIZIN/bin/python3" -m pip install faster-whisper nvidia-cublas-cu12 nvidia-cudnn-cu12 2>&1
                    if "$VENV_DIZIN/bin/python3" -c "import faster_whisper" >/dev/null 2>&1; then
                        echo "   ✅  faster-whisper kuruldu."
                    else
                        echo "   ❌  faster-whisper kurulumu başarısız oldu (yukarıya bakın)."
                    fi
                fi
            else
                echo "❌  Sanal ortam Python'u bulunamadı, faster-whisper kurulamadı."
            fi
        fi

        echo "----------------------------------------------------------------"
        echo "✅  Kurulum kontrolü tamamlandı."
    } | yad --text-info \
            --window-icon="$HOME/.config/subses/subses.png" \
            --title="$UYGULAMA_ADI — Kurulum" \
            --width=780 --height=520 \
            --tail \
            --button="Devam Et:0" \
            --window-icon="system-software-install"
fi

# =============================================================================
# AŞAMA 2 — Kurulumdan sonra tekrar doğrula, hâlâ eksikse net hata ver.
# =============================================================================
if ! command -v ffmpeg >/dev/null 2>&1; then
    yad --error --title="$UYGULAMA_ADI" --width="$YAD_GENISLIK" \
        --window-icon="$HOME/.config/subses/subses.png" \
        --text="ffmpeg kurulamadı.\n\nElle kurmayı deneyin:\n$( [[ "$DAGITIM" == "arch" ]] && echo 'sudo pacman -S ffmpeg' || echo 'sudo apt install ffmpeg' )"
    exit 1
fi

if [[ ! -f "$VSUB_PY" ]]; then
    yad --error --title="$UYGULAMA_ADI" --width="$YAD_GENISLIK" \
        --window-icon="$HOME/.config/subses/subses.png" \
        --text="VSub.py bulunamadı:\n$VSUB_PY\n\nBu arayüz betiğini VSub.py ile aynı klasöre koyun\nya da VSUB_PY ortam değişkenini ayarlayın."
    exit 1
fi

if [[ "$PYTHON_BIN_KULLANICI_VERDI" -eq 0 && ! -x "$VENV_DIZIN/bin/python3" ]]; then
    yad --error --title="$UYGULAMA_ADI" --width="$YAD_GENISLIK" \
        --window-icon="$HOME/.config/subses/subses.png" \
        --text="Python sanal ortamı kurulamadı: $VENV_DIZIN\n\nYukarıdaki kurulum günlüğünü kontrol edin."
    exit 1
fi

# =============================================================================
# AŞAMA 3 — Sanal ortama otomatik GİRİŞ (aktivasyon).
# Betik ne şekilde biterse bitsin (başarı/hata/pencere kapatma) trap ile
# otomatik ÇIKIŞ (deactivate) yapılır.
# =============================================================================
PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_AKTIF=0

if [[ "$PYTHON_BIN_KULLANICI_VERDI" -eq 0 ]]; then
    # shellcheck disable=SC1091
    source "$VENV_DIZIN/bin/activate"
    VENV_AKTIF=1
    PYTHON_BIN="python3"
fi

temizle_ve_cik() {
    if [[ "$VENV_AKTIF" -eq 1 ]]; then
        deactivate 2>/dev/null || true
    fi
}
trap temizle_ve_cik EXIT

# =============================================================================
# AŞAMA 4 — Kullanıcıdan bilgileri al (tek form penceresi)
# =============================================================================
FORM_SONUC=$(yad --form \
    --title="$UYGULAMA_ADI" \
    --width="$YAD_GENISLIK" \
    --window-icon="$HOME/.config/subses/subses.png" \
    --text="<b>Video seçin ve ayarları belirleyin</b>" \
    --field="Video/ses dosyası (Gözat...):FL" "" \
    --field="Model:CB" "small!tiny!base!medium!large-v2!large-v3" \
    --field="Dil (auto = otomatik algıla):CB" "auto!tr!en!de!fr!es!it!ru!ar!ja!ko!zh" \
    --field="Çıktı formatı:CB" "srt!vtt" \
    --field="Cihaz:CB" "auto!cuda!cpu" \
    --field="Sessizlik filtresini (VAD) kapat:CHK" "FALSE" \
    --field="Kelime bazlı zaman damgası hesapla:CHK" "FALSE" \
    --button="Vazgeç:1" \
    --button="Altyazı Oluştur:0" \
    --separator="|")

if [[ $? -ne 0 ]]; then
    exit 0
fi

IFS='|' read -r VIDEO_YOLU MODEL DIL FORMAT CIHAZ VAD_KAPALI KELIME_ZAMANI <<< "$FORM_SONUC"

if [[ -z "$VIDEO_YOLU" ]]; then
    yad --error --title="$UYGULAMA_ADI" \
        --window-icon="$HOME/.config/subses/subses.png" \
        --text="Bir video/ses dosyası seçmelisiniz."
    exit 1
fi

if [[ ! -f "$VIDEO_YOLU" ]]; then
    yad --error --title="$UYGULAMA_ADI" \
        --window-icon="$HOME/.config/subses/subses.png" \
        --text="Dosya bulunamadı:\n$VIDEO_YOLU"
    exit 1
fi

# =============================================================================
# AŞAMA 5 — VSub.py komutunu kur ve çalıştır
#   PYTHONUNBUFFERED / stdbuf -oL -eL: çıktının anlık (satır satır) akması için
# =============================================================================
KOMUT=(env PYTHONUNBUFFERED=1 stdbuf -oL -eL "$PYTHON_BIN" -u "$VSUB_PY" "$VIDEO_YOLU" --model "$MODEL" --format "$FORMAT" --cihaz "$CIHAZ")

if [[ "$DIL" != "auto" ]]; then
    KOMUT+=(--dil "$DIL")
fi
if [[ "$VAD_KAPALI" == "TRUE" ]]; then
    KOMUT+=(--vad-kapali)
fi
if [[ "$KELIME_ZAMANI" == "TRUE" ]]; then
    KOMUT+=(--kelime-zamani)
fi

VIDEO_ADI="$(basename "$VIDEO_YOLU")"

{
    if [[ "$VENV_AKTIF" -eq 1 ]]; then
        echo "🐍  Sanal ortam aktif: $VIRTUAL_ENV"
    else
        echo "🐍  Python: $(command -v "$PYTHON_BIN")"
    fi
    echo "▶  Komut: ${KOMUT[*]}"
    echo "----------------------------------------------------------------"
    "${KOMUT[@]}" 2>&1
    CIKIS_KODU=$?
    echo "----------------------------------------------------------------"
    if [[ $CIKIS_KODU -eq 0 ]]; then
        echo "✅  Tamamlandı."
    else
        echo "❌  Hata ile sonlandı (çıkış kodu: $CIKIS_KODU)."
    fi
} | yad --text-info \
    --title="$UYGULAMA_ADI — İşleniyor: $VIDEO_ADI" \
    --window-icon="$HOME/.config/subses/subses.png" \
    --width=760 --height=480 \
    --tail \
    --button="Kapat:0" \
    --window-icon="video-x-generic"

# =============================================================================
# AŞAMA 6 — Sonuç bildirimi
# =============================================================================
HEDEF_DOSYA="${VIDEO_YOLU%.*}.${FORMAT}"

if [[ -f "$HEDEF_DOSYA" ]]; then
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -i video-x-generic "$UYGULAMA_ADI" "Altyazı hazır:\n$HEDEF_DOSYA"
    fi
    yad --info --title="$UYGULAMA_ADI" --width="$YAD_GENISLIK" \
        --window-icon="$HOME/.config/subses/subses.png" \
        --text="Altyazı dosyası oluşturuldu:\n\n<b>$HEDEF_DOSYA</b>" \
        --button="Klasörü Aç:2" --button="Tamam:0"

    if [[ $? -eq 2 ]]; then
        xdg-open "$(dirname "$HEDEF_DOSYA")" >/dev/null 2>&1 &
    fi
else
    yad --error --title="$UYGULAMA_ADI" --width="$YAD_GENISLIK" \
        --window-icon="$HOME/.config/subses/subses.png" \
        --text="Beklenen altyazı dosyası bulunamadı:\n$HEDEF_DOSYA\n\nYukarıdaki günlük çıktısını kontrol edin."
fi
