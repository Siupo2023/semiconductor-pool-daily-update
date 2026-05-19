#!/usr/bin/env bash

set -euo pipefail

export PATH="/Applications/Codex.app/Contents/Resources:$HOME/.npm-global/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WIKI_ROOT="${SEMI_WIKI_ROOT:-$HOME/llm-wiki}"
PROMPT_TEMPLATE="${SEMI_PROMPT_TEMPLATE:-$SKILL_DIR/references/semiconductor-daily-update.prompt.md}"
EMAIL_ENV="${SEMI_EMAIL_ENV:-$HOME/.openclaw/skills/news-aggregator-skill/.env}"
LOG_FILE="${SEMI_LOG_FILE:-$HOME/.openclaw/logs/semiconductor-daily-update.log}"
END_DATE="${SEMI_END_DATE:-}"
SKIP_WEEKENDS="${SEMI_SKIP_WEEKENDS:-1}"
TODAY_ISO="${SEMI_DATE:-$(date '+%Y-%m-%d')}"
TODAY_YYMMDD="$(date -j -f '%Y-%m-%d' "$TODAY_ISO" '+%y%m%d' 2>/dev/null || date '+%y%m%d')"
SUMMARY_FILE="${SEMI_SUMMARY_FILE:-/tmp/semiconductor-daily-summary-${TODAY_ISO}.txt}"
PROMPT_FILE="${SEMI_PROMPT_FILE:-/tmp/semiconductor-daily-prompt-${TODAY_ISO}.md}"
DAILY_WIKI_FILE="$WIKI_ROOT/wiki/${TODAY_YYMMDD}-半导体公司池每日更新.md"
DAILY_HTML_FILE="$WIKI_ROOT/wiki/${TODAY_YYMMDD}-半导体公司池每日更新.html"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 127
  fi
}

send_email() {
  local subject="$1"
  local body="$2"
  local attachment="${3:-}"

  python3 - "$EMAIL_ENV" "$subject" "$body" "$attachment" <<'PY'
import mimetypes
import smtplib
import ssl
import sys
from email.message import EmailMessage
from email.utils import formatdate
from pathlib import Path

env_path, subject, body, attachment = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
vals = {}
path = Path(env_path).expanduser()
if path.exists():
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        vals[k.strip()] = v.strip().strip('"').strip("'")

smtp_host = vals.get("SMTP_SERVER") or vals.get("SMTP_HOST")
smtp_port = int(vals.get("SMTP_PORT") or 587)
smtp_user = vals.get("SMTP_USER") or vals.get("EMAIL_USER")
smtp_pass = vals.get("SMTP_PASSWORD") or vals.get("SMTP_PASS") or vals.get("EMAIL_PASSWORD")
recipient = vals.get("DEFAULT_EMAIL") or vals.get("RECIPIENT_EMAIL") or smtp_user

if not all([smtp_host, smtp_user, smtp_pass, recipient]):
    raise SystemExit(f"missing SMTP config in {path}")

msg = EmailMessage()
msg["Subject"] = subject
msg["From"] = smtp_user
msg["To"] = recipient
msg["Date"] = formatdate(localtime=True)
msg.set_content(body)

if attachment:
    attachment_path = Path(attachment)
    if attachment_path.exists():
        ctype, _ = mimetypes.guess_type(str(attachment_path))
        maintype, subtype = (ctype or "text/html").split("/", 1)
        msg.add_attachment(
            attachment_path.read_bytes(),
            maintype=maintype,
            subtype=subtype,
            filename=attachment_path.name,
        )

context = ssl.create_default_context()
with smtplib.SMTP(smtp_host, smtp_port, timeout=30) as server:
    server.ehlo()
    server.starttls(context=context)
    server.ehlo()
    server.login(smtp_user, smtp_pass)
    server.send_message(msg)
PY
}

require_bin codex
require_bin pandoc
require_bin python3

if [[ -n "$END_DATE" && "$TODAY_ISO" > "$END_DATE" ]]; then
  log "skip after end date ${END_DATE}"
  exit 0
fi

if [[ "$SKIP_WEEKENDS" == "1" && "$(date '+%u')" -gt 5 ]]; then
  log "skip weekend"
  exit 0
fi

sed \
  -e "s|{{WIKI_ROOT}}|${WIKI_ROOT}|g" \
  -e "s|{{TODAY_ISO}}|${TODAY_ISO}|g" \
  -e "s|{{TODAY_YYMMDD}}|${TODAY_YYMMDD}|g" \
  "$PROMPT_TEMPLATE" > "$PROMPT_FILE"

log "start codex run"

codex --search -a never exec \
  --ignore-user-config \
  --ignore-rules \
  --ephemeral \
  -c 'notify=[]' \
  -c 'plugins."browser@openai-bundled".enabled=false' \
  -c 'plugins."computer-use@openai-bundled".enabled=false' \
  -c 'plugins."chrome@openai-bundled".enabled=false' \
  -c 'plugins."documents@openai-primary-runtime".enabled=false' \
  -c 'plugins."spreadsheets@openai-primary-runtime".enabled=false' \
  -c 'plugins."presentations@openai-primary-runtime".enabled=false' \
  -c 'plugins."zotero@openai-curated".enabled=false' \
  -c 'plugins."morningstar@openai-curated".enabled=false' \
  -c 'plugins."mt-newswires@openai-curated".enabled=false' \
  -c 'plugins."alpaca@openai-curated".enabled=false' \
  -c 'plugins."dow-jones-factiva@openai-curated".enabled=false' \
  -c 'plugins."gmail@openai-curated".enabled=false' \
  -c 'plugins."google-drive@openai-curated".enabled=false' \
  -C "$WIKI_ROOT" \
  -s danger-full-access \
  --output-last-message "$SUMMARY_FILE" \
  "$(cat "$PROMPT_FILE")" >> "$LOG_FILE" 2>&1

if [[ ! -f "$DAILY_WIKI_FILE" ]]; then
  echo "expected report was not created: $DAILY_WIKI_FILE" >&2
  exit 1
fi

pandoc \
  "$DAILY_WIKI_FILE" \
  --standalone \
  --metadata title="${TODAY_ISO} 半导体公司池每日更新" \
  --css=https://cdn.jsdelivr.net/npm/water.css@2/out/water.css \
  -o "$DAILY_HTML_FILE"

log "daily html generated"

SUMMARY_TEXT="$(cat "$SUMMARY_FILE")"
EMAIL_BODY="半导体池更新已完成。

日期：${TODAY_ISO}
Wiki 页面（Markdown）：${DAILY_WIKI_FILE}
邮件附件（HTML）：${DAILY_HTML_FILE}

摘要：
${SUMMARY_TEXT}"

send_email "${TODAY_ISO} 半导体池最新进展 HTML" "$EMAIL_BODY" "$DAILY_HTML_FILE"
log "daily email sent"

echo "$SUMMARY_TEXT"
