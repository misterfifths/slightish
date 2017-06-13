require_relative 'test_helper'

class SimpleSuitesTests < SlightishTest
  # Just stdout

  suite('single command with no output', %[
    $ echo
  ]).should_pass

  suite('single command with correct output', %[
    $ echo 'hello world'
    | hello world
  ]).should_pass

  suite('single command with incorrect output', %[
    $ echo 2
    | 1
  ]).should_fail

  suite('single command with incorrect output by omission', %[
    $ echo 1
  ]).should_fail

  # Just stderr

  suite('single command with correct stderr', %[
    $ echo error >&2
    @ error
  ]).should_pass

  suite('single command with incorrect stderr', %[
    $ echo error >&2
    @ success
  ]).should_fail

  suite('single command with incorrect stderr by omission', %[
    $ echo error >&2
  ]).should_fail

  # Just exit code

  suite('zero exit code is optional', %[
    $ echo
    ? 0
  ]).should_pass

  suite('single command with correct exit code', %[
    $ exit 1
    ? 1
  ]).should_pass

  suite('single command with incorrect exit code', %[
    $ exit 1
    ? 2
  ]).should_fail

  suite('single command with incorrect exit code by omission', %[
    $ exit 1
  ]).should_fail

  # All together

  suite('command with everything', %[
    $ echo a; echo b >&2; exit 2
    | a
    @ b
    ? 2
  ]).should_pass
end
