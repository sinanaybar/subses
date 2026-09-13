#!/usr/bin/env bash
# youtube-subses-ext.sh
# Chrome eklentisinden (background.js) gelen zaman akisini dinleyen
# Python sunucusunu, yad ile alinan ayarlarla baslatir.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------------
# SRT dosyasini "saniye_metin" formatinda sub.log'a cevirir.
# ------------------------------------------------------------------
convert_srt_to_log() {
  local srt="$1" log="$2"
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
    ' "$srt" > "$log"
}

FORM=$(yad --form --center --width=460 --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
    --window-icon="$HOME/.local/lib/subses-app/subses.png" \
    --field="SRT Dosyasi:FL" \
    --field="Altyazi Dil Kodu:" \
    --field="Seslendirme Hizi:" \
    --field="HTTP Portu (extension/background.js ile ayni olmali):" \
    --field="Maks. Gecikme (sn) - bu kadar geride kalan replik atlanir:" \
    "" "tr" "1.5" "8765" "4.0")

[ $? -ne 0 ] && exit 0

IFS='|' read -r SRT_FILE LANG_CODE SPEED PORT MAX_DRIFT <<< "$FORM"

if [ -z "$SRT_FILE" ] || [ ! -f "$SRT_FILE" ]; then
    yad --error --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
        --window-icon="$HOME/.local/lib/subses-app/subses.png" \
        --text="Gecerli bir SRT dosyasi secilmedi."
    exit 1
fi

LOG_FILE="$(mktemp --suffix=.log)"
convert_srt_to_log "$SRT_FILE" "$LOG_FILE"

if [ ! -s "$LOG_FILE" ]; then
    yad --error  --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
        --window-icon="$HOME/.local/lib/subses-app/subses.png" \
        --text="sub.log olusturulamadi ya da bos (SRT formatini kontrol edin)."
    exit 1
fi

trap 'rm -f "$LOG_FILE"' EXIT
ERR_FILE="$(mktemp --suffix=.err)"
trap 'rm -f "$LOG_FILE" "$ERR_FILE"' EXIT

python3 "$SCRIPT_DIR/local_server.py" \
    --log "$LOG_FILE" \
    --port "$PORT" \
    --lang "$LANG_CODE" \
    --speed "$SPEED" \
    --drift "$MAX_DRIFT" \
    2>"$ERR_FILE"
STATUS=$?

if [ "$STATUS" -ne 0 ] && [ -s "$ERR_FILE" ]; then
    yad --title="Dublaj Baslatilamadi (kod: $STATUS)" \
        --window-icon="$HOME/.local/lib/subses-app/subses.png" \
        --text-info --filename="$ERR_FILE" \
        --width=600 --height=300 \
        --button=Tamam:0
fi
