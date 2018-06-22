require './database'
require 'rumoji'

class Reaction < ActiveRecord::Base
  belongs_to :news, counter_cache: true
  belongs_to :user

  def self.raw_reactions_by_news_id(news_id)
    reactions = Reaction.reactions_by_news_id(news_id)

    reactions.count.map do |k, v|
      {
        'reaction' => Rumoji.decode(k),
        'amount' => v,
        'date' => reactions.minimum(:date).select { |r| r == k }[k]
      }
    end
  end

  def self.reactions_by_news_id(news_id)
    Reaction.where("news_id = #{news_id}").group(:reaction)
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
        user_id: user_id,
        date: DateTime.now.strftime('%s')
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
