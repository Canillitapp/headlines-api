require 'date'

class Validations
    IntRegex = /^\d+$/
    def self.is_valid_trending_date(date)
        begin
            Date.strptime(date, '%Y-%m-%d')
            return true
        rescue ArgumentError
            return false
        end
    end

    def self.is_valid_year_month_date(date)
      begin
          Date.strptime(date, '%Y-%m')
          return true
      rescue ArgumentError
        return false
      end
    end

    def self.is_integer(test)
      return !!test.match(IntRegex)
    end
end
