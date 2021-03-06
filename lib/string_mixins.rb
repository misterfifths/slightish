require 'open3'

class String
  def self.color_output?
    $stdout.isatty unless ENV['SLIGHTISH_NO_COLOR']
  end

  {
    red: 1,
    green: 2,
    yellow: 3,
    blue: 4,
    gray: 7
  }.each do |name, code|
    bg_name = ('bg_' + name.to_s).to_sym

    if color_output?
      # :nocov:
      define_method(name) { "\e[#{code + 30}m#{self}\e[39m" }
      define_method(bg_name) { "\e[#{code + 40}m#{self}\e[49m" }
      # :nocov:
    else
      define_method(name) { self }
      define_method(bg_name) { self }
    end
  end

  { bold: 1, faint: 2 }.each do |name, code|
    if color_output?
      # :nocov:
      define_method(name) { "\e[#{code}m#{self}\e[22m" }
      # :nocov:
    else
      define_method(name) { self }
    end
  end

  def expand(chdir: nil, source: nil)
    # Non-existent environmental variables are not replaced.
    # A little unexpected, but it's the behavior of tush.
    # TODO: print a warning when this happens?
    variable_replacer = ->(match) { ENV.fetch(Regexp.last_match(:var_name), match) }
    res = gsub(/\$(?<var_name>[[:alnum:]_]+)/, &variable_replacer) # $VARIABLE
    res.gsub!(/\$\{(?<var_name>[[:alnum:]_]+)\}/, &variable_replacer) # ${VARIABLE}

    command_replacer = ->(_) { capture_stdout_with_logging(Regexp.last_match(:cmd), chdir, source) }
    res.gsub!(/\$\((?<cmd>[^\)]+)\)/, &command_replacer) # $(COMMAND)
    res.gsub!(/`(?<cmd>[^`]+)`/, &command_replacer) # `COMMAND`

    res
  end

  private

  def puts_warning(message, cmd, source)
    s = "warning: #{message} ("
    s += source + '; ' unless source.nil? || source.empty?
    s += "'#{cmd}')"
    $stderr.puts(s.yellow) unless ENV['SLIGHTISH_NO_WARNINGS']
  end

  def capture_stdout_with_logging(cmd, chdir, source)
    if chdir.nil?
      stdout, stderr, status = Open3.capture3(cmd)
    else
      stdout, stderr, status = Open3.capture3(cmd, { chdir: chdir })
    end

    puts_warning('stderr from command substitution will be ignored', cmd, source) unless stderr.empty?
    puts_warning("nonzero exit code (#{status.exitstatus}) from command substitution", cmd, source) unless status.exitstatus.zero?

    stdout.chomp
  end
end
