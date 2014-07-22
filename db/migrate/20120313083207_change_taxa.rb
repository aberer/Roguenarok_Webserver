class ChangeTaxa < ActiveRecord::Migration
  def self.up
    remove_column :taxons, :mr
    remove_column :taxons, :mre
    remove_column :taxons, :userdef
    remove_column :taxons, :dropset
    remove_column :taxons, :strict
    remove_column :taxons, :bipart
    remove_column :taxons, :lsi_dif
    remove_column :taxons, :lsi_ent
    remove_column :taxons, :lsi_max
    remove_column :taxons, :tii
    remove_column :taxons, :support
    remove_column :taxons, :n_bipart
    
    add_column :taxons, :search_id, :integer
    add_column :taxons, :pos, :integer
    add_column :taxons, :score, :decimal
  end

  def self.down
    add_column :taxons, :mr
    add_column :taxons, :mre
    add_column :taxons, :userdef
    add_column :taxons, :dropset
    add_column :taxons, :strict
    add_column :taxons, :bipart
    add_column :taxons, :dif
    add_column :taxons, :ent
    add_column :taxons, :max
    add_column :taxons, :tii
    add_column :taxons, :support,   :limit => 1
    add_column :taxons, :n_bipart , :limit => 1 
    
    remove_column :taxons, :search_id
    remove_column :taxons, :pos
    remove_column :taxons, :score
  end
end
