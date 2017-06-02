require 'logger'

require 'aspire/caching'
require 'aspire/caching/cache_logger'

require_relative 'test_helper'

# Tests the Cache class
class CacheTest < CacheTestBase

  def test_create
    path = '/tmp/aspire_cache'
    @cache = Aspire::Caching::Cache.new(@ld_api, @json_api, path,
                                        logger: @logger, mode: @mode)
    check_cache
  end

  def test_create_defaults
    @cache = Aspire::Caching::Cache.new(@ld_api, @json_api, logger: @logger)
    check_cache
  end

  def test_create_default_path
    @cache = Aspire::Caching::Cache.new(@ld_api, @json_api,
                                        logger: @logger, mode: @mode)
    check_cache
  end

  def test_create_default_mode
    path = '/tmp/aspire_cache'
    @cache = Aspire::Caching::Cache.new(@ld_api, @json_api, path,
                                        logger: @logger)
    check_cache
  end

  def test_delete_cache
    @cache = Aspire::Caching::Cache.new(@ld_api, @json_api, logger: @logger)
    delete_cache
  end

  def test_read
    @cache = Aspire::Caching::Cache.new(@ld_api, @json_api, logger: @logger)
    _data = @cache.read(@list_url1)
    _data_json = @cache.read(@list_url1, json: true)
    refute @cache.empty?
    _data = @cache.read(@list_url2)
    _data_json = @cache.read(@list_url2, json: true)
    refute @cache.empty?
  end

  # def test_remove
  #   test_read
  #   @cache.remove(@list_url1)
  #   refute @cache.empty?
  #   @cache.remove(@list_url2)
  #   assert @cache.empty?
  # end
end

# class CacheBuilderTest < Test
#   def test_new_cache
#     # Build the caching
#     caching = Aspire::Cache.new(@api, @cache_root,
#                                 clear: true, logger: @logger)
#     @logger.info("Started")
#     start = Time.new
#     caching.write(@list_url)
#     elapsed = Time.new - start
#     @logger.info('Finished after %2.2d:%2.2d' % [elapsed / 60, elapsed % 60])
#   end
#
#   def load_environment
#     super
#     @cache_root = ENV['ASPIRE_CACHE_ROOT']
#     @list_url = ENV['ASPIRE_LIST_URL']
#     formatter = proc do |severity, datetime, progname, message|
#       "#{datetime} [#{severity}]: #{message}\n"
#     end
#     @logger = Logger.new(STDERR,
#                          datetime_format: '%Y-%m-%d %H:%M:%S',
#                          formatter: formatter)
#     [@cache_root, @list_url].each do |e|
#       refute_nil e
#       refute_empty e
#     end
#   end
# end

