# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ActiveSG/version'

Gem::Specification.new do |spec|
  spec.name          = "ActiveSG"
  spec.version       = ActiveSG::VERSION
  spec.authors       = ["PandaDrunkard"]
  spec.email         = ["tosho.hirasawa@gmail.com"]
  spec.summary       = %q{A simple ActiveSG client}
  spec.description   = %q{A simple ActiveSG client}
  spec.homepage      = "https://github.com/PandaDrunkard/ActiveSG"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end
