RSpec.describe 'Concurrent' do
  describe 'Promises::Channel', edge: true do
    specify "#capacity" do
      channel = Concurrent::Promises::Channel.new 2
      expect(channel.capacity).to be 2
    end

    specify "#to_s" do
      channel = Concurrent::Promises::Channel.new
      expect(channel.to_s).to match(/Channel.*unlimited/)
      channel = Concurrent::Promises::Channel.new 2
      expect(channel.to_s).to match(/Channel.*0.*2/)
      channel.push :value
      expect(channel.to_s).to match(/Channel.*1.*2/)
    end

    specify "#(try_)push(_op)" do
      channel = Concurrent::Promises::Channel.new 1

      expect(channel.size).to eq 0
      expect(channel.try_push(:v1)).to be_truthy
      expect(channel.size).to eq 1
      expect(channel.try_push(:v2)).to be_falsey
      expect(channel.size).to eq 1

      channel = Concurrent::Promises::Channel.new 1
      expect(channel.push(:v1)).to eq channel
      expect(channel.size).to eq 1
      thread = in_thread { channel.push :v2 }
      is_sleeping thread
      expect(channel.size).to eq 1
      channel.pop
      expect(channel.size).to eq 1
      expect(thread.value).to eq channel
      channel.pop
      expect(channel.size).to eq 0

      channel = Concurrent::Promises::Channel.new 1
      expect(channel.push(:v1)).to eq channel
      expect(channel.size).to eq 1
      thread = in_thread { channel.push :v2, 0.01 }
      is_sleeping thread
      expect(channel.size).to eq 1
      expect(thread.value).to eq false
      channel.pop
      expect(channel.size).to eq 0
      expect(channel.push(:v3, 0)).to eq true
      expect(channel.size).to eq 1
      thread = in_thread { channel.push :v2, 1 }
      is_sleeping thread
      channel.pop
      expect(channel.size).to eq 1
      expect(thread.value).to eq true

      channel = Concurrent::Promises::Channel.new 1
      expect(channel.push_op(:v1).value!).to eq channel
      expect(channel.size).to eq 1
      push_op = channel.push_op :v2
      expect(channel.size).to eq 1
      expect(push_op.pending?).to be_truthy
      channel.pop
      expect(channel.size).to eq 1
      expect(push_op.value!).to eq channel
      channel.pop
      expect(channel.size).to eq 0
    end

    specify "#(try_)pop(_op)" do
      channel = Concurrent::Promises::Channel.new 1
      channel.push :v1

      expect(channel.size).to eq 1
      expect(channel.try_pop).to eq :v1
      expect(channel.size).to eq 0
      expect(channel.try_pop).to eq nil
      expect(channel.size).to eq 0

      channel = Concurrent::Promises::Channel.new 1
      channel.push :v1
      expect(channel.pop).to eq :v1
      expect(channel.size).to eq 0
      thread = in_thread { channel.pop }
      is_sleeping thread
      expect(channel.size).to eq 0
      channel.push :v2
      expect(thread.value).to eq :v2
      expect(channel.size).to eq 0

      channel = Concurrent::Promises::Channel.new 1
      channel.push :v1
      expect(channel.pop).to eq :v1
      expect(channel.size).to eq 0
      thread = in_thread { channel.pop 0.01 }
      is_sleeping thread
      expect(channel.size).to eq 0
      expect(thread.value).to eq nil
      channel.push :v2
      expect(channel.size).to eq 1
      expect(channel.pop).to eq :v2
      expect(channel.size).to eq 0
      thread = in_thread { channel.pop 1 }
      is_sleeping thread
      channel.push :v3
      expect(channel.size).to eq 0
      expect(thread.value).to eq :v3
      channel.push :v4
      expect(channel.pop(0)).to eq :v4

      channel = Concurrent::Promises::Channel.new 1
      channel.push :v1
      expect(channel.pop_op.value!).to eq :v1
      expect(channel.size).to eq 0
      pop_op = channel.pop_op
      expect(channel.size).to eq 0
      expect(pop_op.pending?).to be_truthy
      channel.push :v2
      expect(channel.size).to eq 0
      expect(pop_op.value!).to eq :v2
    end

    specify "#(try_)select(_op)" do
      channel1 = Concurrent::Promises::Channel.new 1
      channel2 = Concurrent::Promises::Channel.new 1

      expect(channel1.try_select(channel2)).to eq nil
      expect(Concurrent::Promises::Channel.try_select([channel1, channel2])).to eq nil
      channel1.push :v1
      expect(channel1.try_select(channel2)).to eq [channel1, :v1]
      expect(channel1.size).to eq 0
      expect(channel2.size).to eq 0

      channel1 = Concurrent::Promises::Channel.new 1
      channel2 = Concurrent::Promises::Channel.new 1
      channel1.push :v1
      expect(Concurrent::Promises::Channel.select([channel1, channel2])).to eq [channel1, :v1]
      channel1.push :v1
      expect(channel1.select(channel2)).to eq [channel1, :v1]
      expect(channel1.size).to eq 0
      expect(channel2.size).to eq 0
      thread = in_thread { channel1.select(channel2) }
      is_sleeping thread
      expect(channel1.size).to eq 0
      channel2.push :v2
      expect(thread.value).to eq [channel2, :v2]
      expect(channel1.size).to eq 0
      expect(channel2.size).to eq 0

      channel1 = Concurrent::Promises::Channel.new 1
      channel2 = Concurrent::Promises::Channel.new 1
      channel1.push :v1
      expect(channel1.select(channel2)).to eq [channel1, :v1]
      expect(channel1.size).to eq 0
      expect(channel2.size).to eq 0
      thread = in_thread { channel1.select(channel2, 0.01) }
      is_sleeping thread
      expect(channel1.size).to eq 0
      expect(channel2.size).to eq 0
      expect(thread.value).to eq nil
      channel2.push :v2
      expect(channel1.size).to eq 0
      expect(channel2.size).to eq 1
      expect(channel2.select(channel1)).to eq [channel2, :v2]
      expect(channel1.size).to eq 0
      expect(channel2.size).to eq 0

      channel1 = Concurrent::Promises::Channel.new 1
      channel2 = Concurrent::Promises::Channel.new 1
      channel1.push :v1
      expect(channel1.select_op(channel2).value!).to eq [channel1, :v1]
      channel1.push :v1
      expect(Concurrent::Promises::Channel.select_op([channel1, channel2]).value!).to eq [channel1, :v1]
      expect(channel1.size).to eq 0
      expect(channel2.size).to eq 0
      select_op = channel2.select_op(channel1)
      expect(channel1.size).to eq 0
      expect(channel2.size).to eq 0
      expect(select_op.pending?).to be_truthy
      channel2.push :v2
      expect(channel1.size).to eq 0
      expect(channel2.size).to eq 0
      expect(select_op.value!).to eq [channel2, :v2]
    end

    specify 'exchanging' do
      channel = Concurrent::Promises::Channel.new 0
      thread  = in_thread { channel.pop }
      is_sleeping thread
      expect(channel.try_push(:v1)).to be_truthy
      push = channel.push_op(:v2)
      expect(push.pending?).to be_truthy
      expect(thread.value).to eq :v1
      expect(channel.pop).to eq :v2
      expect(push.pending?).to be_falsey

      ch1       = Concurrent::Promises::Channel.new 0
      ch2       = Concurrent::Promises::Channel.new 0
      selection = ch1.select_op(ch2)
      expect(ch2.try_push(:v3)).to be_truthy
      expect(selection.value!).to eq [ch2, :v3]
    end

    specify 'integration' do
      ch1 = Concurrent::Promises::Channel.new
      ch2 = Concurrent::Promises::Channel.new
      ch3 = Concurrent::Promises::Channel.new

      add = -> *_ do
        (ch1.pop_op & ch2.pop_op).then do |a, b|
          if a == :done && b == :done
            :done
          else
            # do not add again until push is done
            ch3.push_op(a + b).then(&add)
          end
        end
      end

      ch1.push_op 1
      ch2.push_op 2
      ch1.push_op 'a'
      ch2.push_op 'b'
      ch1.push_op nil
      ch2.push_op true

      result = Concurrent::Promises.future(&add).run.result
      expect(result[0..1]).to eq [false, nil]
      expect(result[2]).to be_a_kind_of(NoMethodError)
      expect(ch3.pop_op.value!).to eq 3
      expect(ch3.pop_op.value!).to eq 'ab'

      ch1.push_op 1
      ch2.push_op 2
      ch1.push_op 'a'
      ch2.push_op 'b'
      ch1.push_op :done
      ch2.push_op :done

      expect(Concurrent::Promises.future(&add).run.result).to eq [true, :done, nil]
      expect(ch3.pop_op.value!).to eq 3
      expect(ch3.pop_op.value!).to eq 'ab'
    end
  end
end
