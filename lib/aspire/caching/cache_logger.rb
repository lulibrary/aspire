require 'logger'

require 'aspire/exceptions'

module Aspire
  # Tools for building a caching from the Aspire APIs
  module Caching
    # A wrapper class for Logger adding utility methods
    class CacheLogger
      # @!attribute [rw] logger
      #   @return [Logger] the logger
      attr_accessor :logger

      # Delegates missing methods to the logger
      # @param method [Symbol] the method name
      # @param args [Array] the method arguments
      # @param block [Proc] the method code block
      # @return [Object] the method result
      def method_missing(method, *args, &block)
        # Do not fail if logger is undefined
        return nil unless logger
        # Fail if logger does not respond to this method
        super unless logger.respond_to?(method)
        # Delegate to the logger method
        logger.public_send(method, *args, &block)
      end

      # Delegates missing method respond_to? to the wrapped logger
      # @param method [Symbol] the method name
      # @return [Boolean] true if the wrapped logger responds to the method
      def respond_to_missing?(method)
        # If logger is undefined, all missing methods are accepted
        logger ? logger.respond_to?(method) : true
      end

      # Initialises a new CacheLogger instance
      # @param logger [Logger] the logger
      def initialize(logger = nil)
        self.logger = logger
      end

      # Logs and raises an exception
      # @param message [String] the error message
      # @param exception [Class] the class of the exception to be raised
      # @param level [Symbol] the logger level (default: Logger::ERROR)
      # @raise [Aspire::Caching::Exceptions::Error]
      def log_exception(message, exception = nil, level: nil)
        log(level || Logger::ERROR, message)
        raise exception || Aspire::Exceptions::Error, message
      end

      # Logs an event and returns its first argument
      # - allows for compact code such as 'return log_return(result, msg,...)'
      # @param result [Object] the return value of the method
      # @param (see #log)
      # @return [Object] the result argument
      def log_return(result, *args, **kwargs)
        log(*args, **kwargs)
        result
      end
    end
  end
end