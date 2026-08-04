#!/usr/bin/env bash
#
# שולח לטלגרם את המנה היומית של היום.
#
# מקור התוכן: docs/daily-ai/queue/YYYY-MM-DD.md
# בתוך הקובץ, כל הודעה מופרדת מהבאה בשורה שכולה %%%
#
# מופעל מ-.github/workflows/daily-digest.yml. דורש secret אחד: TELEGRAM_TOKEN.
# ה-chat_id אינו סוד — לבדו הוא לא מאפשר דבר בלי הטוקן — ולכן הוא בקוד,
# כדי לחסוך צעד ידני נוסף בהגדרה.

set -uo pipefail

CHAT_ID="6481142091"
QUEUE_DIR="docs/daily-ai/queue"

if [[ -z "${TELEGRAM_TOKEN:-}" ]]; then
  echo "::error::חסר secret בשם TELEGRAM_TOKEN. להוסיף ב-Settings › Secrets and variables › Actions"
  exit 1
fi

API="https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage"

# שולח קובץ טקסט אחד כהודעה. הטקסט עובר דרך קובץ ולא בשורת הפקודה —
# עברית בארגומנט ישיר נשברת ("strings must be encoded in UTF-8").
send_file() {
  local path="$1" resp
  resp="$(curl -sS -m 30 -X POST "$API" \
    -F "chat_id=${CHAT_ID}" \
    -F "disable_web_page_preview=true" \
    -F "text=<${path}")"
  if [[ "$resp" == *'"ok":true'* ]]; then
    return 0
  fi
  # לא מדפיסים את $resp — טלגרם מחזיר את ה-URL המלא בשגיאות מסוימות,
  # וה-URL מכיל את הטוקן.
  echo "::error::שליחה נכשלה עבור ${path}"
  return 1
}

# שולח מחרוזת קצרה (להתראות מערכת, לא לתוכן המנה).
send_text() {
  local tmp
  tmp="$(mktemp)"
  printf '%s\n' "$1" > "$tmp"
  send_file "$tmp"
  local rc=$?
  rm -f "$tmp"
  return $rc
}

TODAY="$(TZ=Asia/Jerusalem date +%F)"
FILE="${QUEUE_DIR}/${TODAY}.md"

# כמה מנות עתידיות נשארו בתור. שמות הקבצים הם YYYY-MM-DD.md, ולכן
# השוואת מחרוזות פשוטה מספיקה — אין צורך לפרסר תאריכים.
count_future() {
  find "$QUEUE_DIR" -name '*.md' 2>/dev/null \
    | awk -v t="${TODAY}.md" -F/ '$NF > t' \
    | wc -l | tr -d ' '
}

if [[ ! -f "$FILE" ]]; then
  # התור התרוקן. מודיעים לאיתן במקום להיעלם בשקט — יום בלי הודעה
  # נראה בדיוק כמו תקלה, וזה מה שקרה חמישה ימים ברוטינת הענן.
  remaining="$(count_future)"
  send_text "📭 אין מנה מוכנה ל-${TODAY}.
התור נגמר — נשארו ${remaining} מנות עתידיות.
תפתח את VS Code ותכתוב לקלוד: מלא את התור."
  echo "::warning::אין קובץ ${FILE}"
  exit 0
fi

# פיצול הקובץ להודעות נפרדות לפי שורות %%%
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

awk -v dir="$WORK" '
  BEGIN { n = 1; f = sprintf("%s/part-%02d.txt", dir, n) }
  /^%%%[[:space:]]*$/ { n++; f = sprintf("%s/part-%02d.txt", dir, n); next }
  { print > f }
' "$FILE"

sent=0
failed=0
for part in "$WORK"/part-*.txt; do
  [[ -s "$part" ]] || continue           # מדלג על חלקים ריקים
  if send_file "$part"; then
    sent=$((sent + 1))
  else
    failed=$((failed + 1))
  fi
  sleep 1                                # נותן לטלגרם לנשום בין הודעות
done

echo "נשלחו ${sent} הודעות, נכשלו ${failed}, מתוך ${FILE}"

# כמה מנות נשארו בתור אחרי היום
left="$(count_future)"
echo "נשארו בתור: ${left} מנות"
if [[ "$left" -le 2 ]]; then
  send_text "⏳ נשארו רק ${left} מנות בתור. שווה למלא מחדש."
fi

[[ "$failed" -eq 0 ]]
