require './database'

class Source < ActiveRecord::Base
  has_many :news
end
