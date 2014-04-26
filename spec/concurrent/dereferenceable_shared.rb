require 'spec_helper'

share_examples_for :dereferenceable do

  it 'defaults :dup_on_deref to false' do
    value = 'value'
    value.should_not_receive(:dup).with(any_args)

    subject = dereferenceable_subject(value)
    subject.value.should eq 'value'

    subject = dereferenceable_subject(value, dup_on_deref: false)
    subject.value.should eq 'value'

    subject = dereferenceable_subject(value, dup: false)
    subject.value.should eq 'value'
  end

  it 'calls #dup when the :dup_on_deref option is true' do
    value = 'value'

    subject = dereferenceable_subject(value, dup_on_deref: true)
    subject.value.object_id.should_not eq value.object_id
    subject.value.should eq 'value'

    subject = dereferenceable_subject(value, dup: true)
    subject.value.object_id.should_not eq value.object_id
    subject.value.should eq 'value'
  end

  it 'defaults :freeze_on_deref to false' do
    value = 'value'
    value.should_not_receive(:freeze).with(any_args)

    subject = dereferenceable_subject(value)
    subject.value.should eq 'value'

    subject = dereferenceable_subject(value, freeze_on_deref: false)
    subject.value.should eq 'value'

    subject = dereferenceable_subject(value, freeze: false)
    subject.value.should eq 'value'
  end

  it 'calls #freeze when the :freeze_on_deref option is true' do
    value = 'value'

    subject = dereferenceable_subject(value, freeze_on_deref: true)
    subject.value.should be_frozen
    subject.value.should eq 'value'

    subject = dereferenceable_subject(value, freeze: true)
    subject.value.should be_frozen
    subject.value.should eq 'value'
  end

  it 'defaults :copy_on_deref to nil' do
    value = 'value'

    subject = dereferenceable_subject(value)
    subject.value.object_id.should == value.object_id
    subject.value.should eq 'value'

    subject = dereferenceable_subject(value, copy_on_deref: nil)
    subject.value.object_id.should == value.object_id
    subject.value.should eq 'value'

    subject = dereferenceable_subject(value, copy: nil)
    subject.value.object_id.should == value.object_id
    subject.value.should eq 'value'
  end

  it 'calls the block when the :copy_on_deref option is passed a proc' do
    value = 'value'
    copy = proc{|val| 'copy' }

    subject = dereferenceable_subject(value, copy_on_deref: copy)
    subject.value.object_id.should_not == value.object_id

    subject = dereferenceable_subject(value, copy: copy)
    subject.value.object_id.should_not == value.object_id
  end

  it 'calls the :copy block first followed by #dup followed by #freeze' do
    value = 'value'
    copied = 'copied'
    dup = 'dup'
    frozen = 'frozen'
    copy = proc{|val| copied }

    copied.should_receive(:dup).at_least(:once).with(no_args).and_return(dup)
    dup.should_receive(:freeze).at_least(:once).with(no_args).and_return(frozen)

    subject = dereferenceable_subject(value, dup_on_deref: true, freeze_on_deref: true, copy_on_deref: copy)
    subject.value.should eq frozen
  end

  it 'does not call #dup when #dup_on_deref is set and the value is nil' do
    allow_message_expectations_on_nil
    result = nil
    result.should_not_receive(:dup).with(any_args)
    subject = dereferenceable_subject(result, dup_on_deref: true)
    subject.value
  end

  it 'does not call #freeze when #freeze_on_deref is set and the value is nil' do
    allow_message_expectations_on_nil
    result = nil
    result.should_not_receive(:freeze).with(any_args)
    subject = dereferenceable_subject(result, freeze_on_deref: true)
    subject.value
  end

  it 'does not call the #copy_on_deref block when the value is nil' do
    copier = proc { 42 }
    subject = dereferenceable_subject(nil, copy_on_deref: copier)
    subject.value.should be_nil
  end

  it 'locks when all options are false' do
    subject = dereferenceable_subject(0)
    mutex = double('mutex')
    subject.stub(:mutex).and_return(mutex)
    mutex.should_receive(:lock).at_least(:once)
    mutex.should_receive(:unlock).at_least(:once)
    subject.value
  end

  it 'supports dereference flags with observers' do
    if dereferenceable_subject(0).respond_to?(:add_observer)

      result = 'result'
      result.should_receive(:dup).at_least(:once).and_return(result)
      result.should_receive(:freeze).at_least(:once).and_return(result)
      copier = proc { result }

      observer = double('observer')
      observer.should_receive(:update).at_least(:once).with(any_args)

      subject = dereferenceable_observable(dup_on_deref: true, freeze_on_deref: true, copy_on_deref: copier)

      subject.add_observer(observer)
      execute_dereferenceable(subject)
    end
  end
end
