class CreateTaxons < ActiveRecord::Migration
  def self.up
    create_table :taxons do |t|
      t.integer :roguenarok_id, :dropset
      t.string :name, :strict, :mr, :mre, :userdef, :bipart, :lsi_dif, :lsi_ent, :lsi_max, :tii
      t.string :support, :n_bipart, :limit => 1
      t.string :excluded, :default => 'F' , :limit => 1
      t.timestamps
    end
  end

  def self.down
    drop_table :taxons
  end
end
