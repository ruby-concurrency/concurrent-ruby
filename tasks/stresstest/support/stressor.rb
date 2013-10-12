require_relative 'word_sec'

module Stressor

  FILE_PATH = File.dirname(__FILE__)

  TEST_FILES = {
    test_data_a: {
      file: 'TestdataA.txt',
      total: 13,
      highest_count: 4
    },
    test_data_b: {
      file: 'TestdataB.txt',
      total: 80,
      highest_count: 10
    },
    test_data_c: {
      file: 'TestdataC.txt',
      total: 180,
      highest_count: 17
    },
    the_art_of_war: {
      file: 'the_art_of_war.txt',
      total: 2653,
      highest_count: 294
    },
    the_republic: {
      file: 'the_republic.txt',
      total: 11497,
      highest_count: 1217
    },
    war_and_peace: {
      file: 'war_and_peace.txt',
      total: 20532,
      highest_count: 2302
    }
  }

  Tally = Class.new do
    attr_reader :good, :bad, :ugly, :total
    def initialize
      @good, @bad, @ugly, @total = 0, 0, 0, 0
      @mutex = Mutex.new
    end
    def add(result)
      @mutex.synchronize do
        case result
        when :good
          @good += 1
        when :bad
          @bad += 1
        when :ugly
          @ugly += 1
        end
        @total += 1
      end
    end
    def <<(result)
      self.add(result)
      return self
    end
  end

  def random_dataset
    d100 = rand(100) + 1
    if d100 < 28
      return :test_data_a
    elsif d100 < 56
      return :test_data_b
    elsif d100 < 84
      return :test_data_c
    elsif d100 < 94
      return :the_art_of_war
    elsif d100 < 100
      return :the_republic
    else
      return :war_and_peace
    end
  end
  module_function :random_dataset

  def test(dataset)
    dataset = TEST_FILES[dataset]
    infile = File.open(File.join(FILE_PATH, dataset[:file]))
    words, total_word_count = WordSec.make_word_list(infile)
    infile.close
    tally = WordSec.tally_from_words_array(words, true)
    if tally[:total] == dataset[:total] && tally[:highest_count] == dataset[:highest_count]
      return :good
    else
      return :bad
    end
  rescue => ex
    return :ugly
  end
  module_function :test
end
