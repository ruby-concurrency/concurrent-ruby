require 'spec_helper'

module Concurrent

  describe 'dataflow' do

    let(:executor) { ImmediateExecutor.new }

    before(:each) do
      Concurrent.configure do |config|
        config.global_task_pool = Concurrent::PerThreadExecutor.new
      end
    end

    it 'raises an exception when no block given' do
      expect { Concurrent::dataflow }.to raise_error(ArgumentError)
    end

    it 'accepts zero or more dependencies' do
      Concurrent::dataflow(){0}
      Concurrent::dataflow(Future.execute{0}){0}
      Concurrent::dataflow(Future.execute{0}, Future.execute{0}){0}
    end

    it 'accepts uncompleted dependencies' do
      d = Future.new(executor: executor){0}
      Concurrent::dataflow(d){0}
      d.execute
    end

    it 'accepts completed dependencies' do
      d = Future.new(executor: executor){0}
      d.execute
      Concurrent::dataflow(d){0}
    end

    it 'raises an exception if any dependencies are not IVars' do
      expect { Concurrent::dataflow(nil) }.to raise_error(ArgumentError)
      expect { Concurrent::dataflow(Future.execute{0}, nil) }.to raise_error(ArgumentError)
      expect { Concurrent::dataflow(nil, Future.execute{0}) }.to raise_error(ArgumentError)
    end

    it 'returns a Future' do
      Concurrent::dataflow{0}.should be_a(Future)
    end

    context 'does not schedule the Future' do

      specify 'if no dependencies are completed' do
        d = Future.new(executor: executor){0}
        f = Concurrent::dataflow(d){0}
        f.should be_unscheduled
        d.execute
      end

      specify 'if one dependency of two is completed' do
        d1 = Future.new(executor: executor){0}
        d2 = Future.new(executor: executor){0}
        f = Concurrent::dataflow(d1, d2){0}
        d1.execute
        f.should be_unscheduled
        d2.execute
      end
    end

    context 'schedules the Future when all dependencies are available' do

      specify 'if there is just one' do
        d = Future.new(executor: executor){0}
        f = Concurrent::dataflow(d){0}
        d.execute
        f.value.should eq 0
      end

      specify 'if there is more than one' do
        d1 = Future.new(executor: executor){0}
        d2 = Future.new(executor: executor){0}
        f = Concurrent::dataflow(d1, d2){0}
        d1.execute
        d2.execute
        f.value.should eq 0
      end
    end

    context 'counts already executed dependencies' do

      specify 'if there is just one' do
        d = Future.new(executor: executor){0}
        d.execute
        f = Concurrent::dataflow(d){0}
        f.value.should eq 0
      end

      specify 'if there is more than one' do
        d1 = Future.new(executor: executor){0}
        d2 = Future.new(executor: executor){0}
        d1.execute
        d2.execute
        f = Concurrent::dataflow(d1, d2){0}
        f.value.should eq 0
      end
    end

    context 'passes the values of dependencies into the block' do

      specify 'if there is just one' do
        d = Future.new(executor: executor){14}
        f = Concurrent::dataflow(d) do |v|
          v
        end
        d.execute
        f.value.should eq 14
      end

      specify 'if there is more than one' do
        d1 = Future.new(executor: executor){14}
        d2 = Future.new(executor: executor){2}
        f = Concurrent::dataflow(d1, d2) do |v1, v2|
          v1 + v2
        end
        d1.execute
        d2.execute
        f.value.should eq 16
      end
    end

    context 'module function' do

      it 'can be called as Concurrent.dataflow' do

        def fib_with_dot(n)
          if n < 2
            Concurrent.dataflow { n }
          else
            n1 = fib_with_dot(n - 1)
            n2 = fib_with_dot(n - 2)
            Concurrent.dataflow(n1, n2) { n1.value + n2.value }
          end
        end

        expected = fib_with_dot(14)
        sleep(0.1)
        expected.value.should eq 377
      end

      it 'can be called as Concurrent::dataflow' do

        def fib_with_colons(n)
          if n < 2
            Concurrent::dataflow { n }
          else
            n1 = fib_with_colons(n - 1)
            n2 = fib_with_colons(n - 2)
            Concurrent::dataflow(n1, n2) { n1.value + n2.value }
          end
        end

        expected = fib_with_colons(14)
        sleep(0.1)
        expected.value.should eq 377
      end
    end
  end
end
