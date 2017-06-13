require_relative 'test_helper'

require 'aspire/object/user'
require 'aspire/user_lookup'

# Tests the UserLookup class
class UserLookupTest < Test
  def setup
    users_env
    @user_lookup = user_lookup
  end

  def test_lookup
    @users.each { |user| assert_user(user) }
  end

  private

  def assert_user(user)
    u = @user_lookup[user[:url]]
    refute_nil u
    assert_kind_of(Aspire::Object::User, u)
    assert_equal(user[:first_name], u.first_name)
    assert_equal(user[:email], u.email)
    assert_equal(user[:role], u.role)
    assert_equal(user[:surname], u.surname)
    assert_equal(user[:url], u.uri)
  end
end