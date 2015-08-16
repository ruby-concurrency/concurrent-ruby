require_relative 'collection/priority_queue_shared'

module Concurrent

  describe PriorityQueue do

    it_should_behave_like :priority_queue

    context 'method aliases' do

      specify '#include? is aliased as #has_priority?' do
        10.times{|i| subject.push i}
        expect(subject).to have_priority(5)
      end

      specify '#length is aliased as #size' do
        10.times{|i| subject.push i}
        expect(subject.size).to eq 10
      end

      specify '#pop is aliased as #deq' do
        10.times{|i| subject.push i}
        expect(subject.deq).to eq 9
      end

      specify '#pop is aliased as #shift' do
        10.times{|i| subject.push i}
        expect(subject.shift).to eq 9
      end

      specify '#push is aliased as <<' do
        subject << 1
        expect(subject).to include(1)
      end

      specify '#push is aliased as enq' do
        subject.enq(1)
        expect(subject).to include(1)
      end
    end
  end
end
