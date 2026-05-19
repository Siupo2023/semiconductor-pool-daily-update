# semiconductor-pool-daily-update

A portable OpenClaw/Codex skill for the daily China semiconductor watchlist workflow.

This skill:

- reads local Wiki context and daily review rules
- fetches the latest A-share and U.S. peer data through Codex web search
- writes a Markdown daily report into your Wiki
- renders the report to HTML
- emails the HTML file as an attachment

## Repository Layout

- `SKILL.md`: skill entrypoint and capability contract
- `scripts/semiconductor_daily_update.sh`: runnable workflow script
- `references/semiconductor-daily-update.prompt.md`: Codex prompt template
- `agents/openai.yaml`: basic agent metadata

## Requirements

- `bash`
- `codex`
- `pandoc`
- `python3`
- SMTP credentials for outbound email

## Quick Start

Clone the repo:

```bash
git clone https://github.com/Siupo2023/semiconductor-pool-daily-update.git
cd semiconductor-pool-daily-update
```

Set the core environment variables:

```bash
export SEMI_WIKI_ROOT="$HOME/llm-wiki"
export SEMI_EMAIL_ENV="$HOME/.openclaw/skills/news-aggregator-skill/.env"
```

Run the workflow:

```bash
bash scripts/semiconductor_daily_update.sh
```

Install the skill into the default OpenClaw skills directory:

```bash
bash install.sh
```

## SMTP Config

The workflow reads SMTP values from the file pointed to by `SEMI_EMAIL_ENV`.

Expected keys:

```bash
SMTP_SERVER=smtp.qq.com
SMTP_PORT=587
SMTP_USER=your_email@example.com
SMTP_PASSWORD=your_smtp_authorization_code
DEFAULT_EMAIL=recipient@example.com
```

Do not commit real credentials.

## OpenClaw Install

Use the installer:

```bash
bash install.sh
```

Or install to a custom skills root:

```bash
bash install.sh --target-root "$HOME/.openclaw/skills"
```

Or clone the repo directly into the local skills directory:

```bash
git clone https://github.com/Siupo2023/semiconductor-pool-daily-update.git \
  "$HOME/.openclaw/skills/semiconductor-pool-daily-update"
```

Then run:

```bash
bash "$HOME/.openclaw/skills/semiconductor-pool-daily-update/scripts/semiconductor_daily_update.sh"
```

## Scheduling

The recommended approach is to schedule the shell script, not to rely on the model to remember the task.

Example cron entry:

```cron
40 6 * * 1-5 /bin/bash /path/to/semiconductor-pool-daily-update/scripts/semiconductor_daily_update.sh
```
