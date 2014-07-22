# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120325093830) do

  create_table "excluded_taxons", :force => true do |t|
    t.integer  "taxon_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "lsi_analyses", :force => true do |t|
    t.string   "jobid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "prunings", :force => true do |t|
    t.string   "jobid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "rogue_taxa_analyses", :force => true do |t|
    t.integer  "jobid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "roguenaroks", :force => true do |t|
    t.integer  "user_id"
    t.string   "jobid"
    t.string   "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "sortedby"
    t.string   "filetoparse"
    t.string   "searchname"
    t.string   "modes"
    t.boolean  "ispruning",    :default => false
    t.string   "display_path"
  end

  create_table "searches", :force => true do |t|
    t.string   "jobid"
    t.string   "filename"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "taxons", :force => true do |t|
    t.string   "roguenarok_id"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "search_id"
    t.integer  "pos"
    t.integer  "dropset",       :default => 1,     :null => false
    t.float    "score"
    t.string   "excluded",      :default => "F"
    t.boolean  "isChecked",     :default => false
  end

  create_table "tii_analyses", :force => true do |t|
    t.string   "jobid"
    t.string   "limit"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "email"
    t.string   "ip"
    t.integer  "saved_subs"
    t.integer  "all_subs"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
