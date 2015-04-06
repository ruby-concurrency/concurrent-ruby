module Concurrent

  module EngineDetector
    def on_jruby?
      ruby_engine == 'jruby'
    end

    def on_cruby?
      ruby_engine == 'ruby'
    end

    def on_rbx?
      ruby_engine == 'rbx'
    end

    def ruby_engine
      defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby'
    end
  end

  extend EngineDetector
end
