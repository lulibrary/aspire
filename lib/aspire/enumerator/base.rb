module Aspire
  # Enumerator classes for Aspire reading list processing
  module Enumerator
    # The abstract base class for enumerator classes
    # @abstract Subclasses must implement #enumerate accepting the parameters
    #   passed to #enumerator and yielding values to self.yielder
    class Base
      # The Enumerator::Yielder instance from an Enumerator.new call
      # @!attribute [rw] yielder
      #   @return [Enumerator::Yielder] the yielder instance from an Enumerator
      attr_accessor :yielder

      # Enumerates the data passed in its arguments
      # @abstract Subclasses must implement this method
      def enumerate(*args, **kwargs)
        raise NotImplementedError
      end

      # Returns an enumerator enumerating property/value pairs of JSON data
      # @return [Enumerator] the enumerator
      def enumerator(*args, **kwargs)
        ::Enumerator.new do |yielder|
          self.yielder = yielder
          enumerate(*args, **kwargs)
        end
      end
    end
  end
end