#!/usr/bin/env ruby

# Copyright (c) 2008 Alan Norbauer <altano@gmail.com>

require 'pp'
require 'stringio'
require 'singleton'
require 'tempfile'

# This makes it possible to capture stdout, stderr, and exitstatus of an
# external command.  (Note that this is heavily modified from the original)
# Thanks to Ara.T.Howard <ara [dot] t [dot] howard [at] noaa [dot] gov>
# http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/167206
class Redirector
  include Singleton
  
  def initialize
    @ruby = 'ruby'
    @script = tempfile
    @script.write <<-ruby
      stdout, stderr = ARGV.shift, ARGV.shift
      File::unlink out rescue nil
      File::unlink err rescue nil
      STDOUT.reopen(open(stdout,"w"))
      STDERR.reopen(open(stderr,"w"))
      system(ARGV.join(' '))
      exit($?.exitstatus)
    ruby
    @script.close
  end
  
  def run(command)
    tout = tempfile
    terr = tempfile
    stdout = tout.path
    stderr = terr.path
    
    system "#{ @ruby } #{ @script.path } #{ stdout } #{ stderr } #{ command }"
    ret = IO::read(stdout), IO::read(stderr), $?.exitstatus, $?.success?
    
    tout.close! if tout
    terr.close! if terr
    
    ret
  end
  
  def tempfile
    # I don't think the pid and rand are necessary????
    t = Tempfile::new('tattletale')
    puts t.path
    return t
  end
end

def capture_pp_output(*args)
  old_out = $stdout
  begin
    s=StringIO.new
    $stdout=s
    pp(*args)
  ensure
    $stdout=old_out
  end
  s.string
end

# Parse command line options
if ARGV.empty?
  puts "Usage: #{__FILE__} /some/command/to/execute [options]"
  exit(1)
end

class Output
  include Singleton
  
  def initialize
    @output = ''
  end
  
  def tt(hsh)
    @output << <<-template
#{hsh.keys.first}:
#{hsh.values.first}\n
template
  end
  
  def to_s
    @output + "--------------------------------------------------------------\n\n"
  end
end

def o(*args)
  Output.instance.tt(*args)
end

command = ARGV.join(' ')
o "COMMAND TO EXECUTE" => command

start_time = Time.now
o "TIME OF EXECUTION" => Time.now.strftime("%Y-%m-%d %I:%M%p")
stdout, stderr, exitstatus, success = Redirector.instance.run(command)
end_time = Time.now

o "ELAPSED RUNNING TIME (in seconds)" => end_time - start_time
o "SUCCESSFULLY RAN?" => success
o "EXIT STATUS" => exitstatus if !success
o "STDOUT" => stdout
o "STDERR" => stderr
o "ENVIRONMENT VARIABLES" => capture_pp_output(ENV.sort)

output_file_path = File.expand_path("~/.tattletale_history")
File.open(output_file_path, File::WRONLY|File::APPEND|File::CREAT, 0666) do |f|
  f.puts Output.instance.to_s
end
