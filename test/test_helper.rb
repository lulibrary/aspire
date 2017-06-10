$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'aspire'

require 'dotenv/load'

require 'minitest/autorun'
require 'minitest/reporters'

Minitest::Reporters.use!

# The base class for all test classes
class Test < Minitest::Test
  def setup
    @logger = logger
  end

  private

  def api_opts
    @ssl_ca_file = ENV['SSL_CA_FILE']
    @ssl_ca_path = ENV['SSL_CA_PATH']
    {
      logger: @logger,
      ssl_ca_file: @ssl_ca_file,
      ssl_ca_path: @ssl_ca_path
    }
  end

  def json_api
    @api_client_id = ENV['ASPIRE_API_CLIENT_ID']
    @api_secret = ENV['ASPIRE_API_SECRET']
    @tenant = ENV['ASPIRE_TENANT']
    required(@api_client_id, @api_secret, @tenant)
    Aspire::API::JSON.new(@api_client_id, @api_secret, @tenant,
                          **api_opts)
  end

  def linked_data_api
    @tenant = ENV['ASPIRE_TENANT']
    @tenancy_host_aliases = ENV['ASPIRE_TENANCY_HOST_ALIASES'].to_s.split(';')
    @tenancy_root = ENV['ASPIRE_TENANCY_ROOT']
    required(@tenancy_root, @tenant)
    Aspire::API::LinkedData.new(@tenant,
                                tenancy_host_aliases: @tenancy_host_aliases,
                                tenancy_root: @tenancy_root,
                                **api_opts)
  end

  def logger
    @log_file = ENV['ASPIRE_LOG']
    logger = Logger.new("| tee #{@log_file}") # @log_file || STDOUT)
    logger.datetime_format = '%Y-%m-%d %H:%M:%S'
    logger.formatter = proc do |severity, datetime, _program, msg|
      "#{datetime} [#{severity}]: #{msg}\n"
    end
    logger
  end

  def required(*values)
    values.each do |value|
      refute_nil value
      refute_empty value
    end
  end
end

# The base class for cache test classes
class CacheTestBase < Test
  def setup
    super
    cache_env
    @cache = nil
    @json_api = json_api
    @ld_api = linked_data_api
  end

  def teardown
    @cache.delete if @cache
  end

  private

  def cache_env
    @cache_path = ENV['ASPIRE_CACHE_PATH']
    @list_report = ENV['ASPIRE_LIST_REPORT']
    @list_url1 = ENV['ASPIRE_LIST_URL1']
    @list_url2 = ENV['ASPIRE_LIST_URL2']
    @list_url3 = ENV['ASPIRE_LIST_URL3']
    @mode = ENV['ASPIRE_CACHE_MODE']
    @mode = @mode.nil? || @mode.empty? ? 0o700 : @mode.to_i(8)
    required(@cache_path, @list_url1, @list_url2)
  end

  def check_cache
    assert File.directory?(@cache.path), "Cache path #{@cache.path} not found"
    assert @cache.empty?
    assert @cache.mode, File.stat(@cache.path).mode & 0o777
  end

  def delete_cache
    @cache.delete
    refute File.exist?(@cache.path)
  end
end