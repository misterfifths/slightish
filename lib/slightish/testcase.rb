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

    if @actual_output != (@expected_output || '')
      if @expected_output.empty?
        res += "Expected stdout: empty\n".red.bold
      else
        res += "Expected stdout:\n".red.bold
        res += @expected_output.gray + "\n"
      end

      if @actual_output.empty?
        res += "Actual stdout: empty\n".green.bold
      else
        res += "Actual stdout:\n".green.bold
        res += @actual_output.gray
      end
    end

    if @actual_error_output != (@expected_error_output || '')
      res += "\n\n" unless res == ''
      if @expected_error_output.empty?
        res += "Expected stderr: empty\n".red.bold
      else
        res += "Expected stderr:\n".red.bold
        res += (@expected_error_output || '').gray + "\n"
      end

      if @actual_error_output.empty?
        res += "Actual stderr: empty\n".green.bold
      else
        res += "Actual stderr:\n".green.bold
        res += @actual_error_output.gray
      end
    end

    if @actual_exit_code != @expected_exit_code
      res += "\n\n" unless res == ''
      res += 'Expected exit code: '.red.bold + @expected_exit_code.to_s.gray + "\n"
      res += 'Actual error code: '.green.bold + @actual_exit_code.to_s.gray
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

  def expand(sandbox)
    @command = @raw_command.expand(chdir: sandbox.path, source: source_description)
    @expected_output = (@raw_expected_output || '').expand(chdir: sandbox.path, source: source_description)
    @expected_error_output = (@raw_expected_error_output || '').expand(chdir: sandbox.path, source: source_description)
  end
end
