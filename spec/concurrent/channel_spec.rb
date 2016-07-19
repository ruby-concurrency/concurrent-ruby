module Concurrent

  describe Channel, edge: true do
    def go(prc, *args)
      Channel::Runtime.go(prc, *args)
    end

    def meanwhile(*procs)
      threads = procs.map { |p| Thread.new(&p) }
      yield
      threads.each(&:join)
    end

    def time
      start = Time.now
      yield
      return Time.now - start
    end

    it 'receives when unbuffered' do
      c = Channel.new
      result = nil

      meanwhile(-> { result = c.recv }) do
        c << 'foo'
      end

      expect(result).to eq 'foo'
    end

    it 'can be closed' do
      c = Channel.new
      c.close
      
      expect(c).to be_closed
    end

    it 'does not receive when closed' do
      c = Channel.new
      c.close
      
      expect { c.recv }.to raise_error(Channel::Closed)
    end

    it 'receives when buffered' do
      messages = Channel.new(2)

      messages << 'buffered'
      messages << 'channel'

      expect(messages.recv).to eq 'buffered'
      expect(messages.recv).to eq 'channel'
    end

  # def test_fail_send_to_unbuffered_channel
  #   c = Channel.new
  #   expect {
  #      c.send 'foo'
  #   }.to raise_error('ThreadError', /No live threads left/)
  # end

    it 'sends when buffered' do
      c = Channel.new
      received = nil
      go -> { expect(c.recv).to eq 'foo' }
      c.send 'foo'
    end

  # def test_fill_buffered_channel
  #   c = Channel.new(1)
  #   c.send 'foo'
  #   expect {
  #      c.send 'foo'
  #   }.to raise_error('ThreadError', /No live threads left/)
  # end

    it 'sends on a single thread when buffered' do
      c = Channel.new(1)
      c.send 'foo'
      expect(c.recv).to eq 'foo'
    end

    it 'does not send when closed' do
      c = Channel.new
      c.close
      expect { c << 'foo' }.to raise_error(Channel::Closed) 
    end

    it 'does not receive when closed on a blocking channel' do
      c = Channel.new
      meanwhile(-> { expect { c.recv }.to raise_error(Channel::Closed) }) do
        sleep(0.1)
        c.close
      end
      expect(c).to be_closed
    end

    it 'raises on each recv when closed on a blocking channel' do
      c = Channel.new
      meanwhile(
        -> { expect { c.recv }.to raise_error(Channel::Closed) },
        -> { expect { c.recv }.to raise_error(Channel::Closed) },
        -> { expect { c.recv }.to raise_error(Channel::Closed) },
      ) do
        sleep(0.1)
        c.close
      end
      expect(c).to be_closed
    end

    it 'receives then closes on a buffered channel' do
      c = Channel.new(5)
      meanwhile(
        -> { sleep 0.1; expect(c.recv).to eq 1 },
        -> { sleep 0.2; expect(c.recv).to eq 2 },
        -> { sleep 0.3; expect(c.recv).to eq 3 },
        -> { sleep 0.4; expect { c.recv }.to raise_error(Channel::Closed)},
      ) do
        c << 1
        c << 2
        c << 3
        c.close
      end
      expect(c).to be_closed
    end

    it 'iterates over a buffered channel' do
      c = Channel.new(2)
      c << 1
      c << 2
      c.close

      expect(c.each.to_a).to eq [1, 2]
    end

  # it 'iterates over an unclosed buffered channel' do
  #   c = Channel.new(2)
  #   c << 1
  #   c << 2
  #
  #   expect {
  #      c.each.to_a
  #   }.to raise_error('ThreadError', /No live threads left/)
  # end

    it 'selects according to the receiving channel' do
      c1 = Channel.new
      c2 = Channel.new
      c3 = Channel.new
      c4 = Channel.new

      go -> { sleep(0.1); c1 << '1' }
      go -> { sleep(0.2); c2 << '2' }
      go -> { sleep(0.3); c3 << '3' }
      go -> { sleep(0.4); c4 << '4' }

      4.times do
        Channel.select(c1, c2, c3, c4) do |msg, c|
          case c
          when c1 then expect(msg).to eq '1'
          when c2 then expect(msg).to eq '2'
          when c3 then expect(msg).to eq '3'
          when c4 then expect(msg).to eq '4'
          end
        end
      end
    end

  end

end
