class CreateServiceCenters < ActiveRecord::Migration[8.0]
  def change
    create_table :service_centers, id: :uuid do |t|
      t.string :name
      t.string :address
      t.string :city
      t.string :contact_email
      t.decimal :latitude
      t.decimal :longitude
      t.jsonb :capabilities
      t.boolean :is_partner
      t.boolean :ev_certified

      t.timestamps
    end
  end
end
