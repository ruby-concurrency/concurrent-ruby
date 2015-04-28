module Concurrent
  module Synchronization

    if Concurrent.on_jruby?
      require 'jruby'

      class JavaObject < AbstractObject
        def ensure_ivar_visibility!
          # relying on undocumented behavior of JRuby, ivar access is volatile
        end
      end
    end
  end
end
