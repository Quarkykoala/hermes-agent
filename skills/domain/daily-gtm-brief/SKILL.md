---
name: daily-gtm-brief
description: "Prepare a concise daily GTM brief for Parakh: leads, market changes, follow-ups, and recommended actions."
version: 1.0.0
author: Codex
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [gtm, daily-brief, cron, sales, research]
    category: domain
    related_skills:
      - distressed-cargo-buyer-research
      - industrial-contact-verification
      - company-specific-outreach
      - petrochemical-pricing-analysis
---

# Daily GTM Brief

Use this skill for recurring GTM updates and morning briefs.

## Default Brief Structure

1. What changed since yesterday.
2. Highest-priority leads or accounts.
3. Follow-ups due today.
4. New market/pricing signals.
5. Specific recommended actions.
6. Blockers requiring Parakh's decision.

## Cargo Mode

For distressed cargo, include:

- new verified buyers
- contact paths found
- buyer segment shifts
- pricing evidence
- documents or specs still needed
- calls/emails to send today

## Output

Keep under 800 words unless asked otherwise.

Write detailed artifacts to:

```text
/opt/data/gtm/<date>-daily-brief.md
```

Deliver the short version in Telegram.
