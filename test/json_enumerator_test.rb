require 'aspire/enumerator/json_enumerator'

require_relative 'test_helper'

# Tests the JSONEnumerator class
class JSONEnumeratorTest < Test
  def setup
    @hooks = {
      before_array: proc do |__key, _value, _index|
        print('[')
        true
      end,
      after_array: proc do |_key, _value, _index|
        print('], ')
        true
      end,
      before_hash: proc do |_key, _value, _index|
        print('{')
        true
      end,
      after_hash: proc do |_key, _value, _index|
        print('}, ')
        true
      end,
      before_yield: proc do |_key, _value, _index|
        print(' ')
        true
      end,
      after_yield: proc do |_key, _value, _index|
        print(',')
        true
      end
    }
  end

  def test_array_of_objects
    puts 'Object array'
    a = JSON.parse("[#{obj('o1')},#{obj('o2')}]")
    enumerate(a)
  end

  def test_nested_array
    puts 'Nested array'
    a = JSON.parse('[1,[21,22,[231,232,233],24,[251,[2521,2522,2523],253]],3]')
    enumerate(a)
  end

  def test_object
    puts 'Object'
    o1 = JSON.parse(obj('o1'))
    enumerate(o1)
  end

  private

  def enumerate(data, e = nil)
    e ||= Aspire::Enumerator::JSONEnumerator.new(**@hooks).enumerator(nil, data)
    e.each do |key, value, index|
      print("#{key}#{index.nil? ? '' : '[' + index.to_s + ']'}: #{value}")
    end
    puts "\n\n"
  end

  def obj(name)
    '{' \
      '"name": "' + name + '",' \
      '"type": "Array",' \
      '"values": [' \
        '1,2,' \
        '{"nested": true, "type": "Gubbins", "name": "Dave"},' \
        '["nested1", "nested2", "nested3"]' \
       ']' \
    '}'
  end
end