require 'aspire/enumerator/list_report_enumerator'
require 'aspire/util'

require_relative 'test_helper'

# Tests the Aspire::Caching::Builder class
class CacheBuilderTest < CacheTestBase
  include Aspire::Util

  def setup
    super
    cache = Aspire::Caching::Cache.new(@ld_api, @json_api, @cache_path,
                                       logger: @logger)
    @builder = Aspire::Caching::Builder.new(cache)
  end

  def test_build
    lists = list_enumerator('2016-17', '2015-16')
    @builder.build(lists, clear: true)
  end

  # def test_resume
  #   lists = list_enumerator('2016-17', '2015-16')
  #   @builder.resume(lists)
  # end

  # def test_write
  #   @builder.write_list(@list_url3)
  #   # @builder.write(@list_url2)
  # end

  private

  def list_enumerator(*time_periods)
    filters = [
      proc { |row| time_periods.include?(row['Time Period']) },
      proc { |row| !row['Status'].to_s.start_with?('Published') },
      proc { |row| row['Privacy Control'] == 'Public' }
    ]
    Aspire::Enumerator::ListReportEnumerator.new(@list_report, filters)
                                            .enumerator
  end
end