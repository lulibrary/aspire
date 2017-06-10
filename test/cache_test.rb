require 'logger'

require 'aspire/caching'
require 'aspire/caching/cache_logger'

require_relative 'test_helper'

# Tests the Cache class
# class CacheTest < CacheTestBase
#   def test_create
#     path = '/tmp/aspire_cache'
#     @cache = Aspire::Caching::Cache.new(@ld_api, @json_api, path,
#                                         logger: @logger, mode: @mode)
#     check_cache
#   end
#
#   def test_create_defaults
#     @cache = Aspire::Caching::Cache.new(@ld_api, @json_api, logger: @logger)
#     check_cache
#   end
#
#   def test_create_default_path
#     @cache = Aspire::Caching::Cache.new(@ld_api, @json_api,
#                                         logger: @logger, mode: @mode)
#     check_cache
#   end
#
#   def test_create_default_mode
#     path = '/tmp/aspire_cache'
#     @cache = Aspire::Caching::Cache.new(@ld_api, @json_api, path,
#                                         logger: @logger)
#     check_cache
#   end
#
#   def test_delete_cache
#     @cache = Aspire::Caching::Cache.new(@ld_api, @json_api, logger: @logger)
#     delete_cache
#   end
#
#   def test_read
#     @cache = Aspire::Caching::Cache.new(@ld_api, @json_api, logger: @logger)
#     _data = @cache.read(@list_url1)
#     _data_json = @cache.read(@list_url1, json: true)
#     refute @cache.empty?
#     _data = @cache.read(@list_url2)
#     _data_json = @cache.read(@list_url2, json: true)
#     refute @cache.empty?
#   end
#
#   # def test_remove
#   #   test_read
#   #   @cache.remove(@list_url1)
#   #   refute @cache.empty?
#   #   @cache.remove(@list_url2)
#   #   assert @cache.empty?
#   # end
# end

# Tests the CacheEntry class
class CacheEntryTest < CacheTestBase
  include Aspire::Caching::Exceptions

  def setup
    super
    @cache = Aspire::Caching::Cache.new(@ld_api, @json_api,
                                        logger: @logger, clear: false)
  end

  def test_list
    path_parent = 'lists/12345'
    path_child = "#{path_parent}/child/abcd"
    filename_child = File.join(@cache.path, "#{path_child}.json")
    filename_parent = File.join(@cache.path, "#{path_parent}.json")
    filename_parent_json = File.join(@cache.path, "#{path_parent}-json.json")
    url_child = @ld_api.api_url(path_child)
    url_parent = @ld_api.api_url(path_parent)
    child = cache_entry(path: path_child)
    parent = cache_entry(path: path_parent)
    # Test child_of?
    child_of(url_parent, parent, url_child, child)
    # The entries should not be cached
    cached(parent, false)
    # Test filenames
    filenames(filename_parent, filename_parent_json, parent)
    filenames(filename_child, nil, child)
    # Test JSON-API availability
    assert parent.json?
    refute child.json?
  end

  def test_invalid
    # TODO: Invalid object types should be detected
    # cache_entry(path: 'notanobject/12345', cacheable: false)
    cache_entry(url: 'http://www.google.com', cacheable: false)
    cache_entry(path: ':not:a:valid:url', cacheable: false)
    cache_entry(url: ':not:a:valid:url', cacheable: false)
  end

  private

  def cache_entry(path: nil, url: nil, cacheable: true)
    url ||= @ld_api.api_url(path)
    if cacheable
      Aspire::Caching::CacheEntry.new(url, @cache)
    else
      assert_raises(NotCacheable) do
        Aspire::Caching::CacheEntry.new(url, @cache)
      end
    end
  end

  def cached(entry, expect_cached = true)
    assert_equal expect_cached, entry.cached?(false)
    assert_equal expect_cached, entry.cached?(true)
  end

  def child_of(url_parent, parent, url_child, child)
    # An entry is non-strictly a child of itself
    assert parent.child_of?(url_parent, strict: false)
    assert parent.child_of?(parent, strict: false)
    # An entry is not strictly a child of itself
    refute parent.child_of?(url_parent, strict: true)
    refute parent.child_of?(parent, strict: true)
    # A parent is non-strictly a child of its child - only the parent objects
    # are compared
    assert parent.child_of?(url_child, strict: false)
    assert parent.child_of?(child, strict: false)
    # A parent is not strictly a child of its child
    refute parent.child_of?(url_child, strict: true)
    refute parent.child_of?(child, strict: true)
    # A child is a child of its parent
    assert child.child_of?(url_parent, strict: false)
    assert child.child_of?(url_parent, strict: true)
    assert child.child_of?(parent, strict: false)
    assert child.child_of?(parent, strict: true)
  end

  def filenames(ld, json, entry)
    assert_equal ld, entry.file
    if json.nil?
      assert_nil entry.json_file
    else
      assert_equal json, entry.json_file
    end
  end
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
