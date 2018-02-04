require './database'
require './category'

class Source < ActiveRecord::Base
  has_many :news
  belongs_to :category
end
