require 'rubygems'
require 'rake/gempackagetask'
require 'rspec/core/rake_task'

spec = Gem::Specification.new do |s|
  s.name = "hiera-module-json"
  s.version = "0.0.1"
  s.author = "R.I.Pienaar"
  s.email = "rip@devco.net"
  s.homepage = "https://github.com/ripienaar/hiera-puppet"
  s.platform = Gem::Platform::RUBY
  s.summary = "Load data from a Puppet module"
  s.description = "Store and query Hiera data from Puppet modules"
  s.files = FileList["lib/**/*"].to_a
  s.require_path = "lib"
  s.add_dependency 'hiera', '~>1.0.0'
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

