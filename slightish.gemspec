# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'slightish/version'

Gem::Specification.new do |spec|
  spec.name          = 'slightish'
  spec.version       = Slightish::VERSION
  spec.required_ruby_version = '>=2.2.1'

  spec.authors       = ['Tim Clem']
  spec.email         = ['tim.clem@gmail.com']

  spec.summary       = 'Literate testing of shell tools'
  spec.homepage      = 'http://github.com/misterfifths/slightish'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
