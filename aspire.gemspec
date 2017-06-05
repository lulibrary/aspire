# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aspire/version'

Gem::Specification.new do |spec|
  spec.name          = 'aspire'
  spec.version       = Aspire::VERSION
  spec.authors       = ['Lancaster University Library']
  spec.email         = ['library.dit@lancaster.ac.uk']

  spec.summary       = 'Ruby interface to the Talis Aspire API'
  spec.description   = 'This gem provides a Ruby interface for working with' \
                       'the Talis Aspire API.'
  spec.homepage      = 'https://github.com/lulibrary/aspire'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the
  # 'allowed_push_host' to allow pushing to a single host or delete this section
  # to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem' \
          'pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'loofah', '~>2.0.3'
  spec.add_dependency 'rest-client', '~>2.0.2'

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'dotenv', '~> 2.2.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'minitest-reporters'
end