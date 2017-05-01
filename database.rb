require 'active_record'

# Uncomment this if you want to log some database issue
# ActiveRecord::Base.logger = Logger.new(File.open('database.log', 'w'))

# SQLITE development db
# ActiveRecord::Base.establish_connection(
#   :adapter  => 'sqlite3',
#   :database => 'news.db',
#   :pool => 30
# )

# MySQL production db
ActiveRecord::Base.establish_connection(
  adapter: 'mysql2',
  host: 'localhost',
  username: 'root',
  password: '',
  database: 'canillitapp'
)
