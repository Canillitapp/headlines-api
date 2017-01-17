require './database'
require './source'

class News < ActiveRecord::Base
  belongs_to :source
end
