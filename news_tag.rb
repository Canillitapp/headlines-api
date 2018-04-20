require './database'
require './news'
require './tag'

class NewsTag < ActiveRecord::Base
  belongs_to :news
  belongs_to :tag
end
