# FleetOps Copilot — Case Study Project Context

## Interview Details

- **Company:** Archer Aviation (eVTOL aircraft manufacturer)
- **Position:** Software Engineer
- **Date:** March 19, 2026 — 11:00am to 2:00pm PDT
- **Location:** 190 W Tasman, San Jose, CA
- **Format:** Case study presentation + Q&A on personal laptop with Zoom installed

### Interview Panel

| Time | Interviewer | Notes |
|------|-------------|-------|
| 11:00–11:15 | Jessica Cadigal | Recruiter/coordinator check-in |
| 11:15–12:00 | Bojan Keca | Zoom backup available |
| 12:00–12:45 | Corey Byrum | Zoom backup available |
| 12:45–1:30 | Landon Spear | |
| 1:30–2:00 | Arjan Guglani | |

### Case Study Requirements

- **Prompt:** Build something useful for a trucking operator operating electric semi-trucks
- **Time budget:** No more than 3 hours
- **Allowed tools:** Cursor, Windsurf, code-gen tools (Claude Code qualifies)
- **Prohibited tools:** V0, Replit, Lovable
- **Deliverable:** Presentation on personal laptop + live demo
- **Pre-send:** Email completed presentation to recruiter before interview
- **Presentation includes:** Self intro, case study presentation, Q&A
- **Slide templates available:** Archer branded (Google Slides / PowerPoint)

---

## Product Concept

### FleetOps Copilot

A secure internal AI assistant built on Claude Code's extensibility system (skills, hooks, MCP) that helps fleet operations staff identify maintenance risks, find low-disruption service windows, and generate evidence-backed operational recommendations from real fleet data.

### One-Liner

> "Rather than building another dashboard that requires operators to manually connect the dots, I built an AI copilot that can reason over fleet, route, and maintenance data to surface actionable recommendations with an audit trail."

### Why This Over a Dashboard

| Normal dashboard | FleetOps Copilot |
|---|---|
| "Here is data" | "Here is a system that helps humans make better decisions faster" |
| Requires manual cross-referencing | Synthesizes across multiple data sources |
| Shows what you ask for | Surfaces what you didn't know to ask |
| Static views | Dynamic, multi-step reasoning |
| Business logic in code | Investigation workflows in skills |

### Primary Users (non-engineers)

- Maintenance coordinators
- Dispatchers
- Operations analysts
- Fleet managers

### User Roles

| Role | Access | Responsibilities |
|------|--------|-----------------|
| **Fleet Coordinator** | Full copilot access | Asks questions, runs investigations, generates recommendations, sends service briefs to mechanic shops |
| **Fleet Manager** | GitHub PR access | Reviews and approves maintenance recommendations via PRs — the approval authority |
| **Mechanic (external)** | None — receives email only | Receives emailed HTML service briefs. No agent access, no data access, no system login |

> "Third-party mechanics don't get access to our agent or our data. When a truck goes to the shop, the coordinator generates a service brief and the system emails it directly to the shop. The mechanic gets exactly what they need. Nothing more."

### Core Problems It Solves

- Which trucks are approaching maintenance thresholds?
- Which scheduled trips are at risk because of maintenance windows?
- Which maintenance opportunities are cheapest or least disruptive?
- What happened on recent routes that may indicate battery, charging, or vehicle issues?
- How can I answer these questions without digging through multiple dashboards and spreadsheets?

### Core Value

Instead of forcing staff to manually inspect routes, mileage, maintenance intervals, and future schedules, the copilot can reason across that data and produce a ranked recommendation with an audit trail.

---

## Why Claude Code as the Platform (Not the Claude API)

### The Concept

We are NOT building "an app that calls Claude." We are configuring **Claude Code itself** as the product — using skills, hooks, and MCP servers to turn a general-purpose AI coding agent into a domain-specific operations copilot.

This is the same pattern Intercom uses internally with 100+ skills and 13 plugins.

### What We're Actually Showing

> "I took a general-purpose AI coding agent and turned it into a secure, auditable, domain-specific operations tool using the same extensibility patterns that companies like Intercom are deploying at scale."

### Claude API vs Claude Code Platform

| Claude API approach | Claude Code platform approach |
|---|---|
| You wrote an app that calls an AI | You configured an AI platform for a domain |
| Tools are functions in your codebase | Tools are MCP resources with their own lifecycle |
| Safety is application-level code | Safety is enforced at the harness layer via hooks |
| Audit logging is something you coded | Audit logging is infrastructure — hooks fire regardless of what the AI does |
| Shows you can use an SDK | Shows you understand AI operations at the platform level |

---

## Intercom Thread Reference

Source: Brian Scanlan (@brian_scanlan) Twitter thread, March 17, 2026

### Key Patterns We're Mirroring

1. **MCP servers self-hosted inside Rails apps** — "We self-host MCP servers for internal tools... Just built it into the Rails apps and Okta authentication in front of them."

2. **Non-engineers are the power users** — "the top-5 users weren't engineers - design managers, customer support engineers, product management leaders were all actively using it"

3. **Skill-level gates before dangerous tools** — "A skill-level gate blocks all these tools until Claude loads the safety reference docs first. No cowboy queries."

4. **SessionEnd analysis for improvement loop** — "On SessionEnd, a hook analyzes the entire session transcript with Claude Haiku looking for improvement opportunities. It auto-classifies gaps (missing_skill, missing_tool, repeated_failure, wrong_info) and posts to Slack with a pre-filled GitHub issue URL."

5. **Hooks enforce workflow, not just safety** — "Claude Code hooks enforce our PR workflow at the shell level and blocks it unless the create-pr skill was activated first"

6. **Context is cheap** — "~22k / 1,000,000 tokens used - so just 2%!" — skills, hooks, and safety docs don't blow up context

7. **OpenTelemetry instrumentation** — 14 lifecycle event types flowing to Honeycomb, privacy-first (never capture prompts or messages)

8. **Session transcripts to S3** — with username SHA256-hashed for privacy, used to analyze usage patterns at scale

9. **Read-only Rails console via MCP** — "Claude can now execute arbitrary Ruby against production data - feature flag checks, business logic validation, cache state inspection"

10. **Safety gates on the console** — "read-replica only, blocked critical tables, mandatory model verification before every query, Okta auth, DynamoDB audit trail"

---

## Architecture

### Three Layers

```
Layer 1: Source of Truth (Operational Data)
├── Postgres database
├── Vehicles, trips, maintenance records, service centers, charging events
└── Seeded with realistic relational data

Layer 2: Fleet Intelligence Tools (MCP Server)
├── Headless Rails app (no views, no controllers, no frontend)
├── Database + models + MCP server only
├── 5 curated read-only tools
├── No raw SQL exposed
└── Thin wrappers around ActiveRecord scopes

Layer 3: Copilot Interface (Claude Code)
├── CLAUDE.md — role, constraints, operational context
├── Skills — encoded investigation workflows with HTML report templates
├── Hooks — safety gates, audit logging, workflow enforcement
├── settings.json — permissions, tool whitelisting
├── HTML reports — skill-templated pages opened in browser
└── S3 audit trail
```

### Tech Stack

- **Database:** PostgreSQL with seeded fleet data
- **Web app:** Rails 8, headless (database + models + MCP server only — no views, no controllers, no frontend)
- **MCP server:** Built into the Rails app as MCP endpoints
- **AI platform:** Claude Code with skills, hooks, CLAUDE.md
- **Audit:** S3 bucket for session logs
- **Report output:** Self-contained HTML report templates (generated by skills, opened in browser)

---

## Database Schema (6 Tables)

### vehicles

| Column | Type | Purpose |
|--------|------|---------|
| id | uuid | PK |
| unit_number | string | Fleet ID, e.g., "EV-2401" (type-year-sequential, industry convention) |
| make | string | Manufacturer (Tesla, Freightliner, Volvo) |
| model | string | Model name (Semi 500, eCascadia, VNR Electric) |
| year | integer | Model year |
| battery_capacity_kwh | decimal | Total battery capacity (Tesla: ~850, eCascadia: 438, Volvo: 565) |
| range_miles | integer | Rated range (Tesla: 500, eCascadia: 230, Volvo: 275) |
| current_mileage | integer | Current odometer reading |
| battery_health_percent | decimal | Battery State of Health — current capacity vs original (100% = new, degrades ~2% per year) |
| next_maintenance_due_mileage | integer | Mileage threshold for next scheduled service |
| next_maintenance_type | string | What's due next: safety_check / standard_service / comprehensive_service / major_overhaul |
| last_maintenance_date | date | When last serviced |
| annual_inspection_due | date | DOT annual inspection deadline (regulatory requirement, every 12 months) |
| daily_inspection_current | boolean | Whether today's daily inspection has been completed |
| status | string | active / in_shop / out_of_service / retired |
| created_at | datetime | |
| updated_at | datetime | |

**Maintenance type intervals (generalized from industry PM-A/B/C/D schedule):**
- `safety_check`: every 10,000–15,000 miles — tires, brakes visual, lights, battery coolant level
- `standard_service`: every 25,000–30,000 miles — above + brake pad measurement, HV cable inspection, cabin air filter
- `comprehensive_service`: every 50,000–60,000 miles — above + battery coolant flush, alignment, full diagnostic, often combined with DOT annual inspection
- `major_overhaul`: every 100,000 miles — component replacement, thermal management system overhaul, major battery diagnostic

**Realistic seed data ranges:**
- Regional EV trucks: 50,000–80,000 miles/year
- Battery health: 99-100% (2025-2026 vehicles), 92-96% (2023-2024 vehicles)
- kWh/mile benchmarks: Tesla 1.55–1.73, eCascadia 1.9–2.1, Volvo 1.8–2.0
- EV maintenance costs are 40-70% lower than diesel (key business case stat for presentation)

### trips

| Column | Type | Purpose |
|--------|------|---------|
| id | uuid | PK |
| vehicle_id | uuid | FK to vehicles |
| trip_number | string | Human-readable trip ID, e.g., "TRP-0482" |
| origin | string | Starting location (e.g., "San Jose Distribution Center") |
| destination | string | End location (e.g., "Fresno Regional Hub") |
| distance_miles | integer | Total round-trip distance |
| cargo_weight_lbs | integer | Load weight (affects energy consumption — max ~45,000 lbs cargo for EV semis) |
| departure_at | datetime | Scheduled/actual departure |
| return_at | datetime | Scheduled/actual return |
| status | string | scheduled / in_progress / completed / cancelled |
| energy_consumed_kwh | decimal | Energy used (completed trips) |
| route_waypoints | jsonb | Array of lat/lng waypoints for route geometry |
| created_at | datetime | |
| updated_at | datetime | |

**Realistic seed data ranges:**
- Regional routes: 100–250 miles round trip
- Departure times: 04:30–06:00 (early morning typical for trucking)
- Cargo weights: 35,000–42,000 lbs (typical loaded), 0 for deadhead/empty runs
- Energy consumed: distance_miles * kWh/mile rate (varies by load and vehicle)
- Weekly pattern: 5 route days + 1 light duty + 1 rest day per vehicle

### maintenance_records

| Column | Type | Purpose |
|--------|------|---------|
| id | uuid | PK |
| vehicle_id | uuid | FK to vehicles |
| service_center_id | uuid | FK to service_centers |
| maintenance_type | string | safety_check / standard_service / comprehensive_service / major_overhaul / annual_inspection / battery_diagnostic / tire_rotation / brake_service |
| description | text | What was done |
| mileage_at_service | integer | Odometer at time of service |
| cost | decimal | Service cost |
| duration_hours | decimal | How long the service took |
| completed_at | datetime | When completed |
| created_at | datetime | |
| updated_at | datetime | |

**Realistic cost ranges:**
- safety_check: $150–$300
- standard_service: $400–$800
- comprehensive_service: $1,200–$2,500
- major_overhaul: $3,000–$8,000
- annual_inspection: $150–$300 (often bundled with comprehensive_service)
- battery_diagnostic: $200–$500
- tire_rotation: $200–$400
- brake_service: $500–$1,200

### service_centers

| Column | Type | Purpose |
|--------|------|---------|
| id | uuid | PK |
| name | string | e.g., "Bay Area Fleet Services" |
| address | string | Full address |
| city | string | City name (for display) |
| latitude | decimal | GPS lat |
| longitude | decimal | GPS lng |
| capabilities | jsonb | Array of service types this center can perform |
| contact_email | string | Email address for sending service briefs to mechanic shops |
| is_partner | boolean | Approved/preferred partner (negotiated rates) |
| ev_certified | boolean | Certified for EV/high-voltage work |
| created_at | datetime | |
| updated_at | datetime | |

**Seed with 6-8 service centers along major California routes (I-5, I-880, US-101, CA-99)**

### charging_events

| Column | Type | Purpose |
|--------|------|---------|
| id | uuid | PK |
| vehicle_id | uuid | FK to vehicles |
| trip_id | uuid | FK to trips (nullable — null for depot charging) |
| location_type | string | depot / en_route |
| station_name | string | Charging station identifier |
| latitude | decimal | GPS lat |
| longitude | decimal | GPS lng |
| energy_added_kwh | decimal | Energy charged |
| charge_rate_kw | decimal | Charging speed (depot: 50–150 kW, en_route: 250–1,200 kW) |
| duration_minutes | integer | Time spent charging |
| cost | decimal | Charging cost |
| charged_at | datetime | When charging occurred |
| created_at | datetime | |
| updated_at | datetime | |

**Realistic charging patterns:**
- ~75% of charging is depot (overnight, off-peak, $0.06–$0.10/kWh)
- ~25% is en-route fast charging ($0.30–$0.40/kWh)
- Depot charge: 8–12 hours at 50–150 kW (Level 2 / moderate DC)
- En-route fast charge: 30–90 min at 250–1,200 kW
- Electricity cost per mile: $0.03–$0.06 (vs diesel $0.15–$0.25/mile)

### copilot_sessions (Audit Trail)

| Column | Type | Purpose |
|--------|------|---------|
| id | uuid | PK |
| user_name | string | Who used the copilot |
| session_summary | text | What was asked and recommended |
| tool_invocations | jsonb | Array of tool calls with timestamps |
| outcome | string | successful_recommendation / incomplete / tool_error / question_unanswered |
| s3_transcript_url | string | Link to full transcript in S3 |
| created_at | datetime | Session start time |

---

## Seed Data: Example Fleet (12 vehicles)

Modeled after real EV fleet operations (PepsiCo, Sysco patterns). Regional California fleet based out of San Jose.

| Unit | Make/Model | Year | Mileage | Battery Health | Next Service | Status |
|------|-----------|------|---------|----------------|--------------|--------|
| EV-2301 | Tesla Semi 500 | 2023 | 145,000 | 92% | comprehensive_service @ 150K | active |
| EV-2302 | Tesla Semi 500 | 2023 | 138,000 | 93% | comprehensive_service @ 150K | active |
| EV-2401 | Freightliner eCascadia | 2024 | 87,000 | 96% | standard_service @ 90K | active |
| EV-2402 | Freightliner eCascadia | 2024 | 92,000 | 95% | standard_service @ 90K | in_shop |
| EV-2403 | Freightliner eCascadia | 2024 | 78,000 | 97% | standard_service @ 90K | active |
| EV-2501 | Volvo VNR Electric | 2025 | 34,000 | 99% | safety_check @ 35K | active |
| EV-2502 | Volvo VNR Electric | 2025 | 28,000 | 99% | safety_check @ 30K | active |
| EV-2503 | Tesla Semi 500 | 2025 | 42,000 | 98% | standard_service @ 45K | active |
| EV-2601 | Tesla Semi 500 | 2026 | 5,200 | 100% | safety_check @ 10K | active |
| EV-2602 | Freightliner eCascadia | 2026 | 3,800 | 100% | safety_check @ 10K | active |
| EV-2603 | Volvo VNR Electric | 2026 | 8,100 | 100% | safety_check @ 10K | active |
| EV-2604 | Tesla Semi 500 | 2026 | 6,500 | 100% | safety_check @ 10K | active |

**Demo-critical vehicles:**
- **EV-2501** — 34,000 mi, safety_check due at 35,000. Only 1,000 miles from threshold. Has a Thursday trip (San Jose → Fresno, 185 mi round trip) that will push it past. This is the vehicle the demo centers on.
- **EV-2301** — 145,000 mi, comprehensive_service due at 150,000. Annual DOT inspection also due next week. High urgency.
- **EV-2403** — Battery health declining faster than expected (97% at 78K mi vs expected 98%). Good candidate for the "is this efficiency drop worth investigating?" follow-up.

---

## MCP Tools (5 Tools)

All tools query the operational database in **read-only** mode. They are built into the Rails app as MCP endpoints, wrapping ActiveRecord scopes. The read-only constraint applies to the operational database — the copilot CAN write recommendation artifacts to the filesystem and create git branches/PRs, as that is the output/approval mechanism, not a mutation of source-of-truth data.

### 1. vehicles_due_for_maintenance

**Parameters:** `within_days` (integer, default 7)
**Returns:** Ranked list of vehicles approaching or past maintenance thresholds
**Logic:** Estimates daily mileage from recent trips, projects when each vehicle will hit `next_maintenance_due_mileage`, returns those within the window ranked by urgency

### 2. upcoming_trips_for_vehicle

**Parameters:** `vehicle_id` (uuid), `days_ahead` (integer, default 14)
**Returns:** Scheduled trips with route info, departure/return times, distances
**Logic:** Queries trips table for the vehicle with status=scheduled and departure_at within the window

### 3. service_centers_near_route

**Parameters:** `trip_id` (uuid), `radius_miles` (integer, default 25), `leg` (string: "outbound" | "return" | "full", default "return")
**Returns:** Partner service centers within radius of the specified leg's route waypoints
**Logic:** Uses route_waypoints from the trip. The `leg` parameter selects which portion of the waypoints to search against — "return" uses the latter half (midpoint to final waypoint), "outbound" uses the first half, "full" uses all. Calculates distance to each partner service center, returns those within radius sorted by proximity to route.

### 4. vehicle_health_summary

**Parameters:** `vehicle_id` (uuid)
**Returns:** Efficiency trends, recent charging patterns, maintenance history, utilization stats
**Logic:** Aggregates recent trips (energy_consumed_kwh / distance_miles), charging events, maintenance records. Flags anomalies like declining efficiency or increasing charge times.

### 5. draft_maintenance_recommendation

**Parameters:** `vehicle_id` (uuid), `service_center_id` (uuid), `trip_id` (uuid)
**Returns:** Structured recommendation with reason, evidence, affected trips, suggested maintenance window, assumptions, and confidence level
**Logic:** Combines data from the other tools into a structured recommendation object. This is the tool that produces the artifact for the Git PR workflow.

---

## Skills (5 Skills)

Skills are markdown files in `.claude/skills/` that encode investigation workflows. All output skills generate self-contained HTML reports that are saved to `reports/` and auto-opened in the browser.

### 1. find-maintenance-opportunities

Multi-step investigation workflow that generates an **HTML Maintenance Investigation Report**:
1. Call `vehicles_due_for_maintenance` to identify candidates
2. For each candidate, call `upcoming_trips_for_vehicle` to understand scheduling impact
3. For high-priority vehicles with upcoming trips, call `service_centers_near_route` to find low-disruption service options
4. Rank opportunities by: urgency (miles to threshold), trip disruption (number of affected trips), proximity to partner service centers
5. Present ranked findings with evidence for each
6. Explicitly state assumptions and data limitations (e.g., "service center availability not confirmed," "ranking based on available data — does not account for technician load or bay capacity")
7. Generate HTML report with color-coded urgency indicators, vehicle cards, and evidence tables
8. Save to `reports/maintenance-investigation-{date}.html` and open in browser

### 2. vehicle-health-check

Diagnostic analysis workflow that generates an **HTML Vehicle Health Report**:
1. Call `vehicle_health_summary` for the target vehicle
2. Analyze efficiency trends — flag declining kWh/mile
3. Review charging patterns — flag increasing charge times or failed charges
4. Check maintenance history — flag overdue or approaching intervals
5. Classify findings: normal / monitor / investigate / urgent
6. Present findings with data points and thresholds used
7. Generate HTML report with battery gauge visualization, efficiency trend data, maintenance timeline, and classification badge
8. Save to `reports/vehicle-health-{unit_number}-{date}.html` and open in browser

### 3. draft-maintenance-plan

Recommendation generation workflow that generates an **HTML Maintenance Recommendation Document** (styled as an official work order):
1. Requires `find-maintenance-opportunities` to have been run first (enforced by hook)
2. Call `draft_maintenance_recommendation` with selected vehicle, service center, and trip
3. Generate HTML recommendation document styled as an official work order
4. Save to `reports/maintenance-recommendation-{unit_number}-{date}.html` and open in browser
5. Also write recommendation as structured markdown file to `recommendations/` directory
6. Commit to `recommendations` branch
7. Create PR via `gh pr create` with evidence, affected trips, assumptions
8. Log the recommendation to audit trail

### 4. fleet-safety-protocols

Reference skill that must be loaded before any MCP tools are available (enforced by hook):
- Read-only data access only — never mutate operational data
- All recommendations are proposals, not actions
- Every recommendation must include evidence and assumptions
- Every session is logged and auditable
- No raw SQL — only curated MCP tools
- No cowboy queries

### 5. mechanic-service-brief

Generates an **HTML Mechanic Service Brief** for a specific vehicle and emails it to the service center's `contact_email`:
1. Gather vehicle specs, full maintenance history, current service request details, known issues, and battery health data via MCP tools
2. Generate a self-contained HTML service brief designed for mechanics: clean high-contrast layout with vehicle specs, maintenance history, current service request, known issues, and battery health
3. Save to `reports/service-brief-{unit_number}-{date}.html` and open in browser
4. Mock email: log "Sent service brief to {contact_email}" to audit trail and console output
5. The brief contains exactly what the mechanic needs — nothing more

**All output skills must:**
- Use a strict HTML template defined in the skill
- Include consistent header (FleetOps Copilot branding, date, generated-by)
- Include consistent footer ("Generated by FleetOps Copilot — [timestamp]")
- Save to `reports/` directory with naming convention
- Auto-open in browser via `open` command
- Be uniform and testable — same sections every time

---

## HTML Report Templates

All copilot outputs meant for human consumption are rendered as self-contained HTML pages. This replaces any need for a traditional web frontend — the Rails app is headless, and all visual output comes from skill-templated HTML.

### How It Works

- Templates are defined within each skill's markdown file
- Claude fills the templates with live data from MCP tool calls
- Reports use shared CSS for consistent FleetOps Copilot branding across all report types
- Reports are saved to the `reports/` directory with a consistent naming convention
- Reports auto-open in the browser via the `open` command

### Report Types

| Report | Generated By | Naming Convention |
|--------|-------------|-------------------|
| Maintenance Investigation Report | `find-maintenance-opportunities` | `reports/maintenance-investigation-{date}.html` |
| Vehicle Health Report | `vehicle-health-check` | `reports/vehicle-health-{unit_number}-{date}.html` |
| Maintenance Recommendation Document | `draft-maintenance-plan` | `reports/maintenance-recommendation-{unit_number}-{date}.html` |
| Mechanic Service Brief | `mechanic-service-brief` | `reports/service-brief-{unit_number}-{date}.html` |
| Ad-hoc Query Results | Any skill / direct query | `reports/query-{date}-{timestamp}.html` |

### Shared Structure

Every report includes:
- **Header:** FleetOps Copilot branding, report title, generation date, generated-by attribution
- **Body:** Report-specific content sections (consistent per report type)
- **Footer:** "Generated by FleetOps Copilot — [timestamp]"

---

## Hooks Architecture

### Hook Event Reference (from Medium article)

| Hook | When It Fires | Best Use |
|------|---------------|----------|
| PreToolUse | Before any tool runs | Block dangerous operations |
| PostToolUse | After tool completes | Auto-format, lint, log |
| PermissionRequest | Before permission dialog | Auto-approve safe commands |
| SessionStart | Session begins | Inject context |
| Stop | Claude finishes responding | Run tests, validate output |
| UserPromptSubmit | User hits enter | Inject instructions |

### Our Hook Implementation

#### 1. session-start-safety (SessionStart)

**Purpose:** Load fleet safety protocols before any tools are available AND write state marker for gate-mcp-tools
**Behavior:** Outputs the fleet-safety-protocols content so Claude has safety context from the first message, then writes a marker file that gate-mcp-tools checks
```json
{
  "hooks": [{
    "type": "command",
    "command": "mkdir -p /tmp/fleetops-audit && cat .claude/skills/fleet-safety-protocols.md && echo '## Session Started' && date -u && echo 'safety_loaded' > /tmp/fleetops-audit/.safety-gate-marker"
  }]
}
```

#### 2. gate-mcp-tools (PreToolUse)

**Purpose:** Block MCP database tools until safety skill is loaded in the session
**Matcher:** MCP tool names (the 5 fleet data tools)
**Behavior:** Checks for the state marker file written by session-start-safety. If marker doesn't exist, blocks the tool with a clear message.
```json
{
  "matcher": "vehicles_due_for_maintenance|upcoming_trips_for_vehicle|service_centers_near_route|vehicle_health_summary|draft_maintenance_recommendation",
  "hooks": [{
    "type": "command",
    "command": "if [ ! -f /tmp/fleetops-audit/.safety-gate-marker ]; then echo 'BLOCKED: Fleet safety protocols must be loaded before using data tools. Start a new session.' && exit 1; fi"
  }]
}
```

#### 3. enforce-read-only (PreToolUse)

**Purpose:** Block any write/mutate/delete operations **against the operational database**
**Matcher:** MCP database tools, Bash commands containing SQL
**Behavior:** Inspects tool input for dangerous database patterns (DELETE, UPDATE, INSERT, DROP, TRUNCATE). Blocks with audit log entry. Note: filesystem writes (recommendation artifacts, git operations) are explicitly ALLOWED — the read-only constraint protects operational data, not the recommendation output pipeline.

#### 4. enforce-workflow-order (PreToolUse)

**Purpose:** Block recommendation drafting until investigation is complete
**Matcher:** `draft-maintenance-plan` skill / `draft_maintenance_recommendation` tool
**Behavior:** Checks session state — has `find-maintenance-opportunities` been run? If not, blocks with: "Must complete investigation before generating recommendations."

#### 5. log-tool-invocation (PostToolUse)

**Purpose:** Log every tool call to audit JSONL file AND S3
**Behavior:** Appends `{"tool": "...", "timestamp": "...", "user": "...", "session_id": "..."}` to `/tmp/fleetops-audit/tool-invocations.jsonl`
```json
{
  "matcher": "*",
  "hooks": [{
    "type": "command",
    "command": "mkdir -p /tmp/fleetops-audit && echo '{\"tool\": \"'$CLAUDE_TOOL_NAME'\", \"timestamp\": \"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'\", \"user\": \"'$(whoami)'\"}' >> /tmp/fleetops-audit/tool-invocations.jsonl"
  }]
}
```

#### 6. session-end-audit (Stop — or SessionEnd equivalent)

**Purpose:** Summarize session, classify outcome, ship to S3
**Behavior:**
1. Capture session summary (tools called, recommendations generated)
2. Classify outcome: `successful_recommendation` | `incomplete` | `tool_error` | `question_unanswered`
3. Write structured JSON to local audit directory
4. Upload to S3: `aws s3 cp audit.json s3://fleetops-copilot-audit/sessions/`

### Hook Configuration Notes

- Matcher syntax: pipe-separated, no spaces (`Write|Edit` not `Write | Edit`)
- Multiple hooks on same event run in parallel
- 60-second timeout per hook
- Debug with: `2>&1 | tee ~/.claude/hook-debug.log`
- Settings locations: `.claude/settings.json` (project-shared), `.claude/settings.local.json` (personal), `~/.claude/settings.json` (global)

---

## Git PR as Approval Engine (Plan Enhancement)

### The Concept

When the copilot drafts a maintenance recommendation, it doesn't just output text into a chat. It produces a **structured artifact** — a markdown file committed to a `recommendations` branch and opened as a **pull request**.

The PR IS the approval workflow. Git already handles:
- Version history (audit trail)
- Reviews (approval gates)
- Comments (discussion / decision log)
- Branch protection (who can approve)
- Notifications (GitHub alerts)

### Recommendation File Format

```markdown
recommendations/ev-2501-2026-03-19-safety-check.md
---
vehicle_unit: "EV-2501"
vehicle_id: "a1b2c3d4-..."
service_center: "Bay Area Fleet Services"
service_center_id: "e5f6a7b8-..."
trip_id: "c9d0e1f2-..."
window: "Thursday ~1:00pm - 3:00pm (return leg stop)"
urgency: high
status: proposed
generated_by: "dispatch_coordinator"
---

## Recommendation
Schedule EV-2501 (2025 Volvo VNR Electric) for safety check at Bay Area Fleet Services
during Trip #TRP-0482 return leg on Thursday.

## Evidence
- EV-2501: 1,000 miles from safety check threshold (current: 34,000 mi, due: 35,000 mi)
- Thursday trip #TRP-0482 (San Jose → Fresno, 185 mi round trip) will push past threshold
- Bay Area Fleet Services: 9 miles off return route near Gilroy, EV-certified partner facility
- No other trips scheduled for EV-2501 until Monday

## Affected Trips
- Trip #TRP-0482 (Thursday): ~2 hour delay for service stop on return leg
- Trip #TRP-0491 (Monday): unaffected if safety check completes Thursday

## Assumptions
- Safety check duration: ~2 hours (not confirmed with Bay Area Fleet Services)
- Bay Area Fleet Services has Thursday afternoon availability (not confirmed — recommend calling ahead)
- No technician load or bay capacity data available
- Estimated cost: $150–$300 based on standard safety check rates

## Tool Calls
- vehicles_due_for_maintenance(within_days: 7)
- upcoming_trips_for_vehicle(vehicle_id: "a1b2c3d4-...", days_ahead: 14)
- service_centers_near_route(trip_id: "c9d0e1f2-...", radius_miles: 25, leg: "return")
```

### Workflow

1. Dispatcher or coordinator uses the copilot to investigate maintenance opportunities
2. `draft-maintenance-plan` skill generates the recommendation file
3. Commits to a `recommendations/v-018-2026-03-19-brake-inspection` branch (per-recommendation)
4. Opens a PR via `gh pr create`
5. **Fleet manager** (not the dispatcher) reviews on GitHub — approves, requests changes, or closes
6. PR discussion = decision log, merge history = audit trail
7. A `PreToolUse` hook enforces that recommendations ALWAYS go through this flow

**Note on user roles:** The dispatcher/coordinator ASKS questions and generates recommendations via the copilot. The fleet manager REVIEWS and APPROVES via PR. In production, the approval surface could be Slack, email, or an internal tool — the PR demonstrates the propose-review-approve pattern. GitHub is the stand-in, not the permanent solution.

---

## S3 Audit Logging

### What Gets Logged

1. **Every tool invocation** — tool name, timestamp, user, session ID (PostToolUse hook)
2. **Session transcripts** — full conversation shipped to S3 on session end
3. **Session classification** — outcome type (successful_recommendation / incomplete / tool_error / question_unanswered)
4. **Recommendation artifacts** — the structured markdown files (also in git)

### S3 Bucket Structure

```
s3://fleetops-copilot-audit/
├── sessions/
│   ├── {session-id}.json          # Session metadata + classification
│   └── {session-id}-transcript.md # Full conversation transcript
├── tool-invocations/
│   └── {date}/invocations.jsonl   # All tool calls for the day
└── recommendations/
    └── {date}/{vehicle}-{type}.md # Recommendation artifacts
```

### SessionEnd Hook

```bash
#!/bin/bash
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
USER=$(whoami)
SESSION_ID="$CLAUDE_SESSION_ID"
BUCKET="fleetops-copilot-audit"
AUDIT_DIR="/tmp/fleetops-audit"

mkdir -p "$AUDIT_DIR"

# Write session metadata
cat > "$AUDIT_DIR/${SESSION_ID}.json" << EOF
{
  "session_id": "$SESSION_ID",
  "user": "$USER",
  "timestamp": "$TIMESTAMP",
  "tool_invocations_path": "s3://${BUCKET}/sessions/${SESSION_ID}-tools.jsonl",
  "transcript_path": "s3://${BUCKET}/sessions/${SESSION_ID}-transcript.md"
}
EOF

# Upload metadata
aws s3 cp "$AUDIT_DIR/${SESSION_ID}.json" "s3://${BUCKET}/sessions/${SESSION_ID}.json"

# Upload tool invocation log (if it exists)
if [ -f "$AUDIT_DIR/tool-invocations.jsonl" ]; then
  aws s3 cp "$AUDIT_DIR/tool-invocations.jsonl" "s3://${BUCKET}/sessions/${SESSION_ID}-tools.jsonl"
fi

# Upload session transcript (if available via Claude Code transcript path)
if [ -n "$CLAUDE_SESSION_TRANSCRIPT" ] && [ -f "$CLAUDE_SESSION_TRANSCRIPT" ]; then
  aws s3 cp "$CLAUDE_SESSION_TRANSCRIPT" "s3://${BUCKET}/sessions/${SESSION_ID}-transcript.md"
fi
```

---

## Security Posture

### Design Principles

1. **Read-only data access** — agent has read-only database credentials to an operational replica. Note: the copilot CAN write recommendation artifacts (markdown files) and create git branches/PRs — this is the output/approval pipeline, not a mutation of operational data. The distinction: operational data is read-only, recommendation output is write-enabled.
2. **Curated tools, not raw queries** — no arbitrary SQL, only pre-defined MCP tools wrapping validated ActiveRecord scopes
3. **Skill-level gates** — MCP tools blocked until safety protocols are loaded (Intercom pattern)
4. **Workflow enforcement** — hooks enforce investigation-before-recommendation order
5. **Human-in-the-loop** — recommendations are proposals (PRs), never automatic actions
6. **Audit trail** — every session, tool call, and recommendation logged to S3 with user attribution
7. **Network restriction** (architecture slide) — VPS behind Tailscale, only designated machines can SSH
8. **Private repo** — skills and hooks in private repo, only admins can modify

### What to Say in the Presentation

> "The system uses constrained tools, read-only data access, approval gates, and audit logging. The assistant never mutates source-of-truth systems without approval. Actions are proposed, not blindly executed. Every answer includes evidence. Every session is logged and auditable. No cowboy queries."

### Key Framing

Instead of: "the agent has read-only access to production"
Say: "the copilot queries a read-only operational replica to ground recommendations in current fleet state"

Instead of: "schedule maintenance"
Say: "generate a recommended maintenance plan and a draft handoff for the operations team"

---

## Demo Scenario

### The Killer Demo: "Find maintenance opportunities before this vehicle becomes a scheduling problem"

Each step produces an HTML report that opens in the browser — the audience sees polished, branded output at every stage, not just terminal text.

**Step 1 — Operator asks:**
> "Which vehicles should we pull into maintenance this week with the least disruption to scheduled trips?"

**Step 2 — Copilot activates `find-maintenance-opportunities` skill:**
- Calls `vehicles_due_for_maintenance(within_days: 7)`
- Returns 3 vehicles ranked by urgency:
  - EV-2501: safety check due in 1,000 miles — Thursday trip will push past threshold
  - EV-2301: comprehensive service due in 5,000 miles AND annual inspection due next week
  - EV-2403: approaching standard service interval at 90,000 miles
- **HTML Maintenance Investigation Report opens in browser** — color-coded urgency, vehicle cards, evidence tables

**Step 3 — Operator follows up:**
> "Does EV-2501 have any trips where it passes near an approved service location on return?"

**Step 4 — Copilot investigates:**
- Calls `upcoming_trips_for_vehicle(vehicle_id: <EV-2501 uuid>, days_ahead: 14)`
- Calls `service_centers_near_route(trip_id: <trip uuid>, radius_miles: 25, leg: "return")`
- Returns: "EV-2501 has a scheduled trip Thursday (San Jose → Fresno, return via CA-99/I-880). Bay Area Fleet Services is 9 miles off the return route near Gilroy."

**Step 5 — Operator requests recommendation:**
> "Draft a maintenance plan for EV-2501 at that location."

**Step 6 — Copilot activates `draft-maintenance-plan` skill:**
- Calls `draft_maintenance_recommendation`
- **HTML Maintenance Recommendation Document opens in browser** — styled as an official work order
- Also writes structured recommendation file to `recommendations/`
- Commits to `recommendations` branch
- Opens a PR on GitHub
- Returns: recommendation summary with evidence + PR link

**Step 7 — Show the artifacts:**
- The HTML reports that opened in the browser (investigation report + recommendation document)
- The PR on GitHub with full evidence
- The audit log entries generated by hooks
- The S3 upload confirmation

**Bonus — Follow-up question:**
> "What about EV-2403 — it seems to be losing efficiency. Is that worth investigating?"

- Calls `vehicle_health_summary(vehicle_id: <EV-2403 uuid>)`
- **HTML Vehicle Health Report opens in browser** — battery gauge, efficiency trend, classification badge
- Shows declining kWh/mile over last 5 trips (1.95 → 2.25 kWh/mile — above the 2.1 baseline for eCascadia)
- Battery health at 97% which is slightly below expected 98% for 78K miles
- Recommends scheduling a battery diagnostic at next standard service
- Note: this anomaly is surfaced by `vehicle_health_summary`, NOT by `vehicles_due_for_maintenance` — each tool has a clear contract

### Demo Anti-Patterns (Avoid)

- Don't center the demo around SSH/VPS/infra
- Don't show autonomous write actions
- Don't emphasize "production database access" as the exciting part
- Don't make it feel like "agent maximalism" or "infra flexing"

---

## Presentation Narrative (6 Slides)

### Slide 1: The Problem

Electric fleets create a new operational coordination burden. Maintenance scheduling for EV semi-trucks requires combining mileage data, trip schedules, battery health, service center availability, and route geometry. Today, coordinators do this manually across multiple systems.

### Slide 2: The Insight

> "A rules-only system can catch obvious thresholds, but real fleet operations decisions require combining maintenance status, future trips, route geometry, service availability, and business impact. That's where an AI copilot becomes useful — not as a replacement for source systems, but as a reasoning layer on top of them."

A dashboard shows data. A copilot reasons across it.

### Slide 3: The Product

FleetOps Copilot: a secure internal AI assistant for fleet operations staff.

- Natural language queries over operational data
- Multi-step investigation workflows
- Evidence-backed maintenance recommendations rendered as polished HTML reports
- Branded, self-contained HTML output for every investigation step — opens directly in browser
- Mechanic service briefs emailed directly to shops
- Human approval via GitHub PRs
- Full audit trail

### Slide 4: Architecture

3-layer diagram:
1. **Operational data** — Postgres with vehicles, trips, maintenance, service centers, charging events
2. **Fleet intelligence tools** — 5 curated MCP tools (read-only, built into Rails app)
3. **Copilot interface** — Claude Code with skills, hooks, CLAUDE.md

Security callouts:
- Read-only operational replica
- Curated tools (no raw SQL)
- Skill-level safety gates
- Workflow enforcement hooks
- Immutable S3 audit logging
- Git PRs as approval workflow
- Remote access via Claude Code Remote Control

Deployment model (not live-demoed):
- VPS behind Tailscale
- Private repo for skills/hooks
- Network-restricted access

### Slide 5: Live Demo

The maintenance window scenario (see Demo Scenario section above). Each step produces a branded HTML report that opens in the browser — the audience sees polished, professional output at every stage, not terminal text. The HTML report generation is a key differentiator: it demonstrates that the copilot produces real deliverables, not just chat responses.

### Slide 6: What's Next

- Approval workflow integration (merge PR → schedule in maintenance system)
- Expanded tool set (driver assignments, charger availability, weather/route conditions)
- SessionEnd analysis for continuous improvement (Intercom's feedback loop pattern)
- Role-based tool access (dispatcher vs. maintenance coordinator vs. fleet manager)
- Proactive alerting (daily morning briefing skill)

---

## Key Positioning Lines

### For the Presentation

> "Rather than building another dashboard that requires operators to manually connect the dots, I built an AI copilot that can reason over fleet, route, and maintenance data to surface actionable recommendations with an audit trail."

> "This is the same pattern that engineering teams at companies like Intercom are using internally — they've built 100+ skills and hooks that turn Claude Code into a full-stack engineering platform. I applied that same approach to fleet operations."

> "The differentiator is not 'I used AI.' It is: 'I used AI where natural language plus tool use plus structured data can reduce operational overhead.'"

> "I didn't build a chat UI. I configured an AI platform for a domain. The skills define the workflows. The hooks enforce safety. The MCP tools provide data access. The git PRs create the approval workflow."

### For Positioning Your Approach

You want them to think:
- "This person knows how to build software people would actually use in a serious company."
- "This person understands where AI should help, and where it should stop."
- "This person thinks in terms of operator workflows, AI systems, permissions, auditability, and production constraints."

You do NOT want them to think:
- "John wanted to show off agent infrastructure and wrapped a trucking use case around it."
- "This is agent maximalism / infra flexing."
- "This is a generalized AI shell with database access."

The framing is:
- NOT: "self-hosted AI agent with production DB access and secure infra"
- YES: "secure internal AI operations copilot with constrained tools, evidence-backed recommendations, and human approval"

---

## What We're Actually Proving

1. You know AI should be grounded in real system state (not canned responses)
2. You know operational recommendations require cross-table reasoning (not if/then rules)
3. You know safety means constrained access, not no access
4. You know how to productize AI instead of faking it
5. You understand the Claude Code extensibility model at a platform level (skills, hooks, MCP)
6. You think about non-technical users, audit trails, and approval workflows

---

## 3-Hour Build Plan (Rough Time Allocations)

| Task | Time | Notes |
|------|------|-------|
| Database schema + seed data | 40 min | Postgres, realistic relational data with enough variety for demo |
| Headless Rails app + MCP server | 40 min | Rails 8 headless (no views, no controllers), MCP endpoints wrapping ActiveRecord scopes |
| Skills (5 markdown files) | 30 min | Investigation workflows, safety protocols, mechanic service brief |
| HTML report templates in skills | 30 min | Strict HTML templates for each output skill with shared CSS |
| Shared template CSS | 10 min | Consistent FleetOps Copilot branding across all report types |
| Hooks (6 hooks) | 20 min | Safety gates, audit logging, workflow enforcement |
| CLAUDE.md + settings.json | 10 min | Role, constraints, permissions, hook config |
| Git PR workflow | 15 min | Recommendation file format, branch/PR creation in skill |
| Demo rehearsal | 15 min | Run through the scenario, verify tool calls and HTML reports work |
| Slides | 20 min | 6 slides, content over design, use Archer template |

**Total: ~230 min (3 hrs 50 min)** — tight but achievable with Claude Code building it.

### Build Order (Dependency-Ordered)

1. **First:** Database schema + seeds (unblocks everything)
2. **Then:** Headless Rails app + MCP server (depends on schema — no views/controllers needed)
3. **Parallel with MCP:** Shared template CSS + Skills + CLAUDE.md + hooks (just config files)
4. **After skills defined:** HTML report templates embedded in each skill
5. **After MCP works:** Git PR workflow (depends on working tools)
6. **After everything works:** Demo rehearsal (verify HTML reports open correctly)
7. **Last:** Slides (content is already defined above)

---

## Technical Reference: Claude Code Hook Events

From the Medium article "Claude Code Hooks: 5 Automations That Eliminate Developer Friction":

| Hook | When It Fires | Best Use |
|------|---------------|----------|
| PreToolUse | Before any tool runs | Block dangerous operations |
| PostToolUse | After tool completes | Auto-format, lint, log |
| PermissionRequest | Before permission dialog | Auto-approve safe commands |
| SessionStart | Session begins | Inject context (git status, TODOs) |
| Stop | Claude finishes responding | Run tests, validate output |
| PreCompact | Before context compaction | Backup transcripts |
| SubagentStop | Subagent completes | Validate agent output |
| UserPromptSubmit | You hit enter | Inject instructions, validate input |

### Auto-Approve Pattern

```json
{
  "matcher": "Bash(npm test*)",
  "hooks": [{
    "type": "command",
    "command": "echo '{\"decision\": \"approve\"}'"
  }]
}
```

### Hook Config Locations

| Location | Scope | Use |
|----------|-------|-----|
| `.claude/settings.json` | Project (shared) | Team standards |
| `.claude/settings.local.json` | Project (personal) | Personal preferences |
| `~/.claude/settings.json` | All projects | Global defaults |

### Debugging Tips

- Hook not triggering? Check matcher syntax (no spaces around pipes)
- Command failing silently? Add: `2>&1 | tee ~/.claude/hook-debug.log`
- Slow? 60-second timeout. Run heavy work in background.
- Multiple hooks on same event run in parallel

---

## Review Fixes Applied (Codex Feedback)

Issues identified by Codex review and how they were resolved:

| Issue | Severity | Resolution |
|-------|----------|------------|
| Read-only safety conflicts with git writes | P1 | Clarified: read-only applies to **operational database only**. Filesystem writes (recommendation artifacts, git branches/PRs) are the output pipeline, explicitly allowed. Updated MCP tools header, enforce-read-only hook, and security posture section. |
| Non-engineers using GitHub PRs | P2 | Clarified role separation: dispatchers/coordinators ASK questions via copilot, fleet managers REVIEW/APPROVE via PRs. Added note that PR is a stand-in for any approval workflow (Slack, email, internal tool). |
| Ranking claims exceed schema | P2 | Added explicit assumption disclaimers to find-maintenance-opportunities skill and recommendation template. Rankings use available data (mileage, trip count, proximity) and state what's NOT accounted for (technician load, bay capacity, availability). |
| Demo asks tools beyond contracts | P2 | Fixed: V-024 efficiency anomaly now clearly comes from `vehicle_health_summary` (separate follow-up), not `vehicles_due_for_maintenance`. Added `leg` parameter to `service_centers_near_route` for outbound/return filtering. |
| ID inconsistencies | P2 | Standardized: unit_number format "V-018" for human-readable, UUIDs in tool calls. Per-recommendation branch naming: `recommendations/v-018-2026-03-19-brake-inspection`. Updated recommendation template with both human-readable and UUID references. |
| Privacy/audit inconsistency | P2 | Dropped "immutable" and privacy-first claims. This is audit logging with user attribution, not GDPR-grade privacy infrastructure. Appropriate for a case study. |
| Hook mechanics gaps | P3 | Fixed: session-start-safety now writes state marker file. gate-mcp-tools checks for that marker with concrete implementation. log-tool-invocation now includes `mkdir -p`. SessionEnd hook now uploads both metadata AND transcript. |
