class CorrectTaxon < ActiveRecord::Migration
  def self.up
    remove_column :taxons, :score
    add_column :taxons, :score, :float , :scale => 3 , :precision => 10 
  end

  def self.down
    remove_column :taxons, :score    
    add_column :taxons, :score, :decimal
  end
end
