# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_03_18_205338) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "charging_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "vehicle_id", null: false
    t.uuid "trip_id"
    t.string "location_type"
    t.string "station_name"
    t.decimal "latitude"
    t.decimal "longitude"
    t.decimal "energy_added_kwh"
    t.decimal "charge_rate_kw"
    t.integer "duration_minutes"
    t.decimal "cost"
    t.datetime "charged_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id"], name: "index_charging_events_on_trip_id"
    t.index ["vehicle_id"], name: "index_charging_events_on_vehicle_id"
  end

  create_table "copilot_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "user_name"
    t.text "session_summary"
    t.jsonb "tool_invocations"
    t.string "outcome"
    t.string "s3_transcript_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "maintenance_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "vehicle_id", null: false
    t.uuid "service_center_id", null: false
    t.string "maintenance_type"
    t.text "description"
    t.integer "mileage_at_service"
    t.decimal "cost"
    t.decimal "duration_hours"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_center_id"], name: "index_maintenance_records_on_service_center_id"
    t.index ["vehicle_id"], name: "index_maintenance_records_on_vehicle_id"
  end

  create_table "service_centers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.string "city"
    t.string "contact_email"
    t.decimal "latitude"
    t.decimal "longitude"
    t.jsonb "capabilities"
    t.boolean "is_partner"
    t.boolean "ev_certified"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "trips", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "vehicle_id", null: false
    t.string "trip_number"
    t.string "origin"
    t.string "destination"
    t.integer "distance_miles"
    t.integer "cargo_weight_lbs"
    t.datetime "departure_at"
    t.datetime "return_at"
    t.string "status"
    t.decimal "energy_consumed_kwh"
    t.jsonb "route_waypoints"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_number"], name: "index_trips_on_trip_number", unique: true
    t.index ["vehicle_id", "status"], name: "index_trips_on_vehicle_id_and_status"
    t.index ["vehicle_id"], name: "index_trips_on_vehicle_id"
  end

  create_table "vehicles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "unit_number", null: false
    t.string "make"
    t.string "model"
    t.integer "year"
    t.decimal "battery_capacity_kwh"
    t.integer "range_miles"
    t.integer "current_mileage"
    t.decimal "battery_health_percent"
    t.integer "next_maintenance_due_mileage"
    t.string "next_maintenance_type"
    t.date "last_maintenance_date"
    t.date "annual_inspection_due"
    t.boolean "daily_inspection_current"
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_vehicles_on_status"
    t.index ["unit_number"], name: "index_vehicles_on_unit_number", unique: true
  end

  add_foreign_key "charging_events", "trips"
  add_foreign_key "charging_events", "vehicles"
  add_foreign_key "maintenance_records", "service_centers"
  add_foreign_key "maintenance_records", "vehicles"
  add_foreign_key "trips", "vehicles"
end
