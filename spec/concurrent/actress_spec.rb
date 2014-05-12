require 'spec_helper'
require_relative 'dereferenceable_shared'
require_relative 'observable_shared'

module Concurrent

  describe Actress do
    Child     = Algebrick.atom
    Terminate = Algebrick.atom

    class Ping < Actress::Abstract

      def initialize(queue)
        @queue = queue
      end

      def on_message(message)
        match message,
              on(Terminate) { terminate! },
              on(Child) { spawn Ping, :pong, @queue },
              (on(any) do
                @queue << message
                message
              end)

      end
    end

    it 'works' do
      queue = Queue.new
      actor = Actress.spawn Ping, :ping, queue

      actor << 'a' << 1
      queue.pop.should eq 'a'
      actor.ask(2).value.should eq 2

      actor.parent.should eq Actress::ROOT
      Actress::ROOT.path.should eq '/'
      actor.path.should eq '/ping'
      child = actor.ask(Child).value
      child.path.should eq '/ping/pong'
      queue.clear
      child.ask(3)
      queue.pop.should eq 3

      actor << Terminate
      actor.ask(:blow_up).wait.rejected?.should be_true
    end
  end
end
