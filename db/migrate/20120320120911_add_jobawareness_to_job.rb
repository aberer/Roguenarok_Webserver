class AddJobawarenessToJob < ActiveRecord::Migration
  def self.up
    add_column :roguenaroks, :filetoparse, :string 
    add_column :roguenaroks, :searchname, :string 
    add_column :roguenaroks, :modes, :string
  end

  def self.down
    remove_column :roguenaroks, :filetoparse
    remove_column :roguenaroks, :searchname
    remove_column :roguenaroks, :modes
  end
end
