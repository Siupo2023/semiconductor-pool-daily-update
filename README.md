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

This repository is designed to work on both macOS and Linux. On Ubuntu, the only scheduler-specific change is that you should use `systemd --user` or `cron` instead of `launchd`.

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

## Ubuntu Cloud VM

On an Ubuntu cloud machine, the clean path is:

1. Install the runtime dependencies:

```bash
sudo apt-get update
sudo apt-get install -y pandoc python3 python3-venv ca-certificates
```

2. Install and authenticate the Codex CLI in whatever way you normally use on that machine.

3. Clone both repositories:

```bash
git clone https://github.com/Siupo2023/llm-wiki.git "$HOME/llm-wiki"
git clone https://github.com/Siupo2023/semiconductor-pool-daily-update.git "$HOME/semiconductor-pool-daily-update"
```

4. Create an SMTP env file, for example:

```bash
mkdir -p "$HOME/.config/semiconductor-pool-daily-update"
cat > "$HOME/.config/semiconductor-pool-daily-update/email.env" <<'EOF'
SMTP_SERVER=smtp.qq.com
SMTP_PORT=587
SMTP_USER=your_email@example.com
SMTP_PASSWORD=your_smtp_authorization_code
DEFAULT_EMAIL=recipient@example.com
EOF
```

5. Point the workflow at the Ubuntu paths:

```bash
export SEMI_WIKI_ROOT="$HOME/llm-wiki"
export SEMI_EMAIL_ENV="$HOME/.config/semiconductor-pool-daily-update/email.env"
```

6. Run a smoke test:

```bash
bash "$HOME/semiconductor-pool-daily-update/scripts/semiconductor_daily_update.sh"
```

If you want the Ubuntu VM to produce the same report structure as your current Mac setup, keep the Wiki root at `~/llm-wiki` and reuse the same stock-pool rules file inside that repository.

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
- weekday morning supplement, with Monday also acting as the weekend catch-up before the next A-share session

Because Beijing time shifts with U.S. daylight saving time, do not hardcode a single local time. Instead, schedule more than one local trigger and let the script self-skip outside the valid window.

Suggested local trigger points:

- `04:12` every day
- `05:12` every day
- `06:45` every weekday

Set these environment variables in the scheduler:

```bash
SEMI_ENFORCE_SCHEDULE_WINDOW=1
SEMI_SCHEDULE_MODE=after_us_close_full
```

With that mode enabled, the script will:

- run after U.S. market close when the New York local time is in the `16:05-17:30` window
- run on weekday mornings in Beijing time as a supplement; the Monday run also acts as the weekend catch-up
- skip all other scheduler invocations

See the launchd template:

```text
references/launchd/ai.openclaw.semiconductor-afterclose.plist.example
```

For Ubuntu, use the `systemd --user` examples:

```text
references/systemd/semiconductor-daily-update.service.example
references/systemd/semiconductor-daily-update.timer.example
```

Install them like this:

```bash
mkdir -p "$HOME/.config/systemd/user"
cp references/systemd/semiconductor-daily-update.service.example \
  "$HOME/.config/systemd/user/semiconductor-daily-update.service"
cp references/systemd/semiconductor-daily-update.timer.example \
  "$HOME/.config/systemd/user/semiconductor-daily-update.timer"

systemctl --user daemon-reload
systemctl --user enable --now semiconductor-daily-update.timer
systemctl --user status semiconductor-daily-update.timer
```

If your cloud VM should keep user timers alive after logout, enable lingering once:

```bash
loginctl enable-linger "$USER"
```
