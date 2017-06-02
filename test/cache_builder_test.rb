require 'aspire/util'

require_relative 'test_helper'

# Tests the Aspire::Caching::Builder class
class CacheBuilderTest < CacheTestBase
  include Aspire::Util

  def setup
    super
    cache = Aspire::Caching::Cache.new(@ld_api, @json_api, logger: @logger)
    @builder = Aspire::Caching::Builder.new(cache, clear: true, logger: @logger)
  end

  def test_write
    @builder.write(@list_url1)
    # @builder.write(@list_url2)
  end

  # def test_enum
  #   json_o1 = json('o1')
  #   json_o2 = json('o2')
  #   json_a = "[#{json_o1},#{json_o2}]"
  #   json_a2 = '[1,[21,22,23,[241,242,243],25,[261,[2621,2622,2623],263]],3]'
  #   o1 = JSON.parse(json_o1)
  #   a = JSON.parse(json_a)
  #   a2 = JSON.parse(json_a2)
  #   hooks = {
  #     pre_array: proc { |key, value, yielder, index| puts("New array"); true },
  #     post_array: proc { |key, value, yielder, index| puts("End of array"); true },
  #     pre_hash: proc { |value, yielder, index| puts("New hash"); true },
  #     post_hash: proc { |value, yielder, index| puts("End of hash"); true },
  #     pre_yield: proc { |key, value, yielder, index| puts("#{key}=#{value}"); true },
  #     post_yield: proc { |key, value, yielder, index| puts "Done!"; true }
  #   }
  #   e = json_enumerator('a2', a2, **hooks)
  #   e.each do |key, value, index|
  #     puts("#{key}#{index.nil? ? '' : '[' + index.to_s + ']'} = #{value}")
  #   end
  # end
  #
  # def json(name)
  #   '{' \
  #     '"name": "' + name + '",' \
  #     '"type": "Array",' \
  #     '"values": [' \
  #       '1,2,' \
  #       '{"nested": true, "type": "Gubbins", "name": "Dave"},' \
  #       '["nested1", "nested2", "nested3"]' \
  #      ']' \
  #   '}'
  # end
end