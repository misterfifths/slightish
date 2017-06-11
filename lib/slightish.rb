# -*- coding: utf-8 -*-

require 'fileutils'
require 'tmpdir'
require 'open3'

require 'slightish/version'

class String
  def self.color_output?
      STDOUT.isatty
  end

  { :red     => 1,
    :green   => 2,
    :yellow  => 3,
    :blue    => 4,
    :gray    => 7
  }.each do |name, code|
      bg_name = ('bg_' + name.to_s).to_sym

      if color_output?
          define_method(name) { "\e[#{code + 30}m#{self}\e[39m" }
          define_method(bg_name) { "\e[#{code + 40}m#{self}\e[49m" }
      else
          define_method(name) { self }
          define_method(bg_name) { self }
      end
  end

  { :bold => 1, :faint => 2 }.each do |name, code|
      if color_output?
          define_method(name) { "\e[#{code}m#{self}\e[22m" }
      else
          define_method(name) { self }
      end
  end

  def expand(chdir: nil, source: nil)
    # $VARIABLE
    res = gsub(/\$(?<var_name>[[:alnum:]_]+)/) { |match| ENV.fetch(Regexp.last_match(:var_name), match) }
    # ${VARIABLE}
    res.gsub!(/\$\{(?<var_name>[[:alnum:]_]+)\}/) { |match| ENV.fetch(Regexp.last_match(:var_name), match) }

    # $(COMMAND)
    res.gsub!(/\$\((?<cmd>[^\)]+)\)/) { _capture_stdout_with_logging(Regexp.last_match(:cmd), chdir, source) }
    # `COMMAND`
    res.gsub!(/`(?<cmd>[^`]+)`/) { _capture_stdout_with_logging(Regexp.last_match(:cmd), chdir, source) }

    res
  end

  private

  def _capture_stdout_with_logging(cmd, chdir, source)
    stdout, stderr, status = Open3.capture3(cmd, {:chdir => chdir})

    unless stderr.empty?
      message = 'warning: stderr from command substitution ('
      message += source + '; ' unless source.nil? || source.empty?
      message += "'#{cmd}') will be ignored"
      STDERR.puts(message.yellow)
    end

    unless status.exitstatus == 0
      message = "warning: nonzero exit code ({#status.exitstatus}) from command substitution ("
      message += source + '; ' unless source.nil? || source.empty?
      message += "'#{cmd}')"
      STDERR.puts(message.yellow)
    end

    stdout.chomp
  end
end

module Slightish
  class Sandbox
    attr_reader :path

    def initialize(template_dir: nil, prefix: 'slightish')
      @path = Dir.mktmpdir(prefix)

      unless template_dir.nil?
        # The '.' prevents cp_r from making a new directory at the destination --
        # kind of the equivalent of '/*' in bash.
        FileUtils.cp_r(File.join(template_dir, '.'), @path)
      end

      if block_given?
        begin
          Dir.chdir(@path) { yield self }
        ensure
          delete
        end
      end
    end

    def delete
      FileUtils.remove_entry_secure(@path)
    end
  end

  class TestCase
    attr_reader :source_file
    attr_accessor :start_line, :end_line
    attr_reader :raw_command, :command
    attr_reader :raw_expected_output, :expected_output
    attr_reader :raw_expected_error_output, :expected_error_output
    attr_accessor :expected_exit_code
    attr_reader :actual_output, :actual_error_output, :actual_exit_code

    def initialize(source_file)
      @source_file = source_file
      @expected_exit_code = 0
    end

    def run(sandbox)
      expand(sandbox)

      @actual_output, @actual_error_output, process_status = Open3.capture3(@command, {:chdir => sandbox.path})
      @actual_output.chomp!
      @actual_error_output.chomp!
      @actual_exit_code = process_status.exitstatus
    end

    def passed?
      @actual_output == (@expected_output || '') &&
      @actual_error_output == (@expected_error_output || '') &&
      @actual_exit_code == @expected_exit_code
    end

    def failure_description
      res = ''

      if @actual_output != (@expected_output || '')
        if @expected_output.nil?
          res += "Expected stdout: empty\n".red.bold
        else
          res += "Expected stdout:\n".red.bold
          res += @expected_output.gray + "\n"
        end

        if @actual_output.empty?
          res += "Actual stdout: empty".green.bold
        else
          res += "Actual stdout:\n".green.bold
          res += @actual_output.gray
        end
      end

      if @actual_error_output != (@expected_error_output || '')
        res += "\n\n" unless res == ''
        if @expected_error_output.nil?
          res += "Expected stderr: empty\n".red.bold
        else
          res += "Expected stderr:\n".red.bold
          res += (@expected_error_output || '').gray + "\n"
        end

        if @actual_error_output.empty?
          res += "Actual stderr: empty".green.bold
        else
          res += "Actual stderr:\n".green.bold
          res += @actual_error_output.gray
        end
      end

      if @actual_exit_code != @expected_exit_code
        res += "\n\n" unless res == ''
        res += "Expected exit code: ".red.bold + @expected_exit_code.to_s.gray + "\n"
        res += "Actual error code: ".green.bold + @actual_exit_code.to_s.gray
      end

      res
    end

    def source_description
      if @start_line == @end_line
        return "#{@source_file}:@{@start_line}"
      else
        return "#{@source_file}:#{@start_line}-#{@end_line}"
      end
    end

    def append_command(str)
      if @raw_command.nil?
        @raw_command = str
      else
        @raw_command += "\n" + str
      end
    end

    def append_expected_output(str)
      if @raw_expected_output.nil?
        @raw_expected_output = str
      else
        @raw_expected_output += "\n" + str
      end
    end
    
    def append_expected_error_output(str)
      if @raw_expected_error_output.nil?
        @raw_expected_error_output = str
      else
        @raw_expected_error_output += "\n" + str
      end
    end

    private

    def expand(sandbox)
      @command = @raw_command.expand(chdir: sandbox.path, source: source_description)
      @expected_output = @raw_expected_output.expand(chdir: sandbox.path, source: source_description) unless @raw_expected_output.nil?
      @expected_error_output = @raw_expected_error_output.expand(chdir: sandbox.path, source: source_description) unless @raw_expected_error_output.nil?
    end
  end
  
  class TestSuite
    attr_reader :name, :path, :test_cases

    def initialize(path)
      @path = path
      @name = File.basename(path)

      parse(path, File.read(path))
    end

    def run
      sandbox = Sandbox.new(template_dir: ENV['SLIGHTISH_TEMPLATE_DIR'])

      begin
        @test_cases.each do |test|
          test.run(sandbox)
          unless test.passed?
            puts("❌  #{test.source_description}".bold)
            puts(test.failure_description)
            puts()
          end
        end
      ensure
        sandbox.delete
      end
    end

    def passed?
      @test_cases.all? { |test| test.passed? }
    end

    def passed_count
      @test_cases.count { |test| test.passed? }
    end

    def failed_count
      @test_cases.count { |test| !test.passed? }
    end

    private

    class ParseState
      AWAITING_COMMAND = 0
      READING_MULTILINE_COMMAND = 1
      AWAITING_RESULT_OR_COMMAND = 2
      AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND = 3

      # Start in AWAITING_COMMAND

      # AWAITING_COMMAND -> READING_MULTILINE_COMMAND on '$ .*\' (starting a new command)
      # AWAITING_COMMAND -> AWAITING_RESULT_OR_COMMAND on '$ .*' (starting a new command)
      # any other meaningful line on AWAITING_COMMAND is an error
      # EOF is fine; no stdout or stderr, and expected exit code = 0

      # READING_MULTILINE_COMMAND -> READING_MULTILINE_COMMAND on '.*\'
      # READING_MULTILINE_COMMAND -> AWAITING_RESULT_OR_COMMAND on '.*'
      # EOF from this state is error-ish, but eh, not worth it

      # AWAITING_RESULT_OR_COMMAND -> AWAITING_RESULT_OR_COMMAND on '| .*'
      # AWAITING_RESULT_OR_COMMAND -> AWAITING_COMMAND on '? \d+' (starting a new command)
      # AWAITING_RESULT_OR_COMMAND -> READING_MULTILINE_COMMAND on '$ .*\' (starting a new command; exit code on previous command is 0)
      # AWAITING_RESULT_OR_COMMAND -> AWAITING_RESULT_OR_COMMAND on '$ .*' (starting a new command; exit code on previous command is 0)
      # AWAITING_RESULT_OR_COMMAND -> AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND on '@ .*' (accumulating stderr; stdout lines are no longer acceptable)
      # EOF from here is fine; expected exit code = 0

      # AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND -> AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND on '@ .*'
      # AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND -> AWAITING_COMMAND on '? \d+' (starting new command)
      # AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND -> READING_MULTILINE_COMMAND on '$ .*\' (starting a new command; exit code on previous command is 0)
      # AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND -> AWAITING_RESULT_OR_COMMAND on '$ .*' (starting a new command; exit code on previous command is 0)
      # EOF from here is fine; expected exit code = 0

      # These are subsets of each other. So, we can test in this order and not repeat ourselves:
      # READING_MULTILINE_COMMAND
      # AWAITING_RESULT_OR_COMMAND
        # test for '| .*', else fall through
      # AWAITING_RESULT_OR_COMMAND || AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND
        # test for '@ .*' and '? \d+', else fall through
      # AWAITING_COMMAND || AWAITING_RESULT_OR_COMMAND || AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND
        # test for '$ .*\' or '$ .*'; anything else meaningful is an error
    end

    def parse(file_name, file_contents)
      @test_cases = []

      current_case = nil
      state = ParseState::AWAITING_COMMAND

      file_contents.each_line.with_index do |line, i|
        if state == ParseState::READING_MULTILINE_COMMAND
          if line =~ /^(?<cmd>.*)\\$/
            # multiline input continues
            current_case.append_command(Regexp.last_match(:cmd))
            current_case.end_line = i + 1

            state = ParseState::READING_MULTILINE_COMMAND
            next
          else
            # final line of multiline input
            current_case.append_command(line)
            current_case.end_line = i + 1

            state = ParseState::AWAITING_RESULT_OR_COMMAND
            next
          end
        end

        # Skip lines not intended for us
        next unless line =~ /^[$|@?] /

        if state == ParseState::AWAITING_RESULT_OR_COMMAND
          if line =~ /^\| (?<output>.*)$/
            # accumulating expected stdout
            current_case.append_expected_output(Regexp.last_match(:output))
            current_case.end_line = i + 1

            state = ParseState::AWAITING_RESULT_OR_COMMAND
            next
          end
        end

        if state == ParseState::AWAITING_RESULT_OR_COMMAND || state == ParseState::AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND
          if line =~ /^@ (?<error_output>.*)$/
            # accumulating expected stderr
            current_case.append_expected_error_output(Regexp.last_match(:error_output))
            current_case.end_line = i + 1

            state = ParseState::AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND
            next
          elsif line =~ /\? (?<exit_code>\d+)$/
            # got exit code; only possible option from here is a new command
            current_case.expected_exit_code = Regexp.last_match(:exit_code).to_i
            current_case.end_line = i + 1

            state = ParseState::AWAITING_COMMAND
            next
          end
        end

        # state is anything, and we are looking for a new command
        if line =~ /^\$ (?<cmd>.*?)(?<multiline>\\?)$/
          current_case = TestCase.new(file_name)
          current_case.start_line = current_case.end_line = i + 1
          @test_cases << current_case

          current_case.append_command(Regexp.last_match(:cmd))

          # entering multiline mode if we matched the slash
          multiline = Regexp.last_match(:multiline) == '\\'
          state = multiline ? ParseState::READING_MULTILINE_COMMAND : ParseState::AWAITING_RESULT_OR_COMMAND
          next
        else
          # an error
          raise RuntimeError, "invalid line '#{line}'"
        end
      end
    end
  end
end
