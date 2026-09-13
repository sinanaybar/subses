#!/usr/bin/env bash

find /tmp/ses -maxdepth 1 -name 'AT.??????' -mmin +10 -delete 2>/dev/null || true

urlencode() {
  python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

OKU() {
  metin="${3}"
  local AT_FILE
  AT_FILE="$(mktemp /tmp/ses/AT.XXXXXX)"

  _oku_cleanup() {
    rm -f "$AT_FILE" 2>/dev/null
  }
  trap _oku_cleanup EXIT TERM INT

  mapfile -t birimler < <(
    perl -CSD -0777 -ne '
        s/\[[^\]]*\]//g;
        s/\([^)]*\)//g;
        my @parcalar = split /(?<!\d)[.,](?!\d)|[?!:;]/, $_;
        for my $p (@parcalar) {
            $p =~ s/[^\p{L}\p{N}]+/ /g;
            $p =~ s/^\s+|\s+$//g;
            next unless $p =~ /\p{L}/;
            print "$p\n";
        }
    ' <<<"$metin"
  )

  printf '%s\n' "${birimler[@],,}" > "$AT_FILE"

  local TTS_LIMIT=180
  : > "$AT_FILE"
  for birim in "${birimler[@],,}"; do
    if (( ${#birim} > TTS_LIMIT )); then
      fold -s -w "$TTS_LIMIT" <<<"$birim" >> "$AT_FILE"
    else
      printf '%s\n' "$birim" >> "$AT_FILE"
    fi
  done

  while read -r ou; do
    mpv --no-terminal --speed="${2:-1.0}" --af=rubberband \
    "https://translate.google.com/translate_tts?ie=UTF-8&tl=${1}&client=tw-ob&q=$(urlencode "$ou")"
    [[ ! -e "$AT_FILE" ]] && break
  done <"$AT_FILE"
}

export -f OKU urlencode

# Dogrudan calistirilirsa (kaynak gosterilmeden, ornegin
# "bash subses_core.sh tr 1.2 'metin'" ile) OKU'yu tetikle.
#
# "return" komutunun sadece bir fonksiyon icinde ya da KAYNAK
# GOSTERILMIS (sourced) bir baglamda gecerli olmasindan yararlanan
# bu kontrol, $0 ne olursa olsun doğru sonucu verir: source
# edildiyse "return" basarili olur (OKU otomatik cagrilmaz, cunku
# caller zaten kendisi cagiracaktir); dogrudan calistirildiysa
# "return" hata verir (OKU burada cagrilir).
if ! (return 0 2>/dev/null); then
  OKU "$1" "$2" "$3"
fi
