module Aspire
  # Enumerator classes for Aspire reading list processing
  module Enumerator
    # Enumerates over the properties of a JSON data structure
    class JSONEnumerator
      # @!attribute [rw] hooks
      #   @return [Hash] the callback hooks
      attr_accessor :hooks

      # The Enumerator::Yielder instance from an Enumerator.new call
      # @!attribute [rw] yielder
      #   @return [Enumerator::Yielder] the yielder instance from an Enumerator
      attr_accessor :yielder

      # Initialises a new JSONEnumerator instance
      # @param yielder [Enumerator::Yielder] the yielder from an Enumerator
      # @param hooks [Hash] a hash of executable callback hooks:
      #   {
      #     after_array: proc { |key,value,index| }
      #     after_hash: proc { |key,value,index| }
      #     after_yield: proc { |key,value,index| }
      #     before_array: proc { |key,value,index| }
      #     before_hash: proc { |key,value,index| }
      #     before_yield: proc { |key,value,index| }
      #   }
      #
      #   Each callback is a Proc accepting a property key (name), value, and
      #   optionally the numeric index of the property in its parent array (this
      #   is nil if the property is not an array member).
      #
      #   Value is an array for after/before_array, a hash for after/before_hash
      #   and any type for after/before_yield.
      #
      #   All before hooks must return a truthy value to allow processing of
      #   the value, or a falsey value to prevent processing of the value.
      #
      #   Filters should be implemented in before hooks
      #
      #   Before hooks can also be used to process arrays and hashes as a whole.
      #   They should return false if property-level processing is not required.
      # @return [void]
      def initialize(yielder = nil, **hooks)
        self.hooks = hooks
        self.yielder = yielder
      end

      def [](hook, *args, **kwargs)
        h = hooks[hook]
        return true unless h && h.respond_to?(:call)
        h.call(*args, **kwargs) ? true : false
      end

      def []=(hook, proc)
        unless proc.is_a?(Proc) || proc.is_a?(Method)
          raise ArgumentError, 'Proc or Method expected'
        end
        hooks[hook] = proc
      end

      # Enumerates an array of JSON data structures
      # @param key [String] the property name
      # @param array [Object] the property value
      # @param index [Integer] the index of the property in its parent array, or
      #   nil if not part of an array
      # @return [void]
      def array(key, array, index)
        return unless self[:before_array, key, array, index]
        i = 0
        array.each do |value|
          enumerate(key, value, i)
          i += 1
        end
        self[:after_array, key, array, index]
      end

      # Enumerates the property/value pairs of a JSON data structure
      # @param key [String] the property name
      # @param value [Object] the property value
      # @param index [Integer] the index of the property in its parent array, or
      #   nil if not part of an array
      # @return [void]
      def enumerate(key, value, index = nil)
        if value.is_a?(Array)
          array(key, value, index)
        elsif value.is_a?(Hash)
          hash(key, value, index)
        else
          property(key, value, index)
        end
      end

      # Returns an enumerator enumerating property/value pairs of JSON data
      # @param key [String] the initial key of the data
      # @param value [Object] the initial value of the data
      # @return [Enumerator] the enumerator
      def enumerator(key, value)
        Enumerator.new do |yielder|
          self.yielder = yielder
          enumerate(key, value)
        end
      end

      # Enumerates the property/value pairs of a JSON hash
      # @param key [String] the property name
      # @param hash [Hash] the hash to enumerate
      # @param index [Integer] the index of the property in its parent array, or
      #   nil if not part of an array
      # @return [void]
      def hash(key, hash, index = nil)
        return unless self[:before_hash, key, hash, index]
        hash.each do |k, v|
          v.is_a?(Array) || v.is_a?(Hash) ? enumerate(k, v) : property(k, v)
        end
        self[:after_hash, key, hash, index]
      end

      # Yields a property/value pair
      # @param key [String] the property name
      # @param value [Object] the property value
      # @param index [Integer] the index of the property in its parent array, or
      #   nil if not part of an array
      # @return [void]
      def property(key, value, index = nil)
        return unless self[:before_yield, key, value, index]
        yielder << [key, value, index]
        self[:after_yield, hooks, key, value, index]
      end
    end
  end
end