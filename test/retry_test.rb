require 'retry'

require_relative 'test_helper'

# Tests the Retry class
class RetryTest < Test
  def setup
    handlers
    @exception = nil
    @exceptions = { ArgumentError => true, NoMethodError => true }
    @handlers = {
      ArgumentError => @handler1,
      NoMethodError => @handler2,
      default: @handler3
    }
    @tries = 0
    @do = { delay: 1, exceptions: @exceptions, handlers: @handlers, tries: 3 }
  end

  def test_retry_fail
    assert_raises(ArgumentError) do
      Retry.do(**@do) { raise ArgumentError }
    end
    assert_equal @do[:tries], @tries
    assert_kind_of ArgumentError, @exception
  end

  def test_retry_handler_return
    # NoMethodError should trigger a handler which returns 'OK after 3 tries'
    # on the third try and does not raise an exception
    result = Retry.do(**@do) { raise NoMethodError }
    assert_equal 'OK after 3 tries', result
  end

  def test_retry_handler_default
    # StopIteration is an unspecified exception which should trigger the
    # default handler and not raise an exception
    result = Retry.do(**@do) { raise StopIteration }
    assert_equal 'Default action', result
  end

  private

  def handlers
    @handler1 = proc { |e, tries| @exception = e; @tries += 1 }
    @handler2 = proc do |e, tries|
      @exception = e; @tries += 1
      raise Retry::StopRetry.new('OK after 3 tries') if @tries == 3
    end
    @handler3 = proc { |e, tries| raise Retry::StopRetry.new('Default action') }
  end
end