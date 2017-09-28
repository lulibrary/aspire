require 'aspire/object/resource'

require_relative 'test_helper'

# Tests the Aspire::Object::Resource class
class ResourceTest < Test
  def test_page
    json = { 'page' => '12-34' }
    assert_pages(json,
                 page: '12-34', page_range: '12-34', page_start: '12',
                 page_end: '34')
  end

  def test_page_collapse
    json = { 'page' => '12-12' }
    assert_pages(json,
                 page: '12-12', page_range: '12', page_start: '12',
                 page_end: '12')
  end

  def test_page_collapse_override
    json = { 'page' => '12-12', 'pageStart' => '96', 'pageEnd' => '98' }
    assert_pages(json,
                 page: '12-12', page_range: '12', page_start: '12',
                 page_end: '12')
  end

  def test_page_empty
    json = { 'page' => '' }
    assert_pages(json)
  end

  def test_page_end
    json = { 'pageEnd' => '34' }
    assert_pages(json, page_range: '34', page_end: '34')
  end

  def test_page_end_override
    json = { 'page' => '-34', 'pageStart' => '96', 'pageEnd' => '98' }
    assert_pages(json,
                 page: '-34', page_range: '-34', page_start: '',
                 page_end: '34')
  end

  def test_page_nil
    json = {}
    assert_pages(json)
  end

  def test_page_single
    json = { 'page' => '12' }
    assert_pages(json,
                 page: '12', page_range: '12', page_start: '12', page_end: '12')
  end

  def test_page_single_override
    json = { 'page' => '12', 'pageStart' => '96', 'pageEnd' => '98' }
    assert_pages(json,
                 page: '12', page_range: '12', page_start: '12', page_end: '12')
  end

  def test_page_start
    json = { 'pageStart' => '12' }
    assert_pages(json, page_range: '12', page_start: '12')
  end

  def test_page_start_end
    json = { 'pageStart' => '12', 'pageEnd' => '34' }
    assert_pages(json, page_range: '12-34', page_start: '12', page_end: '34')
  end

  def test_page_start_end_override
    json = { 'page' => '12-34', 'pageStart' => '96', 'pageEnd' => '98' }
    assert_pages(json,
                 page: '12-34', page_range: '12-34', page_start: '12',
                 page_end: '34')
  end

  def test_page_start_override
    json = { 'page' => '12-', 'pageStart' => '96', 'pageEnd' => '98' }
    assert_pages(json,
                 page: '12-', page_range: '12-', page_start: '12',
                 page_end: '')
  end

  private

  def assert_equal_or_nil(expected, actual)
    if expected
      assert_equal(expected, actual)
    else
      assert_nil(actual)
    end
  end

  def assert_pages(json, page: nil, page_range: nil, page_start: nil,
                   page_end: nil)
    res = Aspire::Object::Resource.new('test_page', json: json)
    assert_equal_or_nil(page, res.page)
    assert_equal_or_nil(page_range, res.page_range)
    assert_equal_or_nil(page_start, res.page_start)
    assert_equal_or_nil(page_end, res.page_end)
  end
end