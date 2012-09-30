class Hiera
  module Backend
    class Module_json_backend
      def initialize
        require 'json'

        Hiera.debug("Hiera Module JSON backend starting")

        @cache = {}
      end

      def load_module_config(module_name, environment)
        default_config = {"hierarchy" => ["osfamily/%{::osfamily}", "default"]}

        if mod = Puppet::Module.find(module_name, environment)
          path = mod.path
          module_config = File.join(path, "data", "hiera.json")
          config = nil

          if File.exist?(module_config)
		        begin
              Hiera.debug("Reading config from %s file" % module_config)
              config = load_data(module_config)
            rescue => e
              Hiera.debug("Failed to parse config file %s: %s: %s" % [module_config, e.class, e.to_s])
            end
          end

          config = {} unless config.is_a?(Hash)

          config["path"] = path

          return default_config.merge(config)
        else
          return default_config
        end
      end

      def load_data(path)
        return {} unless File.exist?(path)

        Hiera.debug("Looking for data in source %s" % path)

        cached_read(path, Hash, {})
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        Hiera.debug("Looking up #{key} in Module JSON backend")

        unless scope["module_name"]
          Hiera.debug("Skipping Module JSON backend as this does not look like a module")
          return answer
        end

        config = load_module_config(scope["module_name"], scope["environment"])

        unless config["path"]
          Hiera.debug("Could not find a path to the module '%s' in environment '%s'" % [scope["module_name"], scope["environment"]])
          return answer
        end

        config["hierarchy"].each do |source|
          source = File.join(config["path"], "data", "%s.json" % Backend.parse_string(source, scope))

          data = load_data(source)

          next if data.empty?
          next unless data.include?(key)

          found = data[key]

          case resolution_type
            when :array
              raise("Hiera type mismatch: expected Array or String and got %s" % found.class) unless [Array, String].include?(found.class)
              answer ||= []
              answer << Backend.parse_answer(found, scope)

            when :hash
              raise("Hiera type mismatch: expected Hash and got %s" % found.class) unless found.is_a?(Hash)
              answer ||= {}
              answer = found.merge(answer)

            else
              answer = Backend.parse_answer(found, scope)
              break
          end
        end

        return answer
      end

      def cached_read(path, expected_type=nil, default=nil)
        @cache[path] ||= {:data => nil, :meta => path_metadata(path)}

        if !@cache[path][:data] || stale?(path)
          @cache[path][:data] = JSON.parse(File.read(path))
        end

        unless expected_type.nil?
          unless @cache[path][:data].is_a?(expected_type)
            Hiera.debug("Data retrieved from %s is not a %s, skipping" % [path, expected_type])
            @cache[path][:data] = default
          end
        end

        @cache[path][:data]
      end

      def stale?(path)
        meta = path_metadata(path)

        @cache[path] ||= {:data => nil, :meta => nil}

        if @cache[path][:meta] == meta
          return false
        else
          @cache[path][:meta] = meta
          return true
        end
      end

      def path_metadata(path)
        stat = File.stat(path)
        {:inode => stat.ino, :mtime => stat.mtime, :size => stat.size}
      end
    end
  end
end
