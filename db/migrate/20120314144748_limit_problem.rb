class LimitProblem < ActiveRecord::Migration
  def self.up
    remove_column :taxons, :excluded
    add_column :taxons, :excluded, :string, :default => 'F'
  end

  def self.down
    remove_column :taxons, :excluded
    add_column :taxons, :excluded, :string, :default => 'F', :limit  => 1     
  end
end
