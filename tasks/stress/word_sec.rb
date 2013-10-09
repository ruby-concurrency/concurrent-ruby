require 'rubygems'
require 'pp'

Node = Struct.new(:word, :next, :previous)

def index_in_words_array(word)
  return word[0].ord - ?a.ord unless word.empty?
end

def parse_word_from_token(token)

  token = token.strip # remove leading and trailing whitespace
  token = token.sub(/^\W+/, '') # remove leading punctuation
  token = token.sub(/\W+$/, '') # remove trailing punctuation

  if token =~ /\d/
    token = nil # reject words with digits
  else
    token = token.downcase # make lowercase
  end

  return token
end

def is_word_in_list?(list, word)
  found = false
  current = list
  until current.nil?
    if current.word == word
      found = true
      break
    end
    current = current.next
  end
  return found
end

def insert_word_into_list(list, word)

  if list.nil?
    list = Node.new(word, nil, nil)
  else
    list.previous = Node.new(word, list, nil)
    list = list.previous
  end

  return list
end

def print_word_list(list, letter, silent = false)

  count = 1
  until list.next.nil?
    count = count + 1
    list = list.next
  end

  unless silent
    descriptor = ( count == 1 ? 'word' : 'words' )
    puts "#{count} #{descriptor} beginning with '#{letter}'/'#{letter.upcase}':"

    word_list = ''
    until list.nil?
      word_list << list.word.upcase
      word_list << ', ' unless list.previous.nil?
      list = list.previous
    end

    puts "\t#{word_list}"
  end

  return count
end

def stats_from_words_array(array, silent = false)
  total = 0
  highest_count = 0
  most_common_letters = []

  array.each_with_index do |list, index|

    letter = (index + ?a.ord).chr

    unless list.nil?
      count = print_word_list(list, letter, silent)
      total = total + count

      if count == highest_count
        most_common_letters << letter
      elsif count > highest_count
        most_common_letters = [ letter ]
        highest_count = count
      end
    end
  end

  return {
    total: total,
    highest_count: highest_count,
    most_common_letters: most_common_letters
  }
end

def print_words_array(array)

  stats = stats_from_words_array(array)

  puts "\nThere were #{stats[:total]} unique words in the file."
  puts "The highest word count was #{stats[:highest_count]}."
  puts "\nLetter(s) that began words #{stats[:highest_count]} times were"
  stats[:most_common_letters].each { |letter| puts "\t'#{letter}'/'#{letter.upcase}'" }
end

def make_word_list(infile)

  # create and initialize the words array
  words = []
  (?a..?z).each { words << nil }

  total_word_count = 0

  # loop through each line in the input file
  infile.each_line do |line|

    # tokenize each line
    tokens = line.split(/\s/)

    # parse the words from the tokens
    tokens.each do |token|
      word = parse_word_from_token(token)
      unless word.nil?
        total_word_count = total_word_count + 1
        # build the list
        index = index_in_words_array(word)
        unless index.nil?
          list = words[index]
          unless is_word_in_list?(list, word)
            words[index] = insert_word_into_list(list, word)
          end
        end
      end
    end
  end

  return words, total_word_count
end

def main(argc, argv)

  # check the command-line arguments
  # abend if file name is not given
  if argv.size < 1
    p "File Error: Input file name not given - it should be the first argument"
    return 1
  end

  # attempt to open the file
  # abend on error
  begin
    infile = File.open(argv[0])
  rescue Exception => e
    puts "File Error: #{e.message}"
    return 2
  end

  words, total_word_count = make_word_list(infile)
  infile.close

  puts "Results for file #{File.basename(infile)}:  #{total_word_count} total words processed.\n\n"
  print_words_array(words)

  return 0

end

if $0 == __FILE__
  main(ARGV.size, ARGV)
end
