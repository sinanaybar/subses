# SUBSES Kurulum Yapısı

Arşivdeki kaynak klasör adları çalışma zamanı konumu olarak kullanılmaz. Kurulumdan sonra dosyalar şu konumlarda çalışır:

```text
$HOME/.local/bin/
├── subses
├── subses.sh
├── VSub.py
├── VSub.sh
├── dinle.py
└── youtube-subses

$HOME/.local/lib/subses-app/
├── dil.log
├── local_server.py
├── subses.png
├── subses_core.sh
├── youtube-subses-ext.sh
└── eklenti/
    ├── manifest.json
    ├── background.js
    ├── content.js
    ├── popup.html
    ├── popup.js
    └── icons/
```

## Kurulum

Arşivi açtıktan sonra:

```bash
./install.sh
```

PATH'e eklemek gerekirse:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Kalıcı olarak:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Çalıştırma

```bash
subses
```

veya:

```bash
subses.sh
```

VSub:

```bash
VSub.sh
```

Dinle & Yaz:

```bash
python3 "$HOME/.local/bin/dinle.py"
```

YouTube dublaj sunucusu:

```bash
youtube-subses
```

Chrome/Chromium eklentisi olarak şu klasör yüklenmelidir:

```text
$HOME/.local/lib/subses-app/eklenti
```
