class AddSelection < ActiveRecord::Migration
  def self.up
    add_column :roguenaroks, :ispruning, :boolean, :default => false 
  end

  def self.down
    remove_column  :roguenaroks, :ispruning
  end
end
