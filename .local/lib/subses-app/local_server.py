#!/usr/bin/env python3
"""
local_server.py --log sub.log --port 8765 --lang tr --speed 1.5 --drift 4.0

Sadece Python standart kutuphanesini kullanir, ekstra "pip install"
GEREKMEZ. Eklentiden (background.js) POST /time olarak gelen zaman
bilgisini dinler, sub.log ile eslesince gomulu subses_core.sh
icindeki OKU fonksiyonunu calistirir.

Zamanlama senkronizasyonu:
  OKU cagirisi metni seslendirirken gercek zaman harcar. Ardisik
  repliklerin toplam okuma suresi, videonun gercek akis hizindan uzun
  surerse gecikme birikir ve buyur. Bunu onlemek icin:
    - Ayni anda sadece TEK bir replik konusulur (sirali, cakismasiz).
    - Bir replik konusulmayi bekleyen SIRADAYKEN video ondan --drift
      saniyeden fazla ileri gittiyse, o replik ATLANIR ve en guncel
      esleseni okumaya gecilir; boylece gecikme sonsuza kadar buyumez.

Durdur / Baslat:
  Eklenti popup'indan "Durdur" tiklaninca background.js POST /control
  ile {"enabled": false} gonderir. Bu durumda:
    - O an konusmakta olan surec (bash + OKU + mpv) tum surec
      GRUBUYLA birlikte aninda sonlandirilir.
    - Yeni eslesmeler "Baslat"a basilana kadar islenmez.
"""
import argparse
import json
import os
import signal
import subprocess
import threading
import time as time_module
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SUBSES_CORE = os.path.join(SCRIPT_DIR, "subses_core.sh")


def load_sub_map(path):
    sub_map = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            sec, _, text = line.partition("_")
            try:
                sub_map[int(sec)] = text
            except ValueError:
                continue
    return sub_map


class SharedState:
    SEEK_BACK_THRESHOLD = 0.75  # bu kadar saniyeden fazla geriye gidis = gercek bir geri sarma

    def __init__(self, lang, speed, max_drift):
        self.lock = threading.Lock()
        self.latest_video_time = 0.0
        self.pending = None       # (sec, text) - konusulmayi bekleyen SON eslesme
        self.fired = set()        # daha once kuyruga alinmis saniyeler
        self.lang = lang
        self.speed = speed
        self.max_drift = max_drift
        self.enabled = True       # Durdur/Baslat durumu
        self.current_proc = None  # su an calisan subprocess.Popen (varsa)
        self.interrupt_on_overlap = True  # kisa araliklarda oncekini kes

    def on_time_update(self, t):
        # BUG DUZELTMESI (1/2): eskiden burada sadece "t suanki
        # degerden BUYUKSE" guncelleniyordu (monotonik artan
        # varsayimi). Video ILERI sarilinca bu deger yukseliyor ama
        # GERI sarilinca hic DUSMUYORDU. Sonuc: geri sardiktan (veya
        # ileri sarip normal izlemeye devam ettikten) sonra her yeni
        # eslesmenin "drift"i (latest_video_time - sec) YAPAY olarak
        # devasa cikiyor, bu da --drift esigini asip TUM sonraki
        # repliklerin surekli "atlandi" olarak gecilmesine yol
        # aciyordu. Simdi video nerede oldugunu her zaman doğru
        # yansitmasi icin YONE BAKMAKSIZIN guncelleniyor.
        #
        # BUG DUZELTMESI (2/2): "fired" (okundu) kaydi sunucu
        # calistigi surece KALICIYDI - bir replik bir kez okununca bir
        # daha ASLA tetiklenmiyordu. Kullanici GERI SARIP o sahneyi
        # tekrar izlemek istediginde, dublaj o bolgeyi "zaten okudum"
        # sanip sessiz kaliyor, ancak GERI SARMADAN ONCEKI (henuz
        # okunmamis) noktaya tekrar ulasilana kadar hicbir sey
        # okunmuyordu. Video zamaninin BELIRGIN sekilde GERIYE
        # gittigini (gercek bir seek/rewind - kucuk oynatma
        # titremeleri degil) tespit edince, "okundu" kaydini
        # temizleyip o bolgenin yeniden seslendirilebilmesini
        # sagliyoruz.
        with self.lock:
            if t < self.latest_video_time - self.SEEK_BACK_THRESHOLD:
                self.fired.clear()
                self.pending = None
            self.latest_video_time = t

    def offer_match(self, sec, text):
        # BUG/OZELLIK: eskiden yeni bir eslesme gelince sadece 'pending'
        # degeri degistiriliyordu; su an KONUSMAKTA olan onceki replik
        # bitene kadar calmaya devam ediyordu. Zaman araligi kisa
        # altyazilarda bu, onceki seslendirmenin YENI altyazinin
        # zaman dilimine tasip UST USTE binmesine / karismasina yol
        # aciyordu. "interrupt_on_overlap" acikken, yeni bir eslesme
        # geldiginde o an calan surec ANINDA kesilip yenisine gecilir.
        proc_to_interrupt = None
        with self.lock:
            if not self.enabled:
                return
            if sec in self.fired:
                return
            self.fired.add(sec)
            self.pending = (sec, text)  # eskisi konusulmadiysa uzerine yazilir (atlanir)
            if self.interrupt_on_overlap and self.current_proc is not None:
                proc_to_interrupt = self.current_proc
        if proc_to_interrupt is not None:
            _kill_process_group(proc_to_interrupt)

    def take_pending(self):
        with self.lock:
            if not self.enabled:
                return None, self.latest_video_time
            item = self.pending
            self.pending = None
            return item, self.latest_video_time

    def set_enabled(self, enabled):
        proc_to_kill = None
        with self.lock:
            self.enabled = enabled
            if not enabled:
                self.pending = None
                proc_to_kill = self.current_proc
        if proc_to_kill is not None:
            _kill_process_group(proc_to_kill)

    def set_current_proc(self, proc):
        with self.lock:
            self.current_proc = proc

    def set_interrupt_on_overlap(self, value):
        with self.lock:
            self.interrupt_on_overlap = bool(value)

    def is_enabled(self):
        with self.lock:
            return self.enabled


def _kill_process_group(proc: subprocess.Popen):
    """bash + onun cocuklarini (mpv, wget...) TUM GRUP olarak sonlandirir."""
    try:
        pgid = os.getpgid(proc.pid)
        os.killpg(pgid, signal.SIGTERM)
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            os.killpg(pgid, signal.SIGKILL)
        except KeyboardInterrupt:
            # Kullanici temizlik beklerken sabirsizca ikinci kez Ctrl+C
            # bastiysa: bekleme yerine hemen SIGKILL ile kes, cikisi
            # tamamla, ustune traceback firlatma.
            os.killpg(pgid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass


def worker_loop(state: SharedState, stop_event: threading.Event):
    while not stop_event.is_set():
        if not state.is_enabled():
            time_module.sleep(0.2)
            continue

        item, latest = state.take_pending()
        if item is None:
            time_module.sleep(0.15)
            continue

        sec, text = item
        drift = latest - sec
        if drift > state.max_drift:
            print(f"[atlandi] {sec}s cok geride kaldi (video su an: {latest:.1f}s, fark: {drift:.1f}s)")
            continue

        print(f"[{sec}s] {text}")
        # Harici 'subses' komutu yerine gomulu subses_core.sh icindeki
        # OKU fonksiyonu 'bash -c' ile kaynak gosterilip cagriliyor.
        # Metin $1/$2/$3 pozisyonel parametre olarak gectigi icin
        # shell injection riski yok. os.setsid ile ayri bir surec
        # grubunda baslatiliyor ki "durdur" tiklaninca mpv dahil tum
        # alt surecler tek seferde oldurulebilsin.
        proc = subprocess.Popen(
            ["bash", "-c", 'source "$0"; OKU "$1" "$2" "$3"',
             SUBSES_CORE, state.lang, str(state.speed), text],
            preexec_fn=os.setsid,
            stdin=subprocess.DEVNULL,
        )
        state.set_current_proc(proc)
        proc.wait()
        state.set_current_proc(None)


def make_handler(sub_map: dict, state: SharedState):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            pass

        def _cors(self):
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")

        def do_OPTIONS(self):
            self.send_response(204)
            self._cors()
            self.end_headers()

        def _read_json(self):
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length)
            return json.loads(raw)

        def do_POST(self):
            if self.path == "/time":
                self._handle_time()
            elif self.path == "/control":
                self._handle_control()
            elif self.path == "/settings":
                self._handle_settings()
            else:
                self.send_response(404)
                self._cors()
                self.end_headers()

        def _handle_time(self):
            try:
                msg = self._read_json()
            except json.JSONDecodeError:
                self.send_response(400)
                self._cors()
                self.end_headers()
                return

            try:
                t = float(msg.get("time", -1))
            except (TypeError, ValueError):
                t = -1.0

            if t >= 0:
                state.on_time_update(t)
                sec = int(t)
                if sec in sub_map:
                    state.offer_match(sec, sub_map[sec])

            self.send_response(204)
            self._cors()
            self.end_headers()

        def _handle_control(self):
            try:
                msg = self._read_json()
            except json.JSONDecodeError:
                self.send_response(400)
                self._cors()
                self.end_headers()
                return

            enabled = bool(msg.get("enabled", True))
            state.set_enabled(enabled)
            print("[kontrol] " + ("baslatildi" if enabled else "durduruldu"))

            self.send_response(204)
            self._cors()
            self.end_headers()

        def _handle_settings(self):
            try:
                msg = self._read_json()
            except json.JSONDecodeError:
                self.send_response(400)
                self._cors()
                self.end_headers()
                return

            if "interrupt_on_overlap" in msg:
                value = bool(msg["interrupt_on_overlap"])
                state.set_interrupt_on_overlap(value)
                print("[ayar] cakisma onleme: " + ("acik" if value else "kapali"))

            self.send_response(204)
            self._cors()
            self.end_headers()

    return Handler


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", required=True, help="sub.log dosya yolu")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--lang", default="tr")
    parser.add_argument("--speed", default="1.5")
    parser.add_argument("--drift", type=float, default=4.0,
                         help="Video bu kadar saniyeden fazla ilerlediyse bekleyen replik atlanir")
    args = parser.parse_args()

    sub_map = load_sub_map(args.log)
    state = SharedState(args.lang, args.speed, args.drift)

    stop_event = threading.Event()
    worker = threading.Thread(target=worker_loop, args=(state, stop_event), daemon=True)
    worker.start()

    handler_cls = make_handler(sub_map, state)
    try:
        server = ThreadingHTTPServer(("localhost", args.port), handler_cls)
    except OSError as e:
        print(f"HATA: {args.port} portunda sunucu baslatilamadi: {e}")
        print(f"Ipucu: bu port zaten kullaniliyor olabilir - eskiden acilmis bir "
              f"dublaj uygulamasi hala calisiyor olabilir, ya da baska bir program "
              f"ayni portu kullaniyordur. Farkli bir port deneyin ya da eski "
              f"sureci sonlandirin (orn. 'pkill -f local_server.py').")
        raise SystemExit(1)

    def _handle_term(signum, frame):
        # SIGTERM'i de KeyboardInterrupt gibi ele al ki `kill` ile
        # kapatildiginda da ayni temiz kapanis yolu calissin.
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, _handle_term)

    print(f"HTTP sunucu localhost:{args.port} adresinde dinliyor... (Ctrl+C ile durdur)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        # BUG DUZELTMESI: eskiden burada sadece stop_event set ediliyor,
        # o an calisan (bash + OKU + mpv) sureci hic oldurulmuyordu.
        # Worker thread daemon oldugu icin Python cikiyordu ama alt
        # surecler YETIM kalip terminale bagli sekilde calismaya devam
        # ediyor, bu da terminalin "kilitlenmis" gibi gorunmesine
        # (kapanmayan siddetin stdin/stdout'u tutmasina) yol aciyordu.
        stop_event.set()
        try:
            with state.lock:
                proc_to_kill = state.current_proc
            if proc_to_kill is not None:
                _kill_process_group(proc_to_kill)
            server.server_close()
        except KeyboardInterrupt:
            # Sabirsizca ikinci/ucuncu Ctrl+C: traceback basmadan sessizce cik.
            pass
        print("Sunucu ve alt surecler temiz sekilde kapatildi.")


if __name__ == "__main__":
    main()
