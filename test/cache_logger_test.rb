require 'logger'

require 'aspire/caching/cache_logger'
require 'aspire/caching/exceptions'

require_relative 'test_helper'

# Tests the CacheLogger class
class CacheLoggerTest < Test
  include Aspire::Caching::Exceptions

  def setup
    @logger = Logger.new(STDOUT)
    @cache_logger = Aspire::Caching::CacheLogger.new(@logger)
  end

  def test_methods
    @cache_logger.log(Logger::WARN, 'Warning from CacheLogger#log')
    assert_equal 123, \
                 @cache_logger.log_return(123, Logger::INFO,
                                          'Info from CacheLogger#log_result')
    assert_raises(Error) { @cache_logger.log_exception('Default exception') }
    assert_raises(ReadError) do
      @cache_logger.log_exception('Read error', ReadError)
    end
  end

  def test_delegated_methods
    @cache_logger.add(Logger::DEBUG, 'This is debugging from Logger#add')
    @cache_logger.debug('This is debugging')
    @cache_logger.error('This is an error')
    @cache_logger.fatal('This is fatal')
    @cache_logger.info('This is informational')
    @cache_logger.log(Logger::INFO, 'This is informational from Logger#log')
    @cache_logger.unknown('This is unknown')
    @cache_logger.warn('This is a warning')
  end

  def test_unknown_methods
    assert_raises(NoMethodError) { @cache_logger.notamethod }
  end
end