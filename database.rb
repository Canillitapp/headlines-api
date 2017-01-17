require 'active_record'

# Uncomment this if you want to log some database issue
# ActiveRecord::Base.logger = Logger.new(File.open('database.log', 'w'))

ActiveRecord::Base.establish_connection(
  :adapter  => 'sqlite3',
  :database => 'news.db'
)
