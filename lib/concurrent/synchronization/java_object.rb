module Concurrent
  module Synchronization

    if Concurrent.on_jruby?
      require 'jruby'

      class JavaObject < AbstractObject
        private

        def ensure_ivar_visibility! # TODO move to java version
          # relying on undocumented behavior of JRuby, ivar access is volatile
        end
      end
    end
  end
end
