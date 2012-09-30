class Hiera
  class Filecache
    def initialize
      @cache = {}
    end

    def read(path, expected_type=nil, default=nil)
      @cache[path] ||= {:data => nil, :meta => path_metadata(path)}

      if !@cache[path][:data] || stale?(path)
        if block_given?
          begin
            @cache[path][:data] = yield(File.read(path))
          rescue => e
            Hiera.debug("Reading data from %s failed: %s: %S" % [path, e.class, e.to_s])
            @cache[path][:data] = default
          end
        else
          @cache[path][:data] = File.read(path)
        end
      end

      if block_given? && !expected_type.nil?
        unless @cache[path][:data].is_a?(expected_type)
          Hiera.debug("Data retrieved from %s is not a %s, setting defaults" % [path, expected_type])
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
