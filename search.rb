require './database'

class Search < ActiveRecord::Base
  belongs_to :users
end
