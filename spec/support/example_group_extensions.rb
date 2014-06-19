require 'rbconfig'
require_relative '../../lib/extension_helper.rb'

module Concurrent
  module TestHelpers
    def delta(v1, v2)
      if block_given?
        v1 = yield(v1)
        v2 = yield(v2)
      end
      return (v1 - v2).abs
    end

    def mri?
      RbConfig::CONFIG['ruby_install_name']=~ /^ruby$/i
    end

    def jruby?
      RbConfig::CONFIG['ruby_install_name']=~ /^jruby$/i
    end

    def rbx?
      RbConfig::CONFIG['ruby_install_name']=~ /^rbx$/i
    end

    def use_c_extensions?
      Concurrent.use_c_extensions? # from extension_helper.rb
    end

    def do_no_reset!
      @do_not_reset = true
    end

    @@killed = false

    def reset_gem_configuration
      Concurrent.instance_variable_get(:@configuration).value = Concurrent::Configuration.new if @@killed
      @@killed = false
    end

    def kill_rogue_threads(warning = true)
      return if @do_not_reset
      warn('[DEPRECATED] brute force thread control being used -- tests need updated') if warning
      Thread.list.each do |thread|
        thread.kill unless thread == Thread.current
      end
      @@killed = true
    end

    extend self
  end
end

class RSpec::Core::ExampleGroup
  include Concurrent::TestHelpers
  extend Concurrent::TestHelpers
end
