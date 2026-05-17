---
name: petrochemical-pricing-analysis
description: "Price petrochemical, fuel, residue, and distressed cargo lots with market anchors and negotiation bands."
version: 1.0.0
author: Codex
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [pricing, petrochemicals, cargo, fuel, negotiation]
    category: domain
    related_skills:
      - distressed-cargo-buyer-research
---

# Petrochemical Pricing Analysis

Use this skill when pricing petrochemical cargo, fuel oil substitutes, carbon black oil, heavy aromatic oils, pyrolysis oil, residues, or distressed commodity lots.

## Procedure

1. Identify comparable materials:
   - exact material
   - closest substitute
   - buyer's use-case substitute
   - distressed/liquidation discount anchor
2. Gather price anchors:
   - domestic market
   - import/export if relevant
   - substitute fuels or feedstocks
   - logistics and storage penalty
3. Build a three-tier price:
   - attention-grab price
   - fair target price
   - ceiling/opening price
4. State walk-away minimum and why.
5. Produce buyer-facing and seller-facing versions.

## Distressed Cargo Adjustment

Discount for:

- old cargo or storage age
- demurrage/container pressure
- uncertain end-use approval
- need for sampling/testing
- lot size and need for full-lot buyer

Do not over-discount if specs are strong and logistics are easy.

## Output

Write:

```text
/opt/data/artifacts/pricing/<date>-pricing-memo.md
```

Include:

- price range per MT
- total cargo value
- supporting market anchors
- risk adjustments
- negotiation script
- recommended opening offer
- walk-away minimum
