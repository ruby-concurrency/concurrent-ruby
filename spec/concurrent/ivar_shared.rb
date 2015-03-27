require_relative 'dereferenceable_shared'
require_relative 'obligation_shared'
require_relative 'observable_shared'

shared_examples :ivar do

  it_should_behave_like :obligation
  it_should_behave_like :dereferenceable
  it_should_behave_like :observable

  context 'initialization' do

    it 'sets the state to incomplete' do
      expect(subject).to be_incomplete
    end
  end

  context '#set' do

    it 'sets the state to be fulfilled' do
      subject.set(14)
      expect(subject).to be_fulfilled
    end

    it 'sets the value' do
      subject.set(14)
      expect(subject.value).to eq 14
    end

    it 'raises an exception if set more than once' do
      subject.set(14)
      expect {subject.set(2)}.to raise_error(Concurrent::MultipleAssignmentError)
      expect(subject.value).to eq 14
    end

    it 'returns self' do
      expect(subject.set(42)).to eq subject
    end
    it 'fulfils when given a block which executes successfully' do
      subject.set{ 42 }
      expect(subject.value).to eq 42
    end

    it 'rejects when given a block which raises an exception' do
      expected = ArgumentError.new
      subject.set{ raise expected }
      expect(subject.reason).to eq expected
    end

    it 'raises an exception when given a value and a block' do
      expect {
        subject.set(42){ :guide }
      }.to raise_error(ArgumentError)
    end

    it 'raises an exception when given neither a value nor a block' do
      expect {
        subject.set
      }.to raise_error(ArgumentError)
    end
  end

  context '#fail' do

    it 'sets the state to be rejected' do
      subject.fail
      expect(subject).to be_rejected
    end

    it 'sets the value to be nil' do
      subject.fail
      expect(subject.value).to be_nil
    end

    it 'sets the reason to the given exception' do
      expected = ArgumentError.new
      subject.fail(expected)
      expect(subject.reason).to eq expected
    end

    it 'raises an exception if set more than once' do
      subject.fail
      expect {subject.fail}.to raise_error(Concurrent::MultipleAssignmentError)
      expect(subject.value).to be_nil
    end

    it 'defaults the reason to a StandardError' do
      subject.fail
      expect(subject.reason).to be_a StandardError
    end

    it 'returns self' do
      expect(subject.fail).to eq subject
    end
  end
end
