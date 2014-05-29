require 'spec_helper'
require 'concurrent/actress'

module Concurrent
  module Actress
    i_know_it_is_experimental!

    class Reference
      def backdoor(&block)
        core.send :schedule_execution do
          core.instance_eval &block
        end
      end
    end

    describe 'Concurrent::Actress' do
      prepend_before do
        @do_not_reset               = true
        @@isolated_from_other_tests ||= begin
          sleep 0.1
          true
        end
      end

      def terminate_actors(*actors)
        actors.each do |actor|
          actor.backdoor { terminate! }
          actor.terminated.wait
        end
      end

      class Ping
        include Context

        def initialize(queue)
          @queue = queue
        end

        def on_message(message)
          case message
          when :terminate
            terminate!
          when :child
            AdHoc.spawn(:pong, @queue) { |queue| -> m { queue << m } }
          else
            @queue << message
            message
          end
        end
      end

      # def trace!
      #   set_trace_func proc { |event, file, line, id, binding, classname|
      #     # thread = eval('Thread.current', binding).object_id.to_s(16)
      #     printf "%8s %20s %20s %s %s:%-2d\n", event, id, classname, nil, file, line
      #   }
      #   yield
      # ensure
      #   set_trace_func nil
      # end

      describe 'stress test' do
        1.times do |i|
          it format('run %3d', i) do
            # puts format('run %3d', i)
            Array.new(10).map do
              Thread.new do
                10.times do
                  # trace! do
                  queue = Queue.new
                  actor = Ping.spawn :ping, queue

                  # when spawn returns children are set
                  Concurrent::Actress::ROOT.send(:core).instance_variable_get(:@children).should include(actor)

                  actor << 'a' << 1
                  queue.pop.should eq 'a'
                  actor.ask(2).value.should eq 2

                  actor.parent.should eq Concurrent::Actress::ROOT
                  Concurrent::Actress::ROOT.path.should eq '/'
                  actor.path.should eq '/ping'
                  child = actor.ask(:child).value
                  child.path.should eq '/ping/pong'
                  queue.clear
                  child.ask(3)
                  queue.pop.should eq 3

                  actor << :terminate
                  actor.ask(:blow_up).wait.should be_rejected
                  terminate_actors actor, child
                end
              end
            end.each(&:join)
          end
        end
      end

      describe 'spawning' do
        describe 'Actress#spawn' do
          behaviour = -> v { -> _ { v } }
          subjects  = { spawn:                 -> { Actress.spawn(AdHoc, :ping, 'arg', &behaviour) },
                        context_spawn:         -> { AdHoc.spawn(:ping, 'arg', &behaviour) },
                        spawn_by_hash:         -> { Actress.spawn(class: AdHoc, name: :ping, args: ['arg'], &behaviour) },
                        context_spawn_by_hash: -> { AdHoc.spawn(name: :ping, args: ['arg'], &behaviour) } }

          subjects.each do |desc, subject_definition|
            describe desc do
              subject &subject_definition
              after { terminate_actors subject }
              its(:path) { should eq '/ping' }
              its(:parent) { should eq ROOT }
              its(:name) { should eq 'ping' }
              it('executor should be global') { subject.executor.should eq Concurrent.configuration.global_task_pool }
              its(:reference) { should eq subject }
              it 'returns ars' do
                subject.ask!(:anything).should eq 'arg'
              end
            end
          end
        end

        it 'terminates on failed initialization' do
          a = AdHoc.spawn(name: :fail, logger: Concurrent.configuration.no_logger) { raise }
          a.ask(nil).wait.rejected?.should be_true
          a.terminated?.should be_true
        end

        it 'terminates on failed initialization and raises with spawn!' do
          expect do
            AdHoc.spawn!(name: :fail, logger: Concurrent.configuration.no_logger) { raise 'm' }
          end.to raise_error(StandardError, 'm')
        end

        it 'terminates on failed message processing' do
          a = AdHoc.spawn(name: :fail, logger: Concurrent.configuration.no_logger) { -> _ { raise } }
          a.ask(nil).wait.rejected?.should be_true
          a.terminated?.should be_true
        end
      end

      describe 'messaging' do
        subject { AdHoc.spawn(:add) { c = 0; -> v { c = c + v } } }
        specify do
          subject.tell(1).tell(1)
          subject << 1 << 1
          subject.ask(0).value!.should eq 4
        end
        after { terminate_actors subject }
      end

      describe 'children' do
        let(:parent) do
          AdHoc.spawn(:parent) do
            -> message do
              if message == :child
                AdHoc.spawn(:child) { -> _ { parent } }
              else
                children
              end
            end
          end
        end

        it 'has children set after a child is created' do
          child = parent.ask!(:child)
          parent.ask!(nil).should include(child)
          child.ask!(nil).should eq parent

          terminate_actors parent, child
        end
      end

      describe 'envelope' do
        subject { AdHoc.spawn(:subject) { -> _ { envelope } } }
        specify do
          envelope = subject.ask!('a')
          envelope.should be_a_kind_of Envelope
          envelope.message.should eq 'a'
          envelope.ivar.should be_completed
          envelope.ivar.value.should eq envelope
          envelope.sender.should eq Thread.current
          terminate_actors subject
        end
      end

      describe 'termination' do
        subject do
          AdHoc.spawn(:parent) do
            child = AdHoc.spawn(:child) { -> v { v } }
            -> v do
              if v == :terminate
                terminate!
              else
                child
              end
            end
          end
        end

        it 'terminates with all its children' do
          child = subject.ask! :child
          subject.terminated?.should be_false
          subject.ask(:terminate).wait
          subject.terminated?.should be_true
          child.terminated.wait
          child.terminated?.should be_true

          terminate_actors subject, child
        end
      end

    end
  end
end
