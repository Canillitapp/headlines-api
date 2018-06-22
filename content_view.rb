require './database'

class ContentView < ActiveRecord::Base
  belongs_to :news, counter_cache: true
  belongs_to :users
end
