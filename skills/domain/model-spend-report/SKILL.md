---
name: model-spend-report
description: "Audit Hermes model usage, provider routing, free-model behavior, and paid escalation risk."
version: 1.0.0
author: Codex
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [models, spend, openrouter, deepseek, cost-control, routing]
    category: domain
    related_skills:
      - parakh-operator-os
      - hermes-atlas-watcher
---

# Model Spend Report

Use this skill to keep Parakh's Hermes cheap, predictable, and reliable.

## Policy

Current routing intent:

- Native DeepSeek V4 Flash is the main orchestrator and daily-driver model.
- DeepSeek V4 Pro is an escalation model for high-value synthesis, difficult reasoning, and final decisions.
- OpenRouter free models handle extraction, summaries, title generation, triage, simple workers, and low-risk grunt work.
- Avoid long default thinking. Prefer short reasoning and explicit verification.
- If a free model rate-limits or gives empty/low-quality output, record that and route around it.

## What To Inspect

Use available logs, config, cron outputs, and provider artifacts. Look for:

- which model/provider was used most often
- paid-model escalations and whether they were justified
- free-model failures, rate limits, empty responses, or hallucination patterns
- repeated tasks that should use cheaper auxiliary models
- tasks that deserve DeepSeek Pro or a better specialist model
- any evidence that reasoning/thinking settings are too high

If exact token or cost data is unavailable, say so clearly and produce a qualitative report from config and logs. Do not invent token counts.

## Output

Write the detailed artifact to:

```text
/opt/data/artifacts/reports/<date>-model-spend-report.md
```

Use this structure:

1. Current routing health: green/yellow/red.
2. Paid usage or likely paid usage.
3. Free-model wins.
4. Free-model failures.
5. Routing changes recommended.
6. One action to lower cost or improve reliability.

Keep the Telegram version under 500 words.

