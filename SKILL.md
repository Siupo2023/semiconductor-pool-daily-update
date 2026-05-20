---
name: semiconductor-pool-daily-update
description: "Create, archive, render, and email a Chinese semiconductor watchlist daily update. Use this skill when the user asks to update the semiconductor company pool, run the semiconductor morning review, generate HTML/email reports for A-share semiconductor names, or install/schedule this workflow in OpenClaw/Codex/Claude-style CLIs."
user-invocable: true
metadata:
  openclaw:
    requires:
      bins:
        - bash
        - codex
        - pandoc
        - python3
      env:
        - SMTP_USER
        - SMTP_PASSWORD
        - DEFAULT_EMAIL
---

# Semiconductor Pool Daily Update

This skill runs the semiconductor watchlist workflow as a portable CLI task:

1. Read the local Wiki context and semiconductor review rules.
2. Use Codex with web search to read the market backdrop: U.S. indices, semiconductor peers, rates, FX, A-share indices, and sector rotation.
3. Fetch current A-share data, announcements, dragon-tiger list data, and U.S. peer movement for the watchlist.
4. Explain the chain from macro backdrop to sector strength to individual stock validation.
5. Write the daily Markdown report into `wiki/`.
6. Convert the report to HTML.
7. Email the HTML report as an attachment.

It is intended for OpenClaw, Codex, or similar local CLI agents.

## Quick Use

From the skill directory:

```bash
bash scripts/semiconductor_daily_update.sh
```

Useful environment overrides:

```bash
export SEMI_WIKI_ROOT="$HOME/llm-wiki"
export SEMI_EMAIL_ENV="$HOME/.openclaw/skills/news-aggregator-skill/.env"
export SEMI_END_DATE="2026-05-29"
export SEMI_SKIP_WEEKENDS=1
```

The script defaults to:

- Wiki root: `$HOME/llm-wiki`
- Prompt template: `references/semiconductor-daily-update.prompt.md`
- Output Markdown: `wiki/YYMMDD-半导体公司池每日更新.md`
- Output HTML: `wiki/YYMMDD-半导体公司池每日更新.html`
- Email config file: `$HOME/.openclaw/skills/news-aggregator-skill/.env`

## Required Local Context

The workflow works best when these Wiki pages exist:

- `wiki/260516-半导体主线公司池与每日更新规则.md`
- `wiki/workflow-semiconductor-daily-review.md`
- At least one previous `wiki/*半导体公司池每日更新.md`
- At least one previous `wiki/*半导体池最近进展快照.md`

If a page is missing, the agent should still continue, but must say which context was unavailable.

## Scheduling

For OpenClaw or local automation, schedule the script rather than asking the model to remember the task.

macOS `launchd` example:

```xml
<key>ProgramArguments</key>
<array>
  <string>/bin/bash</string>
  <string>/path/to/semiconductor-pool-daily-update/scripts/semiconductor_daily_update.sh</string>
</array>
<key>StartCalendarInterval</key>
<dict>
  <key>Hour</key>
  <integer>6</integer>
  <key>Minute</key>
  <integer>40</integer>
</dict>
```

Cron example:

```cron
40 6 * * 1-5 /path/to/semiconductor-pool-daily-update/scripts/semiconductor_daily_update.sh
```

## Email Configuration

The script reads SMTP values from the env file path in `SEMI_EMAIL_ENV`.

Expected keys:

```bash
SMTP_SERVER=smtp.qq.com
SMTP_PORT=587
SMTP_USER=your_email@example.com
SMTP_PASSWORD=your_smtp_authorization_code
DEFAULT_EMAIL=recipient@example.com
```

Never commit real SMTP passwords or authorization codes.

## Output Contract

Each run should produce:

- A Markdown report in the Wiki.
- A matching HTML report in the Wiki.
- An email with the HTML attached.
- A short final summary from Codex noting the core conclusion, file paths, and risk points.

Reports must mark the exact data date/time and separate strong evidence from weak or unverified signals.

Each report must first answer the market-level question: why should the semiconductor pool be strong, weak, or divergent today?

The required top-level logic is:

- Macro backdrop: U.S. market, A-share indices, rates, dollar, and risk appetite.
- Sector rotation: semiconductor, storage, PCB, optical module/CPO, equipment, materials, and adjacent hot sectors.
- Watchlist validation: which companies are moving with the sector and which have company-specific evidence.
- Three-grade conclusion: macro tailwind/headwind/neutral, sector tailwind/headwind/neutral, and stock-level validation strong/weak/pending.
