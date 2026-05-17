---
name: industrial-contact-verification
description: "Verify industrial buyer contacts, procurement paths, emails, phones, and confidence before outreach."
version: 1.0.0
author: Codex
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [contacts, verification, outreach, procurement, gtm]
    category: domain
    related_skills:
      - distressed-cargo-buyer-research
      - company-specific-outreach
---

# Industrial Contact Verification

Use this skill before sending outreach to industrial buyers.

## Rules

- Separate verified contact details from inferred or guessed details.
- A generic `info@` inbox is acceptable only as a fallback.
- Procurement, sourcing, fuel, raw-material, purchase, logistics, or plant-level contacts are better than corporate communications.
- Do not invent contact names or emails.
- If an email format is inferred, label it `inferred`, not verified.

## Verification Levels

- `A`: direct procurement/contact page or named buyer contact found.
- `B`: company domain email or relevant department inbox found.
- `C`: generic corporate inbox or phone only.
- `D`: plausible company but no usable contact path yet.
- `Reject`: no evidence of material fit or contact route.

## Procedure

1. Start from the buyer tracker.
2. For each company, search:
   - official website contact/procurement/vendor page
   - product pages showing material fit
   - LinkedIn/company pages for procurement, sourcing, fuel, or raw-material roles
   - trade-directory listings only as secondary evidence
3. Update the tracker with verification level and source URL.
4. Produce a top-10 call list and a top-10 email list.

## Output

Write:

```text
/opt/data/artifacts/outreach/<date>-verified-contact-tracker.csv
/opt/data/artifacts/outreach/<date>-call-list.md
```

Include columns:

```csv
company,segment,contact_name,title,email,email_status,phone,phone_status,source_url,verification_level,next_action
```
