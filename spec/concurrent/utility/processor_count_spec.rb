require 'concurrent/utility/processor_counter'

module Concurrent

  RSpec.describe '#processor_count' do

    it 'returns a positive integer' do
      expect(Concurrent::processor_count).to be_a Integer
      expect(Concurrent::processor_count).to be >= 1
    end
  end

  RSpec.describe '#physical_processor_count' do

    it 'returns a positive integer' do
      expect(Concurrent::physical_processor_count).to be_a Integer
      expect(Concurrent::physical_processor_count).to be >= 1
    end
  end

  RSpec.describe '#cpu_quota' do

    let(:counter) { Concurrent::Utility::ProcessorCounter.new }

    it 'returns #compute_cpu_quota' do
      expect(Concurrent::cpu_quota).to be == counter.cpu_quota
    end

    it 'returns nil if no quota is detected' do
      if RbConfig::CONFIG["target_os"].include?("linux")
        expect(File).to receive(:exist?).twice.and_return(nil) # Checks for cgroups V1 and V2
      end
      expect(counter.cpu_quota).to be_nil
    end

    it 'returns nil if cgroups v2 sets no limit' do
      expect(RbConfig::CONFIG).to receive(:[]).with("target_os").and_return("linux")
      expect(File).to receive(:exist?).with("/sys/fs/cgroup/cpu.max").and_return(true)
      expect(File).to receive(:read).with("/sys/fs/cgroup/cpu.max").and_return("max 100000\n")
      expect(counter.cpu_quota).to be_nil
    end

    it 'returns a float if cgroups v2 sets a limit' do
      expect(RbConfig::CONFIG).to receive(:[]).with("target_os").and_return("linux")
      expect(File).to receive(:exist?).with("/sys/fs/cgroup/cpu.max").and_return(true)
      expect(File).to receive(:read).with("/sys/fs/cgroup/cpu.max").and_return("150000 100000\n")
      expect(counter.cpu_quota).to be == 1.5
    end

    it 'returns nil if cgroups v1 sets no limit' do
      expect(RbConfig::CONFIG).to receive(:[]).with("target_os").and_return("linux")
      expect(File).to receive(:exist?).with("/sys/fs/cgroup/cpu.max").and_return(false)
      expect(File).to receive(:exist?).with("/sys/fs/cgroup/cpu,cpuacct/cpu.cfs_quota_us").and_return(true)

      expect(File).to receive(:read).with("/sys/fs/cgroup/cpu,cpuacct/cpu.cfs_quota_us").and_return("max\n")
      expect(counter.cpu_quota).to be_nil
    end

    it 'returns nil if cgroups v1 and cpu.cfs_quota_us is -1' do
      expect(RbConfig::CONFIG).to receive(:[]).with("target_os").and_return("linux")
      expect(File).to receive(:exist?).with("/sys/fs/cgroup/cpu.max").and_return(false)
      expect(File).to receive(:exist?).with("/sys/fs/cgroup/cpu,cpuacct/cpu.cfs_quota_us").and_return(true)

      expect(File).to receive(:read).with("/sys/fs/cgroup/cpu,cpuacct/cpu.cfs_quota_us").and_return("-1\n")
      expect(counter.cpu_quota).to be_nil
    end

    it 'returns a float if cgroups v1 sets a limit' do
      expect(RbConfig::CONFIG).to receive(:[]).with("target_os").and_return("linux")
      expect(File).to receive(:exist?).with("/sys/fs/cgroup/cpu.max").and_return(false)
      expect(File).to receive(:exist?).with("/sys/fs/cgroup/cpu,cpuacct/cpu.cfs_quota_us").and_return(true)

      expect(File).to receive(:read).with("/sys/fs/cgroup/cpu,cpuacct/cpu.cfs_quota_us").and_return("150000\n")
      expect(File).to receive(:read).with("/sys/fs/cgroup/cpu,cpuacct/cpu.cfs_period_us").and_return("100000\n")
      expect(counter.cpu_quota).to be == 1.5
    end

  end

  RSpec.describe '#available_processor_count' do

    it 'returns #processor_count if #cpu_quota is nil' do
      expect(Concurrent::processor_counter).to receive(:cpu_quota).and_return(nil)
      available_processor_count = Concurrent.available_processor_count
      expect(available_processor_count).to be == Concurrent::processor_count
      expect(available_processor_count).to be_a Float
    end

    it 'returns #processor_count if #cpu_quota is higher' do
      expect(Concurrent::processor_counter).to receive(:cpu_quota).and_return(Concurrent::processor_count.to_f * 2)
      available_processor_count = Concurrent.available_processor_count
      expect(available_processor_count).to be == Concurrent::processor_count
      expect(available_processor_count).to be_a Float
    end

    it 'returns #cpu_quota if #cpu_quota is lower than #processor_count' do
      expect(Concurrent::processor_counter).to receive(:cpu_quota).and_return(Concurrent::processor_count.to_f / 2)
      available_processor_count = Concurrent.available_processor_count
      expect(available_processor_count).to be == Concurrent::processor_count.to_f / 2
      expect(available_processor_count).to be_a Float
    end

  end

  RSpec.describe '#cpu_shares' do
    let(:counter) { Concurrent::Utility::ProcessorCounter.new }

    it 'returns a float when cgroups v2 sets a cpu.weight' do
      expect(RbConfig::CONFIG).to receive(:[]).with("target_os").and_return("linux")
      expect(File).to receive(:exist?).with("/sys/fs/cgroup/cpu.weight").and_return(true)

      expect(File).to receive(:read).with("/sys/fs/cgroup/cpu.weight").and_return("10000\n")
      expect(counter.cpu_shares).to be == 256.0
    end

    it 'returns a float if cgroups v1 sets a cpu.shares' do
      expect(RbConfig::CONFIG).to receive(:[]).with("target_os").and_return("linux")
      expect(File).to receive(:exist?).with("/sys/fs/cgroup/cpu.weight").and_return(false)
      expect(File).to receive(:exist?).with("/sys/fs/cgroup/cpu/cpu.shares").and_return(true)

      expect(File).to receive(:read).with("/sys/fs/cgroup/cpu/cpu.shares").and_return("512\n")
      expect(counter.cpu_shares).to be == 0.5
    end

  end
end
