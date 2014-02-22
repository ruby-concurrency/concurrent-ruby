require 'spec_helper'

module Concurrent

  describe Dataflow do

    context 'dataflow' do

      before(:each) do
        Future.thread_pool = ImmediateExecutor.new
      end

      it 'raises an exception when no block given' do
        expect { Dataflow::dataflow }.to raise_error(ArgumentError)
      end

      it 'accepts zero or more dependencies' do
        Dataflow::dataflow(){0}
        Dataflow::dataflow(Future.execute{0}){0}
        Dataflow::dataflow(Future.execute{0}, Future.execute{0}){0}
      end

      it 'accepts uncompleted dependencies' do
        d = Future.new{0}
        Dataflow::dataflow(d){0}
        d.execute
      end

      it 'accepts completed dependencies' do
        d = Future.new{0}
        d.execute
        Dataflow::dataflow(d){0}
      end

      it 'raises an exception if any dependencies are not Futures' do
        expect { Dataflow::dataflow(nil) }.to raise_error(ArgumentError)
        expect { Dataflow::dataflow(Future.execute{0}, nil) }.to raise_error(ArgumentError)
        expect { Dataflow::dataflow(nil, Future.execute{0}) }.to raise_error(ArgumentError)
      end

      it 'returns a Future' do
        Dataflow::dataflow{0}.should be_a(Future)
      end

      context 'does not schedule the Future' do

        it 'if no dependencies are completed' do
          d = Future.new{0}
          f = Dataflow::dataflow(d){0}
          f.should be_unscheduled
          d.execute
        end

        it 'if one dependency of two is completed' do
          d1 = Future.new{0}
          d2 = Future.new{0}
          f = Dataflow::dataflow(d1, d2){0}
          d1.execute
          f.should be_unscheduled
          d2.execute
        end

      end

      context 'schedules the Future when all dependencies are available' do

        it 'if there is just one' do
          d = Future.new{0}
          f = Dataflow::dataflow(d){0}
          d.execute
          f.value.should  == 0
        end

        it 'if there is more than one' do
          d1 = Future.new{0}
          d2 = Future.new{0}
          f = Dataflow::dataflow(d1, d2){0}
          d1.execute
          d2.execute
          f.value.should  == 0
        end

      end

      context 'counts already executed dependencies' do

        it 'if there is just one' do
          d = Future.new{0}
          d.execute
          f = Dataflow::dataflow(d){0}
          f.value.should  == 0
        end

        it 'if there is more than one' do
          d1 = Future.new{0}
          d2 = Future.new{0}
          d1.execute
          d2.execute
          f = Dataflow::dataflow(d1, d2){0}
          f.value.should  == 0
        end

      end

      context 'passes the values of dependencies into the block' do

        it 'if there is just one' do
          d = Future.new{14}
          f = Dataflow::dataflow(d) do |v|
            v
          end
          d.execute
          f.value.should  == 14
        end

        it 'if there is more than one' do
          d1 = Future.new{14}
          d2 = Future.new{2}
          f = Dataflow::dataflow(d1, d2) do |v1, v2|
            v1 + v2
          end
          d1.execute
          d2.execute
          f.value.should  == 16
        end

      end

    end

  end

  describe Concurrent do

    context 'dataflow' do

      it 'is a utility method for Dataflow::dataflow' do
        expect { Concurrent::dataflow }.to raise_error(ArgumentError)
      end
      
    end

  end

end
