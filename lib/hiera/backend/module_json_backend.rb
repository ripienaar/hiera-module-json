class Hiera
  module Backend
    class Module_json_backend
      def initialize
        require 'json'

        Hiera.debug("Hiera Module JSON backend starting")
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        Hiera.debug("Looking up #{key} in Module JSON backend")

        unless scope["module_name"]
          Hiera.debug("Skipping Module JSON backend as this does not look like a module")
          return nil
        end

        if mod = Puppet::Module.find(scope["module_name"], scope["environment"])
          path = mod.path
          module_config = File.join(path, "data", "hiera.json")
          config = nil

          if File.exist?(module_config)
		        begin
              Hiera.debug("Reading config from %s file" % module_config)
              config = JSON.parse(File.read(module_config))
            rescue
              Hiera.debug("Failed to parse config file %s" % module_config)
            end
          end

          config = {} unless config.is_a?(Hash)
          config = {"hierarchy" => ["osfamily/%{::osfamily}", "default"]}.merge(config)

          config["hierarchy"].each do |source|
            source = File.join(path, "data", "%s.json" % Backend.parse_string(source, scope))

            next unless File.exist?(source)

            Hiera.debug("Looking for data in source %s" % source)

            data = JSON.parse(File.read(source))

            next if data.empty?
            next unless data.include?(key)

            case resolution_type
              when :array
                answer ||= []
                answer << Backend.parse_answer(data[key], scope)
              else
                answer = Backend.parse_answer(data[key], scope)
                break
            end
          end
        end

        return answer
      end
    end
  end
end
