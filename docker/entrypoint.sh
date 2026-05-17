#!/bin/bash
# Docker/Podman entrypoint: bootstrap config files into the mounted volume, then run hermes.
set -e

HERMES_HOME="${HERMES_HOME:-/opt/data}"
INSTALL_DIR="/opt/hermes"

# --- Privilege dropping via gosu ---
# When started as root (the default for Docker, or fakeroot in rootless Podman),
# optionally remap the hermes user/group to match host-side ownership, fix volume
# permissions, then re-exec as hermes.
if [ "$(id -u)" = "0" ]; then
    if [ -n "$HERMES_UID" ] && [ "$HERMES_UID" != "$(id -u hermes)" ]; then
        echo "Changing hermes UID to $HERMES_UID"
        usermod -u "$HERMES_UID" hermes
    fi

    if [ -n "$HERMES_GID" ] && [ "$HERMES_GID" != "$(id -g hermes)" ]; then
        echo "Changing hermes GID to $HERMES_GID"
        # -o allows non-unique GID (e.g. macOS GID 20 "staff" may already exist
        # as "dialout" in the Debian-based container image)
        groupmod -o -g "$HERMES_GID" hermes 2>/dev/null || true
    fi

    # Fix ownership of the data volume. When HERMES_UID remaps the hermes user,
    # files created by previous runs (under the old UID) become inaccessible.
    # Always chown -R when UID was remapped; otherwise only if top-level is wrong.
    actual_hermes_uid=$(id -u hermes)
    needs_chown=false
    if [ -n "$HERMES_UID" ] && [ "$HERMES_UID" != "10000" ]; then
        needs_chown=true
    elif [ "$(stat -c %u "$HERMES_HOME" 2>/dev/null)" != "$actual_hermes_uid" ]; then
        needs_chown=true
    fi
    if [ "$needs_chown" = true ]; then
        echo "Fixing ownership of $HERMES_HOME to hermes ($actual_hermes_uid)"
        # In rootless Podman the container's "root" is mapped to an unprivileged
        # host UID — chown will fail.  That's fine: the volume is already owned
        # by the mapped user on the host side.
        chown -R hermes:hermes "$HERMES_HOME" 2>/dev/null || \
            echo "Warning: chown failed (rootless container?) — continuing anyway"
    fi

    # Ensure config.yaml is readable by the hermes runtime user even if it was
    # edited on the host after initial ownership setup. Must run here (as root)
    # rather than after the gosu drop, otherwise a non-root caller like
    # `docker run -u $(id -u):$(id -g)` hits "Operation not permitted" (#15865).
    if [ -f "$HERMES_HOME/config.yaml" ]; then
        chown hermes:hermes "$HERMES_HOME/config.yaml" 2>/dev/null || true
        chmod 640 "$HERMES_HOME/config.yaml" 2>/dev/null || true
    fi

    echo "Dropping root privileges"
    exec gosu hermes "$0" "$@"
fi

# --- Running as hermes from here ---
source "${INSTALL_DIR}/.venv/bin/activate"

# Create essential directory structure.  Cache and platform directories
# (cache/images, cache/audio, platforms/whatsapp, etc.) are created on
# demand by the application — don't pre-create them here so new installs
# get the consolidated layout from get_hermes_dir().
# The "home/" subdirectory is a per-profile HOME for subprocesses (git,
# ssh, gh, npm …).  Without it those tools write to /root which is
# ephemeral and shared across profiles.  See issue #4426.
mkdir -p "$HERMES_HOME"/{cron,sessions,logs,hooks,memories,skills,skins,plans,workspace,home}

# .env
if [ ! -f "$HERMES_HOME/.env" ]; then
    cp "$INSTALL_DIR/.env.example" "$HERMES_HOME/.env"
fi

# config.yaml
if [ ! -f "$HERMES_HOME/config.yaml" ]; then
    cp "$INSTALL_DIR/cli-config.yaml.example" "$HERMES_HOME/config.yaml"
fi

# Railway operator profile: keep Parakh's Hermes cheap by default while still
# allowing paid fallback/escalation. This is idempotent and preserves unrelated
# config edits on the persistent Railway volume.
case "${HERMES_OPERATOR_OS:-}" in
    1|true|TRUE|True|yes|YES|Yes)
        python3 - <<'PY'
from pathlib import Path
import os
import yaml

home = Path(os.environ.get("HERMES_HOME", "/opt/data"))
path = home / "config.yaml"

try:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
except Exception:
    data = {}

model = data.setdefault("model", {})
model["provider"] = "deepseek"
model["default"] = "deepseek-v4-flash"
model["base_url"] = "https://api.deepseek.com/v1"

data["provider_routing"] = {
    "sort": "price",
    "require_parameters": True,
    "data_collection": "deny",
}

data["fallback_providers"] = [
    {"provider": "deepseek", "model": "deepseek-v4-pro"},
    {"provider": "openrouter", "model": "minimax/minimax-m2.7"},
]
data.pop("fallback_model", None)

auxiliary = data.setdefault("auxiliary", {})

free_auxiliary_models = {
    "web_extract": "minimax/minimax-m2.5:free",
    "compression": "nvidia/nemotron-3-nano-30b-a3b:free",
    "session_search": "nvidia/nemotron-3-nano-30b-a3b:free",
    "skills_hub": "minimax/minimax-m2.5:free",
    "mcp": "openrouter/free",
    "approval": "openai/gpt-oss-20b:free",
    "title_generation": "meta-llama/llama-3.2-3b-instruct:free",
    "triage_specifier": "openai/gpt-oss-20b:free",
    "curator": "minimax/minimax-m2.5:free",
}
for task, aux_model in free_auxiliary_models.items():
    slot = auxiliary.setdefault(task, {})
    slot["provider"] = "openrouter"
    slot["model"] = aux_model
    slot["extra_body"] = {"reasoning": {"enabled": False}}

vision = auxiliary.setdefault("vision", {})
vision["provider"] = "openrouter"
vision["model"] = "nvidia/nemotron-nano-12b-v2-vl:free"
vision["extra_body"] = {"reasoning": {"enabled": False}}

delegation = data.setdefault("delegation", {})
delegation["provider"] = "openrouter"
delegation["model"] = "poolside/laguna-m.1:free"
delegation["max_concurrent_children"] = 2
delegation["max_spawn_depth"] = 1
delegation["reasoning_effort"] = "low"

agent = data.setdefault("agent", {})
agent["api_max_retries"] = 1
agent["reasoning_effort"] = "none"

memory = data.setdefault("memory", {})
memory["memory_enabled"] = True
memory["user_profile_enabled"] = True
memory["eager_nudging_enabled"] = True
memory["memory_char_limit"] = 2200
memory["user_char_limit"] = 1375
memory["nudge_interval"] = 8
memory["flush_min_turns"] = 4

session_reset = data.setdefault("session_reset", {})
session_reset["mode"] = "both"
session_reset["idle_minutes"] = 1440
session_reset["at_hour"] = 4

compression = data.setdefault("compression", {})
compression["enabled"] = True
compression["threshold"] = 0.25

approvals = data.setdefault("approvals", {})
approvals["mode"] = "smart"

terminal = data.setdefault("terminal", {})
terminal["cwd"] = os.environ.get("TERMINAL_CWD", str(home / "workspace"))

paths = data.setdefault("operator_paths", {})
paths["workspace"] = os.environ.get("TERMINAL_CWD", str(home / "workspace"))
paths["wiki"] = os.environ.get("WIKI_PATH", str(home / "wiki"))
paths["artifacts"] = str(home / "artifacts")
paths["gtm"] = str(home / "gtm")
paths["lifeops"] = str(home / "lifeops")
paths["cargo"] = str(home / "wiki" / "cargo")
paths["models"] = str(home / "wiki" / "models")
paths["app_building"] = str(home / "wiki" / "app-building")
paths["outreach"] = str(home / "artifacts" / "outreach")
paths["pricing"] = str(home / "artifacts" / "pricing")
paths["reports"] = str(home / "artifacts" / "reports")

for folder in paths.values():
    Path(folder).mkdir(parents=True, exist_ok=True)

wiki_files = {
    home / "wiki" / "README.md": """# Parakh Hermes Wiki

This is the durable third memory layer. Use it for canonical operating notes,
business assets, reusable research, and cross-session context that is too large
or too specific for MEMORY.md / USER.md.

Memory layer rules:
- Layer 1: memories/MEMORY.md and memories/USER.md hold tiny always-on facts and preferences.
- Layer 2: sessions/state.db holds searchable conversation and task history.
- Layer 3: wiki/ and artifacts/ hold durable business/project assets.

Do not stuff lead lists, long research, or one-off plans into Layer 1.
""",
    home / "wiki" / "cargo" / "heavy-pyrolysis-resin.md": """# Heavy Pyrolysis Resin / Carbon Black Oil Cargo

Canonical workflow note for the distressed cargo resale project.

Current framing:
- Product: Heavy Pyrolysis Resin plus Carbon Black Oil.
- Commercial job: find real buyers for distressed heavy hydrocarbon cargo at Nhava Sheva.
- Primary buyer types: fuel oil traders, industrial fuel distributors, carbon black feedstock users, oil processors, and cement plants using alternative kiln fuels.
- Avoid generic company lists. Verify contact path, buyer rationale, source link, confidence, and next action.
- Preferred output artifacts: buyer tracker CSV, company-specific outreach drafts, pricing memo, response/follow-up tracker.

Keep this file updated when the cargo specs, pricing, buyer feedback, or outreach results change.
""",
    home / "wiki" / "models" / "routing-policy.md": """# Hermes Model Routing Policy

Default philosophy: use the cheapest reliable model that can safely complete the task.

Current roles:
- Native DeepSeek V4 Flash: orchestrator, daily driver, normal reasoning, task routing.
- DeepSeek V4 Pro: deliberate escalation for high-value or difficult reasoning.
- OpenRouter free models: low-risk grunt work, summaries, triage, title generation, and scoped workers.
- Avoid long default thinking. Escalate reasoning only when the task asks for deep/proper/final/production work or when a cheaper route fails.

The orchestrator protects context and decides when to spend. Execution agents receive narrow task packets.
""",
    home / "wiki" / "gtm" / "operating-loop.md": """# GTM Operating Loop

Use for buyer research, market scans, outreach, and follow-up.

Default workflow:
1. Define the exact material or offer.
2. Identify buyer segments and reject weak segments.
3. Find direct buyers or brokers with evidence they handle the material class.
4. Verify contacts before drafting outreach.
5. Produce company-specific emails and call/WhatsApp scripts.
6. Track status, response, follow-up date, and next action.

Artifacts belong under /opt/data/artifacts/outreach and /opt/data/gtm.
""",
}

for file_path, content in wiki_files.items():
    if not file_path.exists():
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text(content, encoding="utf-8")

path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=False), encoding="utf-8")
PY
        ;;
esac

# SOUL.md
if [ ! -f "$HERMES_HOME/SOUL.md" ]; then
    cp "$INSTALL_DIR/docker/SOUL.md" "$HERMES_HOME/SOUL.md"
fi

case "${HERMES_OPERATOR_OS:-}" in
    1|true|TRUE|True|yes|YES|Yes)
        if ! grep -q "BEGIN PARAKH OPERATOR OS" "$HERMES_HOME/SOUL.md"; then
            cat >> "$HERMES_HOME/SOUL.md" <<'EOF'

<!-- BEGIN PARAKH OPERATOR OS -->
# Parakh Operator OS

You are Hermes running as Parakh's always-on operator. Your job is to reduce
the number of times Parakh has to steer, repeat context, or turn intent into
execution manually.

Default posture:
- Be direct, practical, and artifact-oriented.
- Prefer useful outputs over commentary: briefs, plans, repo notes, issue
  triage, lead lists, outreach drafts, specs, checklists, and next actions.
- Use free and cheap models for grunt work first. Escalate to paid/stronger
  models only when the task has higher stakes, needs deeper reasoning, or the
  cheap route is failing.
- Treat GitHub, the persistent wiki, memory, and the workspace as shared
  operating surfaces.
- Ask clarifying questions only when a wrong assumption would cause real
  damage. Otherwise make a reasonable assumption and keep moving.

Architecture:
- Orchestrator agents plan, remember, route, review, and decide when work is
  done. They should keep the global picture and avoid touching risky state
  unless necessary.
- Execution agents receive narrow task packets, scoped credentials, a clear
  workspace, and expected outputs. They do not need full personal context.
- Research agents gather sources and produce structured briefs with citations
  or source links.
- Builder agents work from specs, use GitHub cleanly, run checks, and report
  changed files plus verification.
- GTM agents produce company-specific research, positioning, outreach drafts,
  competitor scans, and daily/weekly pipeline notes.

Daily-driver loops to favor:
- Daily GTM brief: leads, buyer signals, competitor moves, and suggested
  outreach.
- Weekly GitHub shipping review: repo status, stuck work, next shippable
  changes, and PR/review opportunities.
- Research/wiki digest: papers, posts, docs, and reusable ideas folded into the
  persistent wiki.
- Life-ops capture: turn scattered tasks into reminders, docs, drafts, and
  calendar/email prep when integrations are available.
<!-- END PARAKH OPERATOR OS -->
EOF
        fi
        ;;
esac

case "${HERMES_OPERATOR_OS:-}" in
    1|true|TRUE|True|yes|YES|Yes)
        if ! grep -q "BEGIN PARAKH THREE LAYER MEMORY" "$HERMES_HOME/SOUL.md"; then
            cat >> "$HERMES_HOME/SOUL.md" <<'EOF'

<!-- BEGIN PARAKH THREE LAYER MEMORY -->
# Three-Layer Memory Policy

Use memory deliberately. Do not treat every useful fact as always-on memory.

Layer 1: Tiny always-on memory
- Files: memories/MEMORY.md and memories/USER.md.
- Store only durable facts, preferences, environment rules, and repeated corrections.
- Examples: Parakh prefers direct recommendations; Windows/PowerShell is the local machine; cargo resale needs buyer verification before outreach; DeepSeek is the orchestrator and cheap/free models handle grunt work.
- Do not store long research, lead lists, one-off task notes, drafts, or full plans here.

Layer 2: Searchable session history
- Use session_search when the user asks about past work, prior reports, previous decisions, old Hermes output, or "what did we do last time?"
- Prefer searching sessions over guessing from memory.
- When a task produces a lesson, extract only the durable rule into Layer 1 and leave details in sessions or artifacts.

Layer 3: Durable wiki and artifacts
- Use /opt/data/wiki for canonical operating notes, project context, product/cargo briefs, model-routing policy, GTM playbooks, and long-lived research.
- Use /opt/data/artifacts for generated reports, outreach packs, pricing memos, buyer trackers, CSVs, and deliverables.
- For cargo/commercial work, update the relevant wiki note and create artifacts instead of bloating Layer 1 memory.

Default storage behavior:
- Durable rule -> Layer 1.
- Past conversation/task evidence -> Layer 2.
- Business/project asset -> Layer 3.
- If unsure, write an artifact or wiki note first, then summarize only the lasting rule into memory.
<!-- END PARAKH THREE LAYER MEMORY -->
EOF
        fi
        ;;
esac

# auth.json: bootstrap from env on first boot only.  Used by orchestrators
# (e.g. provisioning a Hermes VPS from an account-management service) that
# need to seed the OAuth refresh credential non-interactively, instead of
# walking the user through `hermes setup` + the device-flow login dance.
# Subsequent token rotations write back to the same file, which lives on a
# persistent volume — so this env var is consumed exactly once at first
# boot.  The `[ ! -f ... ]` guard is critical: without it, a container
# restart would clobber a rotated refresh token with the now-stale value
# the orchestrator originally seeded.
if [ ! -f "$HERMES_HOME/auth.json" ] && [ -n "$HERMES_AUTH_JSON_BOOTSTRAP" ]; then
    printf '%s' "$HERMES_AUTH_JSON_BOOTSTRAP" > "$HERMES_HOME/auth.json"
    chmod 600 "$HERMES_HOME/auth.json"
fi

# Sync bundled skills (manifest-based so user edits are preserved)
if [ -d "$INSTALL_DIR/skills" ]; then
    python3 "$INSTALL_DIR/tools/skills_sync.py"
fi

# The main operator skill is managed by this deployment, not by the agent's
# learning loop. Keep the targeted overwrite narrow so other local/user-created
# skills on the persistent volume remain protected by skills_sync.
case "${HERMES_OPERATOR_OS:-}" in
    1|true|TRUE|True|yes|YES|Yes)
        operator_skill_src="$INSTALL_DIR/skills/domain/parakh-operator-os/SKILL.md"
        operator_skill_dst="$HERMES_HOME/skills/domain/parakh-operator-os/SKILL.md"
        if [ -f "$operator_skill_src" ]; then
            mkdir -p "$(dirname "$operator_skill_dst")"
            cp "$operator_skill_src" "$operator_skill_dst"
            echo "Updated managed operator skill: parakh-operator-os"
        fi
        ;;
esac

# Seed Parakh's daily-driver cron loops. Jobs are matched by name so redeploys
# update the durable setup without creating duplicates.
case "${HERMES_OPERATOR_OS:-}" in
    1|true|TRUE|True|yes|YES|Yes)
        python3 - <<'PY'
from pathlib import Path
import os

from cron.jobs import create_job, load_jobs, save_jobs, parse_schedule, compute_next_run

home = Path(os.environ.get("HERMES_HOME", "/opt/data"))
workspace = Path(os.environ.get("TERMINAL_CWD", str(home / "workspace")))
workspace.mkdir(parents=True, exist_ok=True)

reports = home / "artifacts" / "reports"
gtm = home / "gtm"
wiki_ops = home / "wiki" / "operator"
reports.mkdir(parents=True, exist_ok=True)
gtm.mkdir(parents=True, exist_ok=True)
wiki_ops.mkdir(parents=True, exist_ok=True)

(wiki_ops / "cron-loops.md").write_text("""# Operator Cron Loops

Seeded by the Railway deployment when HERMES_OPERATOR_OS is enabled.

Active loops:
- Daily GTM Brief: every day at 08:00 India time.
- Hermes Atlas Watch: Mondays at 09:00 India time.
- Model Spend Report: Fridays at 08:30 India time.

Each job writes detailed artifacts under /opt/data and sends a short version to
Telegram/home channels.
""", encoding="utf-8")

job_specs = [
    {
        "name": "Daily GTM Brief",
        "schedule": "30 2 * * *",
        "skills": [
            "parakh-operator-os",
            "daily-gtm-brief",
            "distressed-cargo-buyer-research",
            "industrial-contact-verification",
            "petrochemical-pricing-analysis",
            "company-specific-outreach",
        ],
        "prompt": """Prepare Parakh's daily GTM brief for today.

Focus on:
- Heavy Pyrolysis Resin / Carbon Black Oil cargo buyer pipeline
- new buyer leads or buyer segments worth checking
- follow-ups due today
- pricing or market signals relevant to distressed petrochemical/fuel substitute cargo
- concrete calls, emails, or WhatsApp actions Parakh should take today

Use existing files under /opt/data/wiki, /opt/data/artifacts, and /opt/data/gtm when available.
Write the detailed artifact to /opt/data/gtm/<date>-daily-brief.md.
Send a concise Telegram-ready version under 800 words.""",
    },
    {
        "name": "Hermes Atlas Watch",
        "schedule": "30 3 * * 1",
        "skills": ["parakh-operator-os", "hermes-atlas-watcher"],
        "prompt": """Review Hermes Atlas for tools that should change Parakh's Hermes setup.

Check:
- https://hermesatlas.com/data/repos.json
- https://hermesatlas.com/data/list-summaries.json
- https://hermesatlas.com/rss.xml

Focus on GTM, app-building, web research, memory, cost control, model routing, workspaces/GUIs, and safe multi-agent orchestration.
Do not recommend installing broad frameworks unless they clearly improve the current Railway + Telegram daily-driver bot.
Write the detailed artifact to /opt/data/artifacts/reports/<date>-hermes-atlas-watch.md.
Send a concise Telegram-ready version under 600 words with one concrete next action.""",
    },
    {
        "name": "Model Spend Report",
        "schedule": "0 3 * * 5",
        "skills": ["parakh-operator-os", "model-spend-report"],
        "prompt": """Audit Parakh's Hermes model routing and likely spend.

Inspect available config, logs, cron outputs, and artifacts. Report:
- whether DeepSeek V4 Flash is still the orchestrator/default
- whether free OpenRouter models are doing grunt work
- any paid escalations or likely paid escalations
- free-model failures, rate limits, or poor outputs
- whether reasoning/thinking settings look too high
- routing changes that would lower cost or improve reliability

Do not invent exact token counts if they are unavailable.
Write the detailed artifact to /opt/data/artifacts/reports/<date>-model-spend-report.md.
Send a concise Telegram-ready version under 500 words.""",
    },
]

jobs = load_jobs()
by_name = {str(job.get("name", "")).strip(): job for job in jobs}

for spec in job_specs:
    existing = by_name.get(spec["name"])
    if existing:
        parsed_schedule = parse_schedule(spec["schedule"])
        current = existing.get("schedule", {})
        current_expr = current.get("expr") if isinstance(current, dict) else None
        schedule_changed = current_expr != spec["schedule"]

        existing["prompt"] = spec["prompt"]
        existing["skills"] = spec["skills"]
        existing["skill"] = spec["skills"][0] if spec["skills"] else None
        existing["deliver"] = "all"
        existing["workdir"] = str(workspace)
        existing["enabled"] = True
        existing["state"] = "scheduled"
        existing["schedule"] = parsed_schedule
        existing["schedule_display"] = parsed_schedule.get("display", spec["schedule"])
        # Leave existing schedule/next_run_at untouched unless the schedule text
        # changed; this avoids delaying an already due job on every redeploy.
        if schedule_changed:
            existing["next_run_at"] = compute_next_run(parsed_schedule, existing.get("last_run_at"))
    else:
        # Flush any in-memory updates before create_job performs its own
        # load/append/save cycle, then refresh our view for the final save.
        save_jobs(jobs)
        create_job(
            prompt=spec["prompt"],
            schedule=spec["schedule"],
            name=spec["name"],
            deliver="all",
            skills=spec["skills"],
            workdir=str(workspace),
        )
        jobs = load_jobs()
        by_name = {str(job.get("name", "")).strip(): job for job in jobs}

save_jobs(jobs)
print("Seeded operator cron loops: Daily GTM Brief, Hermes Atlas Watch, Model Spend Report")
PY
        ;;
esac

# Optionally start `hermes dashboard` as a side-process.
#
# Toggled by HERMES_DASHBOARD=1 (also accepts "true"/"yes", case-insensitive).
# Host/port/TUI can be overridden via:
#   HERMES_DASHBOARD_HOST  (default 0.0.0.0 — exposed outside the container)
#   HERMES_DASHBOARD_PORT  (default 9119, matches `hermes dashboard` default)
#   HERMES_DASHBOARD_TUI   (already honored by `hermes dashboard` itself)
#
# The dashboard is a long-lived server.  We background it *before* the final
# `exec hermes "$@"` so the user's chosen foreground command (chat, gateway,
# sleep infinity, …) remains PID-of-interest for the container runtime.  When
# the container stops the whole process tree is torn down, so no explicit
# cleanup is needed.
case "${HERMES_DASHBOARD:-}" in
    1|true|TRUE|True|yes|YES|Yes)
        dash_host="${HERMES_DASHBOARD_HOST:-0.0.0.0}"
        dash_port="${HERMES_DASHBOARD_PORT:-9119}"
        dash_args=(--host "$dash_host" --port "$dash_port" --no-open)
        # Binding to anything other than localhost requires --insecure — the
        # dashboard refuses otherwise because it exposes API keys.  Inside a
        # container this is the expected deployment (host reaches it via
        # published port), so opt in automatically.
        if [ "$dash_host" != "127.0.0.1" ] && [ "$dash_host" != "localhost" ]; then
            dash_args+=(--insecure)
        fi
        echo "Starting hermes dashboard on ${dash_host}:${dash_port} (background)"
        # Prefix dashboard output so it's distinguishable from the main
        # process in `docker logs`.  stdbuf keeps the pipe line-buffered.
        (
            stdbuf -oL -eL hermes dashboard "${dash_args[@]}" 2>&1 \
                | sed -u 's/^/[dashboard] /'
        ) &
        ;;
esac

# Temporary authenticated read-only file browser for retrieving Hermes
# artifacts from the Railway volume. Enable only when needed.
case "${HERMES_FILE_BROWSER:-}" in
    1|true|TRUE|True|yes|YES|Yes)
        fb_host="${HERMES_FILE_BROWSER_HOST:-0.0.0.0}"
        fb_port="${PORT:-${HERMES_FILE_BROWSER_PORT:-8080}}"
        fb_root="${HERMES_FILE_BROWSER_ROOT:-$HERMES_HOME}"
        fb_token="${HERMES_FILE_BROWSER_TOKEN:-}"
        if [ -z "$fb_token" ]; then
            echo "HERMES_FILE_BROWSER is enabled but HERMES_FILE_BROWSER_TOKEN is empty; refusing to start file browser."
        else
            echo "Starting temporary Hermes file browser on ${fb_host}:${fb_port} for ${fb_root}"
            HERMES_FILE_BROWSER_ROOT="$fb_root" HERMES_FILE_BROWSER_TOKEN="$fb_token" \
            python3 - <<'PY' &
import html
import os
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(os.environ["HERMES_FILE_BROWSER_ROOT"]).resolve()
TOKEN = os.environ["HERMES_FILE_BROWSER_TOKEN"]
HOST = os.environ.get("HERMES_FILE_BROWSER_HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT") or os.environ.get("HERMES_FILE_BROWSER_PORT") or "8080")

REPORT_EXTS = {".md", ".pdf", ".csv", ".xlsx", ".xls", ".txt", ".json", ".log"}
REPORT_WORDS = ("report", "supplier", "contact", "buyer", "petrochemical", "carbon", "pyrolysis", "artifact")

def authorized(handler):
    parsed = urllib.parse.urlparse(handler.path)
    qs = urllib.parse.parse_qs(parsed.query)
    bearer = handler.headers.get("authorization", "")
    return qs.get("token", [""])[0] == TOKEN or bearer == f"Bearer {TOKEN}"

def iter_files():
    for p in ROOT.rglob("*"):
        try:
            if not p.is_file():
                continue
            rel = p.relative_to(ROOT).as_posix()
            st = p.stat()
            yield rel, st.st_size, st.st_mtime
        except Exception:
            continue

def likely_report(rel):
    lower = rel.lower()
    return Path(lower).suffix in REPORT_EXTS or any(word in lower for word in REPORT_WORDS)

class Handler(BaseHTTPRequestHandler):
    def _deny(self):
        self.send_response(401)
        self.end_headers()
        self.wfile.write(b"missing or invalid token")

    def do_GET(self):
        if not authorized(self):
            return self._deny()
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            return
        if parsed.path.startswith("/download/"):
            rel = urllib.parse.unquote(parsed.path[len("/download/"):])
            target = (ROOT / rel).resolve()
            if ROOT not in target.parents and target != ROOT:
                self.send_response(400); self.end_headers(); return
            if not target.is_file():
                self.send_response(404); self.end_headers(); return
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Disposition", f'attachment; filename="{target.name}"')
            self.end_headers()
            with target.open("rb") as f:
                while chunk := f.read(1024 * 1024):
                    self.wfile.write(chunk)
            return

        files = sorted(iter_files(), key=lambda x: x[2], reverse=True)
        reports = [f for f in files if likely_report(f[0])]
        rows = []
        for rel, size, mtime in reports[:250]:
            safe = html.escape(rel)
            href = "/download/" + urllib.parse.quote(rel) + "?token=" + urllib.parse.quote(TOKEN)
            rows.append(f"<tr><td><code>{safe}</code></td><td>{size}</td><td>{mtime:.0f}</td><td><a href='{href}'>download</a></td></tr>")
        body = "<html><body><h1>Hermes Files</h1><p>Newest likely reports first.</p><table border='1' cellpadding='6'><tr><th>Path</th><th>Bytes</th><th>MTime</th><th>Download</th></tr>" + "\n".join(rows) + "</table></body></html>"
        data = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
PY
        fi
        ;;
esac

# Final exec: two supported invocation patterns.
#
#   docker run <image>                 -> exec `hermes` with no args (legacy default)
#   docker run <image> chat -q "..."   -> exec `hermes chat -q "..."` (legacy wrap)
#   docker run <image> sleep infinity  -> exec `sleep infinity` directly
#   docker run <image> bash            -> exec `bash` directly
#
# If the first positional arg resolves to an executable on PATH, we assume the
# caller wants to run it directly (needed by the launcher which runs long-lived
# `sleep infinity` sandbox containers — see tools/environments/docker.py).
# Otherwise we treat the args as a hermes subcommand and wrap with `hermes`,
# preserving the documented `docker run <image> <subcommand>` behavior.
if [ $# -gt 0 ] && command -v "$1" >/dev/null 2>&1; then
    exec "$@"
fi
exec hermes "$@"
