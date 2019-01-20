require File.expand_path(File.dirname(__FILE__) + '/../news.rb')
require File.expand_path(File.dirname(__FILE__) + '/../tag.rb')

regex = /.+[0-9]+\sde\s(\bEnero\b|\bFebrero\b|\bMarzo\b|\bAbril\b|\bMayo\b|\bJunio\b|\bJulio\b|\bAgosto\b|\bSeptiembre\b|\bOctubre\b|\bNoviembre\b|\bDiciembre\b)\sde\s[0-9]+/i

News.all.each do |i|
  if match = i.title.match(regex)
    puts "#{i.source_name} - #{i.title}"
  end
end
