require 'concurrent/actor'

module Concurrent
  module Actor
    AdHoc = Utils::AdHoc

    # FIXME better tests!

    # class Reference
    #   def backdoor(&block)
    #     core.send :schedule_execution do
    #       core.instance_eval &block
    #     end
    #   end
    # end

    describe 'Concurrent::Actor' do
      prepend_before do
        do_no_reset!
      end

      def terminate_actors(*actors)
        actors.each do |actor|
          unless actor.ask!(:terminated?)
            actor.ask!(:terminate!)
          end
        end
      end

      class Ping < Context
        def initialize(queue)
          @queue = queue
        end

        def on_message(message)
          case message
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

      it 'forbids Immediate executor' do
        expect { Utils::AdHoc.spawn name: 'test', executor: ImmediateExecutor.new }.to raise_error
      end

      #describe 'stress test' do
        #1.times do |i|
          #it format('run %3d', i) do
            ## puts format('run %3d', i)
            #Array.new(10).map do
              #Thread.new do
                #10.times do
                  ## trace! do
                  #queue = Queue.new
                  #actor = Ping.spawn :ping, queue

                  ## when spawn returns children are set
                  #expect(Concurrent::Actor.root.send(:core).instance_variable_get(:@children)).to include(actor)

                  #actor << 'a' << 1
                  #expect(queue.pop).to eq 'a'
                  #expect(actor.ask(2).value).to eq 2

                  #expect(actor.parent).to eq Concurrent::Actor.root
                  #expect(Concurrent::Actor.root.path).to eq '/'
                  #expect(actor.path).to eq '/ping'
                  #child = actor.ask(:child).value
                  #expect(child.path).to eq '/ping/pong'
                  #queue.clear
                  #child.ask(3)
                  #expect(queue.pop).to eq 3

                  #actor << :terminate!
                  #expect(actor.ask(:blow_up).wait).to be_rejected
                  #terminate_actors actor, child
                #end
              #end
            #end.each(&:join)
          #end
        #end
      #end

      describe 'spawning' do
        describe 'Actor#spawn' do
          behaviour = -> v { -> _ { v } }
          subjects  = { spawn:                 -> { Actor.spawn(AdHoc, :ping, 'arg', &behaviour) },
                        context_spawn:         -> { AdHoc.spawn(:ping, 'arg', &behaviour) },
                        spawn_by_hash:         -> { Actor.spawn(class: AdHoc, name: :ping, args: ['arg'], &behaviour) },
                        context_spawn_by_hash: -> { AdHoc.spawn(name: :ping, args: ['arg'], &behaviour) } }

          subjects.each do |desc, subject_definition|
            describe desc do
              subject(:actor, &subject_definition)
              after { terminate_actors actor }

              describe '#path' do
                subject { super().path }
                it { is_expected.to eq '/ping' }
              end

              describe '#parent' do
                subject { super().parent }
                it { is_expected.to eq Actor.root }
              end

              describe '#name' do
                subject { super().name }
                it { is_expected.to eq 'ping' }
              end
              it('executor should be global') { expect(subject.executor).to eq Concurrent.global_fast_executor }

              describe '#reference' do
                subject { super().reference }
                it { is_expected.to eq subject }
              end
              it 'returns arg' do
                expect(subject.ask!(:anything)).to eq 'arg'
              end
            end
          end
        end

        it 'terminates on failed initialization' do
          a = AdHoc.spawn(name: :fail, logger: Concurrent.configuration.no_logger) { raise }
          expect(a.ask(nil).wait.rejected?).to be_truthy
          expect(a.ask!(:terminated?)).to be_truthy
        end

        it 'terminates on failed initialization and raises with spawn!' do
          expect do
            AdHoc.spawn!(name: :fail, logger: Concurrent.configuration.no_logger) { raise 'm' }
          end.to raise_error(StandardError, 'm')
        end

        it 'terminates on failed message processing' do
          a = AdHoc.spawn(name: :fail, logger: Concurrent.configuration.no_logger) { -> _ { raise } }
          expect(a.ask(nil).wait.rejected?).to be_truthy
          expect(a.ask!(:terminated?)).to be_truthy
        end
      end

      describe 'messaging' do
        subject { AdHoc.spawn(:add) { c = 0; -> v { c = c + v } } }
        specify do
          subject.tell(1).tell(1)
          subject << 1 << 1
          expect(subject.ask(0).value!).to eq 4
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
          expect(parent.ask!(nil)).to include(child)
          expect(child.ask!(nil)).to eq parent

          terminate_actors parent, child
        end
      end

      describe 'envelope' do
        subject { AdHoc.spawn(:subject) { -> _ { envelope } } }
        specify do
          envelope = subject.ask!('a')
          expect(envelope).to be_a_kind_of Envelope
          expect(envelope.message).to eq 'a'
          expect(envelope.ivar).to be_completed
          expect(envelope.ivar.value).to eq envelope
          expect(envelope.sender).to eq Thread.current
          terminate_actors subject
        end
      end

      describe 'termination' do
        subject do
          AdHoc.spawn(:parent) do
            child = AdHoc.spawn(:child) { -> v { v } }
            -> v { child }
          end
        end

        it 'terminates with all its children' do
          child = subject.ask! :child
          expect(subject.ask!(:terminated?)).to be_falsey
          subject.ask(:terminate!).wait
          expect(subject.ask!(:terminated?)).to be_truthy
          child.ask!(:terminated_event).wait
          expect(child.ask!(:terminated?)).to be_truthy

          terminate_actors subject, child
        end
      end

      describe 'dead letter routing' do
        it 'logs by deafault' do
          ping = Ping.spawn! :ping, []
          ping << :terminate!
          ping << 'asd'
          sleep 0.1
          # TODO
        end
      end

      describe 'message redirecting' do
        let(:parent) do
          AdHoc.spawn(:parent) do
            child = AdHoc.spawn(:child) { -> m { m+1 } }
            -> message do
              if message == :child
                child
              else
                redirect child
              end
            end
          end
        end

        it 'is evaluated by child' do
          expect(parent.ask!(1)).to eq 2
        end
      end

      it 'links' do
        queue   = Queue.new
        failure = nil
        # FIXME this leads to weird message processing ordering
        # failure = AdHoc.spawn(:failure) { -> m { terminate! } }
        monitor = AdHoc.spawn!(:monitor) do
          failure = AdHoc.spawn(:failure) { -> m { m } }
          failure << :link
          -> m { queue << [m, envelope.sender] }
        end
        failure << :hehe
        failure << :terminate!
        expect(queue.pop).to eq [:terminated, failure]

        terminate_actors monitor
      end

      it 'links atomically' do
        queue   = Queue.new
        failure = nil
        monitor = AdHoc.spawn!(:monitor) do
          failure = AdHoc.spawn(name: :failure, link: true) { -> m { m } }
          -> m { queue << [m, envelope.sender] }
        end

        failure << :hehe
        failure << :terminate!
        expect(queue.pop).to eq [:terminated, failure]

        terminate_actors monitor
      end

      describe 'pausing' do
        it 'pauses on error' do
          queue              = Queue.new
          resuming_behaviour = Behaviour.restarting_behaviour_definition.map do |c, args|
            if Behaviour::Supervising == c
              [c, [:resume!, :one_for_one]]
            else
              [c, args]
            end
          end

          test = AdHoc.spawn name: :tester, behaviour_definition: resuming_behaviour do
            actor = AdHoc.spawn name:                 :pausing,
                                behaviour_definition: Behaviour.restarting_behaviour_definition do
              queue << :init
              -> m { m == :add ? 1 : pass }
            end

            actor << :supervise
            queue << actor.ask!(:supervisor)
            actor << nil
            queue << actor.ask(:add)

            -> m do
              queue << m
            end
          end

          expect(queue.pop).to eq :init
          expect(queue.pop).to eq test
          expect(queue.pop.value).to eq 1
          expect(queue.pop).to eq :resumed
          terminate_actors test

          test = AdHoc.spawn name:                 :tester,
                             behaviour_definition: Behaviour.restarting_behaviour_definition do
            actor = AdHoc.spawn name:                 :pausing,
                                supervise:            true,
                                behaviour_definition: Behaviour.restarting_behaviour_definition do
              queue << :init
              -> m { m == :object_id ? self.object_id : pass }
            end

            queue << actor.ask!(:supervisor)
            queue << actor.ask!(:object_id)
            actor << nil
            queue << actor.ask(:object_id)

            -> m do
              queue << m
            end
          end

          expect(queue.pop).to eq :init
          expect(queue.pop).to eq test
          first_id  = queue.pop
          second_id = queue.pop.value
          expect(first_id).not_to eq second_id # context already reset
          expect(queue.pop).to eq :init # rebuilds context
          expect(queue.pop).to eq :reset
          terminate_actors test

          queue              = Queue.new
          resuming_behaviour = Behaviour.restarting_behaviour_definition.map do |c, args|
            if Behaviour::Supervising == c
              [c, [:restart!, :one_for_one]]
            else
              [c, args]
            end
          end

          test = AdHoc.spawn name: :tester, behaviour_definition: resuming_behaviour do
            actor = AdHoc.spawn name:                 :pausing,
                                behaviour_definition: Behaviour.restarting_behaviour_definition do
              queue << :init
              -> m { m == :add ? 1 : pass }
            end

            actor << :supervise
            queue << actor.ask!(:supervisor)
            actor << nil
            queue << actor.ask(:add)

            -> m do
              queue << m
            end
          end

          expect(queue.pop).to eq :init
          expect(queue.pop).to eq test
          expect(queue.pop.wait.reason).to be_a_kind_of(ActorTerminated)
          expect(queue.pop).to eq :init
          expect(queue.pop).to eq :restarted
          terminate_actors test
        end

      end

      describe 'pool' do
        it 'supports asks' do
          worker = Class.new Concurrent::Actor::Utils::AbstractWorker do
            def work(message)
              5 + message
            end
          end

          pool = Concurrent::Actor::Utils::Pool.spawn! 'pool', 5 do |balancer, index|
            worker.spawn name: "worker-#{index}", supervise: true, args: [balancer]
          end

          expect(pool.ask!(5)).to eq 10
          terminate_actors pool
        end
      end

    end
  end
end
