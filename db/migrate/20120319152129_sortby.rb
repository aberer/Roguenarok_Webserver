class Sortby < ActiveRecord::Migration
  def self.up
    add_column :roguenaroks, :sortedby, :integer
  end

  def self.down
    remove_column :roguenaroks, :sortedby
  end
end
