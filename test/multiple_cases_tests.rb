require_relative 'test_helper'

class MultipleCasesTests < SlightishTest
  suite('adjacent commands', %[
    $ echo 2
    $ echo 3
  ]).should do |s|
    assert_equal(2, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo 2', [1, 1])
    assert_case(s.test_cases[1], 'echo 3', [2, 2])
  end

  suite('command after stdout', %[
    $ echo 2
    | 2
    $ echo 3
    | 3
  ]).should do |s|
    assert_equal(2, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo 2', [1, 2], stdout: '2')
    assert_case(s.test_cases[1], 'echo 3', [3, 4], stdout: '3')
  end

  suite('command after stderr', %[
    $ echo 2
    | 2
    @ error output
    $ echo 3
    | 3
  ]).should do |s|
    assert_equal(2, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo 2', [1, 3], stdout: '2', stderr: 'error output')
    assert_case(s.test_cases[1], 'echo 3', [4, 5], stdout: '3')
  end

  suite('command after exit code', %[
    $ echo 2
    ? 2
    $ echo 3
    | 3
  ]).should do |s|
    assert_equal(2, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo 2', [1, 2], exit_code: 2)
    assert_case(s.test_cases[1], 'echo 3', [3, 4], stdout: '3')
  end

  suite('newlines between', %[
    $ echo 1
    | 1

    $ echo 2

    $ echo 3
    | 3
    | 
  ]).should do |s|
    assert_equal(3, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo 1', [1, 2], stdout: '1')
    assert_case(s.test_cases[1], 'echo 2', [4, 4])
    assert_case(s.test_cases[2], 'echo 3', [6, 8], stdout: "3\n")
  end
end
