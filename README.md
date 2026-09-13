# SUBSES

Linux üzerinde **altyazı çevirisi, metin seslendirme, OCR, otomatik altyazı oluşturma ve YouTube videolarını altyazıya göre seslendirme** işlemlerini bir araya getiren araç seti.

SUBSES; Bash, Python, FFmpeg, SoX, MPV, YAD, Tesseract, `faster-whisper` ve Google Translate/TTS servislerini birlikte kullanır.

> **Platform:** Linux masaüstü  
> **Test edilen ortam:** Manjaro + Xfce  
> Diğer Linux dağıtımlarında paket adları ve masaüstü araçları değişebilir.

---

## İçindekiler

- [Ne Yapabilir?](#ne-yapabilir)
- [Nasıl Çalışır?](#nasıl-çalışır)
- [Proje Yapısı](#proje-yapısı)
- [Gereksinimler](#gereksinimler)
- [Kurulum](#kurulum)
- [PATH Ayarı](#path-ayarı)
- [SUBSES Komutları](#subses-komutları)
- [VSub: Videodan Altyazı Üretme](#vsub-videodan-altyazı-üretme)
- [Dinle & Yaz](#dinle--yaz)
- [YouTube Dublaj Sistemi](#youtube-dublaj-sistemi)
- [Tarayıcı Eklentisi](#tarayıcı-eklentisi)
- [Eklenti Dosyaları Nasıl Çalışıyor?](#eklenti-dosyaları-nasıl-çalışıyor)
- [YouTube Sistemi Nasıl Kullanılır?](#youtube-sistemi-nasıl-kullanılır)
- [Yerel HTTP API](#yerel-http-api)
- [SRT Dosyaları](#srt-dosyaları)
- [Wayland ve X11](#wayland-ve-x11)
- [Sorun Giderme](#sorun-giderme)
- [Güvenlik ve Gizlilik](#güvenlik-ve-gizlilik)
- [Geliştiriciler İçin](#geliştiriciler-için)
- [Lisans](#lisans)

---

# Ne Yapabilir?

SUBSES'i birkaç farklı amaçla kullanabilirsiniz.

### 🎬 Videoyu altyazıya dönüştürme

Bir video veya ses dosyasındaki konuşmaları `faster-whisper` ile algılayıp zaman kodlu SRT/VTT oluşturabilirsiniz.

```bash
python3 ~/.local/bin/VSub.py video.mp4 --model small --dil tr
```

### 🌍 Altyazı çevirme

Mevcut bir SRT dosyasını başka bir dile çevirebilirsiniz.

```bash
subses -c tr film.srt
```

### 🔊 Metni seslendirme

Bir metni Google TTS ile ses dosyasına dönüştürebilirsiniz.

```bash
subses -m tr "Merhaba arkadaşlar" "$HOME/Müzik/merhaba.mp3"
```

### 🗣️ Metni anında okutma

Metni doğrudan MPV üzerinden seslendirebilirsiniz.

```bash
subses -k tr 1.2 "Merhaba, bugün yeni bir konu öğreneceğiz."
```

### 🖼️ Ekrandaki yazıyı OCR ile okuma

Tesseract ile ekrandaki yazıyı algılayıp isteğe bağlı olarak çevirebilir ve seslendirebilirsiniz.

```bash
subses -i -o
```

### ⏱️ Altyazı zamanlamasını düzeltme

Altyazıyı ileri veya geri kaydırabilirsiniz.

```bash
subses -z +1.000 film.srt
```

### ▶️ YouTube videosunu altyazıya göre seslendirme

Tarayıcı eklentisi YouTube oynatma zamanını yerel SUBSES sunucusuna gönderir. Python sunucusu o zamana karşılık gelen altyazıyı bulur ve TTS ile seslendirir.

---

# Nasıl Çalışır?

Özellikle YouTube dublaj özelliğinin çalışma şekli şöyledir:

```text
YouTube videosu
      │
      ▼
Chrome / Chromium
      │
      │ video.currentTime
      ▼
content.js
      │
      │ chrome.runtime.sendMessage()
      ▼
background.js
      │
      │ HTTP POST
      ▼
localhost:8765
      │
      ▼
local_server.py
      │
      │ ilgili saniyedeki altyazıyı bulur
      ▼
subses_core.sh
      │
      │ Google TTS
      ▼
MPV
      │
      ▼
Seslendirilmiş altyazı
```

Buradaki önemli nokta şudur:

**Tarayıcı eklentisi TTS yapmaz.**

Eklenti yalnızca YouTube videosunun hangi saniyede olduğunu yerel Python sunucusuna bildirir. Seslendirme işlemini Linux tarafındaki SUBSES bileşeni gerçekleştirir.

---

# Proje Yapısı

Kaynak proje şu yapıya sahiptir:

```text
.
├── install.sh
├── INSTALL.md
│
└── .local/
    ├── bin/
    │   ├── subses
    │   ├── subses.sh
    │   ├── VSub.py
    │   ├── VSub.sh
    │   ├── dinle.py
    │   └── youtube-subses
    │
    └── lib/
        └── subses-app/
            ├── dil.log
            ├── local_server.py
            ├── subses.png
            ├── subses_core.sh
            └── youtube-subses-ext.sh
```

Kurulumdan sonra bu dosyalar şu konumlara taşınır:

```text
$HOME/.local/bin/
```

ve:

```text
$HOME/.local/lib/subses-app/
```

`install.sh`, kaynak dizindeki `.local` klasörünün içeriğini bu çalışma zamanı konumlarına kopyalar.

---

# Gereksinimler

## Sistem komutları

SUBSES'in ana Bash uygulaması aşağıdaki araçları kullanır:

```text
curl
wget
ffmpeg
yad
flock
perl
sox
tesseract
mpv
socat
yt-dlp
jq
pgrep
```

Pano için oturum tipine göre:

### Wayland

```text
wl-paste
wl-copy
wtype
spectacle
```

### X11

```text
xclip
magick
import
```

Ayrıca `subses` tarafından kullanılan `notify-send`, `tput`, `awk`, `sed`, `grep`, `find`, `stat`, `mktemp` gibi standart sistem araçlarının da sistemde bulunması gerekir.

---

# Kurulum

Projeyi indirdikten sonra proje dizinine girin:

```bash
cd subses
```

Kurulum betiğini çalıştırın:

```bash
./install.sh
```

Kurulum sonunda ana dosyalar:

```text
$HOME/.local/bin/subses
$HOME/.local/bin/subses.sh
$HOME/.local/bin/VSub.py
$HOME/.local/bin/VSub.sh
$HOME/.local/bin/dinle.py
$HOME/.local/bin/youtube-subses
```

ve uygulama dosyaları:

```text
$HOME/.local/lib/subses-app/
```

altına yerleştirilir.

## Kurulum sonrası kontrol

```bash
ls -la "$HOME/.local/bin/"
```

Python dosyalarını kontrol etmek için:

```bash
python3 -m py_compile "$HOME/.local/bin/VSub.py"
python3 -m py_compile "$HOME/.local/bin/dinle.py"
python3 -m py_compile "$HOME/.local/lib/subses-app/local_server.py"
```

Bash dosyalarını kontrol etmek için:

```bash
bash -n "$HOME/.local/bin/subses"
bash -n "$HOME/.local/bin/subses.sh"
bash -n "$HOME/.local/bin/VSub.sh"
bash -n "$HOME/.local/bin/youtube-subses"
bash -n "$HOME/.local/lib/subses-app/subses_core.sh"
bash -n "$HOME/.local/lib/subses-app/youtube-subses-ext.sh"
```

---

# PATH Ayarı

Kurulumdan sonra terminal `subses` komutunu bulamıyorsa `~/.local/bin` PATH içinde değildir.

Geçici olarak:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Kalıcı olarak Bash için:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Kontrol:

```bash
command -v subses
```

Beklenen sonuç:

```text
/home/KULLANICI_ADI/.local/bin/subses
```

---

# SUBSES Komutları

Bu bölümde doğrudan kullanılabilen ana işlemler anlatılmaktadır.

> `-v` ve `-y` gibi sürüm/yardım parametreleri bu README'de ayrıca ele alınmamıştır.

---

## `-s` — SRT'den dublajlı video oluşturma

Bu, SUBSES'in en önemli özelliklerinden biridir.

Elinizde:

```text
video.mp4
video.srt
```

olduğunu düşünelim.

SRT'deki cümleler okunur, Google TTS ile seslendirilir ve sesler altyazı zamanlarına göre videoya yerleştirilir.

Örnek:

```bash
subses -s 'video.srt' tr-1.5 'video.mp4'
```

Buradaki parametreler:

```text
-s
│
├── video.srt  → kullanılacak altyazı
├── tr-1.5     → Türkçe, 1.5 tempo
└── video.mp4  → kaynak video
```

### Neden tempo kullanılıyor?

Örneğin altyazının süresi:

```text
00:01:10,000 --> 00:01:12,000
```

yani yalnızca 2 saniyeyse, bu süre içinde okunması gereken uzun bir cümle olabilir.

Ses 2 saniyeye sığmıyorsa SUBSES konuşmayı hızlandırabilir.

Örneğin:

```bash
subses -s 'video.srt' tr-1.8 'video.mp4'
```

Buradaki `1.8`, önceki örnekteki `1.5` değerinden daha hızlı konuşma anlamına gelir.

### Altyazı kalitesi neden önemli?

Dublaj işlemi altyazı zamanlarına bağlıdır.

Örneğin:

```text
00:01:00,000 --> 00:01:01,000
Çok uzun bir cümle...
```

gibi yalnızca 1 saniyelik bir aralığa çok uzun bir cümle koyarsanız sesin kesilmesi veya hızlandırılması gerekebilir.

Bu nedenle dublajdan önce SRT zamanlamasını kontrol etmek önemlidir.

---

# `-m` — Metni MP3 olarak kaydetme

Bu seçenek bir metni ses dosyası olarak kaydetmek için kullanılır.

GUI ile çalıştırmak:

```bash
subses -m tr
```

Terminalden doğrudan metin ve çıktı dosyası vermek:

```bash
subses -m tr 'Merhaba arkadaşlar' "$HOME/Müzik/merhaba.mp3"
```

Başka bir örnek:

```bash
subses -m en 'Hello everyone' "$HOME/Müzik/hello.mp3"
```

Uzun bir metni dosyaya dönüştürmek istediğinizde bu yöntem kullanılabilir.

---

# `-z` — Altyazıyı ileri/geri kaydırma

Ses ve altyazı arasında sabit bir gecikme varsa `-z` kullanılabilir.

## 1 saniye ileri

```bash
subses -z +1.000 'film.srt'
```

Bu durumda altyazının zamanları 1 saniye ileri taşınır.

## 1.5 saniye geri

```bash
subses -z -1.500 'film.srt'
```

Bu durumda altyazı 1.5 saniye geri taşınır.

## GUI ile kullanmak

Dosya ve süreyi GUI üzerinden seçmek için:

```bash
subses -z
```

### Ne zaman kullanılır?

Ses:

```text
00:01:00
```

noktasında başlıyor, altyazı:

```text
00:01:02
```

noktasında görünüyorsa altyazı yaklaşık 2 saniye geridedir.

Bu durumda:

```bash
subses -z -2.000 film.srt
```

denenebilir.

---

# `-c` — SRT çevirme

Bir SRT dosyasını hedef dile çevirmek için:

```bash
subses -c tr 'film.srt'
```

Burada:

```text
tr
```

hedef dilin Türkçe olduğunu belirtir.

Örneğin Almanca:

```bash
subses -c de 'film.srt'
```

İngilizce:

```bash
subses -c en 'film.srt'
```

## Kaynak dil

Kaynak dilin ayrıca verilmesi gerekmez. SUBSES çeviri isteğinde kaynak dili otomatik algılama (`sl=auto`) kullanır.

---

# `-k` — Metni anında seslendirme

Bu seçenek verilen metni beklemeden seslendirir.

Temel yapı:

```bash
subses -k DİL HIZ "METİN"
```

Örneğin:

```bash
subses -k tr 1.2 "Merhaba arkadaşlar"
```

Burada:

```text
tr   = Türkçe
1.2  = konuşma hızı
```

## İngilizce

```bash
subses -k en 1.0 "Hello everyone"
```

## Daha hızlı konuşma

```bash
subses -k tr 1.8 "Bu cümle daha hızlı okunacak."
```

## Belirli bir süre bekledikten sonra okutma

Negatif bir değer başlangıç gecikmesi olarak kullanılabilir.

Örneğin 3 saniye beklemek:

```bash
subses -k -3 tr 1.5 "Üç saniye sonra okuyacağım."
```

Bu özellik özellikle klavye kısayolu veya başka otomasyonlarla birlikte kullanışlıdır.

## Metni etkileşimli almak

```bash
subses -k tr 1.2
```

Bu kullanımda metin girişini GUI/etkileşimli akış üzerinden sağlayabilirsiniz.

---

# `-t` — Metin çevirme

Bir metni doğrudan çevirmek için:

```bash
subses -t tr "Hello everyone"
```

Sonuç Türkçe olarak üretilir.

Pipe ile:

```bash
echo "Hello everyone" | subses -t tr
```

Bir dosyayı pipe ederek:

```bash
cat metin.txt | subses -t tr
```

Clipboard'daki metni kullanmak için:

```bash
subses -t tr X
```

`X`, mevcut masaüstü oturumunun pano aracından metin alınmasını sağlar.

---

# `-i` — OCR

`-i`, ekrandaki bir görüntüden yazıyı Tesseract ile okumak için kullanılır.

Seslendirme akışı:

```bash
subses -i -o
```

Bildirim olarak metin gösterme:

```bash
subses -i -y
```

OCR ekranında önce OCR dilini, ardından isterseniz hedef dili ve konuşma hızını belirleyebilirsiniz.

Örneğin:

```text
eng tr 1.5
```

şu anlama gelir:

```text
eng → görüntüdeki yazı İngilizce
tr  → sonuç Türkçeye çevrilecek
1.5 → seslendirme hızı
```

## OCR işleminin akışı

```text
Ekran görüntüsü
      ↓
ImageMagick ile görüntü hazırlama
      ↓
Tesseract
      ↓
Metin
      ↓
İsteğe bağlı Google Translate
      ↓
İsteğe bağlı TTS / bildirim
```

---

# `-u` — Altyazı sürelerini metin uzunluğuna göre ayarlama

Bazı altyazı dosyalarında kısa cümlelere çok kısa süre verilmiş olabilir.

`-u`, karakter sayısına göre hedef süre belirlemenizi sağlar.

Örneğin:

```bash
subses -u 01-10-1.000 'film.srt'
```

Bu kural:

```text
1–10 karakter arasındaki altyazılar
→ yaklaşık 1 saniye
```

olarak ayarlanır.

## Birden fazla kural

```bash
subses -u '01-10-1.000 10-20-1.500 20-40-2.000' 'film.srt'
```

Anlamı:

```text
1–10 karakter    → 1.000 saniye
10–20 karakter   → 1.500 saniye
20–40 karakter   → 2.000 saniye
```

Daha ayrıntılı bir örnek:

```bash
subses -u '01-10-1.000 10-20-1.500 20-40-2.250 40-60-3.000 60-70-4.000 70-90-5.000' 'film.srt'
```

SUBSES, belirlenen sürenin sonraki altyazının başlangıcını aşmaması için gerekli durumlarda süreyi sınırlar.

Bu özellik özellikle TTS/dublaj öncesinde kısa altyazıların daha rahat okunabilmesini sağlamak için kullanılabilir.

---

# VSub: Videodan Altyazı Üretme
GUI arayüzünden ve manuel olarak çalışır.

`VSub.py`, video veya ses dosyasındaki konuşmaları `faster-whisper` ile algılar ve zaman kodlu altyazı oluşturur.

En basit kullanım:

```bash
python3 ~/.local/bin/VSub.py video.mp4 --model small
```

Sonuç:

```text
video.srt
```

oluşturulur.

---

## Model seçimi

Desteklenen modeller:

```text
tiny
base
small
medium
large-v2
large-v3
```

### Hızlı işlem

```bash
python3 ~/.local/bin/VSub.py video.mp4 --model tiny
```

### Dengeli kullanım

```bash
python3 ~/.local/bin/VSub.py video.mp4 --model small
```

### Daha yüksek doğruluk

```bash
python3 ~/.local/bin/VSub.py video.mp4 --model medium
```

### Büyük model

```bash
python3 ~/.local/bin/VSub.py video.mp4 --model large-v3
```

Genel olarak model büyüdükçe doğruluk ve kaynak kullanımı artar.

---

## Dil belirtmek

Türkçe konuşma:

```bash
python3 ~/.local/bin/VSub.py video.mp4 \
  --model small \
  --dil tr
```

İngilizce:

```bash
python3 ~/.local/bin/VSub.py video.mp4 \
  --model small \
  --dil en
```

Otomatik dil algılama için `--dil` vermeyebilirsiniz.

---

## VTT üretmek

SRT yerine VTT:

```bash
python3 ~/.local/bin/VSub.py video.mp4 \
  --model small \
  --format vtt
```

---

## CPU kullanmak

```bash
python3 ~/.local/bin/VSub.py video.mp4 \
  --model small \
  --cihaz cpu \
  --hesap-tipi int8
```

Daha düşük kaynak tüketimi gereken sistemlerde iyi bir başlangıçtır.

---

## NVIDIA GPU kullanmak

CUDA:

```bash
python3 ~/.local/bin/VSub.py video.mp4 \
  --model large-v3 \
  --cihaz cuda \
  --hesap-tipi float16
```

NVIDIA GPU'yu kontrol etmek için:

```bash
nvidia-smi
```

GPU kullanımı için uygun NVIDIA sürücüsü ve CUDA çalışma ortamının kurulu olması gerekir.

---

## Beam size

Varsayılan değer:

```text
5
```

Değiştirmek için:

```bash
python3 ~/.local/bin/VSub.py video.mp4 \
  --model small \
  --beam-size 8
```

---

## VAD'i kapatma

Varsayılan sessizlik filtrelemesini kapatmak için:

```bash
python3 ~/.local/bin/VSub.py video.mp4 \
  --model small \
  --vad-kapali
```

---

## Kelime bazlı zaman bilgisi

Kelime seviyesinde zaman damgası da hesaplamak için:

```bash
python3 ~/.local/bin/VSub.py video.mp4 \
  --model small \
  --kelime-zamani
```

Bu seçenek normal altyazı üretimine göre daha fazla işlem gerektirebilir.

---

## Birden fazla dosya

Birden fazla dosyayı tek komutta verebilirsiniz:

```bash
python3 ~/.local/bin/VSub.py \
  video1.mp4 \
  video2.mp4 \
  video3.mp4 \
  --model small
```

Shell joker karakterleri de kullanılabilir:

```bash
python3 ~/.local/bin/VSub.py *.mp4 --model small
```

---

## Klasör izleme

Bir klasöre yeni video geldiğinde otomatik olarak işlemek için:

```bash
python3 ~/.local/bin/VSub.py \
  --izle "$HOME/Videolar" \
  --model small
```

Varsayılan tarama aralığı 30 saniyedir.

10 saniyede bir kontrol etmek için:

```bash
python3 ~/.local/bin/VSub.py \
  --izle "$HOME/Videolar" \
  --tarama-araligi 10 \
  --model small
```

Desteklenen başlıca video uzantıları:

```text
.mp4
.mkv
.mov
.avi
.webm
.m4v
.ts
```

Ses dosyaları da VSub tarafından işlenebilir.

---

# Dinle & Yaz

`dinle.py`, mikrofondan gelen konuşmayı `faster-whisper` ile metne dönüştüren PyQt6 tabanlı uygulamadır.

Çalıştırmak için:

```bash
python3 "$HOME/.local/bin/dinle.py"
```

Temel bileşenleri:

```text
faster-whisper
sounddevice
numpy
PyQt6
```

## İşlem akışı

```text
Mikrofon
   ↓
sounddevice
   ↓
Ses verisi
   ↓
faster-whisper
   ↓
Metin
   ↓
PyQt6 arayüzü
```

Uygulama NVIDIA GPU bulunduğunda CUDA kullanımını kontrol eder; uygun ortam yoksa CPU kullanımına geçebilir.

---

# YouTube Dublaj Sistemi

YouTube entegrasyonu iki ana parçadan oluşur:

```text
1. Chrome/Chromium eklentisi
2. Linux'ta çalışan local_server.py
```

Eklenti YouTube zamanını gönderir.

Python sunucusu bu zamanı alır.

```text
YouTube
   ↓
eklenti/content.js
   ↓
eklenti/background.js
   ↓
HTTP POST
   ↓
localhost:8765
   ↓
local_server.py
   ↓
altyazı eşleştirme
   ↓
subses_core.sh
   ↓
Google TTS
   ↓
MPV
```

---

# Tarayıcı Eklentisi

Eklenti uygulamının bir parçasıdır. Youtube için tasarlanmıştır.

Projenin parçası olan gerçek klasör: eklenti

Bu klasör doğrudan Chrome/Chromium'a "paketlenmemiş uzantı" olarak yüklenebilir.

---

## Eklenti dosya yapısı

```text
eklenti/
├── manifest.json
├── background.js
├── content.js
├── popup.html
├── popup.js
└── icons/
    ├── icon16.png
    ├── icon48.png
    └── icon128.png
```

---

# Eklentiyi Chrome/Chromium'a Kurma

Önce SUBSES kurulumunu tamamlayın:

```bash
./install.sh
```

Ardından Chrome veya Chromium'da uzantı yönetim sayfasını açın.

Chrome:

```text
chrome://extensions/
```

Chromium:

```text
chrome://extensions/
```

Sağ üstten:

```text
Geliştirici modu
```

seçeneğini açın.

Ardından:

```text
Paketlenmemiş öğe yükle
```

seçeneğini kullanın.

Seçmeniz gereken klasör:

```text
eklenti/
```
---

# Eklenti Kullanımı

Eklenti yüklendikten sonra tarayıcı araç çubuğundaki SUBSES simgesini açın.

Popup içerisinde üç temel ayar bulunur:

```text
Durdur / Başlat
Port
Yakın altyazılarda öncekini kes
```

---

## Başlat / Durdur

Eklenti varsayılan olarak aktiftir.

Aktif durumda:

```text
Çalışıyor
```

gösterilir.

Durdurduğunuzda:

```text
Durduruldu
```

gösterilir.

Eklenti durdurulmuşsa `content.js` tarafından gönderilen zaman bilgileri `background.js` tarafından sunucuya gönderilmez.

---

## Port

Varsayılan port:

```text
8765
```

Eklenti:

```text
http://localhost:8765
```

adresine bağlanır.

Örneğin Python sunucusunu 8766 portunda çalıştıracaksanız eklentide de:

```text
8766
```

girip:

```text
Kaydet
```

butonuna basmalısınız.

---

## Yakın altyazılarda öncekini kes

Bu seçenek:

```text
Yakin altyazilarda oncekini kes
```

şeklindedir.

Açık olduğunda yeni bir altyazı geldiğinde önceki seslendirme hâlâ devam ediyorsa önceki TTS işlemi kesilebilir.

Amaç:

```text
Ses 1 ───────────────
       Ses 2 ───────────────
```

şeklindeki üst üste binmeyi azaltmaktır.

Ayar kapalıysa mevcut seslendirme mümkün olduğunca devam eder.

Bu ayar `chrome.storage.local` içinde saklanır.

---

# Eklenti Dosyaları Nasıl Çalışıyor?

## `manifest.json`

Eklentinin Chrome/Chromium yapılandırmasıdır.

Manifest sürümü:

```text
Manifest V3
```

Eklentinin adı:

```text
YouTube Subses Zaman Takibi
```

İzinler:

```json
"permissions": [
  "storage",
  "notifications"
]
```

Yerel sunucu erişimi:

```json
"host_permissions": [
  "http://localhost/*"
]
```

YouTube sayfalarında çalışan script:

```json
"content_scripts": [
  {
    "matches": ["*://www.youtube.com/watch*"],
    "js": ["content.js"],
    "run_at": "document_idle"
  }
]
```

Arka plan servisi:

```json
"background": {
  "service_worker": "background.js"
}
```

Bu nedenle eklenti yalnızca YouTube izleme sayfalarında `content.js` çalıştırır.

---

# `content.js`

`content.js` doğrudan YouTube sayfasında çalışır.

Görevi:

**YouTube video oynatıcısının `currentTime` değerini okumaktır.**

Ana video elementi birkaç farklı selector ile aranır:

```text
#movie_player video.html5-main-video
.html5-video-player video.html5-main-video
video.html5-main-video
#movie_player video
video
```

Bu, YouTube'un HTML yapısında değişiklik olduğunda videoyu bulma ihtimalini artırır.

## Zaman gönderme aralığı

Script her:

```text
500 ms
```

de bir kontrol yapar.

Ancak her 500 ms'de HTTP isteği göndermez.

Örneğin video:

```text
10.10
10.60
11.10
11.60
```

şeklinde ilerliyorsa `Math.floor()` kullanıldığı için aynı saniye içinde tekrar tekrar gönderim yapılmaz.

Yaklaşık olarak:

```text
10
11
12
13
...
```

saniye değişimlerinde mesaj gönderilir.

Gönderilen mesaj:

```javascript
{
  type: "time",
  time: t,
  url: location.href
}
```

şeklindedir.

Video duraklatılmışsa:

```text
video.paused
```

veya kullanıcı seek yapıyorsa:

```text
video.seeking
```

zaman gönderilmez.

---

# `background.js`

`background.js`, eklentinin yerel sunucuyla iletişim kuran bölümüdür.

`content.js` doğrudan localhost'a HTTP isteği göndermez.

Akış:

```text
content.js
   ↓
chrome.runtime.sendMessage()
   ↓
background.js
   ↓
fetch()
   ↓
localhost
```

## Varsayılan ayarlar

```javascript
enabled: true
port: 8765
interruptOnOverlap: true
lastConnState: "unknown"
```

Bu ayarlar `chrome.storage.local` üzerinden saklanır.

---

## `/time` isteği

Video zamanı geldiğinde:

```text
POST http://localhost:8765/time
```

gönderilir.

Gönderilen JSON mantıksal olarak:

```json
{
  "type": "time",
  "time": 123.45,
  "url": "https://www.youtube.com/watch?v=..."
}
```

şeklindedir.

---

## `/control` isteği

Kullanıcı eklentiyi durdurduğunda:

```text
POST /control
```

gönderilir.

Örnek gövde:

```json
{
  "enabled": false
}
```

Başlatıldığında:

```json
{
  "enabled": true
}
```

gönderilir.

---

## `/settings` isteği

Çakışma davranışı değiştirildiğinde:

```text
POST /settings
```

gönderilir.

Örneğin:

```json
{
  "interrupt_on_overlap": true
}
```

---

## Bağlantı durumu

Eklenti yerel sunucuya ulaşamadığında bildirim gösterebilir:

```text
Yerel uygulamaya bağlanılamadı
```

Bağlantı tekrar kurulduğunda:

```text
Yerel uygulamaya bağlantı kuruldu.
```

bildirimi gönderilir.

Durum ayrıca:

```text
lastConnState
```

adıyla kaydedilir.

---

# `popup.html`

Eklentinin kullanıcı arayüzüdür.

Popup içerisinde:

```text
Başlat / Durdur
Bağlantı durumu
Port
Kaydet
Çakışan altyazıları kes seçeneği
```

bulunur.

Arayüz özellikle küçük bir tarayıcı popup'ı için tasarlanmıştır.

---

# `popup.js`

`popup.js`, popup'taki kontrollerin davranışını yönetir.

Örneğin Başlat/Durdur butonuna basıldığında:

```text
chrome.storage.local
        ↓
ayar güncelleme
        ↓
chrome.runtime.sendMessage()
        ↓
background.js
        ↓
local_server.py
```

akışı oluşur.

Port değiştirildiğinde:

```text
1. Port değeri kontrol edilir.
2. 1–65535 arasında olması gerekir.
3. storage'a kaydedilir.
4. background.js'e bildirilir.
```

Çakışma seçeneği değiştirildiğinde de yeni değer hem kaydedilir hem Python sunucusuna iletilir.

---

# YouTube Sistemi Nasıl Kullanılır?

Aşağıdaki örnek, sistemi baştan sona gösterir.

## 1. SUBSES'i kurun

```bash
./install.sh
```

## 2. PATH'i ayarlayın

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## 3. YouTube dublaj uygulamasını başlatın

```bash
youtube-subses
```

Bu yardımcı script gerekli SRT dosyasını seçmenizi ve dil/hız gibi ayarları yapmanızı sağlar.

## 4. Eklentiyi Chrome'a yükleyin

Şu klasörü seçin:

```text
eklenti/
```

## 5. YouTube'da video açın

Örneğin:

```text
https://www.youtube.com/watch?v=VIDEO_ID
```

## 6. Eklentiyi aktif edin

Popup'ta:

```text
Çalışıyor
```

durumunu görün.

## 7. Portu kontrol edin

Varsayılan:

```text
8765
```

Eklenti ve Python sunucusunda aynı port kullanılmalıdır.

---

# Yerel HTTP API

`local_server.py`, tarayıcı eklentisiyle SUBSES arasında köprü görevi görür.

Temel endpoint'ler:

```text
POST /time
POST /control
POST /settings
```

Sunucuyu elle başlatmak için:

```bash
python3 "$HOME/.local/lib/subses-app/local_server.py" \
  --log /tmp/sub.log \
  --port 8765 \
  --lang tr \
  --speed 1.5 \
  --drift 4.0
```

Parametreler:

| Parametre | Açıklama |
|---|---|
| `--log` | Altyazı zaman/metin logu |
| `--port` | HTTP portu |
| `--lang` | TTS dili |
| `--speed` | MPV seslendirme hızı |
| `--drift` | Çok geride kalan altyazının atlanma eşiği |

---

## `/time` testi

Sunucu çalışıyorsa:

```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  -d '{"time":120.5}' \
  http://localhost:8765/time
```

Bu istek:

```text
video şu anda 120.5 saniyede
```

bilgisini gönderir.

---

## `/control` ile dublajı durdurma

```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  -d '{"enabled":false}' \
  http://localhost:8765/control
```

Tekrar başlatma:

```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  -d '{"enabled":true}' \
  http://localhost:8765/control
```

---

## `/settings` ile çakışma davranışı

Önceki konuşmayı yeni altyazı geldiğinde kesmek:

```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  -d '{"interrupt_on_overlap":true}' \
  http://localhost:8765/settings
```

Kapatmak:

```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  -d '{"interrupt_on_overlap":false}' \
  http://localhost:8765/settings
```

---

# Drift Nedir?

Drift, videonun mevcut zamanı ile altyazının zamanı arasındaki farktır.

Örneğin:

```text
Video zamanı:      105 saniye
Altyazı zamanı:    100 saniye
Fark:                5 saniye
```

Sunucuyu:

```bash
--drift 4
```

ile çalıştırdıysanız 5 saniyelik fark eşikten büyük olduğu için bu altyazının artık okunmaması tercih edilebilir.

Amaç, kullanıcı videoyu ileri sardığında eski altyazıların arka arkaya okunmasını engellemektir.

---

# Geri Sarma / Seek

Kullanıcı videoda geri sararsa sistem bunu da dikkate alır.

Örneğin video:

```text
100 saniye
```

civarındayken:

```text
40 saniye
```

noktasına geri alınırsa daha önce okunmuş altyazıların durumu temizlenebilir.

Böylece geri sarılan bölüm tekrar oynatıldığında ilgili altyazılar tekrar seslendirilebilir.

---

# SRT Dosyaları

SUBSES'in birçok özelliği SRT zamanlamasına bağlıdır.

Örnek SRT:

```srt
1
00:00:01,000 --> 00:00:03,500
Hello everyone.

2
00:00:04,000 --> 00:00:07,000
Welcome to the video.

3
00:00:08,000 --> 00:00:11,500
Today we will learn something new.
```

SRT'de temel olarak:

```text
altyazı numarası
başlangıç --> bitiş
metin
```

bulunur.

## Dublaj için iyi SRT

İyi bir dublaj altyazısında:

```text
metin uzunluğu
      +
zaman aralığı
```

birbiriyle uyumlu olmalıdır.

Örneğin 50 karakterlik bir cümleyi:

```text
00:01:00,000 --> 00:01:00,500
```

gibi yalnızca 500 ms'lik aralığa koymak TTS açısından problem oluşturabilir.

---

# Wayland ve X11

SUBSES masaüstü oturumunu kontrol ederek bazı araçları değiştirir.

Oturum tipini görmek için:

```bash
echo "$XDG_SESSION_TYPE"
```

---

## Wayland

Pano:

```text
wl-paste
wl-copy
```

Metin girişi:

```text
wtype
```

Ekran görüntüsü:

```text
spectacle
```

Örneğin Arch/Manjaro'da:

```bash
sudo pacman -S wl-clipboard wtype spectacle
```

---

## X11

Pano:

```text
xclip
```

ImageMagick araçları:

```text
magick
import
```

Örneğin:

```bash
sudo pacman -S xclip imagemagick
```

---

# Sorun Giderme

## `subses: command not found`

Önce:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Kontrol:

```bash
command -v subses
```

---

## Eksik sistem paketi

SUBSES eksik bağımlılıkları kontrol eder.

Örneğin:

```bash
ffmpeg --version
```

```bash
mpv --version
```

```bash
sox --version
```

```bash
tesseract --version
```

```bash
yad --version
```

komutlarını ayrı ayrı test edebilirsiniz.

---

## FFmpeg yok

Arch/Manjaro:

```bash
sudo pacman -S ffmpeg
```

Debian/Ubuntu:

```bash
sudo apt install ffmpeg
```

---

## MPV yok

Arch/Manjaro:

```bash
sudo pacman -S mpv
```

Debian/Ubuntu:

```bash
sudo apt install mpv
```

---

## YAD yok

Arch/Manjaro:

```bash
sudo pacman -S yad
```

Debian/Ubuntu:

```bash
sudo apt install yad
```

---

## Tesseract yok

Arch/Manjaro:

```bash
sudo pacman -S tesseract
```

Dil paketlerini de sisteminizin paket yöneticisine göre kurun.

---

## VSub `faster-whisper` bulamıyor

```bash
python3 -m pip install faster-whisper
```

Sanal ortam kullanmak isterseniz:

```bash
python3 -m venv "$HOME/.venvs/subses"
source "$HOME/.venvs/subses/bin/activate"
pip install --upgrade pip
pip install faster-whisper
```

---

## CUDA çalışmıyor

Önce:

```bash
nvidia-smi
```

Ardından CPU ile test edin:

```bash
python3 "$HOME/.local/bin/VSub.py" \
  video.mp4 \
  --model small \
  --cihaz cpu \
  --hesap-tipi int8
```

CPU çalışıyor ancak CUDA çalışmıyorsa sorun büyük ihtimalle NVIDIA/CUDA/CTranslate2 ortamındadır.

---

## YouTube eklentisi bağlanamıyor

Eklenti popup'ında:

```text
Yerel uygulamaya bağlanılamıyor
```

görüyorsanız şu sırayla kontrol edin.

### 1. Sunucu çalışıyor mu?

```bash
pgrep -af local_server.py
```

### 2. Port açık mı?

```bash
ss -ltnp | grep 8765
```

### 3. Eklentideki port doğru mu?

Varsayılan:

```text
8765
```

### 4. Python sunucusunu manuel test edin

```bash
python3 "$HOME/.local/lib/subses-app/local_server.py" \
  --log /tmp/sub.log \
  --port 8765 \
  --lang tr \
  --speed 1.5 \
  --drift 4
```

---

# Eklenti Debugging

Chrome/Chromium:

```text
chrome://extensions/
```

adresini açın.

SUBSES eklentisini bulun.

Buradan:

```text
Service worker
```

veya ilgili inceleme/debug seçeneğini açarak `background.js` hatalarını görebilirsiniz.

YouTube sekmesinde geliştirici araçlarını açarak `content.js` kaynaklı sorunları da kontrol edebilirsiniz.

Özellikle kontrol edilmesi gerekenler:

```text
content.js çalışıyor mu?
        ↓
background.js mesaj alıyor mu?
        ↓
localhost:8765 erişilebilir mi?
        ↓
local_server.py çalışıyor mu?
```

---

# Güvenlik ve Gizlilik

## Google Translate / TTS

Çeviri ve TTS işlemleri Google servislerine HTTP istekleri gönderir.

Bu nedenle SUBSES tamamen offline bir uygulama değildir.

Özellikle:

```text
subses -c
subses -t
subses -m
subses -k
subses -s
```

gibi işlemlerde işlenen metin Google servislerine gönderilebilir.

Gizli veya hassas metinleri bu servislerle işlerken bunu göz önünde bulundurun.

---

## Yerel HTTP sunucusu

YouTube entegrasyonu:

```text
localhost
```

üzerinden çalışır.

Varsayılan port:

```text
8765
```

Sunucuyu internete açacak şekilde reverse proxy, port forwarding veya farklı bind yapılandırmaları kullanacaksanız güvenlik değerlendirmesi yapmanız gerekir.

---

## Dinle & Yaz komut çalıştırma özelliği

`dinle.py` içerisinde konuşma metninden komut çalıştırmaya yönelik özellikler bulunduğundan, bu özelliği güvenilmeyen ses girişleriyle kullanırken dikkatli olun.

Konuşma çıktısını doğrudan shell komutu gibi çalıştırmak güvenlik riski oluşturabilir.

---

# Geçici Dosyalar

SUBSES çalışma sırasında `/tmp` altında geçici dosyalar oluşturur.

Önemli çalışma dizinleri:

```text
/tmp/ses/
```

ve VSub için:

```text
/tmp/video2altyazi/
```

SRT/dublaj işlemlerinde ayrıca:

```text
/tmp/ses.XXXXXX/
```

şeklinde geçici çalışma dizinleri oluşturulabilir.

İşlem tamamlandığında mümkün olduğunca temizlenir.

Eski geçici çalışma dizinleri de belirli durumlarda otomatik olarak temizlenir.

---

# Eşzamanlı İşlemler

SUBSES bazı işlemlerin aynı anda birden fazla kez çalışmasını önlemek için lock dosyaları kullanır.

Örnek:

```text
/tmp/ses/subses.lock
/tmp/ses/subses-c.lock
/tmp/ses/subses-i.lock
/tmp/ses/subses-u.lock
/tmp/ses/subses-z.lock
```

Bu nedenle aynı işlemi ikinci kez başlatmaya çalıştığınızda uygulama mevcut işlemin çalıştığını belirtebilir.

---

# Performans Önerileri

## VSub için

Daha hızlı:

```bash
python3 "$HOME/.local/bin/VSub.py" \
  video.mp4 \
  --model tiny
```

Dengeli:

```bash
python3 "$HOME/.local/bin/VSub.py" \
  video.mp4 \
  --model small
```

Yüksek doğruluk:

```bash
python3 "$HOME/.local/bin/VSub.py" \
  video.mp4 \
  --model medium
```

Güçlü NVIDIA GPU:

```bash
python3 "$HOME/.local/bin/VSub.py" \
  video.mp4 \
  --model large-v3 \
  --cihaz cuda \
  --hesap-tipi float16
```

---

# Tipik Kullanım Senaryosu

Bir İngilizce videoyu Türkçe altyazı ve TTS dublajına hazırlamak için örnek akış:

## 1. Videodan altyazı çıkar

```bash
python3 "$HOME/.local/bin/VSub.py" \
  video.mp4 \
  --model small \
  --dil en
```

Sonuç:

```text
video.srt
```

## 2. Türkçeye çevir

```bash
subses -c tr video.srt
```

## 3. Gerekirse zamanlamayı düzelt

Örneğin altyazıyı 750 ms geri almak:

```bash
subses -z -0.750 video.srt
```

## 4. Kısa altyazıların sürelerini düzenle

```bash
subses -u '01-10-1.000 10-20-1.500 20-40-2.000' video.srt
```

## 5. Dublaj oluştur

```bash
subses -s video.srt tr-1.5 video.mp4
```

Genel akış:

```text
video.mp4
   ↓
faster-whisper
   ↓
video.srt
   ↓
Google Translate
   ↓
Türkçe altyazı
   ↓
zamanlama düzenleme
   ↓
Google TTS
   ↓
dublaj
```

---

# Geliştiriciler İçin

Kaynak kodunda değişiklik yaptıktan sonra syntax kontrolleri çalıştırmanız önerilir.

## Bash

```bash
bash -n .local/bin/subses
bash -n .local/bin/subses.sh
bash -n .local/bin/VSub.sh
bash -n .local/bin/youtube-subses
bash -n .local/lib/subses-app/subses_core.sh
bash -n .local/lib/subses-app/youtube-subses-ext.sh
```

## Python

```bash
python3 -m py_compile .local/bin/VSub.py
python3 -m py_compile .local/bin/dinle.py
python3 -m py_compile .local/lib/subses-app/local_server.py
```

## Chrome eklentisi

Eklenti için:

```text
eklenti/
```

klasörü doğrudan Chrome/Chromium'un geliştirici modundaki:

```text
Paketlenmemiş öğe yükle
```

özelliğiyle yüklenebilir.

Eklenti değiştirildikten sonra:

```text
chrome://extensions/
```

sayfasından eklentiyi yeniden yükleyebilirsiniz.

---

# Lisans

Bu proje arşivinde ayrı bir `LICENSE` dosyası bulunmamaktadır.

GitHub'a yayınlamadan önce bir lisans seçmeniz önerilir.

Örneğin MIT lisansı kullanacaksanız repository köküne:

```text
LICENSE
```

dosyasını ekleyebilirsiniz.

---

# Kısa Komut Referansı

## SRT dublaj

```bash
subses -s 'video.srt' tr-1.5 'video.mp4'
```

## Metni MP3 yap

```bash
subses -m tr 'Merhaba dünya' "$HOME/Müzik/merhaba.mp3"
```

## SRT'yi ileri kaydır

```bash
subses -z +1.000 'video.srt'
```

## SRT'yi geri kaydır

```bash
subses -z -1.500 'video.srt'
```

## SRT çevir

```bash
subses -c tr 'video.srt'
```

## Metni seslendir

```bash
subses -k tr 1.2 'Merhaba arkadaşlar'
```

## OCR + seslendirme

```bash
subses -i -o
```

## Metin çevir

```bash
subses -t tr 'Hello everyone'
```

## Pipe ile çevir

```bash
echo 'Hello everyone' | subses -t tr
```

## SRT sürelerini düzenle

```bash
subses -u '01-10-1.000 10-20-1.500 20-40-2.000' 'video.srt'
```

## Videodan SRT

```bash
python3 "$HOME/.local/bin/VSub.py" \
  video.mp4 \
  --model small
```

## Videodan VTT

```bash
python3 "$HOME/.local/bin/VSub.py" \
  video.mp4 \
  --model small \
  --format vtt
```

## CUDA

```bash
python3 "$HOME/.local/bin/VSub.py" \
  video.mp4 \
  --model large-v3 \
  --cihaz cuda \
  --hesap-tipi float16
```

## Dinle & Yaz

```bash
python3 "$HOME/.local/bin/dinle.py"
```

## YouTube sistemi

```bash
youtube-subses
```

## HTTP sunucusunu manuel başlat

```bash
python3 "$HOME/.local/lib/subses-app/local_server.py" \
  --log /tmp/sub.log \
  --port 8765 \
  --lang tr \
  --speed 1.5 \
  --drift 4.0
```

---

# Sonuç

SUBSES'i kullanarak Linux üzerinde şu zinciri tek bir proje içinde kurabilirsiniz:

```text
Video
  ↓
VSub / faster-whisper
  ↓
SRT
  ↓
Çeviri
  ↓
Zamanlama düzenleme
  ↓
Google TTS
  ↓
Dublaj
```

YouTube tarafında ise:

```text
YouTube
  ↓
Chrome / Chromium eklentisi
  ↓
Video zamanı
  ↓
localhost:8765
  ↓
local_server.py
  ↓
SUBSES
  ↓
Google TTS
  ↓
MPV
  ↓
Anlık dublaj
```

Eklenti bu sistemin ayrılmaz bir parçasıdır ve kaynak projede:

```text
eklenti/
```

klasörü altında yer alır.
