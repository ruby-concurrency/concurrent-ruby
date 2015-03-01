module Concurrent

  describe Configuration do

    before(:each) do
      Concurrent.class_variable_set(
        :@@global_fast_executor,
        Concurrent::LazyReference.new{ Concurrent::ImmediateExecutor.new })
      Concurrent.class_variable_set(
        :@@global_io_executor,
        Concurrent::LazyReference.new{ Concurrent::ImmediateExecutor.new })
      Concurrent.class_variable_set(
        :@@global_timer_set,
        Concurrent::LazyReference.new{ Concurrent::ImmediateExecutor.new })
    end

    after(:each) do
      reset_gem_configuration
    end

    context 'global executors' do

      it 'creates a global timer set' do
        expect(Concurrent.global_timer_set).not_to be_nil
        expect(Concurrent.global_timer_set).to respond_to(:post)
      end

      it 'creates a global fast executor' do
        expect(Concurrent.global_fast_executor).not_to be_nil
        expect(Concurrent.global_fast_executor).to respond_to(:post)
      end

      it 'creates a global io executor' do
        expect(Concurrent.global_io_executor).not_to be_nil
        expect(Concurrent.global_io_executor).to respond_to(:post)
      end

      specify '#shutdown_global_executors acts on all global executors' do
        expect(Concurrent.global_fast_executor).to receive(:shutdown).with(no_args)
        expect(Concurrent.global_io_executor).to receive(:shutdown).with(no_args)
        expect(Concurrent.global_timer_set).to receive(:shutdown).with(no_args)
        Concurrent.shutdown_global_executors
      end

      specify '#kill_global_executors acts on all global executors' do
        expect(Concurrent.global_fast_executor).to receive(:kill).with(no_args)
        expect(Concurrent.global_io_executor).to receive(:kill).with(no_args)
        expect(Concurrent.global_timer_set).to receive(:kill).with(no_args)
        Concurrent.kill_global_executors
      end

      context '#wait_for_global_executors_termination' do

        it 'acts on all global executors' do
          expect(Concurrent.global_fast_executor).to receive(:wait_for_termination).with(0.1)
          expect(Concurrent.global_io_executor).to receive(:wait_for_termination).with(0.1)
          expect(Concurrent.global_timer_set).to receive(:wait_for_termination).with(0.1)
          Concurrent.wait_for_global_executors_termination(0.1)
        end
      end
    end
  end
end
