require 'yard'
require 'md_ruby_eval'

# TODO (pitr-ch 23-Feb-2017): find a proper place
module YARD
  module Templates::Helpers
    # The helper module for HTML templates.
    module HtmlHelper
      def signature_types(meth, link = true)
        meth = convert_method_to_overload(meth)
        if meth.respond_to?(:object) && !meth.has_tag?(:return)
          meth = meth.object
        end

        type = options.default_return || ""
        if meth.tag(:return) && meth.tag(:return).types
          types = meth.tags(:return).map { |t| t.types ? t.types : [] }.flatten.uniq
          first = link ? h(types.first) : format_types([types.first], false)
          # if types.size == 2 && types.last == 'nil'
          #   type = first + '<sup>?</sup>'
          # elsif types.size == 2 && types.last =~ /^(Array)?<#{Regexp.quote types.first}>$/
          #   type = first + '<sup>+</sup>'
          # elsif types.size > 2
          #   type = [first, '...'].join(', ')
          if types == ['void'] && options.hide_void_return
            type = ""
          else
            type = link ? h(types.join(", ")) : format_types(types, false)
          end
        elsif !type.empty?
          type = link ? h(type) : format_types([type], false)
        end
        type = "(#{type}) " unless type.empty?
        type
      end
    end
  end
end

root = File.expand_path File.join(File.dirname(__FILE__), '..')

cmd = lambda do |command|
  puts ">> executing: #{command}"
  puts ">>        in: #{Dir.pwd}"
  system command or raise "#{command} failed"
end

yard_doc = YARD::Rake::YardocTask.new(:yard)
yard_doc.before = -> do
  Dir.chdir File.join(__dir__, '..', 'doc') do
    cmd.call 'bundle exec md-ruby-eval --auto' or raise
  end
end

namespace :yard do

  desc 'Pushes generated documentation to github pages: http://ruby-concurrency.github.io/concurrent-ruby/'
  task :push => [:setup, :yard] do

    message = Dir.chdir(root) do
      `git log -n 1 --oneline`.strip
    end
    puts "Generating commit: #{message}"

    Dir.chdir "#{root}/yardoc" do
      cmd.call "git add -A"
      cmd.call "git commit -m '#{message}'"
      cmd.call 'git push origin gh-pages'
    end

  end

  desc 'Setups second clone in ./yardoc dir for pushing doc to github'
  task :setup do

    unless File.exist? "#{root}/yardoc/.git"
      cmd.call "rm -rf #{root}/yardoc" if File.exist?("#{root}/yardoc")
      Dir.chdir "#{root}" do
        cmd.call 'git clone --single-branch --branch gh-pages git@github.com:ruby-concurrency/concurrent-ruby.git ./yardoc'
      end
    end
    Dir.chdir "#{root}/yardoc" do
      cmd.call 'git fetch origin'
      cmd.call 'git reset --hard origin/gh-pages'
    end

  end

end
