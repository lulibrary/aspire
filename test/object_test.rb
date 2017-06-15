require_relative 'test_helper'

require 'aspire/caching'
require 'aspire/object'
require 'aspire/user_lookup'

# Tests the Aspire reading list object classes
class ObjectTest < CacheTestBase
  def setup
    super
    @cache = Aspire::Caching::Cache.new(@ld_api, @json_api, @cache_path)
    @user_lookup = user_lookup
    @factory = Aspire::Object::Factory.new(@cache, @user_lookup)
  end

  def test_list
    list = @factory.get(@list_url1)
    puts list
  end
end