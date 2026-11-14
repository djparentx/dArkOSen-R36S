#!/bin/bash
#
# Adds the Corridors screensaver strings to every locale in this folder.
# An msgid that already exists in a .po file is skipped.
# No arguments. Log: add_corridors_strings.log in this folder.

DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$DIR/add_corridors_strings.log"
added=0
skipped=0
missing=0

printf '%-7s %-32s %s\n' "LANG" "MSGID" "RESULT" > "$LOG"

while IFS='|' read -r lang id str; do
    [ -z "$lang" ] && continue
    po="$DIR/$lang/emulationstation2.po"

    if [ ! -f "$po" ]; then
        result="no .po file"
        missing=$((missing + 1))
    elif grep -qxF "msgid \"$id\"" "$po"; then
        result="exists, skipped"
        skipped=$((skipped + 1))
    else
        printf '\n#:\nmsgid "%s"\nmsgstr "%s"\n' "$id" "$str" >> "$po"
        result="added"
        added=$((added + 1))
    fi

    printf '%-7s %-32s %s\n' "$lang" "$id" "$result" >> "$LOG"
done <<'EOF'
br|corridors|corredores
br|CORRIDORS SCREENSAVER SETTINGS|AJUSTAR SCREENSAVER CORREDORES
br|CORRIDORS SCREENSAVER|SCREENSAVER CORREDORES
br|SPEED|VELOCIDADE
br|AMBIENT|LUZ AMBIENTE
br|PANELS|PAINÉIS
br|FLICKER|PISCAR
br|FOG|NEBLINA
br|VOLUME|VOLUME
de|corridors|korridore
de|CORRIDORS SCREENSAVER SETTINGS|KORRIDORE-BILDSCHIRMSCHONER-EINSTELLUNGEN
de|CORRIDORS SCREENSAVER|KORRIDORE-BILDSCHIRMSCHONER
de|SPEED|GESCHWINDIGKEIT
de|AMBIENT|UMGEBUNGSLICHT
de|PANELS|LEUCHTPANELE
de|FLICKER|FLACKERN
de|FOG|NEBEL
de|VOLUME|LAUTSTÄRKE
el|corridors|διάδρομοι
el|CORRIDORS SCREENSAVER SETTINGS|ΡΥΘΜΙΣΕΙΣ ΠΡΟΣΤΑΣΙΑΣ ΟΘΟΝΗΣ ΔΙΑΔΡΟΜΩΝ
el|CORRIDORS SCREENSAVER|ΠΡΟΣΤΑΣΙΑ ΟΘΟΝΗΣ ΔΙΑΔΡΟΜΩΝ
el|SPEED|ΤΑΧΥΤΗΤΑ
el|AMBIENT|ΦΩΣ ΠΕΡΙΒΑΛΛΟΝΤΟΣ
el|PANELS|ΦΩΤΙΣΤΙΚΑ
el|FLICKER|ΤΡΕΜΟΠΑΙΓΜΑ
el|FOG|ΟΜΙΧΛΗ
el|VOLUME|ΕΝΤΑΣΗ
es|corridors|pasillos
es|CORRIDORS SCREENSAVER SETTINGS|AJUSTES SALVAPANTALLAS PASILLOS
es|CORRIDORS SCREENSAVER|SALVAPANTALLAS PASILLOS
es|SPEED|VELOCIDAD
es|AMBIENT|LUZ AMBIENTE
es|PANELS|PANELES
es|FLICKER|PARPADEO
es|FOG|NIEBLA
es|VOLUME|VOLUMEN
fr|corridors|couloirs
fr|CORRIDORS SCREENSAVER SETTINGS|PARAMÈTRES DE L'ÉCRAN DE VEILLE COULOIRS
fr|CORRIDORS SCREENSAVER|ÉCRAN DE VEILLE COULOIRS
fr|SPEED|VITESSE
fr|AMBIENT|LUMIÈRE AMBIANTE
fr|PANELS|PANNEAUX
fr|FLICKER|SCINTILLEMENT
fr|FOG|BROUILLARD
fr|VOLUME|VOLUME
it|corridors|corridoi
it|CORRIDORS SCREENSAVER SETTINGS|IMPOSTAZIONI SALVASCHERMO CORRIDOI
it|CORRIDORS SCREENSAVER|SALVASCHERMO CORRIDOI
it|SPEED|VELOCITÀ
it|AMBIENT|LUCE AMBIENTE
it|PANELS|PANNELLI
it|FLICKER|SFARFALLIO
it|FOG|NEBBIA
it|VOLUME|VOLUME
ja|corridors|廊下
ja|CORRIDORS SCREENSAVER SETTINGS|廊下スクリーンセーバーの設定
ja|CORRIDORS SCREENSAVER|廊下スクリーンセーバー
ja|SPEED|速度
ja|AMBIENT|環境光
ja|PANELS|照明パネル
ja|FLICKER|ちらつき
ja|FOG|霧
ja|VOLUME|音量
ko|corridors|복도
ko|CORRIDORS SCREENSAVER SETTINGS|복도 화면보호기 설정
ko|CORRIDORS SCREENSAVER|복도 화면보호기
ko|SPEED|속도
ko|AMBIENT|주변광
ko|PANELS|조명 패널
ko|FLICKER|깜빡임
ko|FOG|안개
ko|VOLUME|음량
pl|corridors|korytarze
pl|CORRIDORS SCREENSAVER SETTINGS|USTAWIENIA WYGASZACZA KORYTARZE
pl|CORRIDORS SCREENSAVER|WYGASZACZ KORYTARZE
pl|SPEED|PRĘDKOŚĆ
pl|AMBIENT|ŚWIATŁO OTOCZENIA
pl|PANELS|PANELE
pl|FLICKER|MIGOTANIE
pl|FOG|MGŁA
pl|VOLUME|GŁOŚNOŚĆ
pt|corridors|corredores
pt|CORRIDORS SCREENSAVER SETTINGS|CONFIGURAÇÕES DO PROTETOR DE ECRÃ CORREDORES
pt|CORRIDORS SCREENSAVER|PROTETOR DE ECRÃ CORREDORES
pt|SPEED|VELOCIDADE
pt|AMBIENT|LUZ AMBIENTE
pt|PANELS|PAINÉIS
pt|FLICKER|CINTILAÇÃO
pt|FOG|NEVOEIRO
pt|VOLUME|VOLUME
ru|corridors|коридоры
ru|CORRIDORS SCREENSAVER SETTINGS|НАСТРОЙКА ЗАСТАВКИ КОРИДОРЫ
ru|CORRIDORS SCREENSAVER|ЗАСТАВКА КОРИДОРЫ
ru|SPEED|СКОРОСТЬ
ru|AMBIENT|ФОНОВЫЙ СВЕТ
ru|PANELS|ПАНЕЛИ
ru|FLICKER|МЕРЦАНИЕ
ru|FOG|ТУМАН
ru|VOLUME|ГРОМКОСТЬ
sv|corridors|korridorer
sv|CORRIDORS SCREENSAVER SETTINGS|INSTÄLLNINGAR FÖR KORRIDORSKÄRMSLÄCKARE
sv|CORRIDORS SCREENSAVER|KORRIDORSKÄRMSLÄCKARE
sv|SPEED|HASTIGHET
sv|AMBIENT|OMGIVNINGSLJUS
sv|PANELS|PANELER
sv|FLICKER|FLIMMER
sv|FOG|DIMMA
sv|VOLUME|VOLYM
ua|corridors|коридори
ua|CORRIDORS SCREENSAVER SETTINGS|НАЛАШТУВАННЯ ЗАСТАВКИ КОРИДОРИ
ua|CORRIDORS SCREENSAVER|ЗАСТАВКА КОРИДОРИ
ua|SPEED|ШВИДКІСТЬ
ua|AMBIENT|ФОНОВЕ СВІТЛО
ua|PANELS|ПАНЕЛІ
ua|FLICKER|МЕРЕХТІННЯ
ua|FOG|ТУМАН
ua|VOLUME|ГУЧНІСТЬ
uk|corridors|коридори
uk|CORRIDORS SCREENSAVER SETTINGS|НАЛАШТУВАННЯ ЗАСТАВКИ КОРИДОРИ
uk|CORRIDORS SCREENSAVER|ЗАСТАВКА КОРИДОРИ
uk|SPEED|ШВИДКІСТЬ
uk|AMBIENT|ФОНОВЕ СВІТЛО
uk|PANELS|ПАНЕЛІ
uk|FLICKER|МЕРЕХТІННЯ
uk|FOG|ТУМАН
uk|VOLUME|ГУЧНІСТЬ
vi|corridors|hành lang
vi|CORRIDORS SCREENSAVER SETTINGS|CÀI ĐẶT BẢO VỆ MÀN HÌNH HÀNH LANG
vi|CORRIDORS SCREENSAVER|BẢO VỆ MÀN HÌNH HÀNH LANG
vi|SPEED|TỐC ĐỘ
vi|AMBIENT|ÁNH SÁNG MÔI TRƯỜNG
vi|PANELS|TẤM ĐÈN
vi|FLICKER|NHẤP NHÁY
vi|FOG|SƯƠNG MÙ
vi|VOLUME|ÂM LƯỢNG
zh-CN|corridors|走廊
zh-CN|CORRIDORS SCREENSAVER SETTINGS|走廊屏幕保护程序设定
zh-CN|CORRIDORS SCREENSAVER|走廊屏幕保护程序
zh-CN|SPEED|速度
zh-CN|AMBIENT|环境光
zh-CN|PANELS|灯板
zh-CN|FLICKER|闪烁
zh-CN|FOG|雾
zh-CN|VOLUME|音量
zh-TW|corridors|走廊
zh-TW|CORRIDORS SCREENSAVER SETTINGS|走廊螢幕保護程式設定
zh-TW|CORRIDORS SCREENSAVER|走廊螢幕保護程式
zh-TW|SPEED|速度
zh-TW|AMBIENT|環境光
zh-TW|PANELS|燈板
zh-TW|FLICKER|閃爍
zh-TW|FOG|霧
zh-TW|VOLUME|音量
EOF

printf '\n%-14s %d\n%-14s %d\n%-14s %d\n' \
    "Added" "$added" "Skipped" "$skipped" "No .po file" "$missing" >> "$LOG"
cat "$LOG"
