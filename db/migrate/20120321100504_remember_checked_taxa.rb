class RememberCheckedTaxa < ActiveRecord::Migration
  def self.up
    add_column :taxons, :isChecked, :boolean, :default => false  
  end

  def self.down
    remove_column :taxons, :isChecked
  end
end
