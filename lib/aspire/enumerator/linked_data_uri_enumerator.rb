require 'aspire/enumerator/json_enumerator'

module Aspire
  # Enumerator classes for Aspire reading list processing
  module Enumerator
    # Enumerates the URI properties of a linked data API object
    class LinkedDataURIEnumerator < JSONEnumerator
      # Initialises a new LinkedDataAPIEnumerator instance
      # @param yielder [Enumerator::Yielder] the yielder from an Enumerator
      # @param hooks [Hash] the callback hooks
      # @yield [key, hash, index] passes each hash to the block
      # @yieldparam key [Object] the hash property name
      # @yieldparam hash [Hash] the hash
      # @yieldparam index [Integer, nil] the index of the hash in its parent
      #   array, or nil if not part of an array
      def initialize(yielder = nil, **hooks)
        super(yielder, **hooks)
        # Yield only hashes { type: "uri", value: "..." }
        self[:before_hash] = proc do |key, hash, index|
          if hash['type'] == 'uri' && hash['value'] && !hash['value'].empty?
            self.yielder << [key, hash, index]
            false
          else
            true
          end
        end
        # Do not yield properties
        self[:before_yield] = proc { |_key, _value, _index| false }
      end
    end
  end
end