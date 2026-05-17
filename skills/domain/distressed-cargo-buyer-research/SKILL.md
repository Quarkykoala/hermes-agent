---
name: distressed-cargo-buyer-research
description: "Find and rank real buyers for distressed cargo, especially petrochemical, fuel, residue, industrial, and commodity lots."
version: 1.0.0
author: Codex
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [cargo, buyers, gtm, petrochemicals, distressed-sale, research]
    category: domain
    related_skills:
      - domain-intel
      - parallel-cli
      - company-specific-outreach
      - industrial-contact-verification
      - petrochemical-pricing-analysis
---

# Distressed Cargo Buyer Research

Use this skill when Parakh asks for buyers, suppliers, offtakers, traders, brokers, or outreach for a distressed cargo lot.

The job is not to produce a generic company list. The job is to identify reachable buyers who plausibly transact in the exact material class.

## Procedure

1. Restate the cargo:
   - material name and aliases
   - HS code, UN/IMO class, specs, quantity, location, storage pressure
   - whether the user is selling or buying
2. Map buyer segments from strongest to weakest.
3. Search for companies that actually handle the material class or close substitutes.
4. For every lead, capture evidence:
   - source URL
   - why they are a fit
   - exact product/use-case match
   - geography/logistics fit
   - contact path
   - confidence score
5. Reject weak leads explicitly.
6. Produce a buyer tracker CSV and a short ranked memo.

## For Heavy Pyrolysis Resin / Carbon Black Oil

Prefer these buyer types first:

1. Fuel oil traders and industrial fuel distributors.
2. Carbon black feedstock oil users, traders, or brokers.
3. Oil processors, residue handlers, re-refineries, and blenders.
4. Cement plants with alternative fuel programs.
5. Industrial boiler/furnace operators.
6. Large chemical companies only when there is evidence they handle heavy aromatic oils, residues, carbon black feedstock, pyrolysis oil, furnace oil substitutes, or refinery streams.

Do not over-prioritize generic chemical companies just because they are large.

## Output Format

Create:

```text
/opt/data/artifacts/outreach/<date>-buyer-tracker.csv
/opt/data/artifacts/reports/<date>-buyer-research.md
```

The CSV should include:

```csv
rank,company,segment,location,fit_reason,material_match,contact_name,contact_email,phone,source_url,confidence,next_action,notes
```

## Quality Bar

- At least 15 high-quality leads before calling the research useful.
- At least 5 must have direct email or phone evidence.
- Mark unverified contacts clearly.
- Never present guessed emails as verified.
- Prefer smaller reachable traders over famous companies with generic inboxes.
