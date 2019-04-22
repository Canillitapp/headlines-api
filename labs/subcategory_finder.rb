require File.expand_path(File.dirname(__FILE__) + '/../news.rb')
require File.expand_path(File.dirname(__FILE__) + '/../subject.rb')

days = [
  '2019-04-21',
  '2019-04-20',
  '2019-04-19',
  '2019-04-18',
  '2019-04-17',
  '2019-04-16',
  '2019-04-15',
  '2019-04-14',
  '2019-04-13',
  '2019-04-12',
  '2019-04-11',
  '2019-04-10',
  '2019-04-09',
]

subjects_to_upload = []

days.each do |day|
  puts day
  subjects = []

  result = News.trending(day, 12)

  result['news'].each do |k, news|
    s = Subject.new(k)

    news.each do |i|
      s.analyse_title(i['title'])
    end
    subjects << s
  end

  subjects.each do |s|
    possible_subjects = s.possible_subjects.select { |i| i[1] > 0.3 && i[0].split(' ').count > 1 }
    possible_subjects.each { |i| subjects_to_upload << i[0] }
  end
end

subjects_to_upload.uniq.sort.each { |i| puts i }
