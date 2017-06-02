require 'aspire/api'

require_relative 'test_helper'

class LinkedDataAPITest < Test
  def setup
    @aliases = %w[alias1.com alias2.com]
    @path = 'canonical.tenancy.com'
    @api = Aspire::API::LinkedData.new('tenancy-code',
                                       tenancy_host_aliases: @aliases,
                                       tenancy_root: @path)
  end

  def test_canonical_url
    aliases = @aliases.map { |a| "http://#{a}/lists/12345" }
    canonical = "http://#{@path}/lists/12345"
    non_alias = 'http://not_an_alias.com/lists/12345'
    # Alias URLs should be converted to the canonical root URL
    aliases.each { |a| assert_equal canonical, @api.canonical_url(a) }
    # Alias host names should be converted to the canonical root URL
    @aliases.each { |a| assert_equal "http://#{@path}", @api.canonical_url(a) }
    # Unknown and invalid URLs should return nil
    assert_nil @api.canonical_url(non_alias)
    assert_nil @api.canonical_url(':not a valid URL:')
  end

  def test_tenancy_host_aliases
    # Assigning URLs should store only the host names
    # Assigning host names should store the host name as given
    @api.tenancy_host_aliases = [
      'http://alias1.com/some/path?query=what',
      'http://alias2.com',
      'alias3.com',
      '',
      nil
    ]
    # The aliases should be a list of host names with no empty elements
    expected_aliases = %w[alias1.com alias2.com alias3.com]
    assert_equal expected_aliases, @api.tenancy_host_aliases
  end

  def test_tenancy_host_aliases_empty
    # Assigning an empty list should give an empty list
    @api.tenancy_host_aliases = []
    assert_equal [], @api.tenancy_host_aliases
  end

  def test_tenancy_host_aliases_nil
    # Assigning nil should give the default tenancy host name
    @api.tenancy_host_aliases = nil
    assert_equal [@api.canonical_host], @api.tenancy_host_aliases
  end

  def test_valid_host
    # Aliases and the tenancy root should be valid
    @aliases.each { |host| assert @api.valid_host?(host) }
    assert @api.valid_host?(@path)
    assert @api.valid_host?(@api.tenancy_root)
    # Anything else, including a valid URL, should be invalid
    [nil, '', ':not a valid hostname:', "http://#{@path}/123"].each do |host|
      refute @api.valid_host?(host)
    end
  end

  def test_valid_url
    # URLs containing valid aliases and the tenancy root should be valid
    @aliases.each { |url| assert @api.valid_url?("http://#{url}/lists/12345") }
    assert @api.valid_url?("http://#{@path}/lists/12345")
    assert @api.valid_url?("#{@api.tenancy_root}/lists/12345")
    # Host names should also be valid
    @aliases.each { |url| assert @api.valid_url?(url) }
    assert @api.valid_url?(@path)
    assert @api.valid_url?(@api.tenancy_root)
    # Anything else should be invalid
    [nil, '', ':not a valid url:', 'http://notanalias.com/'].each do |url|
      refute @api.valid_url?(url)
    end
  end

end