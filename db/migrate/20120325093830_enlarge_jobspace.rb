class EnlargeJobspace < ActiveRecord::Migration
  def self.up
    change_column :taxons, :roguenarok_id, :string 
    change_column :lsi_analyses, :jobid, :string,  :limit => nil 
    change_column :prunings, :jobid, :string,  :limit => nil 
    change_column :roguenaroks, :jobid, :string,  :limit => nil 
  end

  def self.down
    change_column :taxons, :roguenarok_id, :integer
    change_column :lsi_analyses, :jobid, :string,  :limit => 9 
    change_column :prunings, :jobid, :string , :limit => 9 
    change_column :roguenaroks, :jobid, :string, :limit => 9 
  end
end
