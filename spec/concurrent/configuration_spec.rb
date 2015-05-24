module Concurrent

  describe Configuration do

    before(:each) do
      # redundant - done in spec_helper.rb
      # done here again for explicitness
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

      specify '#terminate_pools! acts on all executors with auto_terminate: true' do
        expect(Concurrent.global_fast_executor).to receive(:kill).once.with(no_args).and_call_original
        expect(Concurrent.global_io_executor).to receive(:kill).once.with(no_args).and_call_original
        expect(Concurrent.global_timer_set).to receive(:kill).once.with(no_args).and_call_original
        Concurrent.terminate_pools!
      end
    end
  end
end
