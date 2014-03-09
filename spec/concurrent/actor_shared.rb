def actor_shared_test_message_processor(*message)
  ## the first element of message is the text to echo
  ##   or an exception to be raised
  ## the second (optional) element of message is the number of seconds to sleep

  sleep(message[1]) if message.length > 1
  raise message.first if message.first.is_a?(Exception)
  $__actor_shared_test_last_message__ = message.first
end

share_examples_for :actor do

  let(:last_message){ $__actor_shared_test_last_message__ }

  before(:each) do
    last_message = nil
    actor_server.run!
    sleep(0.1)
  end

  after(:each) do
    actor_server.stop
  end

  context '#post' do

    it 'processes the message asynchronously' do
      actor_client.post('hello world')
      sleep(0.1)
      last_message.should eq 'hello world'
    end
  end

  context '#post?' do

    it 'returns an IVar' do
      ivar = actor_client.post?('hello world')
      ivar.should be_a(Concurrent::IVar)
      ivar.value(1) # let the actor finish
    end

    specify 'the IVar is :pending initially' do
      ivar = actor_client.post?('hello world', 0.1)
      ivar.should be_pending
      ivar.value(1) # let the actor finish
    end

    specify 'the IVar #value is set upon success' do
      ivar = actor_client.post?('hello world')
      sleep(0.1) # let the actor finish
      ivar.value.should eq 'hello world'
      ivar.should be_fulfilled
    end

    specify 'the IVar #reason is set upon failure' do
      error = StandardError.new
      ivar = actor_client.post?(error)
      ivar.value(0.1) # let the actor finish
      ivar.reason.should eq error
      ivar.should be_rejected
    end
  end

  context '#post!' do

    it 'blocks and waits for the response' do
      start = Time.now
      actor_client.post!(5, 'hello world').should eq 'hello world'
      (Time.now - start).should < 5
    end

    it 'blocks and raises exceptions thrown during processing' do
      error_class = Class.new(StandardError)
      start = Time.now
      expect {
        actor_client.post!(5, error_class.new)
      }.to raise_error(error_class)
      (Time.now - start).should < 5
    end

    it 'raises an exception when timeout occurs' do
      start = Time.now
      expect {
        actor_client.post!(0.1, 'timeout', 1)
      }.to raise_error(Concurrent::TimeoutError)
      (Time.now - start).should >= 0.1
    end
  end

  context '#forward' do

    before(:each) do
      @local = Class.new(Concurrent::Actor){
        attr_reader :last_message
        def act(*message)
          @last_message = actor_shared_test_message_processor(*message)
        end
      }.new
      @local.run!
      sleep(0.1)
    end

    after(:each) do
      @local.stop
      sleep(0.1)
    end

    it 'forwards the success value to the recipient' do
      actor_client.forward(@local, 'hello world')
      sleep(0.1)
      @local.last_message.should eq 'hello world'
    end

    it 'does not forward on failure' do
      actor_client.forward(@local, StandardError.new)
      sleep(0.1)
      @local.last_message.should be_nil
    end
  end
end
