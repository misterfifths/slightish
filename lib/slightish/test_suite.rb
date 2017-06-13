require 'slightish/sandbox'
require 'slightish/test_case'

class Slightish::TestSuite
  attr_reader :name, :path, :test_cases
  attr_reader :sandbox_template_dir

  def self.from_file(path, sandbox_template_dir: nil)
    new(path, File.read(path), sandbox_template_dir: sandbox_template_dir)
  end

  def initialize(path, contents, sandbox_template_dir: nil)
    @path = path
    @name = File.basename(path)
    @sandbox_template_dir = sandbox_template_dir

    parse(path, contents)
  end

  def run
    sandbox = Slightish::Sandbox.new(template_dir: @sandbox_template_dir)

    begin
      @test_cases.each { |test| test.run(sandbox) }
    ensure
      sandbox.delete
    end
  end

  def print_failures
    @test_cases.select(&:failed?).each do |test|
      puts("❌  #{test.source_description}".bold)
      puts(test.failure_description)
      puts
    end
  end

  def passed?
    @test_cases.all?(&:passed?)
  end

  def failed?
    @test_cases.any?(&:failed?)
  end

  def passed_count
    @test_cases.count(&:passed?)
  end

  def failed_count
    @test_cases.count(&:failed?)
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

    # READING_MULTILINE_COMMAND -> READING_MULTILINE_COMMAND on '.*\'
    # READING_MULTILINE_COMMAND -> AWAITING_RESULT_OR_COMMAND on anything else
    # EOF from this state is error-ish, but eh, not worth it

    # AWAITING_RESULT_OR_COMMAND -> AWAITING_RESULT_OR_COMMAND on '| .*'
    # AWAITING_RESULT_OR_COMMAND -> AWAITING_COMMAND on '? \d+' (starting a new command)
    # AWAITING_RESULT_OR_COMMAND -> AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND on '@ .*' (now accumulating stderr; stdout lines are no longer acceptable)
    # inherits the AWAITING_COMMAND transitions

    # AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND has same productions as AWAITING_RESULT_OR_COMMAND, except '| .*'
    # '| .*' from here is an error
    # EOF from here is fine; expected exit code = 0

    # These are subsets of each other. So, we can test in this order and not repeat ourselves:
    # READING_MULTILINE_COMMAND
    # skip the line unless it begins with one of the magic strings
    # AWAITING_RESULT_OR_COMMAND
      # test for '| .*', else fall through
    # AWAITING_RESULT_OR_COMMAND || AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND
      # test for '@ .*' and '? \d+', else fall through
    # AWAITING_COMMAND || AWAITING_RESULT_OR_COMMAND || AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND
      # test for '$ .*\' or '$ .*'; anything else is an error
  end

  def parse(file_name, file_contents)
    @test_cases = []

    current_case = nil
    state = ParseState::AWAITING_COMMAND

    file_contents.each_line.with_index(1) do |line, line_number|
      if state == ParseState::READING_MULTILINE_COMMAND
        if line =~ /^(?<cmd>.*)\\$/
          # multiline input continues
          current_case.append_command(Regexp.last_match(:cmd))
          current_case.end_line = line_number

          state = ParseState::READING_MULTILINE_COMMAND
        else
          # final line of multiline input; consume the whole thing
          current_case.append_command(line)
          current_case.end_line = line_number

          state = ParseState::AWAITING_RESULT_OR_COMMAND
        end

        next
      end

      # Skip lines not intended for us
      next unless line =~ /^[$|@?] /

      if state == ParseState::AWAITING_RESULT_OR_COMMAND
        if line =~ /^\| (?<output>.*)$/
          # accumulating expected stdout
          current_case.append_expected_output(Regexp.last_match(:output))
          current_case.end_line = line_number

          state = ParseState::AWAITING_RESULT_OR_COMMAND
          next
        end
      end

      if [ParseState::AWAITING_RESULT_OR_COMMAND, ParseState::AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND].include?(state)
        if line =~ /^@ (?<error_output>.*)$/
          # accumulating expected stderr
          current_case.append_expected_error_output(Regexp.last_match(:error_output))
          current_case.end_line = line_number

          state = ParseState::AWAITING_STDERR_OR_EXIT_CODE_OR_COMMAND
          next
        elsif line =~ /\? (?<exit_code>\d+)$/
          # got exit code; only possible option from here is a new command
          current_case.expected_exit_code = Regexp.last_match(:exit_code).to_i
          current_case.end_line = line_number

          state = ParseState::AWAITING_COMMAND
          next
        end
      end

      # state is anything, and we are looking for a new command
      unless line =~ /^\$ (?<cmd>.*?)(?<multiline>\\?)$/
        raise SyntaxError, "invalid line in test file #{file_name}:#{line_number}; expected a '$ ' line"
      end

      current_case = Slightish::TestCase.new(file_name)
      current_case.start_line = current_case.end_line = line_number
      @test_cases << current_case

      current_case.append_command(Regexp.last_match(:cmd))

      # entering multiline mode if we matched the slash
      multiline = Regexp.last_match(:multiline) == '\\'
      state = multiline ? ParseState::READING_MULTILINE_COMMAND : ParseState::AWAITING_RESULT_OR_COMMAND
    end
  end
end
