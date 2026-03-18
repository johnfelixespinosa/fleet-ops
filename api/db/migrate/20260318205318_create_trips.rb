class CreateTrips < ActiveRecord::Migration[8.0]
  def change
    create_table :trips, id: :uuid do |t|
      t.references :vehicle, null: false, foreign_key: true, type: :uuid
      t.string :trip_number
      t.string :origin
      t.string :destination
      t.integer :distance_miles
      t.integer :cargo_weight_lbs
      t.datetime :departure_at
      t.datetime :return_at
      t.string :status
      t.decimal :energy_consumed_kwh
      t.jsonb :route_waypoints

      t.timestamps
    end

    add_index :trips, :trip_number, unique: true
    add_index :trips, [:vehicle_id, :status]
  end
end
