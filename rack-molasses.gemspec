# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rack/molasses/version"

Gem::Specification.new do |s|
  s.name        = "rack-molasses"
  s.version     = Rack::Molasses::VERSION
  s.authors     = ["Wyatt Greene"]
  s.email       = ["techiferous@gmail.com"]
  s.homepage    = "http://github.com/wegowise/rack-molasses"
  s.summary     = "Rack::Molasses makes caching static assets easier in Rails."
  s.description = "Rack::Molasses makes caching static assets easier in Rails."
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.license = 'MIT'
  s.add_development_dependency "rspec", "~>2.8"
  s.add_runtime_dependency "rack", "~>1.4"
  s.add_runtime_dependency "rack-cache", "~>1.1"
end
