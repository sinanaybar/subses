#!/usr/bin/env bash

set -e
set -u
SH="$HOME/.local/bin/VSub.sh"
DiN="$HOME/.local/bin/dinle.py"
LOCKFILE="/tmp/subses.lock"
exec 200>"$LOCKFILE"
if ! flock -n 200; then
    yad --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
        --window-icon="$HOME/.local/lib/subses-app/subses.png" \
        --text "SUBSES VSub seçeneği zaten çalışıyor...\!\nDevam edilsin mi?" \
        --button=HAYIR:1 --button=EVET:0 --buttons-layout=center
    if [[ $? -ne 0 ]]; then
        exit 0
    fi
fi

if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
  PANO_ARAC="xclip"
else
  export GDK_BACKEND=wayland
  PANO_ARAC="wl-paste"
fi

# Gerekli yardımcı uyg kontrol işlemi.
gereksinim_kontrol() {
  local eksik=()
  local cmd

  # Basit komut adı == görüntü adı olan, oturumdan bağımsız araçlar
  for cmd in curl wget ffmpeg yad flock perl sox tesseract mpv socat yt-dlp jq pgrep; do
    command -v "$cmd" >/dev/null 2>&1 || eksik+=("$cmd")
  done

  command -v "$PANO_ARAC" >/dev/null 2>&1 || eksik+=("$PANO_ARAC")

  # wtype - spectacle sadece wayland altında, ydotool'a ek olarak gerekiyor.
  if [[ "$XDG_SESSION_TYPE" != "x11" ]]; then
    command -v wtype >/dev/null 2>&1 || eksik+=("wtype")
    command -v spectacle >/dev/null 2>&1 || eksik+=("spectacle")
  else
    command -v magick >/dev/null 2>&1 || eksik+=("magick")
    command -v import >/dev/null 2>&1 || eksik+=("import")
  fi

  command -v subses >/dev/null 2>&1 || eksik+=("subses (PATH içinde bulunamadı)")

  test -f "$HOME/.local/bin/subses" || eksik+=("$HOME/.local/bin/subses")
  test -f "$HOME/.local/bin/subses.sh" || eksik+=("$HOME/.local/bin/subses.sh")
  test -f "$HOME/.local/bin/VSub.py" || eksik+=("$HOME/.local/bin/VSub.py")
  test -f "$HOME/.local/bin/VSub.sh" || eksik+=("$HOME/.local/bin/VSub.sh")
  test -f "$HOME/.local/bin/youtube-subses" || eksik+=("$HOME/.local/bin/youtube-subses")
  test -f "$HOME/.local/lib/subses-app/subses.png" || eksik+=("$HOME/.local/lib/subses-app/subses.png")
  test -f "$HOME/.local/lib/subses-app/dil.log" || eksik+=("$HOME/.local/lib/subses-app/dil.log")
  test -f "$HOME/.local/lib/subses-app/local_server.py" || eksik+=("$HOME/.local/lib/subses-app/local_server.py")
  test -f "$HOME/.local/lib/subses-app/subses_core.sh" || eksik+=("$HOME/.local/lib/subses-app/subses_core.sh")
  test -f "$HOME/.local/lib/subses-app/youtube-subses-ext.sh" || eksik+=("$HOME/.local/lib/subses-app/youtube-subses-ext.sh")

  if (( ${#eksik[@]} > 0 )); then
    local liste
    liste="$(printf '  • %s\n' "${eksik[@]}")"
    echo -e "${k_i}${y_K}Eksik bağımlılık/dosya(lar):${y_X}${r_X}\n${liste}" >&2
    echo "Kurulum örneği: sudo pacman -S ${eksik[*]}" >&2
    if command -v yad >/dev/null 2>&1; then
      yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
          --window-icon="$HOME/.local/lib/subses-app/subses.png" \
          --height=220 --width=420 \
          --text="Eksik bağımlılık / dosya(lar):\n\n${liste}"
    fi
    return 1
  fi
}
gereksinim_kontrol || exit 1

SES_DIR="${SES_DIR:-/tmp/ses}"
SUB_LOG="$SES_DIR/suB.log"
YAD_LOG="$SES_DIR/YAD.log"
INI_FILE="$SES_DIR/i.ini"
TAIL_PID="$SES_DIR/Tail.pid"
MPV_SOCK="${MPV_SOCK:-/tmp/mpvsocket}"
mkdir -p "$SES_DIR"

# --- Yardımcılar -------------------------------------------------------

# Metni Google TTS sorgusuna güvenli biçimde koymak için URL-encode eder.
urlencode() {
  jq -rn --arg x "$1" '$x|@uri'
}

# Tail sürecini (varsa) kapatır. oyna() ve trap tarafından kullanılır.
kill_tail() {
  if [[ -f "$TAIL_PID" ]]; then
    while read -r pid; do
      [[ -n "$pid" ]] && kill -9 "$pid" 2>/dev/null
    done < "$TAIL_PID"
  fi
}

_harf_var() {
  grep -qP '\p{L}' <<< "$1"
}

yad_yaz() {
  printf '%s\n---\n' "$1" >> "$YAD_LOG"
}

# -----------------------------------------------------------------------
# Uygulama işlevleri için foksiyonlar
# -----------------------------------------------------------------------

# --- Video oynatma
oyna() {
  local url
  [[ "$2" =~ FALSE ]] && url="$1" || url="$3"
  rm -f "$MPV_SOCK" 2>/dev/null
  mpv -v --cache-pause-initial=yes --autofit=100%x480 \
      --input-ipc-server="$MPV_SOCK" "$url" \
      2>&1 | tee -a "$SES_DIR/mpv-hata.log"
  local status=${PIPESTATUS[0]}

  if (( status != 0 )); then
    yad --on-top --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
        --window-icon="$HOME/.local/lib/subses-app/subses.png" \
        --height=100 --width=300 \
        --text="MPV hata verdi (kod: $status), Video Oynatılamadı..."
  fi

  kill_tail
  rm -rf "$SES_DIR/mpv-hata.log" "$SUB_LOG" "$INI_FILE" "$YAD_LOG" "$TAIL_PID" "$SES_DIR"/wrap.* 2>/dev/null
}

# --- Dublaj / seslendirme
dublaj() {
  uzun() {
    local lang="$1" speed="$2" text="$3"
    local tmp_ini
    tmp_ini="$(mktemp "${SES_DIR}/wrap.XXXXXX")" || return 1

    perl -CSD -MText::Wrap -e '
        local $Text::Wrap::columns = 175;
        print wrap("", "", $ARGV[0]), "\n";
    ' "$text" > "$tmp_ini"

    while IFS= read -r parca; do
      _harf_var "$parca" || continue
      local q
      q="$(urlencode "$parca")"
      mpv --no-terminal --speed="$speed" \
          "https://translate.google.com/translate_tts?ie=UTF-8&tl=${lang}&client=tw-ob&q=${q}" \
          2>/dev/null
    done < "$tmp_ini"

    rm -f "$tmp_ini"
  }
  dur() {
    echo '{"command":["set_property","pause",true]}'|socat - "$MPV_SOCK" >/dev/null 2>&1
    while pgrep -f "mpv .*--no-terminal" >/dev/null 2>&1; do
      sleep 0.1
    done
    echo '{"command":["set_property","pause",false]}'|socat - "$MPV_SOCK" >/dev/null 2>&1
  }
  if ! perl -MText::Wrap -e 1 >/dev/null 2>&1; then
    yad --on-top --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
        --window-icon="$HOME/.local/lib/subses-app/subses.png" \
        --height=120 --width=350 \
        --text="Perl 'Text::Wrap' modülü bulunamadı (genelde perl ile birlikte gelir).\nDağıtımınızda 'perl-modules' veya benzeri paketi kurun."
    return 1
  fi
  : > "$YAD_LOG"
  ( tail -n0 -f "$YAD_LOG" 2>/dev/null & echo $! > "$TAIL_PID" ) | \
    yad --text-info --tail \
        --title='𝕊𝕌𝔹𝕊𝔼𝕊' \
        --window-icon="$HOME/.local/lib/subses-app/subses.png" \
        --width=650 --height=100 \
        --posx=10 --posy=350 \
        --fontname="Monospace 11" \
        --no-buttons &
  local XM=$!
  echo "$XM" >> "$TAIL_PID"
  trap 'kill_tail' RETURN

  sleep 0.2

  if pgrep -f "mpv .*--cache-pause-initial=yes" >/dev/null; then
    yad_yaz "İŞLEM BAŞLATILIYOR..."
    if [[ ! -S "$MPV_SOCK" ]]; then
      yad_yaz "HATA: MPV çalışıyor ama $MPV_SOCK soketi yok. mpv'yi --input-ipc-server=$MPV_SOCK ile başlattığınızdan emin olun."
      sleep 3
      return 1
    fi
  else
    yad_yaz "HATA: --cache-pause-initial=yes ile başlatılmış bir mpv süreci bulunamadı. Önce videoyu oyna() ile başlatın."
    sleep 3
    return 1
  fi

  local BiL_raw
  if ! read -r BiL_raw < <(yad --form --title="𝕊𝕌𝔹𝕊𝔼𝕊" --separator='#' \
      --window-icon="$HOME/.local/lib/subses-app/subses.png" \
      --field="Altyazı Seç (SRT)":FL     "$HOME/*.srt" \
      --field='Sub Hızı'        '1.5' \
      --field="Sub Dil kodu: "  'tr' \
      --field="KAPAT":SW "FALSE" \
      --field="V-DUR":SW "FALSE"); then
    yad_yaz "Altyazı ve Ayarlar Seçilemedi..!"
    sleep 2
    return 1
  fi

  local SUB_FILE SPEED LANG KAPAT_SW VDUR_SW
  IFS='#' read -r SUB_FILE SPEED LANG KAPAT_SW VDUR_SW <<< "$BiL_raw"

  if [[ "$SUB_FILE" == *"#"* ]]; then
    yad_yaz "HATA: Altyazı dosya adından # karakterini kaldırın."
    sleep 2
    return 1
  fi

  if [[ ! -f "$SUB_FILE" ]]; then
    yad_yaz "HATA: Altyazı dosyası bulunamadı: $SUB_FILE"
    sleep 2
    return 1
  fi

  rm -f "$SES_DIR"/wrap.* 2>/dev/null

  perl -CSD -0777 -ne '
    my %data;
    for my $block (split /\n\s*\n/, $_) {
        my @lines = split /\n/, $block;
        next unless @lines;
        shift @lines if $lines[0] =~ /^\s*\d+\s*$/;
        next unless @lines;
        my $timeline = shift @lines;
        next unless $timeline =~ /(\d+):(\d+):(\d+)[,.]\d+\s*-->/;
        my $sec = $1*3600 + $2*60 + $3;
        my $txt = join(" ", @lines);
        $txt =~ s/<[^>]+>//g;
        $txt =~ s/\{[^}]*\}//g;
        $txt =~ s/\s+/ /g;
        $txt =~ s/^\s+|\s+$//g;
        next unless $txt =~ /\p{L}/;
        $data{$sec} .= ($data{$sec} ? " " : "") . $txt;
    }
    print "${_}_$data{$_}\n" for sort { $a <=> $b } keys %data;
  ' "$SUB_FILE" > "$SUB_LOG"

  local -A SUB_MAP=()
  local satir anahtar deger
  while IFS= read -r satir; do
      anahtar="${satir%%_*}"
      deger="${satir#*_}"
      SUB_MAP["$anahtar"]="$deger"
  done < "$SUB_LOG"

  if (( ${#SUB_MAP[@]} == 0 )); then
    yad_yaz "HATA: Altyazıdan hiç satır ayrıştırılamadı. Dosyanın standart .srt biçiminde
(numara / 00:00:00,000 --> 00:00:00,000 / metin / boş satır) ve düz metin (UTF-8)
olduğundan emin olun. VTT, ASS/SSA gibi biçimler bu betikle desteklenmiyor."
    sleep 4
    return 1
  fi

  yad_yaz "HAZIRLIK TAMAMLANDI İYİ SEYİRLER"

  local KAPATILAN=0
  local last_zn=""
  local Q=""
  local UZUN_PID=""

  # Video kapanana / yad penceresi kapanana kadar döngü
  while ps "$XM" &>/dev/null; do
    local resp zn paused line

    resp="$(printf '{"command":["get_property","time-pos"]}\n{"command":["get_property","pause"]}\n' \
            | socat - "$MPV_SOCK" 2>/dev/null)"

    # tek jq çağrısında iki değer birden okunuyor.
    if [[ -n "$resp" ]]; then
      IFS=$'\t' read -r zn paused < <(jq -rs '
          (if .[0].data == null then "" else (.[0].data | floor | tostring) end) as $t
        | (if .[1].data == null then "" else (.[1].data | tostring) end) as $p
        | "\($t)\t\($p)"
      ' <<< "$resp" 2>/dev/null)
    else
      zn=""; paused=""
    fi

    if [[ "$paused" == "true" ]]; then
      sleep 0.5
      continue
    fi

    if [[ -n "$zn" && "$zn" != "$last_zn" ]]; then
      line="${SUB_MAP[$zn]:-}"

      if [[ -n "$line" ]]; then
        last_zn="$zn"
        Q="$(perl -CSD -pe '
            s/\[[^\]]*\]//g;
            s/\([^)]*\)//g;
            s/[^\p{L}\p{N}]+/ /g;
            s/^\s+|\s+$//g;
        ' <<< "$line")"

        if [[ "$KAPAT_SW" == "TRUE" ]]; then
          [[ -n "$UZUN_PID" ]] && kill -9 "$UZUN_PID" 2>/dev/null
          pkill -9 -f "mpv .*--no-terminal" 2>/dev/null && KAPATILAN=$((KAPATILAN + 1))
          UZUN_PID=""
        fi

        if _harf_var "$Q"; then
          [[ "$VDUR_SW" == "TRUE" ]] && dur
          if (( ${#Q} <= 200 )); then
            local qenc
            qenc="$(urlencode "$Q")"
            mpv --no-terminal --speed="$SPEED" \
                "https://translate.google.com/translate_tts?ie=UTF-8&tl=${LANG}&client=tw-ob&q=${qenc}" \
                2>/dev/null &
            UZUN_PID=""
          else
            uzun "$LANG" "$SPEED" "$Q" &
            UZUN_PID=$!
          fi
        fi

        yad_yaz "$(printf '%s-%s\t\tKAPATILAN: %s\n%s' "$LANG" "$SPEED" "$KAPATILAN" "$Q")"
      fi
    fi

    sleep 0.5
  done 2>/dev/null
}

# --- Dublajla / seslendirme eklenti ile
dublajla() {
  local app_dir="$HOME/.local/lib/subses-app"
  local pid_file="/tmp/ses/dublaj.pid"
  local log_file="/tmp/ses/dublaj.log"

  # Zaten calisan bir surec var mi kontrol et
  if [ -f "$pid_file" ]; then
    local eski_pid
    eski_pid="$(cat "$pid_file" 2>/dev/null)"
    if [ -n "$eski_pid" ] && kill -0 "$eski_pid" 2>/dev/null; then
      if yad --question --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
             --window-icon="$HOME/.local/lib/subses-app/subses.png" \
             --text="Dublajlama durdurulsun mu?"; then
        kill -TERM "-$eski_pid" 2>/dev/null
        rm -f "$pid_file"
        yad --info --title="𝕊𝕌𝔹𝕊𝔼𝕊" --text="Dublaj durduruldu." \
            --window-icon="$HOME/.local/lib/subses-app/subses.png" \
            --timeout=2 --button=Tamam:0
      fi
      return 0
    fi
    rm -f "$pid_file"
  fi
  setsid "$app_dir/youtube-subses-ext.sh" >"$log_file" 2>&1 &
  echo "$!" > "$pid_file"
}

# --- Video-Sub eşli bölme
bol() {
  local -a ffPids=()

  ZAMAN() {
    local dosya="$1" ofsSn="$2" izPid="$3"
    local bb sonY=-1 aa=0 Y
    local re_ts='^([0-9]{2}):([0-9]{2}):([0-9]{2}),([0-9]{3}) *--> *([0-9]{2}):([0-9]{2}):([0-9]{2}),([0-9]{3})'

    bb="$(grep -c -- '-->' "$dosya" 2>/dev/null)"
    if (( bb == 0 )); then
      cp -f "$dosya" "$SES_DIR/sub.txt" 2>/dev/null
      return 0
    fi

    : >"$SES_DIR/sub.txt"
    local ofsMs=$(( ofsSn * 1000 ))
    local a b satir

    while IFS= read -r oku; do
      ps "$izPid" >/dev/null 2>&1 || return 1
      if [[ "$oku" =~ $re_ts ]]; then
        a=$(( (10#${BASH_REMATCH[1]}*3600 + 10#${BASH_REMATCH[2]}*60 + 10#${BASH_REMATCH[3]})*1000 \
              + 10#${BASH_REMATCH[4]} - ofsMs ))
        b=$(( (10#${BASH_REMATCH[5]}*3600 + 10#${BASH_REMATCH[6]}*60 + 10#${BASH_REMATCH[7]})*1000 \
              + 10#${BASH_REMATCH[8]} - ofsMs ))
        (( a < 0 )) && a=0
        (( b < 0 )) && b=0
        printf -v satir "%02d:%02d:%02d,%03d --> %02d:%02d:%02d,%03d" \
          $((a/3600000)) $((a/60000%60)) $((a/1000%60)) $((a%1000)) \
          $((b/3600000)) $((b/60000%60)) $((b/1000%60)) $((b%1000))
        echo "$satir" >>"$SES_DIR/sub.txt"
        (( aa++ ))
      else
        echo "$oku" >>"$SES_DIR/sub.txt"
      fi

      Y=$(( aa*100/bb ))
      (( Y >= 100 )) && Y=99
      if [[ "$Y" != "$sonY" ]]; then
        sonY=$Y
        ps "$izPid" >/dev/null 2>&1 && {
          echo "$Y" >&9
          echo "# Altyazı senkronize ediliyor... %$Y" >&9
        }
      fi
    done <"$dosya"
  }

  cop() {
    local p
    for p in "${ffPids[@]}"; do
      kill -9 "$p" 2>/dev/null
    done
    { exec 9>&-; } 2>/dev/null
    rm -rf "$SES_DIR/TaiL.pid" "$SES_DIR/sub.txt" "$SES_DIR/progress.pipe" \
          "$SES_DIR/CD1.txt" "$SES_DIR/CD2.txt" 2>/dev/null
  }

  guncelle() {
    local ffpid="$1"
    while ps "$ffpid" >/dev/null 2>&1; do
      if ! ps "$term" >/dev/null 2>&1; then
        kill -9 "$ffpid" 2>/dev/null
        return 1
      fi
      local boy
      boy="$(du -h "${temelAd}.CD1.mp4" "${temelAd}.CD2.mp4" 2>/dev/null \
             | awk '{print $1}' | paste -sd'/' -)"
      echo "# Video bölünüyor... ${boy}" >&9
      sleep 1
    done
  }

  if [[ -f "$SES_DIR/TaiL.pid" ]]; then
    local eskiPid
    eskiPid="$(<"$SES_DIR/TaiL.pid")"
    if [[ -n "$eskiPid" ]] && ps -p "$eskiPid" >/dev/null 2>&1; then
      yad --title='𝕊𝕌𝔹𝕊𝔼𝕊' \
          --window-icon="$HOME/.local/lib/subses-app/subses.png" \
          --text='SubSes zaten çalışıyor.' --button=Tamam:0 2>/dev/null
      return 1
    fi
  fi

  local sub
  read -r sub< <(yad --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
       --form --item-separator='!' --separator='#' \
       --window-icon="$HOME/.local/lib/subses-app/subses.png" \
       --field="Video Seç":FL             "$HOME/.*" \
       --field="Altyazı Seç (SRT)":FL     "$HOME/.*|*.srt" \
       --field="Buraya kadar kes: "       '00:00:00') || return 2

  local video altyazi kesZamani
  video="$(cut -d# -f1 <<<"$sub")"
  altyazi="$(cut -d# -f2 <<<"$sub")"
  kesZamani="$(cut -d# -f3 <<<"$sub")"

  if [[ -z "$video" || -z "$altyazi" || ! -f "$video" || ! -f "$altyazi" ]]; then
    yad --title='HATA SEÇİM' --text='Video veya altyazı dosyası seçilmedi/geçersiz.' \
        --window-icon="$HOME/.local/lib/subses-app/subses.png" \
        --button=Tamam:0 2>/dev/null
    return 1
  fi
  if [[ ! "$kesZamani" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
    yad --title='HATA SEÇİM' --text='Kesme zamanı SS:DD:ss biçiminde olmalı (örn. 00:12:30).' \
        --window-icon="$HOME/.local/lib/subses-app/subses.png" \
        --button=Tamam:0 2>/dev/null
    return 1
  fi

  local temelAd="${video%.*}"

  rm -f "$SES_DIR/progress.pipe"
  mkfifo -m 600 "$SES_DIR/progress.pipe"
  trap 'cop' RETURN
  trap 'cop; exit 130' INT
  trap 'cop; exit 143' TERM
  trap 'cop; exit 129' HUP
  trap '' PIPE

  yad --progress --auto-close --auto-kill --fixed \
      --title='𝕊𝕌𝔹𝕊𝔼𝕊' \
      --window-icon="$HOME/.local/lib/subses-app/subses.png" \
      --width=500 --height=100 \
      --text="Hazırlanıyor..." \
      --percentage=0 \
      --button="İptal":1 < "$SES_DIR/progress.pipe" &
  local term=$!
  echo "$term" >"$SES_DIR/TaiL.pid"
  exec 9>"$SES_DIR/progress.pipe"
  local bak son sonSn
  bak=$(( 10#${kesZamani:0:2}*3600 + 10#${kesZamani:3:2}*60 + 10#${kesZamani:6:2} ))

  son="$(ffprobe "$video" 2>&1 | awk '/Duration:/{print $2}' | tr -d ',')"
  if [[ -z "$son" ]]; then
    echo "# Video süresi okunamadı!" >&9
    sleep 1.5
    return 1
  fi
  son="${son%%.*}"

  sonSn=$(( 10#${son:0:2}*3600 + 10#${son:3:2}*60 + 10#${son:6:2} ))
  if (( bak >= sonSn )); then
    echo "# Kesme zamanı video süresinden büyük ya da eşit!" >&9
    sleep 1.5
    return 1
  fi

  ffmpeg -nostdin -loglevel quiet \
    -i "$video" -ss "00:00:00" -to "$kesZamani" -acodec ac3 -vcodec copy "${temelAd}.CD1.mp4" &
  ffPids+=("$!")
  guncelle "$!" || return 1

  ffmpeg -nostdin -loglevel quiet \
    -i "$video" -ss "$kesZamani" -to "$son" -acodec ac3 -vcodec copy "${temelAd}.CD2.mp4" &
  ffPids+=("$!")
  guncelle "$!" || return 1

  local re_ts2='^([0-9]{2}):([0-9]{2}):([0-9]{2})'
  local re_harf='[A-Za-zÇĞİÖŞÜçğıöşü]'
  local s=0 bk hedef devamCD=""
  : >"$SES_DIR/CD1.txt"
  : >"$SES_DIR/CD2.txt"

  while IFS= read -r al; do
    ps "$term" >/dev/null 2>&1 || return 1
    if [[ "$al" =~ $re_ts2 ]]; then
      bk=$(( 10#${BASH_REMATCH[1]}*3600 + 10#${BASH_REMATCH[2]}*60 + 10#${BASH_REMATCH[3]} ))
      if (( bk < bak )); then hedef=CD1; else hedef=CD2; fi
      (( s++ ))
      printf '\n%d\n%s\n' "$s" "$al" >>"$SES_DIR/${hedef}.txt"
      devamCD="$hedef"
      if (( s % 20 == 0 )); then
        echo "# Altyazı ayrıştırılıyor... $hedef ($s satır)" >&9
      fi
    elif [[ "$al" =~ $re_harf && -n "$devamCD" ]]; then
      printf '%s\n' "$al" >>"$SES_DIR/${devamCD}.txt"
    fi
  done <"$altyazi"

  if (( s == 0 )); then
    echo "# Altyazıda zaman damgası bulunamadı!" >&9
    sleep 1.5
    return 1
  fi

  ffmpeg -nostdin -loglevel quiet -i "$SES_DIR/CD1.txt" "${temelAd}.CD1.srt"

  local basarili=1
  if ZAMAN "$SES_DIR/CD2.txt" "$bak" "$term"; then
    ffmpeg -nostdin -loglevel quiet -i "$SES_DIR/sub.txt" "${temelAd}.CD2.srt" && basarili=0
  fi

  if (( basarili == 0 )); then
    echo "100" >&9
    echo "# İŞLEM TAMAMLANDI..." >&9
  else
    echo "# İŞLEM HATASI...!" >&9
  fi
  sleep 1.5
}

export SES_DIR SUB_LOG YAD_LOG INI_FILE TAIL_PID MPV_SOCK
export -f oyna dublaj dublajla kill_tail urlencode yad_yaz _harf_var bol

# -----------------------------------------------------------------------

if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
 _url="`xclip -o | awk '/^http/'`"
else
 _url="`wl-paste -n | awk '/^http/'`"
fi

_SH="Video dosyasına srt formatında altyazı dosyası oluşturun."
_tus="Belirtilen tuşları belirtilen zaman ve zaman aralıklarıyla tetikleme yapar."
_mik="Mikrofondan alınan sesi metne dökme yapın."
_bol="Video ve Altyazıyı birbirleriyle uyumlu olarak istenilen zamana kesin."
_oyna="MPV ile url veya video dosyasını oynatın."
_dublaj="MPV ile oynatılan video dublajma işlemini başlatır."
_dublajla="Tarayıcıda yüklü olan eklenti ile bağlantı kurar veya kapatır."
yad --form --title="⟆υᑲ⟆∈⟆  v2.0" --height=200 --width=400 \
    --window-icon="$HOME/.local/lib/subses-app/subses.png" \
    --item-separator='!' --separator=' '\
    --field="<span foreground='blue'>URL:</span>":TXT     "$_url"\
    --field="Video ekle:":SW                              'FALSE'\
    --field="Video Dosyası":FL                            "$HOME/.*"\
    --field="Video OYNAT!gtk-yes!$_oyna":FBTN             'bash -c "oyna %1 %2 %3"'\
    --field="MPV DUBLAJI BAŞLAT!gtk-yes!$_dublaj":FBTN    'bash -c "dublaj"'\
    --field="DUBLAJ AÇ-KAPAT!gtk-yes!$_dublajla":FBTN     'bash -c "dublajla"'\
    --field="Mikrofon Dinle!gtk-yes!$_mik":FBTN           'bash -c "python '$DiN'"'\
    --field="Video+Sub Böl!gtk-yes!$_bol":FBTN            'bash -c "bol"'\
    --field="Video SRT Yap!gtk-yes!$_SH":FBTN             'bash -c '$SH''\
    --button=ÇIKIŞ:0 >/dev/null
set +e
set +u
