require 'open3'

class Slightish::TestCase
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

    @start_line = @end_line = -1
    @raw_command = @command = nil
    @raw_expected_output = @expected_output = nil
    @raw_expected_error_output = @expected_error_output = nil
    @actual_output = @actual_error_output = nil
    @actual_exit_code = nil
  end

  def run(sandbox)
    expand(sandbox)

    @actual_output, @actual_error_output, process_status = Open3.capture3(@command, { chdir: sandbox.path })
    @actual_output.chomp!
    @actual_error_output.chomp!
    @actual_exit_code = process_status.exitstatus
  end

  def passed?
    @actual_output == @expected_output &&
      @actual_error_output == @expected_error_output &&
      @actual_exit_code == @expected_exit_code
  end

  def failed?
    !passed?
  end

  def failure_description
    res = ''
    res += output_failure_description('stdout', @expected_output, @actual_output) unless @expected_output == @actual_output

    if @expected_error_output != @actual_error_output
      res += "\n\n" unless res.empty?
      res += output_failure_description('stderr', @expected_error_output, @actual_error_output)
    end

    if @actual_exit_code != @expected_exit_code
      res += "\n\n" unless res.empty?
      res += 'Expected exit code: '.red.bold + @expected_exit_code.to_s.gray + "\n"
      res += 'Actual exit code: '.green.bold + @actual_exit_code.to_s.gray
    end

    res
  end

  def source_description
    if @start_line == @end_line
      "#{@source_file}:@{@start_line}"
    else
      "#{@source_file}:#{@start_line}-#{@end_line}"
    end
  end

  def append_command(str)
    if @raw_command.nil?
      @raw_command = str
    else
      # bash eats newlines from multiline strings, so no \n here
      # For example:
      # "echo a\
      # b"
      # produces "ab"
      @raw_command += str
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

  def output_failure_description(name, expected, actual)
    res = ''

    if expected.empty?
      res += "Expected #{name}: empty\n".red.bold
    else
      res += "Expected #{name}:\n".red.bold
      res += expected.gray + "\n"
    end

    if actual.empty?
      res += "Actual #{name}: empty".green.bold
    else
      res += "Actual #{name}:\n".green.bold
      res += actual.gray
    end

    res
  end

  def expand(sandbox)
    @command = @raw_command.expand(chdir: sandbox.path, source: source_description)
    @expected_output = (@raw_expected_output || '').expand(chdir: sandbox.path, source: source_description)
    @expected_error_output = (@raw_expected_error_output || '').expand(chdir: sandbox.path, source: source_description)
  end
end
