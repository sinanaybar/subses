#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Dinle & Yaz
- Çalıştığı bilgisayarı otomatik algılar.
- Kendi .venv sanal ortamını ve Python paketlerini kurar.
- NVIDIA GPU varsa CUDA/cuBLAS/cuDNN ortamını otomatik hazırlar.
- PortAudio eksikse Linux paket yöneticisi üzerinden kurmayı dener.
- GPU yoksa CPU moduna otomatik düşer.
- Konuşmayı sürekli metne çevirir.
- İsteğe bağlı olarak son bulunan metni "Çalıştır" ile komut olarak çalıştırır.

Not: "Çalıştır" özelliği yalnızca açıkça etkinleştirildiğinde komut çalıştırır.
Konuşmadan gelen metin doğrudan shell'e gönderilebildiği için bu seçenek bilinçli
olarak opt-in bırakılmıştır.
"""

import os
import sys
import subprocess
import venv
import shutil
import ctypes.util
import platform
import re
import shlex
import time
import queue
import threading
import collections
import datetime
from pathlib import Path


# ----------------------------------------------------------------------
# TEMEL YOLLAR / KURULUM
# ----------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
VENV_DIR = SCRIPT_DIR / ".venv"
SUBSES_APP_DIR = Path.home() / ".local" / "lib" / "subses-app"
TRANSCRIPT_FILE = SUBSES_APP_DIR / "transkript.txt"
MODEL_DIR = SUBSES_APP_DIR / "models"

REQUIRED_PACKAGES = [
    "faster-whisper",
    "sounddevice",
    "numpy",
    "PyQt6",
]

# GPU varsa faster-whisper'ın güncel CUDA 12 yolunu kullan.
NVIDIA_PACKAGES = [
    "nvidia-cublas-cu12",
    "nvidia-cudnn-cu12>=9,<10",
]


def venv_python_path() -> str:
    if os.name == "nt":
        return str(VENV_DIR / "Scripts" / "python.exe")
    return str(VENV_DIR / "bin" / "python")


def run_quiet(cmd, check=False):
    try:
        return subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=check,
        )
    except (FileNotFoundError, OSError, subprocess.SubprocessError):
        return None


def has_nvidia_gpu() -> bool:
    if not shutil.which("nvidia-smi"):
        return False
    result = run_quiet(
        [
            "nvidia-smi",
            "--query-gpu=name",
            "--format=csv,noheader",
        ]
    )
    return bool(result and result.returncode == 0 and result.stdout.strip())


def nvidia_info():
    """GPU adı, VRAM ve sürücü bilgisini mümkün olduğunca al."""
    if not shutil.which("nvidia-smi"):
        return None

    result = run_quiet(
        [
            "nvidia-smi",
            "--query-gpu=name,memory.total,driver_version",
            "--format=csv,noheader,nounits",
        ]
    )
    if not result or result.returncode != 0:
        return None

    line = result.stdout.strip().splitlines()[0] if result.stdout.strip() else ""
    parts = [p.strip() for p in line.split(",")]
    if len(parts) < 3:
        return {"name": line, "vram_mb": 0, "driver": ""}

    try:
        vram = int(float(parts[1]))
    except ValueError:
        vram = 0

    return {"name": parts[0], "vram_mb": vram, "driver": parts[2]}


def install_linux_system_dependency():
    """
    sounddevice için PortAudio yoksa uygun paket yöneticisiyle kurmayı dener.
    Root değilsek sudo kullanır; sudo yoksa sadece hata döndürür.
    """
    if platform.system() != "Linux":
        return True

    if ctypes.util.find_library("portaudio"):
        return True

    print("[kurulum] PortAudio bulunamadı; sistem paketi kurulmaya çalışılıyor...")

    candidates = []
    if shutil.which("pacman"):
        candidates.append(["pacman", "-S", "--needed", "--noconfirm", "portaudio"])
    elif shutil.which("apt-get"):
        candidates.append(["apt-get", "update"])
        candidates.append(["apt-get", "install", "-y", "libportaudio2"])
    elif shutil.which("dnf"):
        candidates.append(["dnf", "install", "-y", "portaudio"])
    elif shutil.which("yum"):
        candidates.append(["yum", "install", "-y", "portaudio"])
    elif shutil.which("zypper"):
        candidates.append(["zypper", "--non-interactive", "install", "portaudio"])

    if not candidates:
        print("[uyarı] Desteklenen paket yöneticisi bulunamadı.")
        return False

    def privileged(cmd):
        if os.geteuid() == 0:
            return cmd
        if shutil.which("sudo"):
            return ["sudo"] + cmd
        return cmd

    for raw_cmd in candidates:
        cmd = privileged(raw_cmd)
        result = run_quiet(cmd)
        if result is None:
            continue
        if result.returncode == 0:
            print("[kurulum] PortAudio hazır.")
        else:
            # apt update başarısız olsa bile bir sonraki install adımına geç.
            print(f"[uyarı] Sistem paketi komutu başarısız: {' '.join(cmd)}")
        if ctypes.util.find_library("portaudio"):
            return True

    return bool(ctypes.util.find_library("portaudio"))


def find_nvidia_library_dirs():
    """
    NVIDIA Python paketlerinin lib klasörlerini güvenli şekilde bulur.

    Önemli: nvidia.cublas.lib.__file__ bir namespace package olduğu için None
    olabilir. Bu nedenle __path__[0] kullanılır.
    """
    dirs = []

    try:
        import importlib

        for module_name in (
            "nvidia.cublas.lib",
            "nvidia.cudnn.lib",
            "nvidia.cuda_nvrtc.lib",
        ):
            try:
                module = importlib.import_module(module_name)
                module_paths = getattr(module, "__path__", None)
                if module_paths:
                    for item in module_paths:
                        p = Path(item)
                        if p.is_dir():
                            dirs.append(str(p))
            except Exception:
                pass
    except Exception:
        pass

    # Ek güvenlik: site-packages/nvidia altındaki tüm lib klasörlerini tara.
    try:
        import site

        roots = []
        roots.extend(site.getsitepackages())
        user_site = site.getusersitepackages()
        if user_site:
            roots.append(user_site)

        for root in roots:
            nvidia_root = Path(root) / "nvidia"
            if nvidia_root.is_dir():
                for p in nvidia_root.glob("*/lib"):
                    if p.is_dir():
                        dirs.append(str(p))
    except Exception:
        pass

    # Sıralı ve benzersiz.
    unique = []
    for d in dirs:
        if d not in unique:
            unique.append(d)
    return unique


def configure_cuda_environment():
    """NVIDIA wheel kütüphanelerini Python başlamadan önce yükleyici yoluna ekler."""
    if platform.system() != "Linux":
        return []

    dirs = find_nvidia_library_dirs()
    if not dirs:
        return []

    current = os.environ.get("LD_LIBRARY_PATH", "")
    current_parts = [p for p in current.split(":") if p]

    merged = []
    for p in dirs + current_parts:
        if p and p not in merged:
            merged.append(p)

    os.environ["LD_LIBRARY_PATH"] = ":".join(merged)
    return dirs


def _missing_required_packages(vpy: str):
    """Gerekli paketleri tek tek kontrol eder; yalnızca eksikleri döndürür."""
    checks = {
        "faster-whisper": "import faster_whisper",
        "sounddevice": "import sounddevice",
        "numpy": "import numpy",
        "PyQt6": "import PyQt6",
    }
    missing = []
    for package, import_stmt in checks.items():
        probe = subprocess.run(
            [vpy, "-c", import_stmt],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if probe.returncode != 0:
            missing.append(package)
    return missing


def _missing_nvidia_packages(vpy: str):
    """CUDA Python paketlerini ayrı ayrı kontrol eder."""
    checks = {
        "nvidia-cublas-cu12": "import nvidia.cublas.lib",
        "nvidia-cudnn-cu12": "import nvidia.cudnn.lib",
    }
    missing = []
    for package, import_stmt in checks.items():
        probe = subprocess.run(
            [vpy, "-c", import_stmt],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if probe.returncode != 0:
            missing.append(package)
    return missing


def ensure_python_packages(use_gpu: bool):
    vpy = venv_python_path()

    # Önce mevcut .venv'i kullan. Varsa silme veya başka bir sanal ortam oluşturma.
    # Sadece Python çalıştırılabiliyor mu ve gerekli paketler mevcut mu kontrol edilir.
    if not Path(vpy).exists():
        print("[kurulum] .venv bulunamadı; oluşturuluyor...")
        venv.EnvBuilder(with_pip=True, clear=False).create(str(VENV_DIR))
    else:
        print("[kurulum] Mevcut .venv kullanılıyor.")

    missing = _missing_required_packages(vpy)
    if missing:
        print("[kurulum] Eksik Python paketleri: " + ", ".join(missing))
        subprocess.check_call([vpy, "-m", "pip", "install", "--upgrade", "pip", "-q"])
        # Yalnızca gerçekten eksik olan paketleri kur.
        package_specs = {name: spec for name, spec in zip(
            ["faster-whisper", "sounddevice", "numpy", "PyQt6"],
            REQUIRED_PACKAGES,
        )}
        subprocess.check_call(
            [vpy, "-m", "pip", "install", "-q"]
            + [package_specs[name] for name in missing]
        )
    else:
        print("[kurulum] Gerekli Python paketleri hazır.")

    if use_gpu:
        missing_cuda = _missing_nvidia_packages(vpy)
        if missing_cuda:
            print("[kurulum] Eksik NVIDIA CUDA paketleri: " + ", ".join(missing_cuda))
            cuda_specs = {
                "nvidia-cublas-cu12": "nvidia-cublas-cu12",
                "nvidia-cudnn-cu12": "nvidia-cudnn-cu12>=9,<10",
            }
            subprocess.check_call(
                [vpy, "-m", "pip", "install", "-q"]
                + [cuda_specs[name] for name in missing_cuda]
            )
        else:
            print("[kurulum] NVIDIA CUDA Python paketleri hazır.")

def bootstrap():
    gpu = has_nvidia_gpu()

    if platform.system() == "Linux":
        install_linux_system_dependency()

    ensure_python_packages(gpu)

    # Venv içindeki Python'a geçmeden önce gerekli NVIDIA dizinlerini mümkün
    # olduğunca bul; venv ilk kez oluşturulduysa bir sonraki çalışmada kesinleşir.
    vpy = venv_python_path()

    if os.path.abspath(sys.executable) != os.path.abspath(vpy):
        env = os.environ.copy()
        env["_DINLE_BOOTSTRAPPED"] = "1"

        # NVIDIA wheel dizinlerini venv içindeki Python ile bul.
        probe = subprocess.run(
            [
                vpy,
                "-c",
                (
                    "import os,site,pathlib; "
                    "r=[]; "
                    "[(r.append(str(p))) for s in site.getsitepackages() "
                    "for p in pathlib.Path(s).glob('nvidia/*/lib') if p.is_dir()]; "
                    "print(':'.join(dict.fromkeys(r)))"
                ),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env,
        )

        if probe.returncode == 0 and probe.stdout.strip():
            parts = [p for p in probe.stdout.strip().split(":") if p]
            old = env.get("LD_LIBRARY_PATH", "")
            env["LD_LIBRARY_PATH"] = ":".join(
                list(dict.fromkeys(parts + [p for p in old.split(":") if p]))
            )

        os.execve(vpy, [vpy] + sys.argv, env)


if not os.environ.get("_DINLE_BOOTSTRAPPED"):
    os.environ["_DINLE_BOOTSTRAPPED"] = "1"
    bootstrap()

# Venv'e geçildikten sonra CUDA yollarını kesin olarak hazırla.
CUDA_LIB_DIRS = configure_cuda_environment()


# ----------------------------------------------------------------------
# ARTIK KURULU ORTAMDAYIZ
# ----------------------------------------------------------------------
import numpy as np
import sounddevice as sd
from faster_whisper import WhisperModel

from PyQt6.QtWidgets import (
    QApplication,
    QMainWindow,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QPushButton,
    QLabel,
    QTextEdit,
    QGroupBox,
    QCheckBox,
    QComboBox,
    QMessageBox,
    QFrame,
    QDialog,
    QFormLayout,
)
from PyQt6.QtCore import QTimer, Qt, QSettings
from PyQt6.QtGui import QPainter, QPen, QColor, QFont, QIcon


# Konuşma dili seçenekleri. Whisper, seçili dili bilirse otomatik dil
# tahmini yapmadığı için benzer diller arasında yanlış algılama azalır.
LANGUAGE_OPTIONS = [
    ("Türkçe", "tr"),
    ("English", "en"),
    ("Deutsch", "de"),
    ("Français", "fr"),
    ("Español", "es"),
    ("Italiano", "it"),
    ("Русский", "ru"),
    ("Polski", "pl"),
    ("العربية", "ar"),
    ("中文", "zh"),
    ("日本語", "ja"),
    ("한국어", "ko"),
    ("Nederlands", "nl"),
    ("Português", "pt"),
]

# ----------------------------------------------------------------------
# DONANIM / MODEL AYARLARI
# ----------------------------------------------------------------------
GPU_INFO = nvidia_info()
GPU_AVAILABLE = bool(GPU_INFO)
DEVICE = "cuda" if GPU_AVAILABLE else "cpu"

MODEL_DIR.mkdir(parents=True, exist_ok=True)

# Her uygulama açılışında önceki transkript temizlenir; oturum temiz başlar.
TRANSCRIPT_FILE.parent.mkdir(parents=True, exist_ok=True)
try:
    TRANSCRIPT_FILE.write_text("", encoding="utf-8")
except OSError as e:
    print(f"[uyarı] transkript.txt temizlenemedi: {e}")

MODEL_OPTIONS = [
    ("tiny", "Tiny"),
    ("base", "Base"),
    ("small", "Small"),
    ("medium", "Medium"),
    ("large-v3", "Large v3"),
]

def recommended_model():
    if GPU_INFO:
        vram = GPU_INFO.get("vram_mb", 0)
        if vram >= 10000:
            return "large-v3"
        if vram >= 6000:
            return "medium"
        if vram >= 3500:
            return "small"
        if vram >= 2000:
            return "base"
        return "tiny"
    return "small"

def supported_cuda_compute_type():
    """Bu makinedeki CTranslate2 CUDA backend'inin gerçekten desteklediği türü seç."""
    if DEVICE != "cuda":
        return "int8"
    try:
        import ctranslate2
        supported = set(ctranslate2.get_supported_compute_types("cuda"))
        # Önce verimli seçenekleri dene; yalnızca gerçekten destekleniyorsa seç.
        for candidate in ("float16", "int8_float16", "int8", "float32"):
            if candidate in supported:
                return candidate
    except Exception:
        pass
    # Backend sorgulanamıyorsa güvenli CUDA seçeneği. Yükleme sırasında hata olursa CPU fallback var.
    return "float16"


def compute_type_for_model(model_name):
    return supported_cuda_compute_type()


MODEL_SIZE = recommended_model()
COMPUTE_TYPE = compute_type_for_model(MODEL_SIZE)
ICON_PATH = SUBSES_APP_DIR / "subses.png"

SAMPLE_RATE = 16000
FRAME_MS = 30
FRAME_SAMPLES = int(SAMPLE_RATE * FRAME_MS / 1000)

VAD_THRESHOLD = 0.015
SILENCE_TIMEOUT_MS = 240
PADDING_MS = 180
MAX_SEGMENT_SEC = 6
WAVEFORM_HISTORY = 150

# Komut çalıştırma varsayılan olarak kapalıdır.
COMMAND_EXECUTION_ENABLED = False


class WaveformWidget(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedHeight(48)
        self.levels = collections.deque(
            [0.0] * WAVEFORM_HISTORY, maxlen=WAVEFORM_HISTORY
        )
        self.setStyleSheet(
            "background:#10151c; border:1px solid #293241; border-radius:10px;"
        )

    def push_level(self, value: float):
        self.levels.append(value)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        w = self.width()
        h = self.height()
        mid = h / 2

        painter.setPen(QPen(QColor("#293241"), 1))
        painter.drawLine(0, int(mid), w, int(mid))

        n = len(self.levels)
        if n < 2:
            return

        step = w / (n - 1)
        painter.setPen(QPen(QColor("#55d187"), 2))

        top = []
        bottom = []
        for i, lvl in enumerate(self.levels):
            x = i * step
            y1 = mid - (lvl * mid * 0.9)
            y2 = mid + (lvl * mid * 0.9)
            top.append((x, y1))
            bottom.append((x, y2))

        for i in range(n - 1):
            painter.drawLine(
                int(top[i][0]), int(top[i][1]),
                int(top[i + 1][0]), int(top[i + 1][1])
            )
            painter.drawLine(
                int(bottom[i][0]), int(bottom[i][1]),
                int(bottom[i + 1][0]), int(bottom[i + 1][1])
            )


class DinleUygulamasi(QMainWindow):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("Dinle & Yaz")
        if ICON_PATH.is_file():
            self.setWindowIcon(QIcon(str(ICON_PATH)))
        self.resize(330, 190)
        self.setMinimumSize(300, 175)

        self.model = None
        self.model_name = None
        self.model_loading = False
        self._model_load_id = 0
        self.settings_store = QSettings("subses-app", "dinle-yaz")
        self.selected_model = self.settings_store.value("model", MODEL_SIZE, type=str)
        if self.selected_model not in {name for name, _ in MODEL_OPTIONS}:
            self.selected_model = MODEL_SIZE
        self.stream = None
        self.worker_thread = None
        self.stop_flag = threading.Event()
        self._capture_paused = False

        self.audio_q = queue.Queue()
        self.level_q = queue.Queue()
        self.text_q = queue.Queue()
        self.status_q = queue.Queue()

        self.last_text = ""
        self.copy_check = QCheckBox()
        self.copy_check.setChecked(self.settings_store.value("copy_enabled", False, type=bool))
        self.command_check = QCheckBox()
        self.command_check.setChecked(self.settings_store.value("command_enabled", False, type=bool))
        self.command_edit = QTextEdit()
        stored_command = self.settings_store.value("command", "", type=str)
        if not stored_command or stored_command == "subses -t tr {text}":
            stored_command = "subses -k ja 1.4 {text}"
        self.command_edit.setPlainText(stored_command)
        self.selected_language = self.settings_store.value("language", "tr", type=str)
        if self.selected_language not in {code for _, code in LANGUAGE_OPTIONS}:
            self.selected_language = "tr"
        self._text_open = False
        self._build_ui()

        self.poll_timer = QTimer(self)
        self.poll_timer.timeout.connect(self._poll_queues)
        self.poll_timer.start(30)

        QTimer.singleShot(250, self._load_model_async)

    # ------------------------------------------------------------------
    # ARAYÜZ
    # ------------------------------------------------------------------
    def _build_ui(self):
        self.setStyleSheet("""
            QMainWindow, QWidget { background:#0b0f14; color:#e6edf3; font-size:11px; }
            QPushButton {
                background:#238636; color:white; border:0; border-radius:7px;
                padding:8px 12px; font-weight:700;
            }
            QPushButton:hover:!disabled { background:#2ea043; }
            QPushButton:disabled { background:#252b33; color:#68717c; }
            QPushButton#stopBtn { background:#30363d; }
            QPushButton#settingsBtn { background:#30363d; }
            QPushButton#textBtn { background:#21262d; }
            QDialog { background:#0b0f14; color:#e6edf3; }
            QComboBox, QTextEdit {
                background:#0d1117; color:#d8dee4; border:1px solid #293241;
                border-radius:7px; padding:5px;
            }
            QCheckBox { color:#b8c0ca; spacing:6px; }
            QLabel { color:#b8c0ca; }
        """)

        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        layout.setContentsMargins(7, 7, 7, 7)
        layout.setSpacing(5)

        # Ana kumandalar: yalnızca istenen üç düğme.
        button_row = QHBoxLayout()
        button_row.setSpacing(5)

        self.start_btn = QPushButton("BAŞLA")
        self.start_btn.setEnabled(False)
        self.start_btn.clicked.connect(self.start)

        self.stop_btn = QPushButton("DUR")
        self.stop_btn.setObjectName("stopBtn")
        self.stop_btn.setEnabled(False)
        self.stop_btn.clicked.connect(self.stop)

        self.settings_btn = QPushButton("AYARLAR")
        self.settings_btn.setObjectName("settingsBtn")
        self.settings_btn.clicked.connect(self._show_settings)

        button_row.addWidget(self.start_btn, 1)
        button_row.addWidget(self.stop_btn, 1)
        button_row.addWidget(self.settings_btn, 1)
        layout.addLayout(button_row)

        # Ses çizgisi: mevcut WaveformWidget'e dokunulmadı.
        self.waveform = WaveformWidget()
        layout.addWidget(self.waveform)

        # Metin alanı açılır/kapanır. Başlangıçta kapalı ve pencere küçüktür.
        self.text_btn = QPushButton("METİN  ▸")
        self.text_btn.setObjectName("textBtn")
        self.text_btn.clicked.connect(self._toggle_text)
        layout.addWidget(self.text_btn)

        self.text_edit = QTextEdit()
        self.text_edit.setReadOnly(True)
        self.text_edit.setMinimumHeight(120)
        self.text_edit.setPlaceholderText("Konuşma metni")
        self.text_edit.hide()
        layout.addWidget(self.text_edit)

        self.status_label = QLabel("")
        self.status_label.setWordWrap(True)
        self.status_label.hide()

    def _show_settings(self):
        dialog = QDialog(self)
        dialog.setWindowTitle("Ayarlar")
        dialog.setMinimumWidth(330)

        layout = QVBoxLayout(dialog)
        form = QFormLayout()
        form.setSpacing(8)

        model_combo = QComboBox()
        for name, label in MODEL_OPTIONS:
            model_combo.addItem(label, name)
        model_combo.setCurrentIndex(max(0, model_combo.findData(self.selected_model)))
        form.addRow("Model", model_combo)

        copy_check = QCheckBox("Panoya kopyala")
        copy_check.setChecked(self.copy_check.isChecked() if hasattr(self, 'copy_check') else False)
        form.addRow(copy_check)

        command_check = QCheckBox("Çalıştır aktif")
        command_check.setChecked(self.command_check.isChecked() if hasattr(self, 'command_check') else False)
        form.addRow(command_check)

        language_combo = QComboBox()
        for name, code in LANGUAGE_OPTIONS:
            language_combo.addItem(name, code)
        idx = max(0, language_combo.findData(self.selected_language))
        language_combo.setCurrentIndex(idx)
        form.addRow("Dil", language_combo)

        command_edit = QTextEdit()
        command_edit.setFixedHeight(55)
        command_edit.setPlainText(self.command_edit.toPlainText() if hasattr(self, 'command_edit') else "subses -k ja 1.4 {text}")
        form.addRow("Komut", command_edit)

        layout.addLayout(form)

        close_btn = QPushButton("KAPAT")
        close_btn.clicked.connect(dialog.accept)
        layout.addWidget(close_btn)

        def apply_settings():
            new_model = model_combo.currentData()
            self.selected_language = language_combo.currentData()
            if hasattr(self, 'copy_check'):
                self.copy_check.setChecked(copy_check.isChecked())
            else:
                self.copy_check = QCheckBox()
                self.copy_check.setChecked(copy_check.isChecked())
            if hasattr(self, 'command_check'):
                self.command_check.setChecked(command_check.isChecked())
            else:
                self.command_check = QCheckBox()
                self.command_check.setChecked(command_check.isChecked())
            if hasattr(self, 'command_edit'):
                self.command_edit.setPlainText(command_edit.toPlainText().strip())
            else:
                self.command_edit = QTextEdit()
                self.command_edit.setPlainText(command_edit.toPlainText().strip())

            self.settings_store.setValue("model", new_model)
            self.settings_store.setValue("language", self.selected_language)
            self.settings_store.setValue("copy_enabled", copy_check.isChecked())
            self.settings_store.setValue("command_enabled", command_check.isChecked())
            self.settings_store.setValue("command", command_edit.toPlainText().strip())
            self.selected_model = new_model
            if new_model != self.model_name:
                self.stop()
                self._load_model_async(new_model)

        dialog.accepted.connect(apply_settings)
        dialog.exec()

    def _toggle_text(self):
        self._text_open = not self._text_open
        self.text_edit.setVisible(self._text_open)
        self.text_btn.setText("METİN  ▾" if self._text_open else "METİN  ▸")
        if self._text_open:
            self.resize(max(self.width(), 330), 360)
        else:
            self.resize(self.width(), 190)

    def _command_toggle_changed(self, state):
        pass

    # ------------------------------------------------------------------
    # MODEL
    # ------------------------------------------------------------------
    def _load_model_async(self, model_name=None):
        model_name = model_name or self.selected_model
        self._model_load_id += 1
        load_id = self._model_load_id
        self.model_loading = True
        self.model = None
        self.model_name = None
        self.start_btn.setEnabled(False)
        self.stop_btn.setEnabled(False)

        def worker():
            try:
                compute_type = compute_type_for_model(model_name)
                print(f"[bilgi] '{model_name}' modeli yükleniyor/indiriliyor (device={DEVICE}, compute_type={compute_type})...")
                loaded = WhisperModel(model_name, device=DEVICE, compute_type=compute_type, download_root=str(MODEL_DIR))

                if load_id != self._model_load_id:
                    return
                self.model = loaded
                self.model_name = model_name
                self.model_loading = False
                self.status_q.put(f"Hazır — {model_name} / {DEVICE} / {compute_type}. BAŞLA'ya basın.")
            except Exception as e:
                if load_id != self._model_load_id:
                    return
                # CUDA başarısızsa aynı seçili modeli CPU'da dene.
                if DEVICE == "cuda":
                    try:
                        print(f"[uyarı] CUDA başlatılamadı: {e!r}; CPU deneniyor...")
                        loaded = WhisperModel(model_name, device="cpu", compute_type="int8", download_root=str(MODEL_DIR))
                        if load_id != self._model_load_id:
                            return
                        self.model = loaded
                        self.model_name = model_name
                        self.model_loading = False
                        self.status_q.put(f"Hazır — {model_name} / CPU / int8. BAŞLA'ya basın.")
                        return
                    except Exception as cpu_error:
                        e = cpu_error
                self.model_loading = False
                self.status_q.put(f"Model yüklenemedi: {e}")

        threading.Thread(target=worker, daemon=True).start()

    # ------------------------------------------------------------------
    # SES
    # ------------------------------------------------------------------
    def _audio_callback(self, indata, frames, time_info, status):
        if status:
            self.status_q.put(f"Ses aygıtı: {status}")

        data = bytes(indata)
        if self._capture_paused:
            return
        self.audio_q.put(data)

        samples = np.frombuffer(data, dtype=np.int16).astype(np.float32)
        rms = np.sqrt(np.mean(samples ** 2)) / 32768.0 if len(samples) else 0.0
        self.level_q.put(min(rms * 4, 1.0))

    def _frame_generator(self):
        while not self.stop_flag.is_set():
            try:
                yield self.audio_q.get(timeout=0.1)
            except queue.Empty:
                continue

    @staticmethod
    def _is_speech(frame: bytes) -> bool:
        samples = np.frombuffer(frame, dtype=np.int16).astype(np.float32)
        if len(samples) == 0:
            return False
        rms = np.sqrt(np.mean(samples ** 2)) / 32768.0
        return rms > VAD_THRESHOLD

    def _vad_collector(self, frames):
        num_padding_frames = max(1, int(PADDING_MS / FRAME_MS))
        ring_buffer = collections.deque(maxlen=num_padding_frames)
        triggered = False
        voiced_frames = []
        num_silence_frames_needed = max(1, int(SILENCE_TIMEOUT_MS / FRAME_MS))
        silence_count = 0
        segment_start_time = None

        for frame in frames:
            if len(frame) != FRAME_SAMPLES * 2:
                continue

            is_speech = self._is_speech(frame)

            if not triggered:
                ring_buffer.append((frame, is_speech))
                num_voiced = sum(1 for _, s in ring_buffer if s)

                if num_voiced > 0.6 * ring_buffer.maxlen:
                    triggered = True
                    segment_start_time = time.time()
                    voiced_frames.extend(f for f, _ in ring_buffer)
                    ring_buffer.clear()
            else:
                voiced_frames.append(frame)
                silence_count = silence_count + 1 if not is_speech else 0
                elapsed = time.time() - segment_start_time

                if (
                    silence_count >= num_silence_frames_needed
                    or elapsed >= MAX_SEGMENT_SEC
                ):
                    triggered = False
                    silence_count = 0
                    segment_bytes = b"".join(voiced_frames)
                    voiced_frames = []
                    yield segment_bytes

    def _worker_loop(self):
        with open(TRANSCRIPT_FILE, "a", encoding="utf-8") as logf:
            for segment_bytes in self._vad_collector(self._frame_generator()):
                if self.stop_flag.is_set():
                    break

                audio_np = (
                    np.frombuffer(segment_bytes, dtype=np.int16).astype(np.float32)
                    / 32768.0
                )

                if len(audio_np) < SAMPLE_RATE * 0.3:
                    continue

                try:
                    segments, info = self.model.transcribe(
                        audio_np,
                        beam_size=1,
                        best_of=1,
                        vad_filter=True,
                        condition_on_previous_text=False,
                        without_timestamps=True,
                        language=self.selected_language,
                    )
                    text = "".join(s.text for s in segments).strip()
                except Exception as e:
                    self.status_q.put(f"Transkripsiyon hatası: {e}")
                    continue

                if not text:
                    continue

                ts = datetime.datetime.now().strftime("%H:%M:%S")
                line = f"[{ts}] ({info.language}) {text}"

                self.text_q.put(line)
                logf.write(line + "\n")
                logf.flush()

    # ------------------------------------------------------------------
    # BAŞLAT / DURDUR
    # ------------------------------------------------------------------
    def start(self):
        if self.model is None:
            QMessageBox.warning(self, "Hazır değil", "Model henüz hazır değil.")
            return

        try:
            self.stop_flag.clear()

            self.stream = sd.RawInputStream(
                samplerate=SAMPLE_RATE,
                blocksize=FRAME_SAMPLES,
                dtype="int16",
                channels=1,
                callback=self._audio_callback,
            )
            self.stream.start()

            self.worker_thread = threading.Thread(
                target=self._worker_loop,
                daemon=True,
            )
            self.worker_thread.start()

            self.start_btn.setEnabled(False)
            self.stop_btn.setEnabled(True)
            self.status_label.setText(
                "Dinleniyor... Konuşun. DUR ile durdurabilirsiniz."
            )

        except Exception as e:
            self.stream = None
            self.status_label.setText(f"Mikrofon başlatılamadı: {e}")
            QMessageBox.critical(
                self,
                "Mikrofon hatası",
                str(e),
            )

    def stop(self):
        self.stop_flag.set()

        if self.stream:
            try:
                self.stream.stop()
                self.stream.close()
            except Exception:
                pass
            self.stream = None

        self.start_btn.setEnabled(self.model is not None)
        self.stop_btn.setEnabled(False)

        if self.model is not None:
            self.status_label.setText("Durduruldu. Tekrar BAŞLA'ya basabilirsiniz.")

    # ------------------------------------------------------------------
    # KOMUTU OTOMATİK ÇALIŞTIR
    # ------------------------------------------------------------------
    def _clear_audio_queue(self):
        """Komut başlamadan önce bekleyen eski mikrofon karelerini temizler."""
        try:
            while True:
                self.audio_q.get_nowait()
        except queue.Empty:
            pass

    def _pause_audio_capture(self):
        """Harici uygulamanın ürettiği sesin Whisper'a ulaşmasını engeller."""
        self._capture_paused = True
        self._clear_audio_queue()

    def _resume_audio_capture(self):
        """Harici uygulama bittikten sonra mikrofonu tekrar açar."""
        self._clear_audio_queue()
        self._capture_paused = False

    def run_last_text(self):
        """Son metni kullanıcı tanımlı komuta gönderir.

        Örnek:
            subses -k ja 1.4 {text}

        {text}, tek bir komut satırı argümanı olarak son konuşma metniyle değiştirilir.
        Komut çalıştığı sürece mikrofon yakalama durdurulur.
        """
        if not self.command_check.isChecked():
            return

        text = self.last_text.strip()
        template = self.command_edit.toPlainText().strip()

        if not text or not template or "{text}" not in template:
            return

        try:
            # Şablondaki {text} alanını tek bir güvenli argv elemanı yap.
            command_line = template.replace("{text}", shlex.quote(text))
            argv = shlex.split(command_line)
        except ValueError as e:
            self.status_q.put(f"Komut biçimi hatası: {e}")
            return

        if not argv:
            return

        # Komut çalışırken ikinci bir metin komutu tetiklenmesin.
        if self._capture_paused:
            return

        self._pause_audio_capture()
        self.status_q.put("Komut çalışıyor — mikrofon geçici olarak susturuldu.")

        def runner():
            try:
                subprocess.run(
                    argv,
                    shell=False,
                    cwd=str(SCRIPT_DIR),
                    env=os.environ.copy(),
                    check=False,
                )
            except FileNotFoundError:
                self.status_q.put(
                    f"Uygulama bulunamadı: {argv[0]} — PATH veya tam yolu kontrol edin."
                )
            except Exception as e:
                self.status_q.put(f"Komut çalıştırma hatası: {e}")
            finally:
                # Hoparlördeki son ses/yankının mikrofona girmemesi için bekle.
                time.sleep(0.4)
                self._resume_audio_capture()
                if not self.stop_flag.is_set():
                    self.status_q.put("Dinleme tekrar aktif.")

        threading.Thread(target=runner, daemon=True).start()

    # ------------------------------------------------------------------
    # UI KUYRUKLARI
    # ------------------------------------------------------------------
    def _poll_queues(self):
        updated_levels = False

        while not self.level_q.empty():
            self.waveform.push_level(self.level_q.get())
            updated_levels = True

        if updated_levels:
            self.waveform.update()

        while not self.text_q.empty():
            line = self.text_q.get()
            self.last_text = re.sub(r"^\[\d{2}:\d{2}:\d{2}\]\s+\([^)]*\)\s*", "", line)
            self.text_edit.append(line)

            if self.copy_check.isChecked() and self.last_text:
                # Panoya kopyala aktifse bulunan her yeni metni otomatik kopyalar.
                QApplication.clipboard().setText(self.last_text)

            if self.command_check.isChecked():
                # Çalıştır aktif ise bulunan her yeni metni otomatik gönder.
                self.run_last_text()

        while not self.status_q.empty():
            self.status_label.setText(self.status_q.get())

            if self.model is not None:
                self.start_btn.setEnabled(True)

    def closeEvent(self, event):
        self.stop()
        event.accept()


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Dinle & Yaz")
    win = DinleUygulamasi()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
