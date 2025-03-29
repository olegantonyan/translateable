lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'translateable/version'

Gem::Specification.new do |spec|
  spec.name          = 'translateable'
  spec.version       = Translateable::VERSION
  spec.authors       = ['Oleg Antonyan']
  spec.email         = ['oleg.b.antonyan@gmail.com']

  spec.summary       = 'Allows to store text data in different languages.'
  spec.description   = "Similar to globalize, but uses PostgreSQL's JSONB to store data in a single field. No additional tables required. Very thin abstraction"
  spec.homepage      = 'https://github.com/olegantonyan/translateable'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = %w(lib)

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'

  spec.add_dependency 'activerecord', '>= 5.0'
  spec.add_dependency 'activesupport', '>= 5.0'
  spec.add_dependency 'i18n'
  spec.add_dependency 'pg'
end
