require 'active_record'
require 'sinatra'
require 'sinatra/config_file'

config_file 'config/config.yml.erb'

if settings.db_adapter == 'sqlite3'
  ActiveRecord::Base.establish_connection(
    adapter: settings.db_adapter,
    database: settings.db_database,
    pool: 30
  )
else
  ActiveRecord::Base.establish_connection(
    adapter: settings.db_adapter,
    host: settings.db_host,
    username: settings.db_username,
    password: settings.db_password,
    database: settings.db_database,
    pool: 100
  )
end

# Uncomment this if you want to log some database issue
# ActiveRecord::Base.logger = Logger.new(File.open('database.log', 'w'))
