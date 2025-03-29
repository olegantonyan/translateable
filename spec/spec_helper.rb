$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'translateable'
require 'active_record'

def prepare_database!
  db = 'translateable_test_db'.freeze

  ActiveRecord::Base.establish_connection(adapter: 'postgresql', database: 'template1', username: 'postgres', password: ENV['POSTGRES_PASSWORD'], port: ENV['POSTGRES_PORT'])

  begin
    ActiveRecord::Base.connection.drop_database(db)
  rescue ActiveRecord::StatementInvalid
  end
  ActiveRecord::Base.connection.create_database(db)

  ActiveRecord::Base.establish_connection(adapter: 'postgresql', database: db, username: 'postgres', password: ENV['POSTGRES_PASSWORD'], port: ENV['POSTGRES_PORT'])

  begin
    ActiveRecord::Base.connection.drop_table :test_models
  rescue ActiveRecord::StatementInvalid
  end

  migrate!
end

def migrate!
  ActiveRecord::Base.connection.create_table :test_models do |t|
    t.jsonb :title
    t.string :description
  end
end

class TestModel < ActiveRecord::Base
  prepare_database!

  include Translateable

  translateable :title
end
