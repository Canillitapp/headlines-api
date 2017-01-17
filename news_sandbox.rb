require './news'

date_begin = Date.new(2016, 12, 1).to_time.to_i
date_end = Date.new(2016, 12, 2).to_time.to_i

result = News
  .where('date > ?', date_begin)
  .where('date < ?', date_end)
  .order('date DESC')

result.each do |i|
  puts "#{Time.at(i.date)} - #{i.title}"
end
