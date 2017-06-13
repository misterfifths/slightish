require_relative 'test_helper'

class ComplexSuitesTests < SlightishTest
  suite('all passing', %[
    $ echo 1
    | 1

    $ echo a\\
    b >&2; exit 2
    @ ab
    ? 2
  ]).should_pass

  suite('all failing', %[
    $ echo 1
    | 2
    $ echo 45
  ]).should_fail

  suite('one failing', %[
    $ echo 1
    | 1
    $ echo 45
  ]).should_fail

  suite('all tests run and appropriate ones fail', %[
    $ echo 45
    $ echo 1
    | 1
  ]).should do |s|
    s.run
    assert(s.failed?)
    assert(s.test_cases[0].failed?)
    assert(s.test_cases[1].passed?)
    assert_equal(1, s.failed_count)
    assert_equal(1, s.passed_count)
  end
end
