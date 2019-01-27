require File.expand_path(File.dirname(__FILE__) + '/../news.rb')
require File.expand_path(File.dirname(__FILE__) + '/../tag.rb')

regex = /.+[0-9]+\sde\s(Enero|Febrero|Marzo|Abril|Mayo|Junio|Julio|Agosto|Septiembre|Octubre|Noviembre|Diciembre)\sde\s[0-9]+/i

News.all.each do |i|
  if match = i.title.match(regex)
    puts "#{i.source_name} - #{i.title}"
  end
end
