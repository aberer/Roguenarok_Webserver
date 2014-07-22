class AddDisplayPath < ActiveRecord::Migration
  def self.up
    add_column :roguenaroks, :display_path, :string
  end

  def self.down
    remove_column  :roguenaroks, :display_path
  end
end
