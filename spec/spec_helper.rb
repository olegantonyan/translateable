$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'translateable'
require 'active_record'
require 'action_controller'
require 'action_view'

begin
  ActiveSupport::JSON.decode('{}')
rescue ArgumentError
  # json 3.0 compat for unreleased Rails, backport of rails/rails@cc07aa3153
  ActiveSupport::JSON.singleton_class.prepend(Module.new do
    def decode(json, options = {})
      data = ::JSON.parse(json, **options)
      ActiveSupport.parse_json_times ? convert_dates_from(data) : data
    end
  end)
end

DB_CONFIG = {
  adapter: 'postgresql',
  username: 'postgres',
  password: ENV['POSTGRES_PASSWORD'],
  port: ENV['POSTGRES_PORT'],
  host: ENV['POSTGRES_HOST'] || 'localhost'
}.freeze

def prepare_database!
  db = 'translateable_test_db'

  ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: 'template1'))
  ActiveRecord::Base.connection.drop_database(db)
  ActiveRecord::Base.connection.create_database(db)

  ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: db))
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Base.connection.create_table :test_models do |t|
    t.jsonb :title
    t.jsonb :body
  end
end

prepare_database!

I18n.available_locales = %i(en ru de it pt-BR)
I18n.default_locale = :en

class TestModel < ActiveRecord::Base
  include Translateable

  translateable :title, :body
end

RSpec.configure do |config|
  config.order = :random

  config.around do |example|
    I18n.with_locale(:en) { example.run }
  end
end
