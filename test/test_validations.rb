require "test/unit"
require File.expand_path(File.dirname(__FILE__) + '/../validations.rb')

class TestValidations < Test::Unit::TestCase
    def test_integer
        assert Validations.is_integer('1')
        assert Validations.is_integer('100')
        assert Validations.is_integer('') == false
        assert Validations.is_integer('100a') == false
    end

    def test_valid_trending_date
        assert Validations.is_valid_trending_date('1985-01-17')
        assert Validations.is_valid_trending_date('2050-01-31')

        # inverted day / month
        assert Validations.is_valid_trending_date('2050-31-01') == false

        # no month has 32 days
        assert Validations.is_valid_trending_date('2050-01-32') == false

        # there's no thirteenth month
        assert Validations.is_valid_trending_date('2050-13-03') == false

        # 2020 is a leap year...
        assert Validations.is_valid_trending_date('2020-02-29')

        # ... but 2019 is not
        assert Validations.is_valid_trending_date('2019-02-29') == false
    end
end
