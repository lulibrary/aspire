module Aspire
  module Exceptions
    # The root of the caching exception hierarchy
    class Error < StandardError; end

    # Raised when a requested URL is not present in the cache
    class CacheMiss < Error; end

    # Raised when an Aspire API call fails
    class APIError < Error; end

    # Raised when an Aspire API call times out
    class APITimeout < APIError; end

    # Raised when a cache entry mark operation fails
    class MarkError < Error; end

    # Raised when trying to mark an already-marked cache entry
    class MarkedError < Error; end

    # Raised when a URL is not cacheable
    class NotCacheable < Error; end

    # Raised when data cannot be read from the cache
    class ReadError < Error; end

    # Raised when data cannot be removed from the cache
    class RemoveError < Error; end

    # Raised when a cache entry unmark operation fails
    class UnmarkError < Error; end

    # Raised when data cannot be written to the cache
    class WriteError < Error; end
  end
end