require 'test/unit'
require 'rails'
require 'active_support'
require 'active_record'
require 'memcache'
require 'model_cached'

ActiveRecord::Base.establish_connection({
  :adapter  => 'sqlite3',
  :database => ':memory:'
})

ActiveRecord::Schema.define do
  create_table :accounts do |t|
    t.string  :name
    t.timestamps
  end

  create_table :users do |t|
    t.string  :email
    t.integer :account_id
    t.boolean :deleted
    t.timestamps
  end
end

class Account < ActiveRecord::Base
  has_many :users
end

class User < ActiveRecord::Base; end

RAILS_CACHE = ActiveSupport::Cache.lookup_store(:mem_cache_store)
