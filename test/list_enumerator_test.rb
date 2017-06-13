require 'aspire/enumerator/report_enumerator'

require_relative 'test_helper'

# Tests the ListReportEnumerator class
class ListReportEnumeratorTest < Test
  def setup
    @file = ENV['ASPIRE_LIST_REPORT']
    @filters = []
  end

  # def test_filters
  #   expected_rows = ENV['ASPIRE_LIST_REPORT_ROWS_2015_17'].to_i
  #   filters = [
  #     proc { |row| %w[2015-16 2016-17].include?(row['Time Period']) }
  #   ]
  #   rows = 0
  #   enum(@file, filters).each do |row|
  #     rows += 1
  #     assert_includes(%w[2015-16 2016-17], row['Time Period'])
  #   end
  #   assert_equal expected_rows, rows
  # end

  def test_multiple_filters
    status = ['Published', 'Published with Unpublished Changes']
    time_period = %w[2015-16 2016-17]
    filters = [
      proc { |row| time_period.include?(row['Time Period']) },
      proc { |row| row['Status'].to_s.start_with?('Published') },
      proc { |row| row['Privacy Control'] == 'Public' }
    ]
    expected_rows = 2471
    rows = 0
    enum(@file, filters).each do |row|
      rows += 1
      assert_includes(time_period, row['Time Period'])
      assert_includes(status, row['Status'])
      assert_equal 'Public', row['Privacy Control']
    end
    assert_equal expected_rows, rows
    puts "#{rows} rows"
  end

  private

  def enum(file, filters)
    Aspire::Enumerator::ReportEnumerator.new(file, filters).enumerator
  end
end