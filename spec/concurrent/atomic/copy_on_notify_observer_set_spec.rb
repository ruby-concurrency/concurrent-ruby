require 'spec_helper'
require_relative 'observer_set_shared'

module Concurrent

  describe CopyOnNotifyObserverSet do
    it_behaves_like 'an observer set'
  end

end