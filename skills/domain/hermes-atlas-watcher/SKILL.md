---
name: hermes-atlas-watcher
description: "Watch Hermes Atlas for new ecosystem tools worth adding to Parakh's operator stack."
version: 1.0.0
author: Codex
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [hermes, ecosystem, atlas, tools, weekly-review]
    category: domain
    related_skills:
      - parakh-operator-os
      - daily-gtm-brief
---

# Hermes Atlas Watcher

Use this skill when monitoring the Hermes ecosystem for tools, skills, plugins, memory providers, workspaces, or deployment patterns that should change Parakh's Hermes setup.

## Sources

Check these sources first:

- `https://hermesatlas.com/data/repos.json`
- `https://hermesatlas.com/data/list-summaries.json`
- `https://hermesatlas.com/rss.xml`
- `https://hermesatlas.com/llms-full.txt` when deeper context is needed

## Ranking Rules

Prioritize tools that improve Parakh's actual operator loop:

1. GTM, buyer research, web research, outreach, or market monitoring.
2. App building, GitHub, code review, deployment, or verification.
3. Cost control, model routing, spend visibility, or reliability.
4. Memory and context only if built-in Hermes memory is clearly failing.
5. Multi-agent orchestration only if it simplifies the current setup.

Deprioritize:

- broad swarm frameworks before the core daily loops are stable
- huge skill packs without a specific workflow need
- dashboards that expose files or terminals without a strong auth story
- experimental forks that require replacing the working Railway deployment

## Weekly Output

Write the detailed artifact to:

```text
/opt/data/artifacts/reports/<date>-hermes-atlas-watch.md
```

Use this structure:

1. New or changed projects worth noticing.
2. Recommended additions to Parakh's Hermes stack.
3. Projects to watch but not install yet.
4. Projects to avoid for now, with reason.
5. One concrete next action.

Keep the Telegram version under 600 words.

