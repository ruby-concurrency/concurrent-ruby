require 'timeout'

module Concurrent

  describe Synchronization do

    shared_examples :attr_volatile do

      specify 'older writes are always visible' do
        # store              = BClass.new
        store.not_volatile = 0
        store.volatile     = 0

        t1 = Thread.new do
          Thread.abort_on_exception = true
          1000000000.times do |i|
            store.not_volatile = i
            store.volatile     = i
          end
        end

        t2 = Thread.new do
          10.times do
            volatile     = store.volatile
            not_volatile = store.not_volatile
            expect(not_volatile).to be >= volatile
            Thread.pass
          end
        end

        t2.join
        t1.kill
      end
    end

    describe Synchronization::Object do
      class AAClass < Synchronization::Object
      end

      class ABClass < AAClass
        safe_initialization!
      end

      class ACClass < ABClass
      end

      class ADClass < ACClass
        safe_initialization!
      end

      it 'does not ensure visibility when not needed' do
        expect_any_instance_of(AAClass).not_to receive(:full_memory_barrier)
        AAClass.new
      end

      it "does ensure visibility when specified" do
        expect_any_instance_of(ABClass).to receive(:full_memory_barrier)
        ABClass.new
      end

      it "does ensure visibility when specified in a parent" do
        expect_any_instance_of(ACClass).to receive(:full_memory_barrier)
        ACClass.new
      end

      it "does ensure visibility once when specified in child again" do
        expect_any_instance_of(ADClass).to receive(:full_memory_barrier)
        ADClass.new
      end

      # TODO (pitr 12-Sep-2015): give a whole gem a pass to find classes with final fields without using the convention and migrate
      Synchronization::Object.ensure_safe_initialization_when_final_fields_are_present

      class VolatileFieldClass < Synchronization::Object
        attr_volatile :volatile
        attr_accessor :not_volatile
      end

      let(:store) { VolatileFieldClass.new }
      it_should_behave_like :attr_volatile
    end

    describe Synchronization::LockableObject do

      class BClass < Synchronization::LockableObject
        safe_initialization!

        attr_volatile :volatile
        attr_accessor :not_volatile

        def initialize(value = nil)
          super()
          @Final = value
          ns_initialize
        end

        def final
          @Final
        end

        def count
          synchronize { @count += 1 }
        end

        def wait(timeout = nil)
          synchronize { ns_wait(timeout) }
        end

        public :synchronize

        private

        def ns_initialize
          @count = 0
        end
      end

      subject { BClass.new }

      describe '#wait' do

        it 'puts the current thread to sleep' do
          t = Thread.new do
            Thread.abort_on_exception = true
            subject.wait
          end
          sleep 0.1
          expect(t.status).to eq 'sleep'
        end

        it 'allows the sleeping thread to be killed' do
          t = Thread.new do
            Thread.abort_on_exception = true
            subject.wait rescue nil
          end
          sleep 0.1
          t.kill
          sleep 0.1
          expect(t.status).to eq false
          expect(t.alive?).to eq false
        end

        it 'releases the lock on the current object' do
          expect { Timeout.timeout(3) do
            t = Thread.new { subject.wait }
            sleep 0.1
            expect(t.status).to eq 'sleep'
            subject.synchronize {} # we will deadlock here if #wait doesn't release lock
          end }.not_to raise_error
        end

        it 'can be called from within a #synchronize block' do
          expect { Timeout.timeout(3) do
            # #wait should release lock, even if it was already held on entry
            t = Thread.new { subject.synchronize { subject.wait } }
            sleep 0.1
            expect(t.status).to eq 'sleep'
            subject.synchronize {} # we will deadlock here if lock wasn't released
          end }.not_to raise_error
        end
      end

      describe '#synchronize' do
        it 'allows only one thread to execute count' do
          threads = 10.times.map { Thread.new(subject) { 100.times { subject.count } } }
          threads.each(&:join)
          expect(subject.count).to eq 1001
        end
      end

      describe 'signaling' do
        pending 'for now pending, tested pretty well by Event'
      end

      specify 'final field always visible' do
        store = BClass.new 'asd'
        t1    = Thread.new { 1000000000.times { |i| store = BClass.new i.to_s } }
        t2    = Thread.new { 10.times { expect(store.final).not_to be_nil; Thread.pass } }
        t2.join
        t1.kill
      end

      let(:store) { BClass.new }
      it_should_behave_like :attr_volatile
    end

    describe 'Concurrent::Synchronization::Volatile module' do
      class BareClass
        include Synchronization::Volatile

        attr_volatile :volatile
        attr_accessor :not_volatile
      end

      let(:store) { BareClass.new }
      it_should_behave_like :attr_volatile
    end

    describe 'attr_volatile_with_cas' do
      specify do
        a = Class.new(Synchronization::Object) do
          attr_volatile_with_cas :a

          def initialize(*rest)
            super
            self.a = :a
          end
        end

        b = Class.new(a) do
          attr_volatile_with_cas :b

          def initialize
            super
            self.b = :b
          end
        end

        instance = b.new
        expect(instance.a).to be == :a
        expect(instance.b).to be == :b
      end
    end

  end
end
