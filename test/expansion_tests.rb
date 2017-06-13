require_relative 'test_helper'

class ExpansionTests < SlightishTest
  # Environmental variables

  add_expand_test('bare env variable', '$PATH', ENV['PATH'])
  add_expand_test('braced env variable', '${PATH}', ENV['PATH'])

  add_expand_test('interpolated bare env variable', '/$HOME/nonsense', "/#{ENV['HOME']}/nonsense")
  add_expand_test('interpolated braced env variable', '/${HOME}/nonsense', "/#{ENV['HOME']}/nonsense")

  add_expand_test('nonexistent bare variable', 'abc$_TOTAL_NONSENSE_ 123', 'abc$_TOTAL_NONSENSE_ 123')
  add_expand_test('nonexistent braced variable', 'abc${_TOTAL_NONSENSE_}def', 'abc${_TOTAL_NONSENSE_}def')

  add_expand_test('vars work in multiline strings', "1.\n2. $PATH\n3.", "1.\n2. #{ENV['PATH']}\n3.")

  # Basic commands

  pwd = `pwd`.chomp
  add_expand_test('braced cmd', '$(pwd)', pwd)
  add_expand_test('backtick cmd', '`pwd`', pwd)

  add_expand_test('interpolated braced cmd', '12$(echo "3")45', '12345')
  add_expand_test('interpolated backtick cmd', '12`echo 3`45', '12345')

  add_expand_test('cmds work in multiline strings', "1\n`echo 2` 3\n4", "1\n2 3\n4")

  # Command edge cases

  add_expand_test('only captures stdout of cmd', '$(echo 1 >&2)', '')
  add_expand_test('only captures stdout of cmd', '$(echo 1 >&2; echo 2)', '2')

  add_expand_test('ignores nonzero exit codes', '$(echo 1; exit 1)', '1')

  # Parsing edge cases

  add_expand_test('does not understand escapes', '\\$PATH', "\\#{ENV['PATH']}")
  add_expand_test('does not understand single quotes', '\'$PATH\'', "'#{ENV['PATH']}'")
end
