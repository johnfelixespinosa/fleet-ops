# FleetOps Copilot

An AI fleet operations assistant built on Claude Code's extensibility system (skills, hooks, MCP) that reasons over real fleet data to produce evidence-backed maintenance recommendations.

**Live Dashboard:** [fleetops-api-production.up.railway.app](https://fleetops-api-production.up.railway.app)
**Presentation:** [fleetops-api-production.up.railway.app/presentation.html](https://fleetops-api-production.up.railway.app/presentation.html)

---

## What It Does

FleetOps Copilot helps maintenance coordinators, dispatchers, and fleet managers make better operational decisions by querying production fleet data in natural language.

- **Scan the fleet** for vehicles approaching maintenance thresholds
- **Find service centers** along existing trip routes for low-disruption scheduling
- **Generate HTML reports** with evidence, assumptions, and recommendations
- **Draft formal recommendations** as GitHub PRs for fleet manager approval
- **Track copilot sessions** on the production dashboard with full tool call audit trails

## Architecture

```
fleet-ops/
├── api/                        # Rails 8 app — data layer + MCP server
│   ├── app/models/             # 6 models (Vehicle, Trip, MaintenanceRecord, etc.)
│   ├── app/services/mcp/       # MCP server + 6 read-only tools
│   ├── app/controllers/        # Dashboard, vehicles, service centers, sessions
│   ├── app/views/              # Tailwind CSS views with pagination
│   ├── db/seeds.rb             # Timeline-based seed data (real-world validated)
│   └── bin/mcp_server          # JSON-RPC over stdio entry point
│
├── copilot/                    # Claude Code instance — run from here
│   ├── .claude/
│   │   ├── CLAUDE.md           # Role, rules, domain knowledge, 6 tool docs
│   │   ├── settings.json       # Hook definitions
│   │   └── skills/             # 5 investigation workflow skills
│   │       ├── fleet-safety-protocols/
│   │       ├── find-maintenance-opportunities/
│   │       ├── vehicle-health-check/
│   │       ├── draft-maintenance-plan/
│   │       ├── mechanic-service-brief/
│   │       └── report-styles/
│   ├── bin/hooks/              # Shell scripts for session lifecycle
│   ├── mcp.json                # MCP server config
│   └── start                   # Launch script (isolates skills, connects MCP)
│
└── docs/                       # Planning docs
```

## Tech Stack

- **Backend:** Rails 8, PostgreSQL (Railway), Tailwind CSS
- **MCP Server:** Hand-rolled JSON-RPC over stdio (~90 lines), 6 read-only tools
- **AI Platform:** Claude Code with CLAUDE.md, skills, hooks, MCP
- **Deployment:** Railway (API + PostgreSQL)
- **Seed Data:** 12 EV semi-trucks, 7 service centers, 210+ trips, real-world validated specs

## MCP Tools

| Tool | Description |
|------|-------------|
| `vehicles_due_for_maintenance` | Projects daily mileage, flags vehicles approaching thresholds |
| `upcoming_trips_for_vehicle` | Scheduled trips with routes, distances, departure times |
| `service_centers_near_route` | Haversine search for EV-certified shops along trip waypoints |
| `vehicle_health_summary` | Battery health, efficiency trends, charging patterns |
| `draft_maintenance_recommendation` | Structured recommendation with evidence and assumptions |
| `fleet_query` | General-purpose data lookup (vehicles, trips, centers, history) |

## Skills

| Skill | Trigger | Output |
|-------|---------|--------|
| Find Maintenance Opportunities | `/maintenance` | Investigation report (HTML) |
| Vehicle Health Check | `/health` | Health report (HTML) |
| Draft Maintenance Plan | `/recommend` | Recommendation + GitHub PR |
| Mechanic Service Brief | `/service-brief` | Service brief (HTML) + mock email |

## Quick Start

### Prerequisites
- Ruby 3.4.2 (via RVM)
- PostgreSQL
- Claude Code CLI (`claude`)

### Setup
```bash
# Clone and setup Rails
cd api
bundle install
rails db:create db:migrate db:seed

# Start the copilot
cd ../copilot
./start
```

### Or use the alias
```bash
# Add to ~/.zshrc
alias start-copilot="cd /path/to/fleet-ops/copilot && ./start --dangerously-skip-permissions"

# Then just:
start-copilot
```

## Guardrails

- **Read-only data access** — all 6 MCP tools query but never modify operational data
- **Safety protocols** — loaded automatically at session start before any tool can execute
- **Audit logging** — every tool call recorded with tool name, query parameters, and timestamp
- **Session tracking** — full sessions synced to production dashboard on CLI exit
- **Human approval** — recommendations submitted as GitHub PRs for fleet manager review

## Vehicle Data (Real-World Validated)

| Make | Battery | Range | kWh/mile |
|------|---------|-------|----------|
| Tesla Semi 500 | 850 kWh | 500 mi | 1.55–1.73 |
| Freightliner eCascadia | 438 kWh | 230 mi | 1.9–2.1 |
| Volvo VNR Electric | 565 kWh | 275 mi | 1.8–2.0 |

Sources: ArcBest, PepsiCo, DHL real-world tests (Tesla); manufacturer specs (Freightliner, Volvo).

---

Built with Claude Code · Rails 8 · PostgreSQL · MCP · Tailwind CSS
