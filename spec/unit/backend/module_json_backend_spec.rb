require 'spec_helper'

class Hiera
  module Backend
    describe Module_json_backend do
      before do
        Hiera.stubs(:debug)
        Hiera.stubs(:warn)
        @backend = Module_json_backend.new
      end

      describe "#load_module_config" do
        it "should attempt to load the config from a puppet module directory" do
          Puppet::Module.expects(:find).with("rspec", "testing").returns(OpenStruct.new(:path => "/nonexisting"))

          config_path = File.join("/nonexisting", "data", "hiera.json")

          File.expects(:exist?).with(config_path).returns(true)
          @backend.expects(:load_data).with(config_path).returns({"hierarchy" => ["x"]})

          @backend.load_module_config("rspec", "testing").should == {"hierarchy" => ["x"], "path" => "/nonexisting"}
        end

        it "should return default config if the JSON config file is not a hash" do
          Puppet::Module.expects(:find).with("rspec", "testing").returns(OpenStruct.new(:path => "/nonexisting"))

          config_path = File.join("/nonexisting", "data", "hiera.json")

          File.expects(:exist?).with(config_path).returns(true)
          @backend.expects(:load_data).with(config_path).returns("rspec")

          @backend.load_module_config("rspec", "testing").should == {"hierarchy" => ["osfamily/%{::osfamily}", "default"], "path" => "/nonexisting"}
        end

        it "should return the default if not found" do
          Puppet::Module.expects(:find).returns(nil)
          @backend.load_module_config("rspec", "rspec").should == {"hierarchy" => ["osfamily/%{::osfamily}", "default"]}
        end
      end

      describe "#load_data" do
        it "should return an empty hash when the file does not exist" do
          File.expects(:exist?).with("/nonexisting").returns(false)
          @backend.load_data("/nonexisting").should == {}
        end

        it "should read using the caching system" do
          File.expects(:exist?).with("/nonexisting").returns(true)
          @backend.expects(:cached_read).with("/nonexisting", Hash, {}).returns({"rspec" => true})
          @backend.load_data("/nonexisting").should == {"rspec" => true}
        end
      end

      describe "#lookup" do
        it "should only resolve data when puppet has set module_name" do
          Hiera.expects(:debug).with(regexp_matches(/does not look like a module/))
          @backend.lookup("x", {}, nil, nil).should == nil
        end

        it "should fail if the config loader did not find a module path" do
          @backend.expects(:load_module_config).with("rspec", "testing").returns({})
          Hiera.expects(:debug).with(regexp_matches(/Could not find a path to the module/))

          @backend.lookup("x", {"module_name" => "rspec", "environment" => "testing"}, nil, nil).should == nil
        end

        it "should load data from the hierarchies" do
          scope = {"module_name" => "rspec", "environment" => "testing"}

          @backend.expects(:load_module_config).returns({"hierarchy" => ["one", "two"], "path" => "/nonexisting"})
          Backend.expects(:parse_string).with("one", scope).returns("one")
          Backend.expects(:parse_string).with("two", scope).returns("two")
          Backend.expects(:parse_string).with("rspec", scope, {}).returns("rspec")

          @backend.expects(:load_data).with(File.join("/nonexisting", "data", "one.json")).returns({})
          @backend.expects(:load_data).with(File.join("/nonexisting", "data", "two.json")).returns({"rspec" => "rspec"})

          @backend.lookup("rspec", scope, nil, nil).should == "rspec"
        end

        it "should support array merges" do
          scope = {"module_name" => "rspec", "environment" => "testing"}

          @backend.expects(:load_module_config).returns({"hierarchy" => ["one", "two"], "path" => "/nonexisting"})
          Backend.expects(:parse_string).with("one", scope).returns("one")
          Backend.expects(:parse_string).with("two", scope).returns("two")
          Backend.expects(:parse_string).with("rspec1", scope, {}).returns("rspec1")
          Backend.expects(:parse_string).with("rspec2", scope, {}).returns("rspec2")

          @backend.expects(:load_data).with(File.join("/nonexisting", "data", "one.json")).returns({"rspec" => "rspec1"})
          @backend.expects(:load_data).with(File.join("/nonexisting", "data", "two.json")).returns({"rspec" => "rspec2"})

          @backend.lookup("rspec", scope, nil, :array).should == ["rspec1", "rspec2"]
        end

        it "should support hash merges" do
          scope = {"module_name" => "rspec", "environment" => "testing"}

          @backend.expects(:load_module_config).returns({"hierarchy" => ["one", "two"], "path" => "/nonexisting"})
          Backend.expects(:parse_string).with("one", scope).returns("one")
          Backend.expects(:parse_string).with("two", scope).returns("two")

          @backend.expects(:load_data).with(File.join("/nonexisting", "data", "one.json")).returns({"rspec" => {"one" => "1"}})
          @backend.expects(:load_data).with(File.join("/nonexisting", "data", "two.json")).returns({"rspec" => {"two" => "2"}})

          @backend.lookup("rspec", scope, nil, :hash).should == {"one"=>"1", "two"=>"2"}
        end
      end

      describe "#cached_read" do
        it "should cache and read data" do
          File.expects(:read).with("/nonexisting").returns('{"rspec":1}')
          @backend.expects(:path_metadata).returns(File.stat(__FILE__)).once
          @backend.expects(:stale?).once.returns(false).once

          @backend.cached_read("/nonexisting").should == {"rspec" => 1}
          @backend.cached_read("/nonexisting").should == {"rspec" => 1}
        end

        it "should support validating return types and setting defaults" do
          File.expects(:read).with("/nonexisting").returns('{"rspec":1}')
          JSON.expects(:parse).returns(1)

          @backend.expects(:path_metadata).returns(File.stat(__FILE__))

          Hiera.expects(:debug).with(regexp_matches(/is not a Hash, skipping/))

          @backend.cached_read("/nonexisting", Hash, {"rspec" => 1}).should == {"rspec" => 1}
        end
      end

      describe "#stale?" do
        it "should return false when the file has not changed" do
          stat = File.stat(__FILE__)

          @backend.stubs(:path_metadata).returns(stat)
          @backend.stale?("/nonexisting").should == true
          @backend.stale?("/nonexisting").should == false
        end

        it "should update and return true when the file changed" do
          @backend.expects(:path_metadata).returns({:inode => 1, :mtime => Time.now, :size => 1})
          @backend.stale?("/nonexisting").should == true
          @backend.expects(:path_metadata).returns({:inode => 2, :mtime => Time.now, :size => 1})
          @backend.stale?("/nonexisting").should == true
        end
      end

      describe "#path_metadata" do
        it "should return the right data" do
          stat = File.stat(__FILE__)

          File.expects(:stat).with("/nonexisting").returns(stat)

          @backend.path_metadata("/nonexisting").should == {:inode => stat.ino, :mtime => stat.mtime, :size => stat.size}
        end
      end
    end
  end
end
