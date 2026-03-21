#!/usr/bin/env bash
# ██████████████████████████████████████
# █─▄▄▄▄█▄─██─▄█▄─▄─▀█─▄▄▄▄█▄─▄▄─█─▄▄▄▄█
# █▄▄▄▄─██─██─███─▄─▀█▄▄▄▄─██─▄█▀█▄▄▄▄─█
# ▀▄▄▄▄▄▀▀▄▄▄▄▀▀▄▄▄▄▀▀▄▄▄▄▄▀▄▄▄▄▄▀▄▄▄▄▄▀
# --------------------------------------
## Uyg arayüz sağlamak için çalışan scripting dosyasıdır.
## subses.desktop Dosyası olarak menüye ekleyin..
## Url için indirme, bilgi, dublajma, tuş konbinasyon
## birleştirme, ses den metne gibi işlemlerini yad arayüzü sağlanır.

# Gereksinim duyulan uyg ve dosyaların varlığını yoklama
which mpv >/dev/null || {
yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
    --window-icon="$HOME/.config/subses/subses.png" \
    --height=100 --width=300 \
    --text="MPV uyg yüklü değil...";
}
which yt-dlp >/dev/null || {
yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
    --window-icon="$HOME/.config/subses/subses.png" \
    --height=100 --width=300 \
    --text="YT-DLP uyg yüklü değil...";
}
which xterm >/dev/null || {
yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
    --window-icon="$HOME/.config/subses/subses.png" \
    --height=100 --width=300 \
    --text="XTERM uyg yüklü değil...";
}
which sox >/dev/null || {
yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
    --window-icon="$HOME/.config/subses/subses.png" \
    --height=100 --width=300 \
    --text="SOX uyg yüklü değil...";
}
which ffmpeg >/dev/null || {
yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
    --window-icon="$HOME/.config/subses/subses.png" \
    --height=100 --width=300 \
    --text="FFMPEG uyg yüklü değil...";
}
which xev >/dev/null || {
yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
    --window-icon="$HOME/.config/subses/subses.png" \
    --height=100 --width=300 \
    --text="XEV uyg yüklü değil...";
}
which wget >/dev/null || {
yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
    --window-icon="$HOME/.config/subses/subses.png" \
    --height=100 --width=300 \
    --text="WGET uyg yüklü değil...";
}
test -f "$HOME/.config/subses/subses.png" || {
yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
     --window-icon="$HOME/.config/subses/subses.png" \
     --height=100 --width=300 \
     --text="Gerekli Dosyalar Konumda Değil..!\n$HOME/.config/subses/subses.png";
}
test -f "$HOME/.config/subses/dil.log" || {
yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
     --window-icon="$HOME/.config/subses/subses.png" \
     --height=100 --width=300 \
     --text="Gerekli Dosyalar Konumda Değil..!\n$HOME/.config/subses/dil.log";
}
# Dublajlı olarak seslendirme işlem.
function dublaj() {
# Mevcut sınırı geçen altyazıları parçalı olarak okuma işlemi
function uzun() {
fmt -sw 150 <<<"$3" >'/tmp/ses/i.ini'
while read -r oku; do
 test -e '/tmp/ses/i.ini'|| break
 [[ "$oku" =~ ([A-Za-z]) ]] && mpv --no-terminal --speed="$2" \
 "https://translate.google.com/translate_tts?ie=UTF-8&tl=${1}&client=tw-ob&q=${oku}"
done <'/tmp/ses/i.ini'
}
 # Mpv çalıyor mu diye kontrol edilir.
 if pidof mpv >/dev/null; then
  echo -ne "İŞLEM BAŞLATILIYOR..." >'/tmp/ses/xterm.log'
  # Çalışan mpv log dosyasına yönlendirme yapıldığını doğrulama.
  [[ ! -e '/tmp/ses/mpv' ]] && {
  echo "MPV > /tmp/ses/mpv Dosyasına yönlendirin." >'/tmp/ses/xterm.log';
  yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
      --window-icon="$HOME/.config/subses/subses.png" \
      --height=100 --width=300 \
      --text="Yönlendirilmiş MPV Bulunamadı...";
  }
 else
  echo "MPV ÇALIŞMIYOR..." >'/tmp/ses/xterm.log'
  yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
      --window-icon="$HOME/.config/subses/subses.png" \
      --height=100 --width=300 \
      --text="Çalışmakta olan MPV uyg Bulunamadı..."
 fi
 # Yad ile veri girdisi kontrol edilerek işlem başlatılır.
 if read -r BiL< <(yad --form --title="𝕊𝕌𝔹𝕊𝔼𝕊" --separator='#' \
    --window-icon="$HOME/.config/subses/subses.png" \
    --field="Altyazı Seç":FL  "hata" \
    --field='Sub Hızı'        '1.5' \
    --field="Sub Dil kodu: "  'tr' \
    --field="KAPAT":SW "FALSE"); then
 echo -ne >'/tmp/ses/suB.log'
 [[ "${BiL/.*/}" =~ "#" ]] &&\
 yad --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
     --window-icon="$HOME/.config/subses/subses.png" \
     --height=100 --width=300 \
     --text="Altyazı adından # kaldırın."
 BiL=( "`cut -d# -f1 <<<"$BiL"`" "`cut -d# -f2 <<<"$BiL"`" "`cut -d# -f3 <<<"$BiL"`" "`cut -d# -f4 <<<"$BiL"`" )
 # xterm bilgi verilmek için başlatılır.
 xterm -geometry 80x10-10+300 -fa -hold -T '𝕊𝕌𝔹𝕊𝔼𝕊' -e 'bash -c "watch -n1 cat /tmp/ses/xterm.log"' &
 XM=$!
 # Altyazı biçimleme ve düzenleme başlatılır.
 XX="$(grep -c "^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]," "${BiL[0]}")"
 paste -- \
  <(grep -now "^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]" "${BiL[0]}"|sed '$d') \
  <(grep -now "^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]" "${BiL[0]}"|sed '1d')|\
  awk -F: '{print $2":"$3":"$4,$1}' >'/tmp/ses/M.log'
 grep -now "^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]" "${BiL[0]}"|tail -n1|\
  awk -F: -v s="$(wc -l <"${BiL[0]}")" '{print $2":"$3":"$4"\t"s+1,$1}' >>'/tmp/ses/M.log'
 strings '/tmp/ses/M.log'|while read -r oku; do
   _oku=( $oku )
   MT="`sed -n -e 's/<[^>]*>//g' -e ''"$((_oku[2]+1)),$((_oku[1]-3))"'p' "${BiL[0]}"|tr [:space:] ' '`"
   printf "%s_%s\n" "${_oku[0]}" "$MT" >>'/tmp/ses/suB.log'
   iX="$(grep -c "[0-9]_" '/tmp/ses/suB.log')"
   Y=$(("${iX}*100/${XX}*100"/100))
   B=$(("${Y}*5"/10))
   K=$((50-B))
   T=$(perl -E 'say "┃"x'"$B")
   E=$(perl -E 'say "╺"x'"$K")
   echo -e "\n${iX}>${XX} ╏${T}${E}╏${Y}%" >'/tmp/ses/xterm.log'
 done 2>/dev/null
 rm -rf '/tmp/ses/M.log'
 echo -e "\nHAZIRLIK TAMAMLANDI VİDEO BAŞLATIN..!\n\t İYİ SEYİRLER" >'/tmp/ses/xterm.log'
 # Hazırlanan altyazı log dosyası ile mpv log dosyası kullanılarak döngüye girilir.
 OY=( "KAPATILAN:" "0" )
 until ! ps "$XM" &>/dev/null; do
  ZN=( `strings '/tmp/ses/mpv'|tail -n1|awk '{print $2" --> "$4}'` )
  if grep "^${ZN[0]}_" '/tmp/ses/suB.log' >/dev/null; then
   Q="$(awk -F_ '/^'"${ZN[0]}"'/{printf "%s ",$2}' '/tmp/ses/suB.log'\
   |sed -e 's/[[][^[]*]//g' -e 's/([^)]*)//g' -e 's/\W/ /g' -e 's/\s\{1,\}/ /g' -e 's/^\s//')"
   if [[ "${BiL[3]}" =~ 'TRUE' ]]; then
    test -e '/tmp/ses/i.ini' && rm '/tmp/ses/i.ini'
    kill -9 "`ps axu|awk '$11=="mpv" && /--no-terminal/{printf "%s ",$2}'`" 2>/dev/null && \
    OY=( "KAPATILAN:" "$((OY[1]+1))" )
   fi
   if ! strings '/tmp/ses/mpv'|tail -n1|grep -w '^(Paused)' >/dev/null; then
    if (( "${#Q}" <= "200" )); then
     [[ "$Q" =~ ([A-Za-z]) ]] && mpv --no-terminal --speed="${BiL[1]}" \
     "https://translate.google.com/translate_tts?ie=UTF-8&tl=${BiL[2]}&client=tw-ob&q=${Q}" &
     sleep 0.1
     if awk -F_ '/^'"${ZN[0]}"'/{print $2}' '/tmp/ses/suB.log'|sed -e 's/\s\{1,\}//'|grep '^\[.*\]' >/dev/null; then
      awk -F_ '/^'"${ZN[0]}"'/{print $2}' '/tmp/ses/suB.log'|sed -e 's/\s\{1,\}//'|grep '\[.*\]'|\
      awk -F']' -v z="${ZN[*]}" -v d="${BiL[2]}" -v t="${BiL[1]}" -v o="${OY[*]}" '{
          print z"\t\t"d"-"t"\t\t"o"\n"$1"]\n"$2}'|fmt -sw 90 >'/tmp/ses/xterm.log'
     else
      echo -e "${ZN[*]}\t\t${BiL[2]}-${BiL[1]}\t\t${OY[*]}\n`fmt -sw 90 <<<"$Q"`" >'/tmp/ses/xterm.log'
     fi
    else
     uzun "${BiL[2]}" "${BiL[1]}" "$Q" &
     if awk -F_ '/^'"${ZN[0]}"'/{print $2}' '/tmp/ses/suB.log'|sed -e 's/\s\{1,\}//'|grep '^\[.*\]' >/dev/null; then
      awk -F_ '/^'"${ZN[0]}"'/{print $2}' '/tmp/ses/suB.log'|sed -e 's/\s\{1,\}//'|grep '\[.*\]'|\
      awk -F']' -v z="${ZN[*]}" -v d="${BiL[2]}" -v t="${BiL[1]}" -v o="${OY[*]}" '{
          print z"\t\t"d"-"t"\t\t"o"\n"$1"]\n"$2}'|fmt -sw 90 >'/tmp/ses/xterm.log'
     else
      echo -e "${ZN[*]}\t\t${BiL[2]}-${BiL[1]}\t\t${OY[*]}\n`fmt -sw 90 <<<"$Q"`" >'/tmp/ses/xterm.log'
     fi
    fi
   fi
  fi
  echo -e "${ZN[*]}\t\t${BiL[2]}-${BiL[1]}\t\t${OY[*]}\n`fmt -sw 80 <<<"$Q"`" >'/tmp/ses/xterm.log'
  sleep 1
 done 2>/dev/null
 else
  notify-send --icon="$HOME/.config/subses/subses.png" "Altyazı ve Ayarlar Seçilemedi..!"
 fi
}
# İndirme işlemi yapılacak olan kod blok. ( yt-dlp,wget )
function indir() {
# Yad menu yt-dlp veya wget ile indirme ayar seçimi.
read -ra in< <(yad --title="𝕊𝕌𝔹𝕊𝔼𝕊" --window-icon="$HOME/.config/subses/subses.png" \
    --form --separator=' ' --height=100 --width=500 \
    --text="<span foreground='blue'><b><big><big>İŞLEM AYAR SEÇİMİ:</big></big></b></span>" \
    --field="Video URL:":TXT                                        "$1" \
    --field="<b><big><big>İndirici Seçimi</big></big></b>":CB       'YT-DLP!Wget' \
    --field="<b><big><big>Seç indir </big></big></b>(yt-dlp)":CBE   'SUB!OTO-SUB!ViDEO!SES!ViD+SES' \
    --field="<b><big><big>Video Kod </big></big></b>(yt-dlp)"       "NO" \
    --field="<b><big><big>Altyazı Kod </big></big></b>(yt-dlp)"     "tr" \
    --field="<b><big><big>Kayıt Konum</big></big></b>":DIR          "$HOME")
# Yad ile alınan girdi ile işlem başlatılır.
case ${in[1]} in
YT-DLP)
if [[ "${in[2]}" == 'ViDEO' ]]; then
 [[ "${in[3]}" == NO ]] && NO=mp4 || NO="${in[3]}"
 yt-dlp -f "$NO" -o "${in[5]}/%(title)s.%(ext)s" "${in[0]}" 2>&1|tee '/tmp/ses/yt-dlp.log' &
 knt="$!"
 until ! ps "$knt" >/dev/null; do
  sleep 0.5
  [ "`ps aux|awk '$12 ~ /--no-buttons/{print $2|"wc -l"}'`" \> 0 ] || {
  echo >'/tmp/ses/yt-X.log';
  killall yt-dlp ; break ; }
  read -ra BK< <(strings /tmp/ses/yt-dlp.log|grep -w "\[download\]"|tail -n1)
  if test "$(strings /tmp/ses/yt-dlp.log|grep -c "\[download\]")" -ge 4; then
   echo "${BK[1]/.*/}"
   echo "#$(tr -d '[downloaditf]' <<<"${BK[@]}")"
  else
   sleep 0.5
  fi
  if grep -w 'ERROR:' '/tmp/ses/yt-dlp.log' >/dev/null; then
   yad --text-info --title="YT-DLP HATALI ÇIKTI VERİLERİ" \
       --window-icon="$HOME/.config/subses/subses.png" \
       --height=200 --width=500 --wrap \
       --justify=center< <(strings '/tmp/ses/yt-dlp.log'|grep -w "ERROR:")
  fi
 done|yad --no-buttons --progress --title="𝕊𝕌𝔹𝕊𝔼𝕊" --width=400 \
          --window-icon="$HOME/.config/subses/subses.png" &
 until ! ps "$knt" >/dev/null; do sleep 1 ; done
 if grep -w 'ERROR:' '/tmp/ses/yt-dlp.log' >/dev/null; then
  yad --text-info --title="YT-DLP HATALI ÇIKTI VERİLERİ" \
       --window-icon="$HOME/.config/subses/subses.png" \
       --height=200 --width=500 --wrap \
       --justify=center< <(strings '/tmp/ses/yt-dlp.log'|grep -w "ERROR:")
 fi
 rm '/tmp/ses/yt-dlp.log' 2>/dev/null
 kill -9 `ps aux|awk '$12 ~ /--no-buttons/{printf "%s ",$2}'` 2>/dev/null
elif [[ "${in[2]}" == 'SES' ]]; then
 nohup yt-dlp -x --audio-format mp3 \
              -o "${in[5]}/%(title)s.%(ext)s" ${in[0]} >'/tmp/ses/yt-dlp.log' &
 knt="$!"
 until ! ps "$knt" >/dev/null; do
  sleep 0.5
  [ "`ps aux|awk '$12 ~ /--no-buttons/{print $2|"wc -l"}'`" \> 0 ] || {
  echo >'/tmp/ses/yt-X.log';
  killall yt-dlp ; break ; }
  read -ra BK< <(strings /tmp/ses/yt-dlp.log|grep -w "\[download\]"|tail -n1)
  if test "$(strings /tmp/ses/yt-dlp.log|grep -c "\[download\]")" -ge 4; then
   echo "${BK[1]/.*/}"
   echo "#$(tr -d '[downloaditf]' <<<"${BK[@]}")"
  else
   sleep 0.5
  fi
  if grep -w 'ERROR:' '/tmp/ses/yt-dlp.log' >/dev/null; then
   yad --text-info --title="YT-DLP HATALI ÇIKTI VERİLERİ" \
       --window-icon="$HOME/.config/subses/subses.png" \
       --height=200 --width=500 --wrap \
       --justify=center< <(strings '/tmp/ses/yt-dlp.log'|grep -w "ERROR:")
  fi
 done|yad --no-buttons --progress --title="𝕊𝕌𝔹𝕊𝔼𝕊" --width=400 \
          --window-icon="$HOME/.config/subses/subses.png" &
 until ! ps "$knt" >/dev/null; do sleep 1 ; done
 until ! pidof ffmpeg >/dev/null; do sleep 1 ; done
 if grep -w 'ERROR:' '/tmp/ses/yt-dlp.log' >/dev/null; then
  yad --text-info --title="YT-DLP HATALI ÇIKTI VERİLERİ" \
       --window-icon="$HOME/.config/subses/subses.png" \
       --height=200 --width=500 --wrap \
       --justify=center< <(strings '/tmp/ses/yt-dlp.log'|grep -w "ERROR:")
 fi
 rm '/tmp/ses/yt-dlp.log' 2>/dev/null
 kill -9 `ps aux|awk '$12 ~ /--no-buttons/{printf "%s ",$2}'` 2>/dev/null
elif [[ "${in[2]}" == 'SUB' ]]; then
 YTpipe="/tmp/ses/yt.pipe"
 if ! test -e "$YTpipe"; then mkfifo $YTpipe; fi
 exec 9<> $YTpipe
 nohup yt-dlp --write-auto-subs --sub-lang "${in[4]}" --sub-format ttml --convert-subs srt \
        -o "${in[5]}/%(title)s" --skip-download "${in[0]}" >&9 &
 yad --text-info --title="𝕊𝕌𝔹𝕊𝔼𝕊" --height=500 --width=800 \
      --window-icon="$HOME/.config/subses/subses.png" \
      --justify=center <&9
 exec 9>&-
 rm -rf "/tmp/ses/yt.pipe"
elif [[ "${in[2]}" == 'OTO-SUB' ]]; then
 YTpipe="/tmp/ses/yt.pipe"
 if ! test -e "$YTpipe"; then mkfifo $YTpipe; fi
 exec 9<> $YTpipe
 nohup yt-dlp --skip-download --write-auto-subs --write-subs \
       --sub-lang ${in[4]} --convert-subtitles srt -o "${in[5]}/%(title)s" "${in[0]}" >&9 &
 yad --text-info --title="𝕊𝕌𝔹𝕊𝔼𝕊" --height=500 --width=800 \
      --window-icon="$HOME/.config/subses/subses.png" \
      --justify=center <&9
 exec 9>&-
 rm -rf "/tmp/ses/yt.pipe"
elif [[ "${in[2]}" == 'ViD+SES' ]]; then
 [[ "${in[3]}" == NO ]] && NO=mp4 || NO="${in[3]}"
 (
 nohup yt-dlp -x --audio-format mp3 \
              -o "${in[5]}/%(title)s.%(ext)s" ${in[0]} >'/tmp/ses/yt-dlp.log' &
 knt="$!"
 until ! ps "$knt" >/dev/null; do
  sleep 0.5
  [ "`ps aux|awk '$12 ~ /--no-buttons/{print $2|"wc -l"}'`" \> 0 ] || {
  echo >'/tmp/ses/yt-X.log';
  killall yt-dlp ; break ; }
  read -ra BK< <(strings /tmp/ses/yt-dlp.log|grep -w "\[download\]"|tail -n1)
  if test "$(strings /tmp/ses/yt-dlp.log|grep -c "\[download\]")" -ge 4; then
   echo "${BK[1]/.*/}"
   echo "#$(tr -d '[downloaditf]' <<<"${BK[@]}")"
  else
   sleep 0.5
  fi
  if grep -w 'ERROR:' '/tmp/ses/yt-dlp.log' >/dev/null; then
   yad --text-info --title="YT-DLP HATALI ÇIKTI VERİLERİ" \
       --window-icon="$HOME/.config/subses/subses.png" \
       --height=200 --width=500 --wrap \
       --justify=center< <(strings '/tmp/ses/yt-dlp.log'|grep -w "ERROR:")
  fi
 done|yad --no-buttons --progress --title="𝕊𝕌𝔹𝕊𝔼𝕊" --width=400 \
          --window-icon="$HOME/.config/subses/subses.png" &
 until ! ps "$knt" >/dev/null; do sleep 1 ; done
 until ! pidof ffmpeg >/dev/null; do sleep 1 ; done
 if grep -w 'ERROR:' '/tmp/ses/yt-dlp.log' >/dev/null; then
  yad --text-info --title="YT-DLP HATALI ÇIKTI VERİLERİ" \
       --window-icon="$HOME/.config/subses/subses.png" \
       --height=200 --width=500 --wrap \
       --justify=center< <(strings '/tmp/ses/yt-dlp.log'|grep -w "ERROR:")
 fi
 )
 sleep 0.5
 SES="$(awk -F: '/Destination:/{print $2| "tail -n1"}' '/tmp/ses/yt-dlp.log'|sed s/'\s'// )"
 rm '/tmp/ses/yt-dlp.log' 2>/dev/null
 kill -9 `ps aux|awk '$12 ~ /--no-buttons/{printf "%s ",$2}'` 2>/dev/null
 (
 [[ -f '/tmp/ses/yt-X.log' ]] ||\
 yt-dlp -f "$NO" -o "${in[5]}/%(title)s.mp4" "${in[0]}" 2>&1|tee '/tmp/ses/yt-dlp.log' &
 knt2="$!"
 until ! ps "$knt2" >/dev/null; do
  [ "`ps aux|awk '$12 ~ /--no-buttons/{print $2|"wc -l"}'`" \> 0 ] || {
  echo >'/tmp/ses/yt-X.log';
  killall yt-dlp ; break ; }
  read -ra BK< <(strings /tmp/ses/yt-dlp.log|grep -w "\[download\]"|tail -n1)
  if test "$(strings /tmp/ses/yt-dlp.log|grep -c "\[download\]")" -ge 4; then
   echo "${BK[1]/.*/}"
   echo "#$(tr -d '[downloaditf]' <<<"${BK[@]}")"
  else
   sleep 0.5
  fi
  if grep -w 'ERROR:' '/tmp/ses/yt-dlp.log' >/dev/null; then
   yad --text-info --title="YT-DLP HATALI ÇIKTI VERİLERİ" \
       --window-icon="$HOME/.config/subses/subses.png" \
       --height=200 --width=500 --wrap \
       --justify=center< <(strings '/tmp/ses/yt-dlp.log'|grep -w "ERROR:")
  fi
 done|yad --no-buttons --progress --title="𝕊𝕌𝔹𝕊𝔼𝕊" --width=400 \
          --window-icon="$HOME/.config/subses/subses.png" &
 until ! ps "$knt2" >/dev/null; do sleep 1 ; done
 until ! pidof ffmpeg >/dev/null; do sleep 1 ; done
 )
 sleep 0.5
 ViD="$(awk -F: '/Destination:/{print $2}' '/tmp/ses/yt-dlp.log'|sed s/'\s'// )"
 kill -9 `ps aux|awk '$12 ~ /--no-buttons/{printf "%s ",$2}'` 2>/dev/null
 (
 [[ -f '/tmp/ses/yt-X.log' ]] ||\
 nohup ffmpeg -i "$ViD" -i "$SES" -c copy "${SES/.*/}.mkv" > '/tmp/ses/ff.log' &
 ff=$!
 i=0
 until ! ps "$ff" >/dev/null; do
  echo "$i"
  echo "# $(iconv '/tmp/ses/ff.log'|awk '/frame/{print $6,$7,$9,$10|"tail -n1"}')"
  sleep 0.1
  [ "`ps aux|awk '$12 ~ /--no-buttons/{print $2|"wc -l"}'`" \> 0 ] || {
  echo >'/tmp/ses/yt-X.log';
  killall ffmpeg ; break ; }
  ((i++)) || true
 done|yad --no-buttons --progress --title="𝕊𝕌𝔹𝕊𝔼𝕊" --width=400 \
     --pulsate \
     --text="Video ve Ses Dosyaları birkleştiriliyor..." \
     --window-icon="$HOME/.config/subses/subses.png" &
 until ! ps "$ff" >/dev/null; do sleep 1 ; done 2>/dev/null
 kill -9 `ps aux|awk '$12 ~ /--no-buttons/{printf "%s ",$2}'` 2>/dev/null
 )
 sleep 1
fi
rm -rf '/tmp/ses/ff.log' '/tmp/ses/yt-dlp.log' '/tmp/ses/yt-X.log' 2>/dev/null
;;
Wget)
wget -P "${in[5]}" "${in[0]}" 2>&1|tee '/tmp/ses/wget.log' &
Wget=$!
until ! ps "$Wget" >/dev/null; do
 sleep 0.5
 BK=( $(tr -d '.' <'/tmp/ses/wget.log'|awk '/^[0-9]/{print $1,$(NF-2),$(NF-1)|"tail -n1"}') )
 echo "${BK[1]}"
 echo "# ${BK[1]} 🢀 ${BK[2]}  $(grep -wB 2 '0K ...' '/tmp/ses/wget.log'|awk -F/ '/^[A-Z]/{print $NF}')"
done|yad --no-buttons --progress --title="𝕊𝕌𝔹𝕊𝔼𝕊" --width=500 \
         --window-icon="$HOME/.config/subses/subses.png" &
until ! ps "$Wget" >/dev/null; do sleep 1 ; done
Wge="$(strings '/tmp/ses/wget.log'|tail -n1)"
if grep -w "404" <<<"$Wge" >/dev/null; then
    yad --on-top --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
        --height=100 --width=300 \
        --text="Wget hata verdi..!" \
        --window-icon="$HOME/.config/subses/subses.png"
fi
kill -9 `ps aux|awk '$12 ~ /--no-buttons/{printf "%s ",$2}'` 2>/dev/null
rm '/tmp/ses/wget.log' 2>/dev/null
;;
esac
}
# Mpv çıktısı yönlendilir. Hatalı çıktısı yazdırılır.
function oyna() {
[[ "$2" =~ FALSE ]] && url="$1" || url="$3"
if nohup  mpv --pause --cache-pause-initial=yes --autofit=100%x480 "$url" >'/tmp/ses/mpv'; then
 rm -rf '/tmp/ses/mpv' '/tmp/ses/suB.log' '/tmp/ses/i.in' '/tmp/ses/xterm.log' 2>/dev/null
else
 yad --on-top --dnd --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
     --window-icon="$HOME/.config/subses/subses.png" \
     --height=100 --width=300 --text="MPV hata verdi, video oynatılamadı..."
 rm -rf '/tmp/ses/mpv' '/tmp/ses/suB.log' '/tmp/ses/i.in' '/tmp/ses/xterm.log' 2>/dev/null
fi
killall xterm 2>/dev/null
}
# yt-dlp ile video ve altyazı hakkında bilgi alınır.
function bilgi() {
case $1 in
sub)
yad --text-info --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
    --window-icon="$HOME/.config/subses/subses.png" --height=500 \
    --width=1000 --wrap --justify=center< <(yt-dlp --list-subs "$2") 2>/dev/null
;;
video)
yad --text-info --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
    --window-icon="$HOME/.config/subses/subses.png" --height=600 \
    --width=1100 --wrap --justify=center< <(yt-dlp -F "$2") 2>/dev/null
;;
esac
}
# Video-Sub eşli bölme işlemi
function bol() {
  # Video & Altyazı eş zamanlı olarak bölme işlemi.
  ZAMAN() {
  _sub=( "$2" "$1" )
  # Altyazı zamanlama yapılacak kod döngü blok
  i=0
  D=01234567
  bb="$(grep -c '[0-9][0-9]:[0-9][0-9]:' "${_sub[0]}")"
  while read -r oku; do
   pidof xterm || break
   if [[ "$oku" =~ ([0-9][0-9]:) ]]; then
     read -ra II< <(awk -F':|,|-->' -v x="${_sub[1]}" '{
     a = $1*60*60+$2*60+$3"."$4;
     b = $5*60*60+$6*60+$7"."$8;
     printf("%.3f ", a-x);
     printf("%.3f", b-x);
     }' <<<"$oku")
     X="`printf "%02d:%02d:%02d" "$((${II[0]/.*/}/3600))" "$((${II[0]/.*/}%3600/60))" "$((${II[0]/.*/}%60))"`"
     S="`printf "%02d:%02d:%02d" "$((${II[1]/.*/}/3600))" "$((${II[1]/.*/}%3600/60))" "$((${II[1]/.*/}%60))"`"
     echo "$X,${II[0]/*./} --> $S,${II[1]/*./}" >>'/tmp/ses/sub.txt'
   else
    echo "$oku" >>'/tmp/ses/sub.txt'
   fi
   aa=$(grep -c '[0-9][0-9]:[0-9][0-9]:' '/tmp/ses/sub.txt')
   Y=$(("${aa}*100/${bb}*100"/100))
   B=$(("${Y}*5"/10))
   K=$((50-B))
   T=$(perl -E 'say "┃"x'"$B")
   E=$(perl -E 'say "╺"x'"$K")
   pidof xterm && echo -e "`head -n2 '/tmp/ses/xterm.log'`\n╏${T}${E}╏${Y}%" >'/tmp/ses/xterm.log'
  done <"${_sub[0]}"
  }
  cop() {
  find '/tmp/ses' -type f \( -iname "*.txt" -o -iname "*.log" \) -exec rm -rf {} \;
  killall ffmpeg 2>/dev/null
  rm "${yol}.${sub[1]}.txt" 2>/dev/null
  exit 0
  }
  trap cop EXIT
  # Gerekli dosya varlık kontrol edilir yoksa yad ile istenir.
   read -r sub< <(yad --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
    --form --item-separator='!' --separator='#' \
    --window-icon="$HOME/.config/subses/subses.png" \
    --field="Video Seç":FL             "*.mp4" \
    --field="Altyazı Seç":FL           "*.srt" \
    --field="Buraya kadar kes: "       '00:00:00') || exit 2
   sub=( "`cut -d# -f1 <<<"$sub"`" "`cut -d# -f2 <<<"$sub"`" "`cut -d# -f3 <<<"$sub"`" )
   xterm -geometry 80x10-10+300 -fa -hold -T '𝕊𝕌𝔹𝕊𝔼𝕊' -e 'bash -c "watch -n1 cat /tmp/ses/xterm.log"' &
  read -r bak< <(awk -F':' '{print $1*60*60+$2*60+$3}' <<<"${sub[2]}")
  read -r son< <(ffprobe "${sub[0]}" 2>&1 | awk '/Duration:/{print $2}')
  echo -ne "\n"
  # Verilen zamana göre video bölünür.
  ffmpeg -nostdin -loglevel quiet \
  -i "${sub[0]}" -ss "00:00:00" -to "${sub[2]}" -acodec ac3 -vcodec copy "${sub[0]/.*/}.CD1.mp4" &
  ff=$!
  while ps "$ff" >/dev/null; do
   sleep 0.5
   pidof xterm && du -h "${sub[0]/.*/}.CD1.mp4" >'/tmp/ses/xterm.log'
  done
  ffmpeg -nostdin -loglevel quiet \
  -i "${sub[0]}" -ss "${sub[2]}" -to "${son/.*/}" -acodec ac3 -vcodec copy "${sub[0]/.*/}.CD2.mp4" &
  ff=$!
  while ps "$ff" >/dev/null; do
   sleep 0.5
   pidof xterm && du -h "${sub[0]/.*/}.CD1.mp4" "${sub[0]/.*/}.CD2.mp4" >'/tmp/ses/xterm.log'
  done
  # Altyazıyı bölünecek metin dosyasına döngü blok
  s=0
  while read -r al; do
   pidof xterm || break
   if [[ "$al" =~ ([0-9][0-9]:) ]];then
    read -r bk< <(awk -F':|,' '{print $1*60*60+$2*60+$3}' <<<"$al")
    if [[ ! "$bk" -ge "$bak" ]]; then
     echo -e "\n$((++s))\n${al}" >>'/tmp/ses/CD1.txt'
     echo -e "`du -h "${sub[0]/.*/}.CD1.mp4" "${sub[0]/.*/}.CD2.mp4"`
     \n CD-1 Bölünüyor: `du -h '/tmp/ses/CD1.txt'|cut -f1`" >'/tmp/ses/xterm.log'
    else
     echo -e "\n$((++s))\n${al}" >>'/tmp/ses/CD2.txt'
     echo -e "`du -h "${sub[0]/.*/}.CD1.mp4" "${sub[0]/.*/}.CD2.mp4"`
     \n CD-2 Bölünüyor: `du -h '/tmp/ses/CD2.txt'|cut -f1`" >'/tmp/ses/xterm.log'
    fi
   fi
   if [[ "$al" =~ ([A-Za-z]) ]];then
    if [[ ! "$bk" -ge "$bak" ]]; then
     echo -e "$al\n" >>'/tmp/ses/CD1.txt'
    else
     echo -e "$al\n" >>'/tmp/ses/CD2.txt'
    fi
   fi
  done <"${sub[1]}"
  # Bölünen altyazı metin dosyaları srt dönüştürülür.
  ffmpeg -nostdin -loglevel quiet -i '/tmp/ses/CD1.txt' "${sub[0]/.*/}.CD1.srt"
  # Bölünen srt dosyaları bölünen zamana göre yeniden zamanlanır.
  ZAMAN "$bak" "/tmp/ses/CD2.txt" && \
  ffmpeg -nostdin -loglevel quiet -i '/tmp/ses/sub.txt' "${sub[0]/.*/}.CD2.srt"
  if [ $? = 0 ]; then
   echo -e "\nİŞLEM TAMAMLANDI..." >>'/tmp/ses/xterm.log'
   rm '/tmp/ses/sub.txt' '/tmp/ses/CD1.txt' '/tmp/ses/CD2.txt' 2>/dev/null
   sleep 1.5
  else
   echo -e "\nİŞLEM HATASI...!" >>'/tmp/ses/xterm.log'
   rm '/tmp/ses/sub.txt' '/tmp/ses/CD1.txt' '/tmp/ses/CD2.txt' 2>/dev/null
   sleep 1.5
  fi
  killall xterm 2>/dev/null
}
# Video Ses birleştirme
function birles() {
# Mevcut Video ve ses dosyasını secim.
read -r VS< <(yad --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
     --height=80 --width=300 \
     --window-icon="$HOME/.config/subses/subses.png" \
     --text="<span foreground='blue'><b><big><big>Video-SES Secin:</big></big></b></span>" \
     --form --separator='#' \
     --field="Video Dosya:FL" \
     --field="Ses Dosya:FL")
VS=( "`cut -d# -f1 <<<"$VS"`" "`cut -d# -f2 <<<"$VS"`" )
# FFmpeg ile birleştirme işlemi. Çıktı log yönlendilir.
# Log dosyası takip edilerek Yad bile bilgi yazdırılır.
i=0
nohup ffmpeg -i "${VS[0]}" -i "${VS[1]}" -c copy "${VS[0]/.*/}.mkv" >'/tmp/ses/ff.log' &
until ! pidof ffmpeg >/dev/null; do
  echo "$i"
  echo "# $(strings '/tmp/ses/ff.log'|awk '/frame/{print $6,$7,$9,$10|"tail -n1"}')"
  sleep 0.1
  ((i++)) || true
done|yad --no-buttons --progress --title="𝕊𝕌𝔹𝕊𝔼𝕊"\
     --pulsate --width=500 \
     --text="Video ve Ses Dosyaları birkleştiriliyor..." \
     --window-icon="$HOME/.config/subses/subses.png" &
until ! ps "$ff" >/dev/null; do sleep 1 ; done 2>/dev/null
# Yad penceresi kapatılır ve lod silinir.
kill -9 `ps aux|awk '$12 ~ /--no-buttons/{printf "%s ",$2}'` 2>/dev/null
rm '/tmp/ses/ff.log' 2>/dev/null
}
# Mikrofon dinlenerek yazdırma işlemi
function mik() {
  # Mikrofon dineleme ve metne dönüştürülür.
  bnpipe="/tmp/ses/X.pipe"
  if ! test -e "$bnpipe"; then mkfifo $bnpipe; fi
  exec 9<> $bnpipe
  read -ra DiL< <(yad --window-icon="$HOME/.config/subses/subses.png" \
      --title="⟆υᑲ⟆∈⟆" --completion \
      --entry="Name:" ""  $(awk '{printf "\" %s \" ",$1}' "$HOME/.config/subses/dil.log")|\
      while read line; do EX=`echo $line|awk -F',' '{print $1}'`; echo "$EX"; done; sleep 0.1)
  # Tuş konbinasyonu için uygulanacak pencere seçimi.
  function pencere() {
  xdotool selectwindow getmouselocation --shell|awk -F= '/WINDOW/{printf $2 >"/tmp/ses/PX"}';
  }
  export -f pencere
  # Yad arayüzü kullanılarak pipeden veriler aktarılır.
  yad --text-info --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
      --height=600 --width=400 \
      --window-icon="$HOME/.config/subses/subses.png" \
      --wrap --button="SEÇİLEN PENCEYE DE YAZDIR":"bash -c "pencere"" \
      --wrap --button="SEÇİLEN PENCEYE YAZDIRMA":"rm -rf /tmp/ses/PX" \
      --justify=center <&9 ||kill -9 `ps aux|awk '$12 ~ /--on-top/{printf "%s ",$2}'` & SeS=$!
  # Yad arayüzü açık olduğu sürece çalışacak kod blok, mikrofon dinlenir google api kullanılarak metne çevrilir.
  until ! ps "$SeS" &> /dev/null; do
   yad --on-top --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
       --button="LÜTFEN KONUŞUN....":0 \
       --window-icon="$HOME/.config/subses/subses.png" & _yad=$!
   # Mikrofondan kayıt ve GOOGLE url yükleme ve çıktıyı alma.
   rec -q -r 16000 -b 16 -e signed-integer -p silence 1 0.50 0.1% 1 10:00 0.1% trim 0 4 |\
   sox -q -p '/tmp/ses/X.ogg' silence 1 0.50 0.1% 1 2.0 0.1% : newfile : restart || break >/dev/null
   kill -9 "$_yad" 2>/dev/null
   if sox -q '/tmp/ses/X001.ogg' -r 16000 -c 1 -b 16 '/tmp/ses/x.flac'; then >/dev/null
    rm -rf '/tmp/ses/x.wav' 2>/dev/null
    MOZ='Mozilla/5.0'
    KEY='AIzaSyBOti4mM-6x9WDnZIjIeyEU21OpBXqWBgw'
    _metin="$(curl -X POST \
    --data-binary @'/tmp/ses/x.flac' \
    --user-agent $MOZ \
    --header 'Content-Type: audio/x-flac; rate=16000;' \
    "https://www.google.com/speech-api/v2/recognize?output=json&lang=$DiL&key="$KEY"&client="$MOZ \
    |sed -e 's/[{}]/\n/g' -e 's/^\s\{1,\}//'\
    |awk -F'"' '/transcript/{print $4 | "tail -n1"}')"
    echo "$_metin" >&9
    if [[ -e '/tmp/ses/PX' ]]; then xdotool type --window "$(</tmp/ses/PX)" "$_metin "; fi
    rm -rf '/tmp/ses/x.flac' '/tmp/ses/X001.ogg' 2>/dev/null
   else
    rm -rf '/tmp/ses/X001.ogg' '/tmp/ses/x.flac' 2>/dev/null
   fi
  done 2>/dev/null
  exec 9>&-
  rm -rf '/tmp/ses/X.pipe' '/tmp/ses/PX' 2>/dev/null
}
# Tuş konbinasyon işlemi
function tus() {
  # xdotool uyg kullanımı için basit bir arayüz...
  echo -n > '/tmp/ses/kod'
  # Seçim yapılan pencerenin sayısal kod alımı yapılan foksiyon.
  function pencere() {
  xdotool selectwindow getmouselocation --shell|\
  awk -F= -v s="$1" '/WINDOW/{print "\n# "$2,s"\n" >>"/tmp/ses/kod"}'
  }
  # Tuş konbinasyon işleminin kayıt edilen foksiyon
  function klavye() {
  _depo+="$(xev|awk -F'[ )]+' '/^KeyPress/ { a[NR+2] } NR in a { printf "%s ",$8}')"
  for i in $_depo; do
   if [[ "${i:(-2)}" == "_L" ]]; then
    printf "%s" "${i/_L/+}" >>'/tmp/ses/kod'
   else
    printf "%s\n" "$i" >>'/tmp/ses/kod'
   fi
  done
  }
  # xterm ile tuş konbinasyon kontrol
  XTERM() {
  xterm -geometry 50x20-10+10 -fa -hold -T '𝕊𝕌𝔹𝕊𝔼𝕊' -e 'bash -c "watch -n1 cat /tmp/ses/kod"'
  }
  # Foksiyonlar için export kullanımı
  export -f pencere
  export -f klavye
  export -f XTERM
  # uyg'nın arayüz kod blok
  yad --form --title="𝕊𝕌𝔹𝕊𝔼𝕊" \
      --window-icon="$HOME/.config/subses/subses.png" \
      --field="TEKRARLAT":SW "FALSE"\
      --field="Baş Beklet":NUM "0"\
      --field="Ara Beklet" "0" \
      --field='PENCERE!gtk-yes!popup':FBTN 'bash -c "pencere %3"' \
      --field='TUŞ!gtk-yes!popup':FBTN 'bash -c "klavye"' \
      --field='BAŞLA!gtk-yes!popup':FBTN 'echo "%2 %1"' \
      --field='TUŞ BİLGİ!gtk-yes!popup':FBTN 'bash -c "XTERM"' \
      --field='DUR!gtk-yes!popup':FBTN 'rm /tmp/ses/kod' \
      --button=iptal:1 |\
      while read -ra oku; do
       sleep ${oku[0]}
       if [[ "${oku[1]}" == "FALSE" ]]; then
        while read -ra yaz; do
         test ! -e '/tmp/ses/kod' && break
         if [[ "${yaz[0]}" == "#" ]]; then
          UiD=${yaz[1]}
          DUR=${yaz[2]}
         else
          xdotool sleep "$DUR" windowactivate --sync "$UiD" key "${yaz[0]}"
         fi
        done <'/tmp/ses/kod'
       elif [[ "${oku[1]}" == "TRUE" ]]; then
        while test -e '/tmp/ses/kod'; do
         while read -ra yaz; do
          test ! -e '/tmp/ses/kod' && break
          if [[ "${yaz[0]}" == "#" ]]; then
           UiD=${yaz[1]}
           DUR=${yaz[2]}
          else
           xdotool sleep "$DUR" windowactivate --sync "$UiD" key "${yaz[0]}"
          fi
         done <'/tmp/ses/kod'
        done
       fi
      done >/dev/null &
}
# Uyg için çalışan foksiyonlar
export -f dublaj
export -f bilgi
export -f indir
export -f oyna
export -f birles
export -f mik
export -f tus
export -f bol
# Pano içeriği kontrol edilir link ise aktarılır. Uyg için basit bir arayüz sağlanır.
_url="`xclip -o -rmlastnl -selection clipboard|awk '/^http/'`"
yad --form --title="⟆υᑲ⟆∈⟆  v1.6" --height=200 --width=400 \
    --window-icon="$HOME/.config/subses/subses.png" \
    --item-separator='!' --separator=' '\
    --field="<span foreground='blue'><b><big><big>URL:</big></big></b></span>":TXT "$_url"\
    --field="Video ve Sub":CB                                                      'sub!video'\
    --field="Video ekle:":SW                                                       'FALSE'\
    --field="Video Dosyası":FL                                                     'ViDEO'\
    --field='<b><big><big>Youtube Bilgi</big></big></b>!gtk-yes!popup':BTN         'bash -c "bilgi %2 %1"'\
    --field='<b><big><big>Video OYNAT</big></big></b>!gtk-yes!popup':FBTN          'bash -c "oyna %1 %3 %4"'\
    --field='<b><big><big>DUBLAJI BAŞLAT</big></big></b>!gtk-yes!popup':FBTN       'bash -c "dublaj"'\
    --field='<b><big><big>iNDiRME MENU</big></big></b>!gtk-yes!popup':FBTN         'bash -c "indir %1"'\
    --field='<b><big><big>TUŞ Konbinasyon </big></big></b>!gtk-yes!popup':FBTN     'bash -c "tus"'\
    --field='<b><big><big>Mikrofon Dinle</big></big></b>!gtk-yes!popup':FBTN       'bash -c "mik"'\
    --field='<b><big><big>Video+Sub Böl</big></big></b>!gtk-yes!popup':FBTN        'bash -c "bol"'\
    --field='<b><big><big>Video+Ses Birleştir</big></big></b>!gtk-yes!popup':FBTN  'bash -c "birles"'\
    --button=ÇIKIŞ:0 >/dev/null
