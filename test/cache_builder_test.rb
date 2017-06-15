require 'byebug'
require 'logglier'
require 'raven'

require 'aspire/enumerator/report_enumerator'
require 'aspire/util'

require_relative 'test_helper'

Raven.configure do |config|
  config.dsn = ENV['SENTRY_DSN']
end

# Tests the Aspire::Caching::Builder class
class CacheBuilderTest < CacheTestBase
  include Aspire::Util

  def setup
    super
    cache = Aspire::Caching::Cache.new(@ld_api, @json_api, @cache_path,
                                       logger: @logger)
    @builder = Aspire::Caching::Builder.new(cache)
  end

  # def test_build
  #   lists = list_enumerator('2016-17', '2015-16')
  #   @builder.build(lists, clear: true)
  # end

  # def test_resume
  #   lists = list_enumerator('2016-17', '2015-16')
  #   @builder.resume(lists)
  # end

  # def test_write
  #   @builder.write_list(@list_url3)
  #   # @builder.write(@list_url2)
  # end

  # def test_section
  #   @builder.write('http://lancaster.myreadinglists.org/sections/34C1190E-F50E-35CB-94C9-F476963D69C0')
  # end

  def test_list
    @builder.write_list('http://lancaster.myreadinglists.org/lists/A56880F3-10B3-45EC-FD16-D29D0198AEE3')
  end

  private

  def list_enumerator(*time_periods)
    filters = [
      proc { |row| time_periods.include?(row['Time Period']) },
      proc { |row| !row['Status'].to_s.start_with?('Published') },
      proc { |row| row['Privacy Control'] == 'Public' }
    ]
    Aspire::Enumerator::ReportEnumerator.new(@list_report, filters)
                                            .enumerator
  end
end