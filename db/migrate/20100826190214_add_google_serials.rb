class AddGoogleSerials < ActiveRecord::Migration
  def self.up
    create_table :google_serials do |t|
      t.integer :person_id
      t.string :serial
      t.timestamps
    end
  end

  def self.down
    drop_table :google_serials
  end
end
