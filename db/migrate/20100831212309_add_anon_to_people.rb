class AddAnonToPeople < ActiveRecord::Migration
  def self.up
    add_column :people, :anonymous, :boolean
  end

  def self.down
    remove_column :people, :anonymous
  end
end
