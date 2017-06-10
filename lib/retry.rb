# Support for performing retriable operations
module Retry
  # Common exceptions suitable for retrying
  module Exceptions
    SOCKET_EXCEPTIONS = [
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EINTR,
      Errno::EHOSTUNREACH,
      Errno::ENETDOWN,
      Errno::ENETUNREACH,
      Errno::ENOBUFS,
      Errno::ENOSR,
      Errno::ETIMEDOUT,
      IO::WaitReadable
    ].freeze
  end

  # Retry handlers should raise this exception to stop retry processing and
  # return the return value from the Retry.do method
  class StopRetry < RuntimeError
    attr_accessor :value
    def initialize(value = nil)
      self.value = value
    end
  end

  # Support for repeatedly calling retriable operations
  class Engine
    attr_accessor :delay
    attr_accessor :exceptions
    attr_accessor :handlers
    attr_accessor :tries

    # Initialises a new Engine instance
    # @param delay [Float] the default delay before retrying
    # @param exceptions [Hash<Exception, Boolean>] the default retriable
    #   exceptions
    # @param handlers [Hash<Exception|Symbol, Proc>] the default exception
    #   handlers
    # @param tries [Integer, Proc] the default maximum number of tries or
    #   a proc which accepts an Exception and returns true if a retry is allowed
    #   or false if not
    # @return [void]
    def initialize(delay: nil, exceptions: nil, handlers: nil, tries: nil)
      self.delay = delay.to_f
      self.exceptions = exceptions || {}
      self.handlers = handlers || {}
      self.tries = tries
    end

    # Executes the class method do using instance default values
    def do(delay: nil, exceptions: nil, handlers: nil, tries: nil, &block)
      Retry.do(delay: delay || self.delay,
               exceptions: exceptions || self.exceptions,
               handlers: handlers || self.handlers,
               tries: tries || self.tries,
               &block)
    end
  end

  # Executes the code block until it returns successfully, throws a
  # non-retriable exception or some termination condition is met.
  # @param delay [Float] the number of seconds to wait before retrying.
  #   Positive values specify an exact delay, negative values specify a
  #   random delay no longer than this value.
  # @param exceptions [Hash<Exception, Boolean>] the hash of retriable
  #   exceptions
  # @param handlers [Hash<Exception|Symbol, Proc>] handlers to be invoked
  #   when specific exceptions occur. A handler should accept the exception
  #   and the number of tries remaining as arguments. It does not need to
  #   re-raise its exception argument, but it may throw another exception
  #   to prevent a retry.
  # @param tries [Integer] the maximum number of tries
  # @return [Object] the return value of the block
  def self.do(delay: nil, exceptions: nil, handlers: nil, tries: nil)
    yield if block_given?
  rescue StandardError => exception
    # Decrement the tries-remaining count if appropriate
    tries -= 1 if tries.is_a?(Numeric)
    # Handlers may raise StopRetry to force a return value from the method
    # Check if the exception is retriable
    retriable = retry?(exception, exceptions, tries)
    begin
      # Run the exception handler
      # - this will re-raise the exception if it is not retriable
      handle_exception(exception, handlers, tries, retriable)
      # Run the retry handler and retry
      handle_retry(exception, handlers, tries, retriable, delay)
      retry
    rescue StopRetry => exception
      # Force a return value from the handler
      exception.value
    end
  end

  # Executes a handler for an exception
  # @param exception [Exception] the exception
  # @param handlers [Hash<Exception|Symbol, Proc>] the exception handlers
  # @param tries [Integer] the number of tries remaining
  # @param retriable [Boolean] true if the exception is retriable, false if not
  # @return [Object] the return value of the handler, or nil if no handler
  #   was executed
  def self.handle_exception(exception, handlers, tries, retriable)
    # Execute the general exception handler
    handler(exception, handlers, tries, retriable, :all)
    # Execute the exception-specific handler
    handler(exception, handlers, tries, retriable)
    # Re-raise the exception if not retriable
    raise exception unless retriable
  end

  # Executes the retry handler
  # @param exception [Exception] the exception
  # @param handlers [Hash<Exception|Symbol, Proc>] the exception handlers
  # @param tries [Integer] the number of tries remaining
  # @param retriable [Boolean] true if the exception is retriable, false if not
  # @param delay [Float] the number of seconds to wait before retrying
  def self.handle_retry(exception, handlers, tries, retriable, delay)
    # Wait for the specified delay
    wait(delay) unless delay.zero?
    # Return the result of the retry handler
    handler(exception, handlers, tries, retriable, :retry)
  end

  # Executes the specified handler
  # @param exception [Exception] the exception
  # @param handlers [Hash<Exception|Symbol, Proc>] the exception handlers
  # @param tries [Integer] the number of tries remaining
  # @param retriable [Boolean] true if the exception is retriable, false if not
  # @param name [Symbol] the handler name, defaults to the exception class
  # @return [Object] the return value of the handler, or nil if no handler
  #   was executed
  def self.handler(exception, handlers, tries, retriable, name = nil)
    handler = nil
    if name.nil?
      # Find the handler for the exception class
      handlers.each do |e, h|
        next unless e.is_a?(Class) && exception.is_a?(e)
        handler = h
        break
      end
      # Use the default handler if no match was found
      handler ||= handlers[:default]
    else
      # Use the named handler, do not use the default if not found
      handler = handlers[name]
    end
    handler ? handler.call(exception, tries, retriable) : nil
  end

  # Returns true if the exception instance is retriable, false if not
  # @param exception [Exception] the exception instance
  # @param tries [Integer, Proc] the number of tries remaining or a proc
  #   determining whether tries remain
  # @return [Boolean] true if the exception is retriable, false if not
  def self.retry?(exception, exceptions, tries)
    # Return false if there are no more tries remaining
    return false unless tries_remain?(exception, tries)
    # Return true if the exception matches a retriable exception class
    exceptions.each { |e| return true if exception.is_a?(e) }
    # The exception didn't match any retriable classes
    false
  end

  # Returns true if there are tries remaining
  # @param exception [Exception] the exception instance
  # @param tries [Integer, Proc] the number of tries remaining or a proc
  #   determining whether tries remain
  def self.tries_remain?(exception, tries)
    # If tries is numeric, this is the number of tries remaining
    return false if tries.is_a?(Numeric) && tries.zero?
    # If tries has a #call method, this should return true to allow a retry or
    # false to raise the exception
    return false if tries.respond_to?(:call) && !tries.call(exception)
    # Otherwise allow a retry
    true
  end

  # Waits for the specified number of seconds. If delay is positive, sleep
  # for that period. If delay is negative, sleep for a random time up to
  # that duration.
  # @param delay [Float] the number of seconds to wait before retrying
  # @return [void]
  def self.wait(delay)
    sleep(delay > 0 ? delay : Random.rand(-delay))
  end

  class << self
    private :handle_exception
    private :handle_retry
    private :handler
    private :retry?
    private :tries_remain?
    private :wait
  end
end