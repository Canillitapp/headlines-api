class Subject
  attr_reader :main_word
  attr_accessor :items_quantity

  def initialize(word)
    @main_word = word
    @leading_words = []
    @trailing_words = []
    @items_quantity = 0.0
    @blacklist = ['a', 'que', 'de', 'la', 'las', 'en', 'una', 'tras', 'y']
  end

  def analyse_title(title)
    words = title.split(' ')
    index_main_word = words.index(@main_word)

    return if index_main_word.nil?

    prev_index = index_main_word - 1
    unless prev_index <= 0 || @blacklist.include?(words[prev_index])
      @leading_words << words[prev_index]
    end

    next_index = index_main_word + 1
    unless next_index > words.length || @blacklist.include?(words[next_index])
      @trailing_words << words[next_index]
    end

    @items_quantity += 1
  end

  def possible_subjects
    tmp = {}
    @leading_words.uniq.each do |i|
      k = "#{i} #{@main_word}".strip
      tmp[k] =  @leading_words.count(i) / @items_quantity
    end

    @trailing_words.uniq.each do |i|
      k = "#{@main_word} #{i}".strip
      tmp[k] = @trailing_words.count(i) / @items_quantity
    end

    tmp.sort_by { |_, v| v }.reverse
  end
end
