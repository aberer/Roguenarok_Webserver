class AddDropset < ActiveRecord::Migration
  def self.up
    add_column :taxons, :dropset , :integer , :null => false, :default => 1 
  end

  def self.down
    remove_column :taxons, :dropset
  end
end
