require_relative 'test_helper'

require 'aspire/caching/util'

# Tests the Aspire::Caching::Util class
class CacheUtilTest < Test
  include Aspire::Caching::Util

  # Tests add_filename_prefix
  def test_add_filename_prefix
    assert_equal('prefix-path', add_filename_prefix('path', 'prefix-'))
    assert_equal('/prefix-path', add_filename_prefix('/path', 'prefix-'))
    assert_equal('prefix-path/', add_filename_prefix('path/', 'prefix-'))
    assert_equal('path/to/a-file', add_filename_prefix('path/to/file', 'a-'))
    assert_equal('/path/to/a-file', add_filename_prefix('/path/to/file', 'a-'))
    assert_equal('path/to/a-file.json',
                 add_filename_prefix('path/to/file.json', 'a-'))
    assert_equal('/path/to/a-file.json',
                 add_filename_prefix('/path/to/file.json', 'a-'))
  end

  # Tests add_filename_suffix with simple cases
  def test_add_filename_suffix
    assert_equal('path-suffix', add_filename_suffix('path', '-suffix'))
    assert_equal('/path-suffix', add_filename_suffix('/path', '-suffix'))
    assert_equal('path/to/file-a', add_filename_suffix('path/to/file', '-a'))
    assert_equal('/path/to/file-a', add_filename_suffix('/path/to/file', '-a'))
    # This should be consistent with add_filename_prefix
    assert_equal('path-suffix/', add_filename_suffix('path/', '-suffix'))
  end

  # Tests add_filename_suffix with dotfiles
  def test_add_filename_suffix_dot
    assert_equal('.a-suffix', add_filename_suffix('.a', '-suffix'))
    assert_equal('path/.a-suffix', add_filename_suffix('path/.a', '-suffix'))
    assert_equal('path/...-suffix', add_filename_suffix('path/...', '-suffix'))
    # Handle . and .. correctly
    assert_equal('path-suffix/.', add_filename_suffix('path/.', '-suffix'))
    assert_equal('path-suffix/..', add_filename_suffix('path/..', '-suffix'))
  end

  # Tests add_filename_suffix with extensions
  def test_add_filename_suffix_ext
    assert_equal('path/to/file-a.json',
                 add_filename_suffix('path/to/file.json', '-a'))
    assert_equal('/path/to/file-a.json',
                 add_filename_suffix('/path/to/file.json', '-a'))
    assert_equal('path/.a-suffix.json',
                 add_filename_suffix('path/.a.json', '-suffix'))
  end

  # Tests strip_filename_prefix
  def test_strip_filename_prefix
    assert_equal('path', strip_filename_prefix('prefix-path', 'prefix-'))
    assert_equal('/path', strip_filename_prefix('/prefix-path', 'prefix-'))
    assert_equal('path/', strip_filename_prefix('path/prefix-', 'prefix-'))
    assert_equal('path/to/file', strip_filename_prefix('path/to/a-file', 'a-'))
    assert_equal('/path/to/file',
                 strip_filename_prefix('/path/to/a-file', 'a-'))
    assert_equal('path/to/file.json',
                 strip_filename_prefix('path/to/a-file.json', 'a-'))
    assert_equal('/path/to/file.json',
                 strip_filename_prefix('/path/to/a-file.json', 'a-'))
  end

  # Tests strip_filename_suffix
  def test_strip_filename_suffix
    assert_equal('path', strip_filename_suffix('path-suffix', '-suffix'))
    assert_equal('/path', strip_filename_suffix('/path-suffix', '-suffix'))
    assert_equal('path/', strip_filename_suffix('path/-suffix', '-suffix'))
    assert_equal('path/to/file', strip_filename_suffix('path/to/file-a', '-a'))
    assert_equal('/path/to/file',
                 strip_filename_suffix('/path/to/file-a', '-a'))
    assert_equal('path/to/file.json',
                 strip_filename_suffix('path/to/file-a.json', '-a'))
    assert_equal('/path/to/file.json',
                 strip_filename_suffix('/path/to/file-a.json', '-a'))
  end
end