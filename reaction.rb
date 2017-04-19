require './database'
require 'rumoji'

class Reaction < ActiveRecord::Base
  belongs_to :news
  belongs_to :user

  def self.raw_reactions_by_news_id(news_id)
    Reaction.reactions_by_news_id(news_id).map do |k, v|
      {
        'reaction' => Rumoji.decode(k),
        'amount' => v
      }
    end
  end

  def self.reactions_by_news_id(news_id)
    Reaction.where("news_id = #{news_id}").group(:reaction).count
  end
end
