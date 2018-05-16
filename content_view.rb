require './database'

class ContentView < ActiveRecord::Base
  belongs_to :news
  belongs_to :users
end
