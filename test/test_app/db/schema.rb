ActiveRecord::Schema.define(version: 2020_05_08_150547) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "hstore"
  enable_extension "pg_stat_statements"
  enable_extension "plpgsql"

  create_table "users", id: :integer, force: :cascade do |t|
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "role"
  end

  create_table "groups", id: :integer, force: :cascade do |t|
    t.string "name"
  end

  create_table "groups_users" do |t|
    t.bigint "user_id"
    t.bigint "group_id"
  end

  create_table "vehicles", id: :integer, force: :cascade do |t|
    t.string "make"
    t.string "model"
    t.bigint "user_id"
    t.string "type"
  end

  create_table "parts", id: :integer, force: :cascade do |t|
    t.string "name"
    t.bigint "partable_id"
    t.string "partable_type"
    t.index ["partable_type", "partable_id"], name: "index_parts_on_partable_type_and_partable_id"
  end

  create_table "brands_parts" do |t|
    t.bigint "brand_id"
    t.bigint "part_id"
  end

  create_table "brands", id: :integer, force: :cascade do |t|
    t.string "name"
  end
end