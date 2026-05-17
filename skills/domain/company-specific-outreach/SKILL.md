---
name: company-specific-outreach
description: "Draft company-specific industrial outreach emails, WhatsApp scripts, and call openers from a verified lead tracker."
version: 1.0.0
author: Codex
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [outreach, sales, gtm, cargo, email]
    category: domain
    related_skills:
      - industrial-contact-verification
      - distressed-cargo-buyer-research
---

# Company-Specific Outreach

Use this skill after leads have been researched and at least lightly verified.

## Rules

- Do not blast one generic email to every company.
- Mention the buyer's likely use-case.
- Keep distressed-sale urgency factual, not desperate.
- Do not overclaim product suitability. Say inspection, sampling, and documents are available.
- Always include material, quantity, location, specs, and next action.

## Procedure

1. Group leads by segment:
   - fuel traders
   - carbon black/feedstock users
   - oil processors
   - cement alternative fuel teams
   - industrial boiler/furnace users
2. Draft a segment-specific base message.
3. Customize per company with:
   - why this company is relevant
   - what they likely care about
   - the contact path
   - suggested subject line
4. Produce WhatsApp/call scripts for the top 10.
5. Create a follow-up schedule.

## Output

Write:

```text
/opt/data/artifacts/outreach/<date>-company-specific-emails.md
/opt/data/artifacts/outreach/<date>-whatsapp-call-scripts.md
/opt/data/artifacts/outreach/<date>-followup-tracker.csv
```

Follow-up tracker columns:

```csv
company,contact,email_or_phone,initial_message_sent,followup_1_date,followup_2_date,response,status,next_action
```
