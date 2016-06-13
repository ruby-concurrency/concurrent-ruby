require 'rubygems'
require 'bundler/setup'
require 'pry'
require 'pp'

class MDFormatter

  def initialize(input_file, environment)
    @input_path  = input_file
    @environment = environment
    @output      = ''

    process_file input_file
  end

  def evaluate (code, line)
    eval(code, @environment, @input_path, line)
  end

  def process_ruby(part, start_line)
    lines  = part.lines
    chunks = []
    line   = ''

    while !lines.empty?
      line += lines.shift
      if Pry::Code.complete_expression? line
        chunks << line
        line = ''
      end
    end

    raise unless line.empty?

    chunk_lines = chunks.map { |chunk| [chunk, [chunk.split($/).size, 1].max] }
    indent      = 40

    line_count = start_line
    output     = ''
    chunk_lines.each do |chunk, lines|
      result = evaluate(chunk, line_count)
      if chunk.strip.empty? || chunk.include?('#')
        output << chunk
      else
        pre_lines = chunk.lines.to_a
        last_line = pre_lines.pop
        output << pre_lines.join

        if last_line =~ /\#$/
          output << last_line.gsub(/\#$/, '')
        else
          if last_line.size < indent && result.inspect.size < indent
            output << "%-#{indent}s %s" % [last_line.chomp, "# => #{result.inspect}\n"]
          else
            inspect_lines = result.pretty_inspect.lines
            output << last_line << "# => #{inspect_lines[0]}" << inspect_lines[1..-1].map { |l| format '#    %s', l }.join
          end
        end
      end
      line_count += lines
    end
    output
  end

  def process_file(input_path)
    output_path = input_path.gsub /\.in\.md$/, '.out.md'
    input       = File.read(input_path)
    parts       = input.split(/^(```\w*\n)/)

    # pp parts.map(&:lines)

    code_block  = nil
    line_count  = 1

    parts.each do |part|
      if part =~ /^```(\w+)$/
        code_block = $1
        @output << part
        line_count += 1
        next
      end

      if part =~ /^```$/
        code_block = nil
        @output << part
        line_count += 1
        next
      end

      if code_block == 'ruby'
        @output << process_ruby(part, line_count)
        line_count += part.lines.size
        next
      end

      @output << part
      line_count += part.lines.size
    end

    puts "#{input_path}\n -> #{output_path}"
    File.write(output_path, @output)
  rescue => ex
    puts "#{ex} (#{ex.class})\n#{ex.backtrace * "\n"}"

  end
end

input_paths = if ARGV.empty?
                Dir.glob("#{File.dirname(__FILE__)}/*.in.md")
              else
                ARGV
              end.map { |p| File.expand_path p }

input_paths.each_with_index do |input_path, i|

  pid = fork do
    require_relative 'init.rb'
    MDFormatter.new input_path, binding
  end

  Process.wait pid
end
