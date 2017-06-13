require_relative 'test_helper'

class BasicParsingTests < SlightishTest
  suite('empty suite', '').should do |s|
    assert_empty(s.test_cases)
  end

  suite('simple command', %[
    $ echo 2
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo 2', [1, 1])
  end

  suite('command with exit code', %[
    $ echo 2
    ? 3
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo 2', [1, 2], exit_code: 3)
  end

  suite('command with output', %[
    $ echo 2
    | 2
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo 2', [1, 2], stdout: '2')
  end

  suite('command with multiline output', %[
    $ echo 2
    | 2
    | 3 5 6 
    | 4
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo 2', [1, 4], stdout: "2\n3 5 6 \n4")
  end

  suite('command with error output', %[
    $ echo 2
    @ 2
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo 2', [1, 2], stderr: '2')
  end

  suite('command with multiline error output', %[
    $ echo 2
    @ 2
    @ 3 5 6 
    @ 4
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo 2', [1, 4], stderr: "2\n3 5 6 \n4")
  end

  suite('the whole shebang', %[
    $ echo 2
    | 2
    | 3 4
    @ error output
    @ 
    ? 4
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(
      s.test_cases[0],
      'echo 2',
      [1, 6],
      stdout: "2\n3 4",
      stderr: "error output\n",
      exit_code: 4
    )
  end
end
