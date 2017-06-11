require 'open3'

class String
  def self.color_output?
    STDOUT.isatty
  end

  { red: 1,
    green: 2,
    yellow: 3,
    blue: 4,
    gray: 7 }.each do |name, code|
    bg_name = ('bg_' + name.to_s).to_sym

    if color_output?
      define_method(name) { "\e[#{code + 30}m#{self}\e[39m" }
      define_method(bg_name) { "\e[#{code + 40}m#{self}\e[49m" }
    else
      define_method(name) { self }
      define_method(bg_name) { self }
    end
  end

  { bold: 1, faint: 2 }.each do |name, code|
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
    stdout, stderr, status = Open3.capture3(cmd, { chdir: chdir })

    unless stderr.empty?
      message = 'warning: stderr from command substitution ('
      message += source + '; ' unless source.nil? || source.empty?
      message += "'#{cmd}') will be ignored"
      STDERR.puts(message.yellow)
    end

    unless status.exitstatus.zero?
      message = "warning: nonzero exit code (#{status.exitstatus}) from command substitution ("
      message += source + '; ' unless source.nil? || source.empty?
      message += "'#{cmd}')"
      STDERR.puts(message.yellow)
    end

    stdout.chomp
  end
end
