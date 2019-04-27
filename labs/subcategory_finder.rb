require File.expand_path(File.dirname(__FILE__) + '/../news.rb')
require File.expand_path(File.dirname(__FILE__) + '/../subject.rb')

def subjects_from_day(date)
  tmp = []

  result = News.trending(date, 12)

  result['news'].each do |k, news|
    s = Subject.new(k)

    news.each do |i|
      s.analyse_title(i['title'])
    end
    tmp << s
  end

  tmp
end

start_date = Date.strptime('2018-01-01', '%Y-%m-%d')
end_date = Date.today
date = start_date

subjects_to_upload = []

while date <= end_date
  puts date
  subjects = subjects_from_day(date)

  subjects.each do |s|
    possible_subjects = s.possible_subjects.select { |i| i[1] > 0.3 && i[0].split(' ').count > 1 }
    possible_subjects.each { |i| subjects_to_upload << i[0] }
  end

  date += 1
end

subjects_to_upload.uniq.sort.each { |i| puts i }
