require 'slightish/testcase'
require 'slightish/sandbox'

class Slightish::TestSuite
  attr_reader :name, :path, :test_cases

  def initialize(path)
    @path = path
    @name = File.basename(path)

    parse(path, File.read(path))
  end

  def run
    sandbox = Slightish::Sandbox.new(template_dir: ENV['SLIGHTISH_TEMPLATE_DIR'])

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
        current_case = Slightish::TestCase.new(file_name)
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