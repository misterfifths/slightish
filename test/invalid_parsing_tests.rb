require_relative 'test_helper'

class InvalidParsingTests < SlightishTest
  suite('stdout without command', %[
    | nonsense
  ]).should_raise

  suite('stderr without command', %[
    @ nonsense
  ]).should_raise

  suite('exit code without command', %[
    ? 1
  ]).should_raise

  suite('stderr before stdout', %[
    $ echo 1
    @ 1
    | 2
  ]).should_raise

  suite('stdout after exit code', %[
    $ echo 1
    ? 1
    | 1
  ]).should_raise

  suite('stderr after exit code', %[
    $ echo 1
    ? 1
    @ 1
  ]).should_raise

  suite('more than one exit code', %[
    $ echo 1
    ? 1
    ? 2
  ]).should_raise

  suite('non-integer exit code', %[
    $ echo 1
    ? d
  ]).should_raise

  suite('negative exit code', %[
    $ echo 1
    ? -2
  ]).should_raise

  suite('empty command', %[
    $ 
  ]).should_raise
end
