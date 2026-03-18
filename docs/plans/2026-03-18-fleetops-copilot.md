# FleetOps Copilot Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a secure AI fleet operations copilot using Claude Code's extensibility system (skills, hooks, MCP) that can reason over real fleet data and produce evidence-backed maintenance recommendations — output as professional HTML reports that auto-open in the browser — for a case study presentation at Archer Aviation.

**Architecture:** Two-directory project. `api/` is a Rails 8 app with PostgreSQL that provides the operational data layer (database, models, seeds, simple read-only views) and hosts an MCP server with 5 read-only tools. `copilot/` is the Claude Code instance configured with skills (investigation workflows that generate self-contained HTML report pages), hooks (safety gates, audit logging, workflow enforcement), and CLAUDE.md (role/constraints). Recommendations go through git PRs for the approval workflow.

**Tech Stack:** Rails 8 (with Tailwind, read-only views), PostgreSQL, MCP server (built into Rails), Claude Code skills/hooks, HTML report templates, AWS S3 (audit)

**Context doc:** `docs/fleetops-copilot-context.md`

**Time budget:** 3 hours total

---

## Project Directory Structure

```
/Users/johnespinosa/Desktop/Projects/fleet-ops/
├── api/                        # Rails app — data layer + MCP server + read-only views
│   ├── app/
│   │   ├── models/
│   │   ├── controllers/
│   │   ├── views/
│   │   └── services/mcp/
│   ├── bin/mcp_server
│   ├── config/routes.rb
│   ├── db/
│   │   ├── migrate/
│   │   └── seeds.rb
│   └── ...
│
├── copilot/                    # Claude Code instance — run `claude` from here
│   ├── .claude/
│   │   ├── CLAUDE.md
│   │   ├── settings.json      # MCP points to ../api/bin/mcp_server
│   │   └── skills/
│   │       ├── fleet-safety-protocols/
│   │       ├── find-maintenance-opportunities/
│   │       ├── vehicle-health-check/
│   │       ├── draft-maintenance-plan/
│   │       ├── mechanic-service-brief/
│   │       └── report-styles/
│   ├── bin/hooks/
│   │   └── session-end-audit.sh
│   └── recommendations/       # Where PR recommendation files get committed
│
├── desktop/                    # White-labeled CLUI CC — FleetOps Copilot desktop app
│   ├── src/
│   │   ├── main/              # Electron main process
│   │   ├── renderer/          # React UI (theme, components, stores)
│   │   ├── preload/           # IPC bridge
│   │   └── shared/            # Types
│   ├── resources/             # App icon
│   └── release/               # Built .app output
│
└── docs/                       # Plan + context
    ├── fleetops-copilot-context.md
    └── plans/
        └── 2026-03-18-fleetops-copilot.md
```

---

## Task 1: Rails App Scaffold + Database Schema

**Files:**
- Create: `fleet-ops/api/` (Rails app directory)
- Create: `fleet-ops/api/db/migrate/*` (6 migration files)
- Create: `fleet-ops/api/app/models/*.rb` (6 model files)

**Step 1: Create the project directory and Rails app**

```bash
mkdir -p /Users/johnespinosa/Desktop/Projects/fleet-ops
cd /Users/johnespinosa/Desktop/Projects/fleet-ops
rails new api --database=postgresql --skip-test --skip-system-test --skip-action-mailer --skip-action-mailbox --skip-action-text --skip-active-storage --skip-action-cable --skip-jbuilder --css=tailwind
cd api
```

The Rails app provides: database + models + seeds + read-only views + MCP server. Views are simple index/show pages for browsing fleet data during the demo.

**Step 2: Enable UUID primary keys**

Add to `config/initializers/generators.rb`:

```ruby
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

Add to the database migration (or a new migration):

```ruby
enable_extension "pgcrypto"
```

**Step 3: Generate models and migrations**

```bash
rails generate model Vehicle unit_number:string make:string model:string year:integer battery_capacity_kwh:decimal range_miles:integer current_mileage:integer battery_health_percent:decimal next_maintenance_due_mileage:integer next_maintenance_type:string last_maintenance_date:date annual_inspection_due:date daily_inspection_current:boolean status:string

rails generate model Trip vehicle:references trip_number:string origin:string destination:string distance_miles:integer cargo_weight_lbs:integer departure_at:datetime return_at:datetime status:string energy_consumed_kwh:decimal route_waypoints:jsonb

rails generate model MaintenanceRecord vehicle:references service_center:references maintenance_type:string description:text mileage_at_service:integer cost:decimal duration_hours:decimal completed_at:datetime

rails generate model ServiceCenter name:string address:string city:string contact_email:string latitude:decimal longitude:decimal capabilities:jsonb is_partner:boolean ev_certified:boolean

rails generate model ChargingEvent vehicle:references trip:references location_type:string station_name:string latitude:decimal longitude:decimal energy_added_kwh:decimal charge_rate_kw:decimal duration_minutes:integer cost:decimal charged_at:datetime

rails generate model CopilotSession user_name:string session_summary:text tool_invocations:jsonb outcome:string s3_transcript_url:string
```

Note: `ServiceCenter` includes `contact_email` for the mechanic service brief workflow (mock email destination).

**Step 4: Review and fix migrations**

- Ensure all tables use `id: :uuid`
- Ensure foreign keys use `type: :uuid`
- Add `null: false` on critical fields (unit_number, status)
- Add unique index on `vehicles.unit_number`
- Add unique index on `trips.trip_number`
- Add index on `vehicles.status`
- Add index on `trips.vehicle_id, :status`
- Add index on `maintenance_records.vehicle_id`
- Make `trip:references` on ChargingEvent optional (`null: true`)

**Step 5: Run migrations**

```bash
rails db:create
rails db:migrate
```

**Step 6: Set up model associations and validations**

Uses Rails string-backed enums (Rails 7+ pattern, validated by RubyGems/OpenProject in real-world-rails). Status subset constants follow rescue-rails Dog pattern.

`app/models/vehicle.rb`:
```ruby
class Vehicle < ApplicationRecord
  has_many :trips, dependent: :destroy
  has_many :maintenance_records, dependent: :destroy
  has_many :charging_events, dependent: :destroy

  MAINTENANCE_SCHEDULE = {
    safety_check:          { interval: 15_000, cost_range: 150..300,    duration_hours: 1.5..2.5 },
    standard_service:      { interval: 30_000, cost_range: 400..800,    duration_hours: 3.0..5.0 },
    comprehensive_service: { interval: 60_000, cost_range: 1_200..2_500, duration_hours: 6.0..10.0 },
    major_overhaul:        { interval: 100_000, cost_range: 3_000..8_000, duration_hours: 16.0..24.0 }
  }.freeze

  def next_maintenance_schedule
    MAINTENANCE_SCHEDULE[next_maintenance_type&.to_sym]
  end

  def miles_to_maintenance
    next_maintenance_due_mileage - current_mileage
  end

  def maintenance_urgent?(horizon_miles = 1000)
    miles_to_maintenance <= horizon_miles
  end

  enum :status, { active: "active", in_shop: "in_shop", out_of_service: "out_of_service", retired: "retired" }
  enum :next_maintenance_type, {
    safety_check: "safety_check",
    standard_service: "standard_service",
    comprehensive_service: "comprehensive_service",
    major_overhaul: "major_overhaul"
  }, prefix: :maintenance

  validates :unit_number, presence: true, uniqueness: true
  validates :status, presence: true

  # Dashboard scopes (Mastodon/reservations pattern)
  scope :needing_attention, -> { active.where("next_maintenance_due_mileage - current_mileage < 5000") }
  scope :due_for_maintenance, ->(within_miles) { where("current_mileage + ? >= next_maintenance_due_mileage", within_miles) }
  scope :low_battery, -> { where("battery_health_percent < ?", 95) }

  # Status subsets (rescue-rails Dog pattern)
  OPERATIONAL_STATUSES = %w[active].freeze
  ATTENTION_STATUSES = %w[in_shop out_of_service].freeze
end
```

Seeds, MCP tools, and views all reference `Vehicle::MAINTENANCE_SCHEDULE` for intervals, costs, and durations — single source of truth.

`app/models/trip.rb`:
```ruby
class Trip < ApplicationRecord
  belongs_to :vehicle

  enum :status, { scheduled: "scheduled", in_progress: "in_progress", completed: "completed", cancelled: "cancelled" }

  validates :trip_number, presence: true, uniqueness: true
  validates :status, presence: true

  scope :upcoming, ->(days) { scheduled.where(departure_at: Time.current..days.days.from_now) }
  scope :recent, -> { completed.order(return_at: :desc) }
end
```

`app/models/maintenance_record.rb`:
```ruby
class MaintenanceRecord < ApplicationRecord
  belongs_to :vehicle
  belongs_to :service_center

  scope :recent, -> { order(completed_at: :desc) }
end
```

`app/models/service_center.rb`:
```ruby
class ServiceCenter < ApplicationRecord
  has_many :maintenance_records

  scope :partners, -> { where(is_partner: true) }
  scope :ev_certified, -> { where(ev_certified: true) }
end
```

`app/models/charging_event.rb`:
```ruby
class ChargingEvent < ApplicationRecord
  belongs_to :vehicle
  belongs_to :trip, optional: true

  scope :depot, -> { where(location_type: "depot") }
  scope :en_route, -> { where(location_type: "en_route") }
  scope :recent, -> { order(charged_at: :desc) }
end
```

`app/models/copilot_session.rb`:
```ruby
class CopilotSession < ApplicationRecord
  validates :user_name, presence: true
end
```

**Step 7: Verify**

```bash
rails db:migrate:status
rails runner "puts Vehicle.count"
```

**Step 8: Commit**

```bash
git add -A
git commit -m "feat: scaffold Rails app with fleet operations schema (6 tables, UUID PKs)"
```

---

## Task 2: Seed Data

**Files:**
- Create: `fleetops/db/seeds.rb`

**Step 1: Write comprehensive seed file**

**Seeding strategy: Vehicle timelines, not disconnected records.** Structure seeds.rb around vehicle timelines using a small `TimelineBuilder` module (~20-30 lines). For each vehicle, walk forward from acquisition date: generate trips at weekly cadence accumulating mileage, insert maintenance records when thresholds are crossed, generate charging events per trip. The demo-critical vehicles (EV-2501, EV-2301, EV-2403) get hand-tuned story beats; other vehicles use generic patterns. This ensures any thread an interviewer pulls on leads to coherent data. Reference `Vehicle::MAINTENANCE_SCHEDULE` for intervals and costs.

Patterns from real-world-rails: cfp-app's `find_or_create_by!` for idempotency, Growstuff's per-parent loops for nested records, adopt-a-hydrant's hard-coded lat/lng for geographic data, dev.to's production guard.

```ruby
# Top of seeds.rb
return if Rails.env.production?
puts "Seeding fleet data..."
```

Use `find_or_create_by!` for reference data (vehicles, service centers) so seeds are idempotent and safe to re-run. Use `create!` for transactional data (trips, charging events) guarded by a count check.

Reference `docs/fleetops-copilot-context.md` section "Seed Data: Example Fleet" for the vehicle table. The seed file must create:

**12 vehicles** — per the context doc's "Seed Data: Example Fleet" table. Key demo-critical vehicles:
- EV-2501: 34,000 mi, safety_check due at 35,000, Thursday trip (San Jose -> Fresno)
- EV-2301: 145,000 mi, comprehensive_service due at 150,000, annual inspection due next week
- EV-2403: battery health declining faster than expected (97% at 78K mi)

**7 service centers** along California routes. Each center needs a `contact_email` field:
- Bay Area Fleet Services (Gilroy) — `service@bayareafleet.com` — demo-critical, 9 mi off EV-2501's return route
- Central Valley Truck Care (Modesto) — `dispatch@centralvalleytruck.com`
- Sacramento EV Service Center (Sacramento) — `service@sacevservice.com`
- Fresno Fleet Maintenance (Fresno) — `shop@fresnofleet.com`
- South Bay Commercial Repair (San Jose) — `service@southbaycommercial.com`
- Stockton Heavy Vehicle Service (Stockton) — `service@stocktonheavy.com`
- Bakersfield Fleet Works (Bakersfield) — `service@bakersfieldfleet.com`
- All with realistic lat/lng, capabilities arrays, and ev_certified flags

**~40 trips** across the fleet:
- Past completed trips (last 30 days) with energy consumption data
- Upcoming scheduled trips (next 14 days)
- EV-2501 must have a Thursday trip: San Jose -> Fresno, 185 mi round trip, return via CA-99/I-880
- Realistic departure times (04:30-06:00), cargo weights (35,000-42,000 lbs)
- Trip numbers: TRP-0460 through TRP-0499

**~30 maintenance records** (historical):
- Various types across the fleet
- Realistic costs ($150-$8,000 depending on type)
- EV-2501's last safety_check was at 20,000 miles

**~60 charging events** (mix of depot and en-route):
- 75% depot charging (overnight, $0.06-$0.10/kWh, 50-150 kW)
- 25% en-route fast charging ($0.30-$0.40/kWh, 250-750 kW)

**Step 2: Run seeds**

```bash
rails db:seed
```

**Step 3: Verify key data points for demo**

```bash
rails runner "
  v = Vehicle.find_by(unit_number: 'EV-2501')
  puts \"EV-2501: #{v.current_mileage} mi, due at #{v.next_maintenance_due_mileage}, health: #{v.battery_health_percent}%\"
  puts \"Scheduled trips: #{v.trips.scheduled.count}\"
  puts \"Total vehicles: #{Vehicle.count}\"
  puts \"Total trips: #{Trip.count}\"
  puts \"Service centers: #{ServiceCenter.count}\"
  sc = ServiceCenter.find_by(city: 'Gilroy')
  puts \"Bay Area Fleet Services contact_email: #{sc.contact_email}\"
"
```

**Step 4: Commit**

```bash
git add db/seeds.rb
git commit -m "feat: seed realistic fleet data (12 vehicles, 40 trips, 7 service centers)"
```

---

## Task 3: Read-Only Views

**Files:**
- Create: `api/app/controllers/vehicles_controller.rb`
- Create: `api/app/controllers/service_centers_controller.rb`
- Create: `api/app/controllers/dashboard_controller.rb`
- Create: `api/app/views/vehicles/index.html.erb`
- Create: `api/app/views/vehicles/show.html.erb`
- Create: `api/app/views/service_centers/index.html.erb`
- Create: `api/app/views/dashboard/index.html.erb`
- Modify: `api/config/routes.rb`

Simple read-only views for browsing fleet data during the demo. No forms, no create/edit/delete. Patterns validated by real-world-rails research: Mastodon dashboard (named scope counts), Samson status badges (hash mapping), Bike Index show (partials for related records), fr-staffapp (read-only routes).

**Step 1: Set up routes**

```ruby
# config/routes.rb (fr-staffapp/Spree pattern: only: [:index, :show])
Rails.application.routes.draw do
  root "dashboard#index"
  resources :vehicles, only: [:index, :show]
  resources :service_centers, only: [:index]
end
```

**Step 2: Status badge helper (Samson hash-mapping pattern)**

`app/helpers/application_helper.rb`:
```ruby
module ApplicationHelper
  VEHICLE_STATUS_COLORS = {
    "active" => "green", "in_shop" => "amber",
    "out_of_service" => "red", "retired" => "gray"
  }.freeze

  TRIP_STATUS_COLORS = {
    "scheduled" => "blue", "in_progress" => "amber",
    "completed" => "green", "cancelled" => "gray"
  }.freeze

  URGENCY_COLORS = {
    "critical" => "red", "high" => "orange",
    "moderate" => "amber", "normal" => "green"
  }.freeze

  def status_badge(status, color_map = VEHICLE_STATUS_COLORS)
    color = color_map.fetch(status.to_s, "gray")
    content_tag :span, status.to_s.titleize,
      class: "inline-block px-2 py-1 rounded text-xs font-medium bg-#{color}-100 text-#{color}-800"
  end

  def vehicle_status_badge(status) = status_badge(status, VEHICLE_STATUS_COLORS)
  def trip_status_badge(status) = status_badge(status, TRIP_STATUS_COLORS)
end
```

**Step 3: Dashboard controller + view (Mastodon pattern: named scope counts)**

`app/controllers/dashboard_controller.rb`:
```ruby
class DashboardController < ApplicationController
  def index
    @vehicle_count = Vehicle.count
    @active_count = Vehicle.active.count
    @needing_attention = Vehicle.needing_attention.order(:unit_number)
    @low_battery = Vehicle.low_battery.active
    @upcoming_trips = Trip.scheduled.where(departure_at: ..7.days.from_now).order(:departure_at).limit(10)
  end
end
```

`app/views/dashboard/index.html.erb`:
- Fleet summary stats at the top: total vehicles, active count, needing attention count, upcoming trips
- "Needs Attention" section with vehicle cards (unit number linked to show, status badge, miles to threshold)
- Upcoming trips table (next 7 days)
- Links to vehicles index and service centers index

**Step 4: Vehicles controller + views**

`app/controllers/vehicles_controller.rb`:
```ruby
class VehiclesController < ApplicationController
  def index
    @vehicles = Vehicle.order(:unit_number)
  end

  def show
    @vehicle = Vehicle.find(params[:id])
    @upcoming_trips = @vehicle.trips.scheduled.order(:departure_at)
    @recent_trips = @vehicle.trips.recent.limit(10)
    @maintenance_history = @vehicle.maintenance_records.recent.limit(10)
    @recent_charging = @vehicle.charging_events.recent.limit(10)
  end
end
```

`app/views/vehicles/index.html.erb`:
- Table of all 12 vehicles: unit number (linked to show), make/model, year, current mileage, battery health %, status badge, next maintenance type + miles remaining

`app/views/vehicles/show.html.erb` — Uses partials for related record tables (Bike Index pattern):
```erb
<%= render "vehicles/header", vehicle: @vehicle %>
<%= render "trips/table", trips: @upcoming_trips, title: "Upcoming Trips" %>
<%= render "trips/table", trips: @recent_trips, title: "Recent Completed Trips" %>
<%= render "maintenance_records/table", records: @maintenance_history, title: "Maintenance History" %>
<%= render "charging_events/table", events: @recent_charging, title: "Recent Charging" %>
```

Partials to create:
- `app/views/vehicles/_header.html.erb` — unit number, make/model/year, status badge, battery health gauge, mileage, next maintenance info
- `app/views/trips/_table.html.erb` — reusable table: trip number, route, date, distance, cargo weight, energy consumed, status badge
- `app/views/maintenance_records/_table.html.erb` — type, date, mileage, service center, cost, description
- `app/views/charging_events/_table.html.erb` — date, location type, station, energy added, duration, cost

**Step 5: Service Centers controller + view**

`app/controllers/service_centers_controller.rb`:
```ruby
class ServiceCentersController < ApplicationController
  def index
    @service_centers = ServiceCenter.order(:name)
  end
end
```

`app/views/service_centers/index.html.erb`:
- Table of all 7 centers: name, city, EV certified badge, partner badge, capabilities list, contact email

**Step 6: Application layout with Tailwind**

`app/views/layouts/application.html.erb`:
- Navy header bar with "FleetOps" branding and nav links (Dashboard, Vehicles, Service Centers)
- White content area with max-width container
- Tailwind utility classes throughout
- Color-coded status badges via the helper
- Striped tables with `even:bg-gray-50`

**Step 7: Verify**

```bash
rails server
```

Open `http://localhost:3000` — verify dashboard loads with stats and "needs attention" vehicles, click into a vehicle, check all 4 related record tables render with seeded data, check service centers index.

**Step 8: Commit**

```bash
git add app/controllers/ app/views/ app/helpers/ config/routes.rb
git commit -m "feat: read-only views with dashboard, vehicle detail, and service centers (Tailwind)"
```

---

## Task 4: MCP Server (in api/)

**Files:**
- Create: `fleetops/app/services/mcp/` directory
- Create: `fleetops/app/services/mcp/server.rb`
- Create: `fleetops/app/services/mcp/tools/*.rb` (5 tool files)
- Create: `fleetops/bin/mcp_server` (executable entry point)

This is the most critical task. The MCP server is what gives Claude Code access to the fleet data. It must speak the MCP protocol (JSON-RPC over stdio).

**Step 1: Research MCP server implementation for Ruby**

Check if there's a Ruby MCP SDK gem available. If not, implement a minimal stdio JSON-RPC server. The protocol is:
- Client sends JSON-RPC requests over stdin
- Server responds over stdout
- Methods: `initialize`, `tools/list`, `tools/call`

Options:
- `mcp-ruby` gem if it exists
- `fast-mcp` gem (check rubygems)
- Minimal hand-rolled implementation (~100 lines for the protocol layer)

**Step 2: Implement tool classes**

Each tool is a Ruby class that:
- Declares its name, description, and input schema (JSON Schema)
- Has an `execute(params)` method that queries the database and returns structured results

`app/services/mcp/tools/vehicles_due_for_maintenance.rb`:
```ruby
module Mcp
  module Tools
    class VehiclesDueForMaintenance
      def self.name = "vehicles_due_for_maintenance"

      def self.description
        "Find vehicles approaching or past their maintenance threshold within a given number of days. " \
        "Estimates daily mileage from recent trips and projects when each vehicle will reach its threshold."
      end

      def self.input_schema
        {
          type: "object",
          properties: {
            within_days: { type: "integer", description: "Number of days to look ahead (default: 7)", default: 7 }
          }
        }
      end

      def self.execute(params)
        within_days = params["within_days"] || 7
        vehicles = Vehicle.active

        results = vehicles.filter_map do |v|
          # Calculate average daily mileage from last 30 days of completed trips
          recent_trips = v.trips.where(status: "completed").where("return_at > ?", 30.days.ago)
          daily_miles = if recent_trips.any?
            total_miles = recent_trips.sum(:distance_miles)
            days = [(recent_trips.maximum(:return_at).to_date - recent_trips.minimum(:departure_at).to_date).to_i, 1].max
            (total_miles.to_f / days).round(1)
          else
            0
          end

          projected_mileage = v.current_mileage + (daily_miles * within_days)
          miles_to_threshold = v.next_maintenance_due_mileage - v.current_mileage

          if projected_mileage >= v.next_maintenance_due_mileage || miles_to_threshold <= 1000
            {
              unit_number: v.unit_number,
              vehicle_id: v.id,
              make_model: "#{v.year} #{v.make} #{v.model}",
              current_mileage: v.current_mileage,
              threshold_mileage: v.next_maintenance_due_mileage,
              miles_remaining: miles_to_threshold,
              maintenance_type: v.next_maintenance_type,
              daily_mileage_estimate: daily_miles,
              projected_days_until_due: daily_miles > 0 ? (miles_to_threshold / daily_miles).round(1) : nil,
              annual_inspection_due: v.annual_inspection_due&.iso8601,
              battery_health_percent: v.battery_health_percent
            }
          end
        end

        results.sort_by { |r| r[:miles_remaining] }
      end
    end
  end
end
```

`app/services/mcp/tools/upcoming_trips_for_vehicle.rb`:
```ruby
module Mcp
  module Tools
    class UpcomingTripsForVehicle
      def self.name = "upcoming_trips_for_vehicle"

      def self.description
        "Get scheduled trips for a specific vehicle within a given number of days ahead."
      end

      def self.input_schema
        {
          type: "object",
          properties: {
            vehicle_id: { type: "string", description: "UUID of the vehicle" },
            days_ahead: { type: "integer", description: "Number of days to look ahead (default: 14)", default: 14 }
          },
          required: ["vehicle_id"]
        }
      end

      def self.execute(params)
        vehicle = Vehicle.find(params["vehicle_id"])
        trips = vehicle.trips.upcoming(params["days_ahead"] || 14).order(:departure_at)

        trips.map do |t|
          {
            trip_id: t.id,
            trip_number: t.trip_number,
            origin: t.origin,
            destination: t.destination,
            distance_miles: t.distance_miles,
            cargo_weight_lbs: t.cargo_weight_lbs,
            departure_at: t.departure_at.iso8601,
            return_at: t.return_at.iso8601,
            has_waypoints: t.route_waypoints.present?
          }
        end
      end
    end
  end
end
```

`app/services/mcp/tools/service_centers_near_route.rb`:
```ruby
module Mcp
  module Tools
    class ServiceCentersNearRoute
      def self.name = "service_centers_near_route"

      def self.description
        "Find partner service centers within a given radius of a trip's route. " \
        "Can search along the full route, outbound leg, or return leg."
      end

      def self.input_schema
        {
          type: "object",
          properties: {
            trip_id: { type: "string", description: "UUID of the trip" },
            radius_miles: { type: "integer", description: "Search radius in miles (default: 25)", default: 25 },
            leg: { type: "string", enum: ["outbound", "return", "full"], description: "Which portion of route to search (default: return)", default: "return" }
          },
          required: ["trip_id"]
        }
      end

      def self.execute(params)
        trip = Trip.find(params["trip_id"])
        radius = params["radius_miles"] || 25
        leg = params["leg"] || "return"
        waypoints = trip.route_waypoints || []

        # Select waypoints based on leg
        selected = case leg
        when "outbound" then waypoints.first(waypoints.size / 2)
        when "return" then waypoints.last(waypoints.size / 2)
        else waypoints
        end

        return [] if selected.empty?

        # Find service centers near any waypoint
        centers = ServiceCenter.partners.ev_certified
        results = centers.filter_map do |sc|
          min_distance = selected.map do |wp|
            haversine_miles(wp["lat"], wp["lng"], sc.latitude.to_f, sc.longitude.to_f)
          end.min

          if min_distance <= radius
            {
              service_center_id: sc.id,
              name: sc.name,
              city: sc.city,
              contact_email: sc.contact_email,
              distance_from_route_miles: min_distance.round(1),
              capabilities: sc.capabilities,
              ev_certified: sc.ev_certified
            }
          end
        end

        results.sort_by { |r| r[:distance_from_route_miles] }
      end

      def self.haversine_miles(lat1, lng1, lat2, lng2)
        rad = Math::PI / 180
        dlat = (lat2 - lat1) * rad
        dlng = (lng2 - lng1) * rad
        a = Math.sin(dlat / 2)**2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dlng / 2)**2
        3959 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      end
    end
  end
end
```

`app/services/mcp/tools/vehicle_health_summary.rb`:
```ruby
module Mcp
  module Tools
    class VehicleHealthSummary
      def self.name = "vehicle_health_summary"

      def self.description
        "Get a comprehensive health summary for a specific vehicle including efficiency trends, " \
        "charging patterns, maintenance history, and utilization stats."
      end

      def self.input_schema
        {
          type: "object",
          properties: {
            vehicle_id: { type: "string", description: "UUID of the vehicle" }
          },
          required: ["vehicle_id"]
        }
      end

      def self.execute(params)
        v = Vehicle.find(params["vehicle_id"])
        recent_trips = v.trips.where(status: "completed").order(return_at: :desc).limit(10)
        recent_charging = v.charging_events.order(charged_at: :desc).limit(10)
        maintenance_history = v.maintenance_records.order(completed_at: :desc).limit(5)

        # Efficiency trend (kWh/mile over recent trips)
        efficiency_trend = recent_trips.filter_map do |t|
          next unless t.energy_consumed_kwh&.positive? && t.distance_miles&.positive?
          {
            trip_number: t.trip_number,
            date: t.return_at.to_date.iso8601,
            kwh_per_mile: (t.energy_consumed_kwh / t.distance_miles).round(3),
            distance_miles: t.distance_miles,
            cargo_weight_lbs: t.cargo_weight_lbs
          }
        end

        # Charging patterns
        depot_charges = recent_charging.select { |c| c.location_type == "depot" }
        enroute_charges = recent_charging.select { |c| c.location_type == "en_route" }

        {
          unit_number: v.unit_number,
          make_model: "#{v.year} #{v.make} #{v.model}",
          current_mileage: v.current_mileage,
          battery_health_percent: v.battery_health_percent,
          battery_capacity_kwh: v.battery_capacity_kwh,
          status: v.status,
          efficiency_trend: efficiency_trend,
          avg_kwh_per_mile: efficiency_trend.any? ? (efficiency_trend.sum { |e| e[:kwh_per_mile] } / efficiency_trend.size).round(3) : nil,
          charging_summary: {
            depot_charges_last_10: depot_charges.size,
            enroute_charges_last_10: enroute_charges.size,
            avg_depot_kwh: depot_charges.any? ? (depot_charges.sum(&:energy_added_kwh) / depot_charges.size).round(1) : nil,
            avg_enroute_kwh: enroute_charges.any? ? (enroute_charges.sum(&:energy_added_kwh) / enroute_charges.size).round(1) : nil
          },
          recent_maintenance: maintenance_history.map { |m|
            { type: m.maintenance_type, date: m.completed_at.to_date.iso8601, mileage: m.mileage_at_service, cost: m.cost }
          },
          next_maintenance: {
            type: v.next_maintenance_type,
            due_at_mileage: v.next_maintenance_due_mileage,
            miles_remaining: v.next_maintenance_due_mileage - v.current_mileage
          },
          annual_inspection_due: v.annual_inspection_due&.iso8601
        }
      end
    end
  end
end
```

`app/services/mcp/tools/draft_maintenance_recommendation.rb`:
```ruby
module Mcp
  module Tools
    class DraftMaintenanceRecommendation
      def self.name = "draft_maintenance_recommendation"

      def self.description
        "Generate a structured maintenance recommendation with evidence, affected trips, " \
        "suggested window, and assumptions. Returns data suitable for creating a recommendation artifact."
      end

      def self.input_schema
        {
          type: "object",
          properties: {
            vehicle_id: { type: "string", description: "UUID of the vehicle" },
            service_center_id: { type: "string", description: "UUID of the recommended service center" },
            trip_id: { type: "string", description: "UUID of the trip during which maintenance could occur" }
          },
          required: ["vehicle_id", "service_center_id", "trip_id"]
        }
      end

      def self.execute(params)
        vehicle = Vehicle.find(params["vehicle_id"])
        center = ServiceCenter.find(params["service_center_id"])
        trip = Trip.find(params["trip_id"])

        # Find trips that would be affected
        affected_trips = vehicle.trips.scheduled
          .where("departure_at > ?", trip.departure_at)
          .order(:departure_at)
          .limit(5)

        {
          vehicle: {
            unit_number: vehicle.unit_number,
            make_model: "#{vehicle.year} #{vehicle.make} #{vehicle.model}",
            current_mileage: vehicle.current_mileage,
            battery_health_percent: vehicle.battery_health_percent
          },
          maintenance: {
            type: vehicle.next_maintenance_type,
            threshold_mileage: vehicle.next_maintenance_due_mileage,
            miles_remaining: vehicle.next_maintenance_due_mileage - vehicle.current_mileage
          },
          service_center: {
            name: center.name,
            city: center.city,
            contact_email: center.contact_email,
            ev_certified: center.ev_certified,
            capabilities: center.capabilities
          },
          trip_context: {
            trip_number: trip.trip_number,
            route: "#{trip.origin} -> #{trip.destination}",
            departure: trip.departure_at.iso8601,
            return: trip.return_at.iso8601
          },
          affected_trips: affected_trips.map { |t|
            { trip_number: t.trip_number, departure: t.departure_at.iso8601, destination: t.destination }
          },
          assumptions: [
            "Service center availability not confirmed — recommend calling ahead",
            "Duration estimate based on standard #{vehicle.next_maintenance_type} (~#{estimated_hours(vehicle.next_maintenance_type)} hours)",
            "No technician load or bay capacity data available",
            "Cost estimate: #{estimated_cost_range(vehicle.next_maintenance_type)}"
          ]
        }
      end

      def self.estimated_hours(type)
        { "safety_check" => 2, "standard_service" => 4, "comprehensive_service" => 6, "major_overhaul" => 10 }[type] || 3
      end

      def self.estimated_cost_range(type)
        { "safety_check" => "$150-$300", "standard_service" => "$400-$800", "comprehensive_service" => "$1,200-$2,500", "major_overhaul" => "$3,000-$8,000" }[type] || "varies"
      end
    end
  end
end
```

**Step 3: Implement the MCP server protocol layer**

`app/services/mcp/server.rb` — handles JSON-RPC over stdio, routes `tools/list` and `tools/call` to the tool classes.

`bin/mcp_server` — executable that boots Rails and starts the MCP server:
```ruby
#!/usr/bin/env ruby
require_relative "../config/environment"
Mcp::Server.new.run
```

Make executable: `chmod +x bin/mcp_server`

**Step 4: Test the MCP server manually**

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | bin/mcp_server
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"vehicles_due_for_maintenance","arguments":{"within_days":7}}}' | bin/mcp_server
```

Verify that tools return real data from the seeded database.

**Step 5: Commit**

```bash
git add app/services/mcp/ bin/mcp_server
git commit -m "feat: MCP server with 5 fleet operations tools (read-only)"
```

---

## Task 5: Claude Code Configuration — copilot/ (CLAUDE.md + settings.json)

**Files:**
- Create: `fleetops/.claude/CLAUDE.md`
- Create: `fleetops/.claude/settings.json`

**Step 1: Write CLAUDE.md**

This establishes the copilot's role, constraints, and operational context:

```markdown
# FleetOps Copilot

You are the FleetOps Copilot — a secure internal AI assistant for electric truck fleet operations.

## Your Role

You help maintenance coordinators, dispatchers, and fleet managers make better operational decisions by reasoning over fleet data.

## Your Users

Your users are NOT engineers. They are fleet operations staff who need answers in plain language. Do not use technical jargon, code snippets, or references to databases. Speak in terms of vehicles, trips, service appointments, and recommendations.

## Your Tools

You have access to 5 MCP tools that query a read-only operational database:

1. **vehicles_due_for_maintenance** — find vehicles approaching service thresholds
2. **upcoming_trips_for_vehicle** — get scheduled trips for a vehicle
3. **service_centers_near_route** — find service centers along a trip route
4. **vehicle_health_summary** — get efficiency, charging, and maintenance trends
5. **draft_maintenance_recommendation** — generate a structured recommendation

## Rules

1. **Read-only** — You can query fleet data but NEVER modify it
2. **Evidence-based** — Every recommendation must cite specific data points
3. **Assumptions stated** — Always list what you don't know (availability, capacity, etc.)
4. **Propose, don't execute** — Generate recommendations for human review, never take action
5. **Use skills** — Follow investigation workflows defined in skills before generating recommendations

## Output Format

All investigation results and reports are generated as self-contained HTML pages and opened in the user's browser. Use the HTML report templates defined in each skill. Every report uses the shared FleetOps Copilot branding (header, footer, color scheme).

## Fleet Context

- Regional EV fleet based in San Jose, California
- 12 vehicles: Tesla Semi 500, Freightliner eCascadia, Volvo VNR Electric
- Routes: San Jose, Fresno, Sacramento, Stockton, Bakersfield corridor
- 7 partner service centers along major California routes
```

**Step 2: Write settings.json**

Configure MCP server and hook definitions:

```json
{
  "mcpServers": {
    "fleetops": {
      "command": "bin/mcp_server",
      "cwd": "/Users/johnespinosa/Desktop/Projects/fleet-ops/api"
    }
  },
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "mkdir -p /tmp/fleetops-audit && cat .claude/skills/fleet-safety-protocols.md && echo '---' && echo 'Session started:' && date -u && echo 'safety_loaded' > /tmp/fleetops-audit/.safety-gate-marker && echo '{\"type\":\"session_start\",\"ts\":\"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'\",\"user\":\"'$(whoami)'\",\"sid\":\"'\"${CLAUDE_SESSION_ID:-unknown}\"'\"}' >> /tmp/fleetops-audit/events.jsonl"
      }]
    }],
    "PreToolUse": [
      {
        "matcher": "vehicles_due_for_maintenance|upcoming_trips_for_vehicle|service_centers_near_route|vehicle_health_summary|draft_maintenance_recommendation",
        "hooks": [{
          "type": "command",
          "command": "if [ ! -f /tmp/fleetops-audit/.safety-gate-marker ]; then echo 'BLOCKED: Fleet safety protocols must be loaded first.' && exit 1; fi"
        }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "vehicles_due_for_maintenance|upcoming_trips_for_vehicle|service_centers_near_route|vehicle_health_summary|draft_maintenance_recommendation",
        "hooks": [{
          "type": "command",
          "command": "mkdir -p /tmp/fleetops-audit && echo '{\"type\":\"tool_call\",\"tool\":\"'\"$CLAUDE_TOOL_NAME\"'\",\"ts\":\"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'\",\"user\":\"'$(whoami)'\",\"sid\":\"'\"${CLAUDE_SESSION_ID:-unknown}\"'\"}' >> /tmp/fleetops-audit/events.jsonl"
        }]
      }
    ],
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "echo 'ROUTING: Classify this request as exactly one of: [find-maintenance-opportunities, vehicle-health-check, draft-maintenance-plan, mechanic-service-brief, general-question]. Activate the matching skill and generate the corresponding HTML report. If general-question, answer directly using MCP tools with evidence.'"
      }]
    }]
  }
}
```

The `UserPromptSubmit` hook prevents the most likely demo failure: an ambiguous prompt producing text-only output instead of activating the skill's HTML report pipeline.

**Step 3: Commit**

```bash
git add .claude/
git commit -m "feat: Claude Code configuration (CLAUDE.md, settings.json, MCP + hooks)"
```

---

## Task 6: Skills as Folders (5 Skills with HTML Templates)

Skills are **folders, not single files** (per Anthropic's latest best practices). Each skill has a SKILL.md orchestrator, actual HTML template files that Claude copies and fills in, and a gotchas file for common failure points. This ensures consistent, repeatable output every time.

**Directory structure:**

```
copilot/.claude/skills/
├── fleet-safety-protocols/
│   └── SKILL.md
│
├── find-maintenance-opportunities/
│   ├── SKILL.md                         # Orchestrator — workflow steps only
│   ├── templates/
│   │   └── investigation-report.html    # Actual HTML template with {{placeholders}}
│   └── gotchas.md
│
├── vehicle-health-check/
│   ├── SKILL.md
│   ├── templates/
│   │   └── health-report.html
│   └── gotchas.md
│
├── draft-maintenance-plan/
│   ├── SKILL.md
│   ├── templates/
│   │   ├── recommendation-report.html
│   │   └── recommendation.md            # Markdown template for the git PR
│   └── gotchas.md
│
├── mechanic-service-brief/
│   ├── SKILL.md
│   ├── templates/
│   │   └── service-brief.html
│   └── gotchas.md
│
└── report-styles/
    ├── SKILL.md
    └── assets/
        ├── shared-styles.css            # Actual CSS file
        └── base-layout.html             # Base HTML structure all reports use
```

**Key principle:** SKILL.md is the orchestrator — it contains the workflow steps and points Claude to the template files. The HTML templates are actual files with `{{placeholders}}` that Claude copies, fills in with MCP tool data, and writes as the output. This eliminates CSS drift and missing sections.

**Step 0: Create skill chaining manifest**

`copilot/.claude/skills/skill-chain.json`:
```json
{
  "chains": {
    "maintenance-workflow": {
      "description": "Full investigation-to-recommendation pipeline",
      "steps": [
        {
          "skill": "find-maintenance-opportunities",
          "produces": {
            "flagged_vehicles": "array of { vehicle_id, unit_number, urgency, trip_id, service_center_id }",
            "investigation_report": "/tmp/fleetops-reports/maintenance-investigation-{date}.html"
          }
        },
        {
          "skill": "vehicle-health-check",
          "optional": true,
          "requires": ["flagged_vehicles.vehicle_id"],
          "produces": {
            "health_classification": "normal | monitor | investigate | urgent",
            "health_report": "/tmp/fleetops-reports/vehicle-health-{unit_number}-{date}.html"
          }
        },
        {
          "skill": "draft-maintenance-plan",
          "requires": ["flagged_vehicles.vehicle_id", "flagged_vehicles.trip_id", "flagged_vehicles.service_center_id"],
          "produces": {
            "recommendation_report": "/tmp/fleetops-reports/recommendation-{unit_number}-{date}.html",
            "recommendation_artifact": "recommendations/{unit_number}-{date}-{type}.md",
            "pr_url": "string"
          }
        },
        {
          "skill": "mechanic-service-brief",
          "requires": ["flagged_vehicles.vehicle_id", "flagged_vehicles.service_center_id"],
          "produces": {
            "service_brief": "/tmp/fleetops-reports/service-brief-{unit_number}-{date}.html",
            "email_log": "/tmp/fleetops-audit/events.jsonl"
          }
        }
      ]
    }
  }
}
```

Self-documenting pipeline. Each skill's SKILL.md references this manifest for required inputs and expected outputs.

**Step 1: Create the report-styles skill folder (shared assets)**

`copilot/.claude/skills/report-styles/SKILL.md`:
```markdown
---
name: report-styles
description: Shared CSS and HTML base layout for all FleetOps Copilot reports. Other skills reference these assets when generating output.
---

# FleetOps Copilot Report Styles

This skill contains the shared visual assets for all reports. When generating any HTML report:

1. Read `assets/base-layout.html` for the HTML structure
2. Read `assets/shared-styles.css` for the CSS
3. Copy the base layout, inject the CSS into the `<style>` tag
4. Fill in the report-specific content in the `<main>` section

All reports are written to `/tmp/fleetops-reports/`. Create the directory if needed:
```bash
mkdir -p /tmp/fleetops-reports
```

After writing the HTML file, open it:
```bash
open /tmp/fleetops-reports/{filename}.html
```
```

`copilot/.claude/skills/report-styles/assets/base-layout.html`:
A complete, self-contained HTML file with:
- `{{REPORT_TITLE}}`, `{{REPORT_TYPE}}`, `{{REPORT_DATE}}`, `{{REPORT_BODY}}` placeholders
- Header: FleetOps Copilot branding (navy background, white text), report type, date
- Main section: `{{REPORT_BODY}}` placeholder for skill-specific content
- Footer: "Generated by FleetOps Copilot — {{TIMESTAMP}}" + disclaimer
- `<style>` tag with `{{STYLES}}` placeholder (or inline the CSS directly)

**Template hydration pattern:** The base-layout.html includes reusable `<template>` elements (vehicle-card, data-table, badge, metric, progress-bar) and a 15-line inline script that hydrates them from `window.REPORT_DATA`. Claude's job is to generate a JSON data blob, not HTML structure. This eliminates HTML generation errors.

Each skill's template file becomes a data-only fragment:
```html
<script>
window.REPORT_DATA = {
  vehicles: [{ unit_number: 'EV-2501', make_model: '2025 Volvo VNR Electric', ... }],
  trips: [{ trip_number: 'TRP-0482', route: 'San Jose → Fresno', ... }]
};
</script>
<div data-render='vehicle-card' data-source='vehicles'></div>
<div data-render='data-table' data-source='trips'></div>
```

The hydration script clones template elements, fills `data-field` attributes from the JSON, and appends to the render containers. Claude is dramatically better at producing structured JSON than correct nested HTML.

`copilot/.claude/skills/report-styles/assets/shared-styles.css`:
Actual CSS file implementing the design system:
- **Primary:** `#1a365d` (navy) — header, headings
- **Accent:** `#2b6cb0` (blue) — links, highlights
- **Success:** `#38a169` (green), **Warning:** `#d69e2e` (amber), **Danger:** `#e53e3e` (red), **Investigate:** `#dd6b20` (orange)
- **Background:** `#f7fafc`, **Cards:** `#ffffff`, **Text:** `#2d3748`
- **Font:** `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`
- **Max width:** `900px` centered
- Classes: `.report`, `.report-header`, `.report-footer`, `.card`, `.badge`, `.badge-critical`, `.badge-high`, `.badge-moderate`, `.badge-normal`, `.badge-proposed`, `.data-table`, `.progress-bar`, `.gauge`, `.metric`, `.evidence-list`, `.assumptions-list`
- `@media print` styles for clean printing

**Step 2: Create fleet-safety-protocols skill**

`copilot/.claude/skills/fleet-safety-protocols/SKILL.md`:
```markdown
---
name: fleet-safety-protocols
description: Safety protocols that must be loaded before using any fleet data tools. Loaded automatically by SessionStart hook.
---

# Fleet Safety Protocols

## Data Access
- All database access is READ-ONLY via curated MCP tools
- Never attempt to write, update, or delete operational data
- Never execute raw SQL or direct database commands

## Recommendations
- All maintenance recommendations are PROPOSALS for human review
- Never present a recommendation as a confirmed action
- Always include evidence (data points) and assumptions (what you don't know)
- Recommendations are submitted as git PRs for fleet manager approval

## Output
- All investigation results and reports are generated as HTML pages using the templates in each skill's `templates/` directory
- Always use the shared styles from `report-styles/assets/`
- Every report must include the standard header and footer

## Audit
- Every tool call is logged automatically
- Every session is recorded for audit purposes
- Always identify yourself as the FleetOps Copilot in recommendations
```

**Step 3: Create find-maintenance-opportunities skill folder**

`copilot/.claude/skills/find-maintenance-opportunities/SKILL.md`:
```markdown
---
name: find-maintenance-opportunities
description: Use when asked about vehicles due for maintenance, upcoming service needs, or fleet maintenance scheduling. Runs a multi-step investigation and outputs a Maintenance Investigation Report HTML page.
---

# Find Maintenance Opportunities

## Workflow

1. Call `vehicles_due_for_maintenance` with the requested time window
2. For each flagged vehicle, call `upcoming_trips_for_vehicle` to understand scheduling impact
3. For vehicles with upcoming trips, call `service_centers_near_route` (leg: "return") to find low-disruption service options
4. Rank opportunities by: miles remaining to threshold, number of affected trips, proximity of service centers to routes
5. Read `gotchas.md` before generating output
6. Read `report-styles/assets/base-layout.html` and `report-styles/assets/shared-styles.css`
7. Copy `templates/investigation-report.html`, fill in with investigation data
8. Write to `/tmp/fleetops-reports/maintenance-investigation-{date}.html`
9. Open in browser: `open /tmp/fleetops-reports/maintenance-investigation-{date}.html`
```

`copilot/.claude/skills/find-maintenance-opportunities/templates/investigation-report.html`:
HTML template (extends base-layout) with sections for:
- Summary stats (vehicles scanned, flagged, time window)
- Vehicle cards with: unit number, make/model, urgency badge, mileage progress bar, maintenance type, upcoming trips table, nearest service center
- Assumptions section
- All using `{{PLACEHOLDER}}` syntax for Claude to fill in

`copilot/.claude/skills/find-maintenance-opportunities/gotchas.md`:
```markdown
# Gotchas

- Do NOT flag vehicles with status `in_shop` or `out_of_service` — they're already being handled
- Do NOT assume service center availability — always list as "not confirmed"
- Always state what data you lack: technician load, bay capacity, parts availability
- If a vehicle has no recent trips (no mileage data), say "insufficient data to project threshold date" rather than guessing
- Urgency classification: critical = will exceed threshold before next scheduled trip, high = within 1,000 miles, moderate = within 5,000 miles
- A vehicle can have BOTH a maintenance threshold approaching AND an annual inspection due — flag both
```

**Step 4: Create vehicle-health-check skill folder**

`copilot/.claude/skills/vehicle-health-check/SKILL.md`:
```markdown
---
name: vehicle-health-check
description: Use when asked about a specific vehicle's health, efficiency, battery condition, or whether anomalies are worth investigating. Outputs a Vehicle Health Report HTML page.
---

# Vehicle Health Check

## Workflow

1. Call `vehicle_health_summary` for the target vehicle
2. Analyze efficiency trend (kWh/mile) — read gotchas.md for model-specific benchmarks
3. Review battery health vs expected degradation (~2% per year is normal)
4. Check charging patterns — high DC fast charge ratio accelerates degradation
5. Review maintenance history
6. Classify: normal / monitor / investigate / urgent
7. Read `report-styles/assets/base-layout.html` and `report-styles/assets/shared-styles.css`
8. Copy `templates/health-report.html`, fill in with analysis data
9. Write to `/tmp/fleetops-reports/vehicle-health-{unit_number}-{date}.html`
10. Open in browser
```

`copilot/.claude/skills/vehicle-health-check/templates/health-report.html`:
HTML template with sections for:
- Vehicle identity card (unit, make/model, mileage, status)
- Classification badge (normal/monitor/investigate/urgent)
- Battery health gauge (visual percentage)
- Efficiency trend table (recent trips with kWh/mile, benchmark comparison)
- Charging pattern summary (depot vs en-route ratio)
- Maintenance history table
- Classification reasoning and recommended action

`copilot/.claude/skills/vehicle-health-check/gotchas.md`:
```markdown
# Gotchas

- kWh/mile benchmarks differ BY MODEL — never compare across models:
  - Tesla Semi: 1.55–1.73 kWh/mile
  - Freightliner eCascadia: 1.9–2.1 kWh/mile
  - Volvo VNR Electric: 1.8–2.0 kWh/mile
- Battery health below 95% before 50,000 miles IS unusual and warrants investigation
- Normal degradation is ~2% per year. Faster than that → flag it
- Cargo weight affects efficiency — a trip at 42,000 lbs will show higher kWh/mile than 35,000 lbs. Don't compare loaded vs empty trips
- DC fast charging (en_route) above 50% of total charges correlates with accelerated degradation
- Classification guide:
  - normal: all metrics within expected ranges
  - monitor: one metric slightly outside range, no immediate action needed
  - investigate: efficiency declining or battery health below expected, recommend diagnostic
  - urgent: multiple metrics outside range, or safety-related concern
```

**Step 5: Create draft-maintenance-plan skill folder**

`copilot/.claude/skills/draft-maintenance-plan/SKILL.md`:
```markdown
---
name: draft-maintenance-plan
description: Use after investigating maintenance opportunities, when ready to generate a formal recommendation. Creates an HTML report AND a git PR for fleet manager approval.
---

# Draft Maintenance Plan

## Prerequisites
- You MUST have run find-maintenance-opportunities first
- You MUST have identified a specific vehicle, service center, and trip

## Workflow

1. Call `draft_maintenance_recommendation` with the vehicle, service center, and trip
2. Read `report-styles/assets/base-layout.html` and `report-styles/assets/shared-styles.css`
3. Copy `templates/recommendation-report.html`, fill in with recommendation data
4. Write HTML to `/tmp/fleetops-reports/recommendation-{unit_number}-{date}.html`
5. Open in browser
6. Copy `templates/recommendation.md`, fill in with the same data
7. Write markdown to `recommendations/{unit_number}-{date}-{maintenance_type}.md`
8. Create git branch: `recommendations/{unit_number}-{date}-{maintenance_type}`
9. Commit the recommendation file
10. Create PR: `gh pr create --title "Maintenance: {unit_number} {maintenance_type} at {service_center}"`
11. Report the PR URL back to the user
```

`copilot/.claude/skills/draft-maintenance-plan/templates/recommendation-report.html`:
HTML template with sections for:
- Status badge: "PROPOSED — Pending Fleet Manager Approval"
- Vehicle info, maintenance details, service center, trip context
- Affected trips table
- Evidence section, assumptions section
- Approval section: "Submitted as PR #{{PR_NUMBER}} for review"
- Tool calls section (transparency)

`copilot/.claude/skills/draft-maintenance-plan/templates/recommendation.md`:
```markdown
---
vehicle_unit: "{{UNIT_NUMBER}}"
vehicle_id: "{{VEHICLE_ID}}"
service_center: "{{SERVICE_CENTER_NAME}}"
service_center_id: "{{SERVICE_CENTER_ID}}"
trip_id: "{{TRIP_ID}}"
window: "{{MAINTENANCE_WINDOW}}"
urgency: {{URGENCY}}
status: proposed
generated_by: "{{USER}}"
---

## Recommendation
{{RECOMMENDATION_SUMMARY}}

## Evidence
{{EVIDENCE_BULLETS}}

## Affected Trips
{{AFFECTED_TRIPS}}

## Assumptions
{{ASSUMPTIONS}}

## Tool Calls
{{TOOL_CALLS}}
```

`copilot/.claude/skills/draft-maintenance-plan/gotchas.md`:
```markdown
# Gotchas

- Always create the git branch BEFORE committing — if you commit to main, the PR won't work
- The recommendation markdown file AND the HTML report are separate outputs — generate both
- Never omit the Assumptions section even if everything looks certain — there's always something unconfirmed
- The PR title format must be: "Maintenance: {unit_number} {maintenance_type} at {service_center}"
- Always include cost estimates as RANGES, never exact numbers
- If the service center's capabilities don't include the needed maintenance type, flag it explicitly
```

**Step 6: Create mechanic-service-brief skill folder**

`copilot/.claude/skills/mechanic-service-brief/SKILL.md`:
```markdown
---
name: mechanic-service-brief
description: Use when sending a vehicle to a service center for maintenance. Generates an HTML service brief with vehicle specs, history, and service request, and mock-emails it to the service center.
---

# Mechanic Service Brief

## Context
When a truck goes to the shop, the coordinator generates a service brief — a single document with everything the mechanic needs. The mechanic does NOT get access to our agent or fleet data. They get this document.

## Prerequisites
- Which vehicle, which service center, and what service is requested
- If a recommendation was already drafted, use that context

## Workflow

1. Call `vehicle_health_summary` for the vehicle
2. Read `gotchas.md`
3. Read `report-styles/assets/base-layout.html` and `report-styles/assets/shared-styles.css`
4. Copy `templates/service-brief.html`, fill in with vehicle data
5. Write to `/tmp/fleetops-reports/service-brief-{unit_number}-{date}.html`
6. Open in browser
7. Mock-email: log to console AND to `/tmp/fleetops-audit/events.jsonl`:
```bash
mkdir -p /tmp/fleetops-audit
echo '{"type":"service_brief","vehicle":"{unit_number}","recipient":"{contact_email}","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","sid":"'${CLAUDE_SESSION_ID:-unknown}'"}' >> /tmp/fleetops-audit/events.jsonl
echo "Service brief sent to {contact_email}"
```
```

`copilot/.claude/skills/mechanic-service-brief/templates/service-brief.html`:
HTML template with sections for:
- Addressed to: service center name, city, contact email
- Vehicle specifications (unit, make/model, battery capacity, range, mileage)
- Current service request (type, reason, estimated duration, window)
- Battery health gauge and charging pattern summary
- Maintenance history table (last 5 records)
- Known issues / flags
- Special instructions (EV safety: high-voltage system, PPE requirements)
- Footer: "Auto-generated. Contact dispatch for questions."

`copilot/.claude/skills/mechanic-service-brief/gotchas.md`:
```markdown
# Gotchas

- The mechanic is NOT an employee — never include fleet-wide data, trip schedules, or other vehicles
- Only include information about the SPECIFIC vehicle being serviced
- Always include the EV safety reminder — mechanics may not be used to high-voltage systems
- VIN field: use "N/A — see physical vehicle" for the demo (we don't have VINs in seed data)
- If battery health is below 95% or efficiency is trending up, include it in Known Issues even if the current service request is unrelated — the mechanic should know
- Cost estimates in the service brief are for the SERVICE CENTER's reference, not the fleet's internal cost tracking
```

**Step 7: Commit all skills**

```bash
git add .claude/skills/
git commit -m "feat: 5 Claude Code skills as folders with HTML templates, gotchas, and shared report styles (Anthropic best practices)"
```

---

## Task 7: (Merged into Task 6)

Shared report styles are now part of the `report-styles/` skill folder created in Task 6, Step 1. No separate task needed.

**Step 1: Write the shared report styles skill**

```markdown
---
name: report-styles
description: Shared CSS and HTML template structure for all FleetOps Copilot HTML reports. Referenced by other skills when generating output.
---

# FleetOps Copilot Report Styles

When generating any HTML report, use the following shared structure and styles. All reports must be **self-contained** (inline CSS, no external dependencies), **print-friendly**, and **professional**.

## HTML Structure

Every report must follow this structure:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{Report Type} — FleetOps Copilot</title>
  <style>
    /* Paste the shared CSS below */
  </style>
</head>
<body>
  <div class="report">
    <header class="report-header">
      <div class="brand">
        <div class="logo">FleetOps Copilot</div>
        <div class="report-type">{Report Type}</div>
      </div>
      <div class="report-meta">
        <div class="report-date">{Date}</div>
        <div class="report-generated-by">Generated by FleetOps Copilot</div>
      </div>
    </header>

    <main class="report-body">
      <!-- Report-specific content -->
    </main>

    <footer class="report-footer">
      <p>Generated by FleetOps Copilot &mdash; {ISO 8601 timestamp}</p>
      <p class="disclaimer">This report is auto-generated from operational data. Verify critical details before acting.</p>
    </footer>
  </div>
</body>
</html>
```

## Shared CSS

Use this CSS in every report. The executing agent should include the full CSS inline in the `<style>` tag.

**Design system:**
- **Primary color:** `#1a365d` (dark navy) — used for header, headings
- **Accent color:** `#2b6cb0` (medium blue) — used for links, highlights
- **Success/normal:** `#38a169` (green)
- **Warning/monitor:** `#d69e2e` (amber)
- **Danger/urgent:** `#e53e3e` (red)
- **Investigate:** `#dd6b20` (orange)
- **Background:** `#f7fafc` (light gray)
- **Card background:** `#ffffff` (white)
- **Text:** `#2d3748` (dark gray)
- **Muted text:** `#718096` (medium gray)
- **Font stack:** `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`
- **Max width:** `900px`, centered

**Key CSS classes to implement:**
- `.report` — max-width container, centered, background
- `.report-header` — navy background, white text, flex layout with brand left and meta right
- `.report-footer` — light border top, muted text, centered
- `.logo` — bold, large, white
- `.report-type` — lighter weight, white
- `.card` — white background, subtle shadow, rounded corners, padding, margin-bottom
- `.card-title` — section heading within a card
- `.badge` — inline status badge with padding and rounded corners
- `.badge-critical` — red background, white text
- `.badge-high` — orange background, white text
- `.badge-moderate` — amber background, dark text
- `.badge-normal` — green background, white text
- `.badge-proposed` — blue background, white text
- `.data-table` — full-width table with alternating row colors, clean borders
- `.data-table th` — navy background, white text
- `.data-table td` — padding, border-bottom
- `.progress-bar` — visual bar for mileage progress (background track + colored fill)
- `.gauge` — visual percentage indicator for battery health
- `.metric` — large number with label below (for key stats)
- `.metric-value` — large bold number
- `.metric-label` — small muted text
- `.evidence-list` — styled bullet list for evidence points
- `.assumptions-list` — styled bullet list with different marker for assumptions
- `.section-divider` — subtle horizontal rule between sections

**Print styles (`@media print`):**
- Hide unnecessary elements
- Ensure page breaks don't split cards
- Remove shadows and reduce color intensity
- Set background to white

## File Output

All reports are written to `/tmp/fleetops-reports/`. Create the directory if it does not exist:
```bash
mkdir -p /tmp/fleetops-reports
```

After writing the HTML file, open it in the default browser:
```bash
open /tmp/fleetops-reports/{filename}.html
```
```

**Step 2: Commit**

```bash
git add .claude/skills/report-styles.md
git commit -m "feat: shared report CSS/template styles for HTML report output"
```

---

## Task 8: S3 Audit Logging

**Files:**
- Create: `fleetops/bin/hooks/session-end-audit.sh`

**Step 1: Create the SessionEnd audit hook**

```bash
#!/bin/bash
AUDIT_DIR="/tmp/fleetops-audit"
BUCKET="fleetops-copilot-audit"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

# Write session end event to the unified stream
echo "{\"type\":\"session_end\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"user\":\"$(whoami)\",\"sid\":\"$SESSION_ID\"}" >> "$AUDIT_DIR/events.jsonl"

# Upload the single file
if command -v aws &> /dev/null; then
  aws s3 cp "$AUDIT_DIR/events.jsonl" "s3://${BUCKET}/sessions/${SESSION_ID}-events.jsonl" 2>/dev/null
fi
```

```bash
chmod +x bin/hooks/session-end-audit.sh
```

**Step 2: Add Stop hook to settings.json**

Add to the hooks section in `.claude/settings.json`:

```json
"Stop": [{
  "hooks": [{
    "type": "command",
    "command": "bin/hooks/session-end-audit.sh"
  }]
}]
```

**Step 3: Create S3 bucket (if not exists)**

```bash
aws s3 mb s3://fleetops-copilot-audit --region us-west-2
```

If AWS isn't configured, the hook writes locally and silently skips S3. The local audit files at `/tmp/fleetops-audit/` still work for the demo.

All audit events flow to one append-only JSONL file with typed events. Filter at read time with jq, not at write time with separate files. SessionEnd uploads one file to S3.

**Step 4: Commit**

```bash
git add bin/hooks/ .claude/settings.json
git commit -m "feat: S3 audit logging hook (session metadata + tool invocations)"
```

---

## Task 9: White-Label CLUI CC Desktop App

**Files:**
- Clone: `fleet-ops/desktop/` (forked from lcoutodemos/clui-cc)
- Modify: `src/renderer/theme.ts`
- Modify: `src/renderer/components/SlashCommandMenu.tsx`
- Modify: `src/renderer/components/TabStrip.tsx`
- Modify: `src/renderer/components/StatusBar.tsx`
- Modify: `src/renderer/components/MarketplacePanel.tsx`
- Modify: `src/renderer/App.tsx`
- Modify: `src/main/index.ts`
- Modify: `resources/` (app icon)

CLUI CC is an MIT-licensed Electron desktop wrapper for Claude Code. It provides a floating pill interface with multi-tab sessions, permission approval UI, and a skill marketplace. We fork it and white-label it as the FleetOps Copilot desktop app. This transforms the demo from "a terminal" to "a shipped product."

**Step 1: Clone and install**

```bash
cd /Users/johnespinosa/Desktop/Projects/fleet-ops
git clone https://github.com/lcoutodemos/clui-cc.git desktop
cd desktop
./commands/setup.command
```

Verify it runs: `npm run dev` — the floating pill should appear. Close it.

**Step 2: Re-theme to FleetOps navy/blue palette**

`src/renderer/theme.ts` — replace the orange accent palette with FleetOps colors:

```typescript
// Replace all instances of the orange accent
// FROM:
accent: '#d97757',
accentLight: 'rgba(217, 119, 87, 0.1)',
accentSoft: 'rgba(217, 119, 87, 0.15)',
// TO:
accent: '#2b6cb0',
accentLight: 'rgba(43, 108, 176, 0.1)',
accentSoft: 'rgba(43, 108, 176, 0.15)',

// Also update status colors to match:
statusRunning: '#2b6cb0',       // was orange
statusRunningBg: 'rgba(43, 108, 176, 0.1)',
statusPermission: '#2b6cb0',
statusPermissionGlow: 'rgba(43, 108, 176, 0.4)',

// Update input focus border:
inputFocusBorder: 'rgba(43, 108, 176, 0.4)',

// Timeline:
timelineNode: 'rgba(43, 108, 176, 0.2)',
timelineNodeActive: '#2b6cb0',
```

Do the same for the light theme colors in the same file. The goal: the entire app feels navy/blue instead of orange.

**Step 3: Replace slash commands with fleet ops skills**

`src/renderer/components/SlashCommandMenu.tsx` — replace the `SLASH_COMMANDS` array:

```typescript
import { Wrench, HeartPulse, FileText, Envelope, Trash, ShieldCheck, Question } from '@phosphor-icons/react'

export const SLASH_COMMANDS: SlashCommand[] = [
  { command: '/maintenance', description: 'Find vehicles due for maintenance', icon: <Wrench size={13} /> },
  { command: '/health', description: 'Run vehicle health check', icon: <HeartPulse size={13} /> },
  { command: '/recommend', description: 'Draft maintenance recommendation', icon: <FileText size={13} /> },
  { command: '/service-brief', description: 'Generate mechanic service brief', icon: <Envelope size={13} /> },
  { command: '/safety', description: 'Review fleet safety protocols', icon: <ShieldCheck size={13} /> },
  { command: '/clear', description: 'Clear conversation', icon: <Trash size={13} /> },
  { command: '/help', description: 'Show available commands', icon: <Question size={13} /> },
]
```

These map to our Claude Code skills — when the user types `/maintenance`, Claude Code receives the slash command and activates the `find-maintenance-opportunities` skill.

**Step 4: Update branding text**

`src/renderer/components/StatusBar.tsx` — Find any "Claude" or "CLUI" branding text and replace with "FleetOps Copilot".

`src/renderer/components/TabStrip.tsx` — If there's a header/brand element, change to "FleetOps Copilot".

`src/main/index.ts` — Update the Electron window title:
```typescript
// Find the BrowserWindow creation and update the title
title: 'FleetOps Copilot'
```

**Step 5: Set default working directory to copilot/**

`src/renderer/App.tsx` — In the `useEffect` that initializes the working directory, replace the home directory default:

```typescript
// FROM:
const homeDir = useSessionStore.getState().staticInfo?.homePath || '~'
// TO:
const homeDir = '/Users/johnespinosa/Desktop/Projects/fleet-ops/copilot'
```

This ensures the app always starts in the copilot directory with our CLAUDE.md, skills, and hooks loaded.

**Step 6: Electron spawns Rails server on launch**

`src/main/index.ts` — Add Rails server lifecycle management so opening the desktop app starts everything:

```typescript
import { spawn, ChildProcess } from 'child_process'

let railsProcess: ChildProcess | null = null
const API_DIR = '/Users/johnespinosa/Desktop/Projects/fleet-ops/api'

app.whenReady().then(() => {
  // Start Rails server as managed child process
  railsProcess = spawn('bundle', ['exec', 'rails', 'server'], {
    cwd: API_DIR,
    env: { ...process.env, RAILS_ENV: 'development' },
    stdio: 'pipe'
  })

  railsProcess.stdout?.on('data', (data) => {
    console.log(`[rails] ${data}`)
  })

  railsProcess.stderr?.on('data', (data) => {
    console.error(`[rails] ${data}`)
  })

  // ... existing window creation code ...
})

app.on('before-quit', () => {
  if (railsProcess) {
    railsProcess.kill('SIGTERM')
    railsProcess = null
  }
})
```

This eliminates 'open a separate terminal for rails server' from the demo flow. Opening the FleetOps Copilot desktop app starts the Rails server, MCP server, and Claude Code instance. Closing the app stops everything. One process to launch, one to quit.

**Step 7: Disable or customize the marketplace**

`src/renderer/components/MarketplacePanel.tsx` — Either:
- Option A: Hide the marketplace button entirely (remove the HeadCircuit button from App.tsx)
- Option B: Replace the marketplace content with a static list of our 5 installed skills with descriptions

Option A is simpler and cleaner for the demo. In `App.tsx`, remove or comment out the marketplace button in the circles stack.

**Step 8: Update app icon (optional but impactful)**

Replace `resources/icon.png` with a FleetOps-branded icon. Could be as simple as a truck icon in navy/blue. If time is short, skip this — the default icon is fine.

**Step 9: Build and test**

```bash
npm run dev
```

Verify:
- App launches with navy/blue theme
- Slash commands show fleet ops skills only
- Branding says "FleetOps Copilot"
- App starts in the copilot/ directory
- Claude Code connects and MCP tools are available
- Type a question and verify the full flow works through CLUI CC

**Step 10: Build production .app**

```bash
npm run dist
```

This creates a macOS `.app` in `release/`. For the demo, you can either run from `npm run dev` or use the built app.

**Step 11: Commit**

```bash
git add -A
git commit -m "feat: white-label CLUI CC as FleetOps Copilot desktop app (navy theme, fleet skills, custom branding)"
```

---

## Task 10: Demo Rehearsal

**Files:** None new — this is testing the full system

**Step 1: Launch the FleetOps Copilot desktop app**

Launch the FleetOps Copilot desktop app — this automatically starts the Rails server and Claude Code.

```bash
cd /Users/johnespinosa/Desktop/Projects/fleet-ops/desktop
npm run dev
```

Or open the built `.app` from `release/`.

Open `http://localhost:3000` — verify dashboard loads, vehicles table shows all 12, service centers page works.

Verify:
- App appears with FleetOps Copilot branding and navy/blue theme
- Rails server starts automatically (check console output for `[rails]` logs)
- SessionStart hook fires and loads safety protocols
- MCP server connects and tools are available
- Slash commands show fleet ops skills

**Step 2: Run the demo scenario**

Ask: "Which vehicles should we pull into maintenance this week with the least disruption to scheduled trips?"

Verify:
- `find-maintenance-opportunities` skill activates
- `vehicles_due_for_maintenance` tool returns EV-2501, EV-2301, EV-2403
- Follow-up tool calls work (upcoming trips, service centers)
- Results include evidence and assumptions
- **Maintenance Investigation Report HTML opens in the browser** with vehicle cards, urgency badges, and data tables

**Step 3: Test the follow-up**

Ask: "Does EV-2501 have any trips where it passes near an approved service location on return?"

Verify:
- Returns Bay Area Fleet Services near Gilroy
- References the Thursday trip

**Step 4: Test recommendation generation**

Ask: "Draft a maintenance plan for EV-2501 at that location."

Verify:
- **Maintenance Recommendation Document HTML opens in the browser** with evidence, service center, trip context
- Recommendation markdown file is created in `recommendations/`
- Git branch and PR are created
- PR has evidence and assumptions

**Step 5: Test the mechanic service brief**

Ask: "Generate a service brief for the mechanic at Bay Area Fleet Services for EV-2501's safety check."

Verify:
- **Mechanic Service Brief HTML opens in the browser** with vehicle specs, maintenance history, battery health, service request
- Console shows: "Service brief sent to service@bayareafleet.com"
- `/tmp/fleetops-audit/events.jsonl` has the service_brief event

**Step 6: Test the health check follow-up**

Ask: "What about EV-2403 — is the efficiency drop worth investigating?"

Verify:
- `vehicle_health_summary` returns efficiency trend data
- kWh/mile trend shows increase
- Classification and recommendation provided
- **Vehicle Health Report HTML opens in the browser** with efficiency trend, battery gauge, classification badge

**Step 7: Check audit artifacts**

```bash
cat /tmp/fleetops-audit/events.jsonl
ls /tmp/fleetops-reports/
ls /tmp/fleetops-audit/
```

Verify tool calls were logged and HTML reports were generated.

**Step 8: Fix any issues and re-test**

If tools return wrong data, fix seeds. If MCP server fails, debug. If hooks don't fire, check settings.json matchers. If HTML reports don't open or look wrong, fix the skill templates.

---

## Task 11: Presentation Slides

**Files:**
- Create: Slides in Archer template (Google Slides or PowerPoint)

**6 slides — content over design:**

**Slide 1: The Problem**
- Electric fleets create a new coordination burden
- Maintenance scheduling requires combining mileage, trips, battery health, service availability, route geometry
- Today: manual cross-referencing across multiple systems

**Slide 2: The Insight**
- "A rules-only system catches obvious thresholds. Real decisions require combining maintenance status, future trips, route geometry, and service availability."
- A dashboard shows data. A copilot reasons across it.

**Slide 3: The Product**
- FleetOps Copilot: secure internal AI assistant for fleet operations staff
- Natural language → multi-step investigation → evidence-backed recommendation → HTML report + PR for approval
- Built on Claude Code's extensibility system (same pattern as Intercom with 100+ skills)

**Slide 4: Architecture**
- 3-layer diagram: Operational Data → MCP Tools → Claude Code (skills + hooks)
- Security callouts: read-only data, curated tools, safety gates, workflow enforcement, S3 audit
- Output: professional HTML reports auto-opened in browser + git PRs for approval workflow
- Deployment model: VPS + Tailscale (not live-demoed)

**Slide 5: Live Demo**
- Start in browser: show the Rails dashboard and vehicle pages — "here's the fleet data"
- Open the FleetOps Copilot desktop app (white-labeled CLUI CC) — looks like a shipped product, not a terminal
- Show custom slash commands for fleet skills
- Ask about maintenance opportunities → HTML report opens in browser
- Draft recommendation → PR created on GitHub
- Generate mechanic service brief → mock email sent

**Slide 6: What's Next**
- Approval workflow integration (merge PR → schedule in maintenance system)
- Expanded tools (driver assignments, charger availability, weather)
- Role-based tool access (dispatcher vs fleet manager)
- SessionEnd analysis for continuous improvement

**Step: Email slides to recruiter before interview**

---

## Build Order Summary

| Order | Task | Directory | Time | Depends On | Parallelizable? |
|-------|------|-----------|------|------------|-----------------|
| 1 | Rails scaffold + schema + MAINTENANCE_SCHEDULE | api/ | ~30 min | Nothing | — |
| 2 | Seed data (timeline-based) | api/ | ~50 min | Task 1 | — |
| 3 | Read-only views | api/ | ~20 min | Task 2 | Yes, with Task 4 |
| 4 | MCP server + 5 tools | api/ | ~50 min | Task 2 | Yes, with Task 3 |
| 5 | CLAUDE.md + settings.json + UserPromptSubmit | copilot/ | ~12 min | Task 4 | Yes, with Task 6 |
| 6 | Skills as folders (5 skills + chain manifest + templates + gotchas) | copilot/ | ~60 min | Nothing | Yes, with Task 4+5 |
| 7 | (merged into Task 6) | — | — | — | — |
| 8 | S3 audit hook (unified JSONL) | copilot/ | ~10 min | Task 5 | — |
| 9 | White-label CLUI CC desktop app + Rails lifecycle | desktop/ | ~70 min | Nothing | Yes, with Tasks 1-8 |
| 10 | Demo rehearsal + fixes | all | ~20 min | Tasks 1-9 | — |
| 11 | Slides | — | ~20 min | Task 10 | — |

**Total: ~342 min (~5 hrs 42 min)** — heavy parallelization brings this down. Enhancement breakdown: MAINTENANCE_SCHEDULE (+5 min to Task 1), temporal seeding (+15 min to Task 2), UserPromptSubmit (+2 min to Task 5), skill chain manifest (+5 min to Task 6), template hydration (+10 min to Task 6), unified JSONL (net 0 to Task 8, simplifies it), Electron Rails lifecycle (+10 min to Task 9). ~47 min additional, most of which runs in parallel streams.

- Tasks 3+4 run in parallel (save ~20 min)
- Tasks 5+6 run in parallel (save ~12 min)
- **Task 9 (CLUI CC) runs in parallel with ALL other tasks** — it has no dependencies on the Rails app, copilot config, or MCP server until demo rehearsal. A separate agent can fork and customize CLUI CC while the main build progresses. (save ~70 min)

**Compressed timeline: ~3 hrs 30 min** with three parallel work streams:
1. **Stream A (api/):** Task 1 → 2 → 3+4 parallel → done
2. **Stream B (copilot/):** Task 5+6 parallel → 8 → done
3. **Stream C (desktop/):** Task 9 → done
4. **Merge:** Task 10 (rehearsal) → Task 11 (slides)

**Critical path:** Task 1 → Task 2 → Task 4 → Task 5 → Task 8 → Task 10. CLUI CC (Task 9) must finish before demo rehearsal but can build entirely in parallel.

**Demo flow:**
1. Open the **FleetOps Copilot desktop app** — Rails server starts automatically, then open `http://localhost:3000` (Rails views) — "here's the fleet data"
2. The desktop app (white-labeled CLUI CC) looks like a shipped product, not a terminal
3. Show custom slash commands: `/maintenance`, `/health`, `/recommend`, `/service-brief`
4. Ask about maintenance opportunities → HTML Investigation Report opens in browser
5. Draft recommendation → Recommendation Document opens + PR created on GitHub
6. Generate mechanic service brief → Service Brief opens + "emailed" to service center
7. Show audit trail artifacts

---

## Appendix: Real-World Rails Validation

Every major pattern in this plan was validated against production Rails apps in the real-world-rails repository (200+ open-source apps).

| Pattern | Validated By | Key Reference |
|---------|-------------|---------------|
| UUID PKs with `pgcrypto` + generator config | Fizzy (Rails 8, all-UUID) | `config/application.rb`, `db/migrate/` |
| `t.references :name, type: :uuid` for FK refs | Fizzy, Test Track, Publisher (GOV.UK) | Migrations |
| String-backed `enum` for status fields | RubyGems, OpenProject, Open Build Service | `app/models/` |
| Status subset constants (`ACTIVE_STATUSES`) | rescue-rails Dog model | `app/models/dog.rb` |
| has_many associations (vehicle → treatment_records) | rescue-rails Dog → TreatmentRecord | `app/models/dog.rb`, `app/models/treatment_record.rb` |
| JSONB with `store_accessor` | OpenProject Journal | `app/models/journal.rb` |
| Dashboard with named scope counts | Mastodon admin dashboard | `app/controllers/admin/dashboard_controller.rb` |
| Status badge helper (hash mapping) | Samson | `app/helpers/status_helper.rb` |
| Show view with partials for related records | Bike Index organizations | `app/views/admin/organizations/show.html.erb` |
| Read-only routes (`only: [:index, :show]`) | fr-staffapp, Spree, squash-web | `config/routes.rb` |
| Namespaced service objects (`Service::Ticket::Create`) | Zammad | `app/services/service/` |
| Finder/query objects with `execute` method | GitLab `app/finders/` | `DeploymentsFinder` |
| Plain hash returns from services | Gumroad | `app/services/` |
| `bin/` scripts that boot Rails | Huginn (`bin/agent_runner.rb`) | `bin/`, `pre_runner_boot.rb` |
| Inline haversine calculation | worldcubeassociation.org | `app/models/competition.rb:1227` |
| `find_or_create_by!` for idempotent seeds | cfp-app | `db/seeds.rb` |
| Per-parent loops for child record seeding | Growstuff | `db/seeds.rb` |
| Hard-coded lat/lng for geographic seed data | adopt-a-hydrant | `db/seeds.rb` |
| Production guard in seeds | dev.to (Forem) | `db/seeds.rb` |
