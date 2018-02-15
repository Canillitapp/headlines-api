require './database'
require './category'

class Source < ActiveRecord::Base
  has_many :news
  belongs_to :category
  delegate :name, :to => :category, :prefix => true, :allow_nil => true
end
