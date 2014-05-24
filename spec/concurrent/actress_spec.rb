require 'spec_helper'
require 'concurrent/actress'

module Concurrent
  module Actress
    describe 'Concurrent::Actress' do

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

      def assert condition
        unless condition
          # require 'pry'
          # binding.pry
          raise
          puts "--- \n#{caller.join("\n")}"
        end
      end

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
                  assert Concurrent::Actress::ROOT.send(:core).instance_variable_get(:@children).include?(actor)

                  actor << 'a' << 1
                  assert queue.pop == 'a'
                  assert actor.ask(2).value == 2

                  assert actor.parent == Concurrent::Actress::ROOT
                  assert Concurrent::Actress::ROOT.path == '/'
                  assert actor.path == '/ping'
                  child = actor.ask(:child).value
                  assert child.path == '/ping/pong'
                  queue.clear
                  child.ask(3)
                  assert queue.pop == 3

                  actor << :terminate
                  assert actor.ask(:blow_up).wait.rejected?
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
              its(:path) { should eq '/ping' }
              its(:parent) { should eq ROOT }
              its(:name) { should eq 'ping' }
              its(:executor) { should eq Concurrent.configuration.global_task_pool }
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
        end
      end

    end
  end
end

