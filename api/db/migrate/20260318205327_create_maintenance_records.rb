class CreateMaintenanceRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :maintenance_records, id: :uuid do |t|
      t.references :vehicle, null: false, foreign_key: true, type: :uuid
      t.references :service_center, null: false, foreign_key: true, type: :uuid
      t.string :maintenance_type
      t.text :description
      t.integer :mileage_at_service
      t.decimal :cost
      t.decimal :duration_hours
      t.datetime :completed_at

      t.timestamps
    end
  end
end
