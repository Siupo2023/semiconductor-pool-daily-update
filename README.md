# semiconductor-pool-daily-update

A portable OpenClaw/Codex skill for the daily China semiconductor watchlist workflow.

This skill:

- reads local Wiki context and daily review rules
- explains the macro and market backdrop before reviewing the watchlist
- compares U.S. market movement, A-share indices, sector rotation, rates, and risk appetite
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

## Report Logic

The report is designed to answer one practical question first:

> Why should the semiconductor pool be strong, weak, or divergent today?

Each run should cover:

- U.S. market backdrop: Nasdaq, S&P 500, Philadelphia Semiconductor Index, key semiconductor peers, rates, dollar, and risk appetite
- A-share market backdrop: major indices, Science and Technology 50, sector gainers/losers, and market style
- Semiconductor branches: storage, PCB, optical module/CPO, equipment, materials, chip design, consumer electronics
- Watchlist validation: company announcements, earnings, research, dragon-tiger list, capital flow, and overseas peer mapping
- Three-grade conclusion: macro tailwind/headwind/neutral, sector tailwind/headwind/neutral, and stock-level validation strong/weak/pending
- One-line strategy: whether the current setup is more suited to chasing strength, buying dips, observing, or reducing risk

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

Current preferred mode is:

- full report after the U.S. market closes, using the latest U.S. close plus the previous A-share session
- Monday morning weekend catch-up, to cover weekend announcements before the next A-share session

Because Beijing time shifts with U.S. daylight saving time, do not hardcode a single local time. Instead, schedule more than one local trigger and let the script self-skip outside the valid window.

Suggested local trigger points:

- `04:12` every day
- `05:12` every day
- `06:45` every Monday

Set these environment variables in the scheduler:

```bash
SEMI_ENFORCE_SCHEDULE_WINDOW=1
SEMI_SCHEDULE_MODE=after_us_close_full
```

With that mode enabled, the script will:

- run after U.S. market close when the New York local time is in the `16:05-17:30` window
- run once on Monday morning Beijing time as a weekend catch-up
- skip all other scheduler invocations

See the launchd template:

```text
references/launchd/ai.openclaw.semiconductor-afterclose.plist.example
```
