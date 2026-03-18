class CreateChargingEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :charging_events, id: :uuid do |t|
      t.references :vehicle, null: false, foreign_key: true, type: :uuid
      t.references :trip, null: true, foreign_key: true, type: :uuid
      t.string :location_type
      t.string :station_name
      t.decimal :latitude
      t.decimal :longitude
      t.decimal :energy_added_kwh
      t.decimal :charge_rate_kw
      t.integer :duration_minutes
      t.decimal :cost
      t.datetime :charged_at

      t.timestamps
    end
  end
end
