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
CODEX_TIMEOUT_SECONDS="${SEMI_CODEX_TIMEOUT_SECONDS:-1500}"
ENFORCE_SCHEDULE_WINDOW="${SEMI_ENFORCE_SCHEDULE_WINDOW:-0}"
SCHEDULE_MODE="${SEMI_SCHEDULE_MODE:-default}"
TODAY_ISO="${SEMI_DATE:-$(date '+%Y-%m-%d')}"
TODAY_YYMMDD="$(date -j -f '%Y-%m-%d' "$TODAY_ISO" '+%y%m%d' 2>/dev/null || date '+%y%m%d')"
SUMMARY_FILE="${SEMI_SUMMARY_FILE:-/tmp/semiconductor-daily-summary-${TODAY_ISO}.txt}"
PROMPT_FILE="${SEMI_PROMPT_FILE:-/tmp/semiconductor-daily-prompt-${TODAY_ISO}.md}"
DAILY_WIKI_FILE="$WIKI_ROOT/wiki/${TODAY_YYMMDD}-半导体公司池每日更新.md"
DAILY_HTML_FILE="$WIKI_ROOT/wiki/${TODAY_YYMMDD}-半导体公司池每日更新.html"
LOCK_DIR="${SEMI_LOCK_DIR:-/tmp/semiconductor-daily-update.lock}"

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

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "skip because lock exists at ${LOCK_DIR}"
  send_email \
    "${TODAY_ISO} 半导体池自动更新未执行" \
    "半导体池自动更新未执行，因为发现已有运行中的锁目录：${LOCK_DIR}

日期：${TODAY_ISO}
日志：${LOG_FILE}

请检查是否有前一轮任务卡住。" \
    ""
  exit 1
fi

cleanup() {
  rm -rf "$LOCK_DIR"
}

trap cleanup EXIT

if [[ -n "$END_DATE" && "$TODAY_ISO" > "$END_DATE" ]]; then
  log "skip after end date ${END_DATE}"
  exit 0
fi

if [[ "$SKIP_WEEKENDS" == "1" && "$(date '+%u')" -gt 5 ]]; then
  log "skip weekend"
  exit 0
fi

if [[ "$ENFORCE_SCHEDULE_WINDOW" == "1" && "$SCHEDULE_MODE" == "after_us_close_full" ]]; then
  NY_HM="$(TZ=America/New_York date '+%H%M')"
  NY_WDAY="$(TZ=America/New_York date '+%u')"
  LOCAL_HM="$(date '+%H%M')"
  LOCAL_WDAY="$(date '+%u')"
  NY_HM_NUM=$((10#$NY_HM))
  LOCAL_HM_NUM=$((10#$LOCAL_HM))
  TRIGGER_REASON=""

  if [[ "$NY_WDAY" -le 5 && "$NY_HM_NUM" -ge 1605 && "$NY_HM_NUM" -le 1730 ]]; then
    TRIGGER_REASON="us_close_window"
  elif [[ "$LOCAL_WDAY" -le 5 && "$LOCAL_HM_NUM" -ge 630 && "$LOCAL_HM_NUM" -le 830 ]]; then
    if [[ "$LOCAL_WDAY" == "1" ]]; then
      TRIGGER_REASON="monday_weekend_catchup"
    else
      TRIGGER_REASON="weekday_morning_supplement"
    fi
  else
    log "skip outside schedule window: local=${LOCAL_WDAY}/${LOCAL_HM} ny=${NY_WDAY}/${NY_HM} mode=${SCHEDULE_MODE}"
    exit 0
  fi

  log "schedule window matched: ${TRIGGER_REASON} local=${LOCAL_WDAY}/${LOCAL_HM} ny=${NY_WDAY}/${NY_HM}"
fi

sed \
  -e "s|{{WIKI_ROOT}}|${WIKI_ROOT}|g" \
  -e "s|{{TODAY_ISO}}|${TODAY_ISO}|g" \
  -e "s|{{TODAY_YYMMDD}}|${TODAY_YYMMDD}|g" \
  "$PROMPT_TEMPLATE" > "$PROMPT_FILE"

log "start codex run"

python3 - "$LOG_FILE" "$WIKI_ROOT" "$SUMMARY_FILE" "$PROMPT_FILE" "$CODEX_TIMEOUT_SECONDS" <<'PY'
import subprocess
import sys
from pathlib import Path

log_file, wiki_root, summary_file, prompt_file, timeout_seconds = sys.argv[1:6]
prompt = Path(prompt_file).read_text(encoding="utf-8")

cmd = [
    "codex",
    "--search",
    "-a",
    "never",
    "exec",
    "--ignore-user-config",
    "--ignore-rules",
    "--ephemeral",
    "-c",
    "notify=[]",
    "-c",
    'plugins."browser@openai-bundled".enabled=false',
    "-c",
    'plugins."computer-use@openai-bundled".enabled=false',
    "-c",
    'plugins."chrome@openai-bundled".enabled=false',
    "-c",
    'plugins."documents@openai-primary-runtime".enabled=false',
    "-c",
    'plugins."spreadsheets@openai-primary-runtime".enabled=false',
    "-c",
    'plugins."presentations@openai-primary-runtime".enabled=false',
    "-c",
    'plugins."zotero@openai-curated".enabled=false',
    "-c",
    'plugins."morningstar@openai-curated".enabled=false',
    "-c",
    'plugins."mt-newswires@openai-curated".enabled=false',
    "-c",
    'plugins."alpaca@openai-curated".enabled=false',
    "-c",
    'plugins."dow-jones-factiva@openai-curated".enabled=false',
    "-c",
    'plugins."gmail@openai-curated".enabled=false',
    "-c",
    'plugins."google-drive@openai-curated".enabled=false',
    "-C",
    wiki_root,
    "-s",
    "danger-full-access",
    "--output-last-message",
    summary_file,
    prompt,
]

with open(log_file, "a", encoding="utf-8") as log:
    try:
        completed = subprocess.run(
            cmd,
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=int(timeout_seconds),
            check=False,
        )
    except subprocess.TimeoutExpired:
        log.write(f"\n[watchdog] codex timed out after {timeout_seconds} seconds\n")
        sys.exit(124)

sys.exit(completed.returncode)
PY

CODEX_EXIT=$?

if [[ "$CODEX_EXIT" -ne 0 ]]; then
  log "codex run failed with exit code ${CODEX_EXIT}"
  send_email \
    "${TODAY_ISO} 半导体池自动更新失败" \
    "半导体池自动更新未成功完成。

日期：${TODAY_ISO}
退出码：${CODEX_EXIT}
预期主稿：${DAILY_WIKI_FILE}
日志：${LOG_FILE}

如果退出码是 124，表示 codex 在 ${CODEX_TIMEOUT_SECONDS} 秒内没有完成，已被看门狗终止。" \
    ""
  exit "$CODEX_EXIT"
fi

if [[ ! -f "$DAILY_WIKI_FILE" ]]; then
  log "expected report was not created: ${DAILY_WIKI_FILE}"
  send_email \
    "${TODAY_ISO} 半导体池自动更新失败" \
    "半导体池自动更新已执行完 codex，但未发现预期主稿。

日期：${TODAY_ISO}
预期主稿：${DAILY_WIKI_FILE}
日志：${LOG_FILE}" \
    ""
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
