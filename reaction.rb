require './database'
require 'rumoji'

class Reaction < ActiveRecord::Base
  has_one :news
  has_one :user

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

  def self.react(news_id:, user_id:, reaction:)
    r = Reaction.where(
      news_id: news_id,
      user_id: user_id,
      reaction: reaction
    )

    if r.empty?
      Reaction.create(
        reaction: reaction,
        news_id: news_id,
        user_id: user_id
      )
    else
      Reaction.where(
        news_id: news_id,
        user_id: user_id,
        reaction: reaction
      ).delete_all
    end
  end
end
