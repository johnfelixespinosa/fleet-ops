class CreateVehicles < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pgcrypto"

    create_table :vehicles, id: :uuid do |t|
      t.string :unit_number, null: false
      t.string :make
      t.string :model
      t.integer :year
      t.decimal :battery_capacity_kwh
      t.integer :range_miles
      t.integer :current_mileage
      t.decimal :battery_health_percent
      t.integer :next_maintenance_due_mileage
      t.string :next_maintenance_type
      t.date :last_maintenance_date
      t.date :annual_inspection_due
      t.boolean :daily_inspection_current
      t.string :status, null: false

      t.timestamps
    end

    add_index :vehicles, :unit_number, unique: true
    add_index :vehicles, :status
  end
end
