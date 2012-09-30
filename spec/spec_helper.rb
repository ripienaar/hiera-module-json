$:.insert(0, File.join([File.dirname(__FILE__), "..", "lib"]))

require 'rubygems'
require 'rspec'
require 'mocha'
require 'hiera'
require 'puppet'
require 'ostruct'
require 'hiera/backend/module_json_backend'

RSpec.configure do |config|
    config.mock_with :mocha
end
