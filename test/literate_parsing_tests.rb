require_relative 'test_helper'

class LiterateParsingTests < SlightishTest
  suite('no tests', %[
    There are no tests in this suite;
    it is literate and all ignored by slightish.
  ]).should do |s|
    assert_empty(s.test_cases)
  end

  suite('test before prose', %[
    $ echo 2
    | 2
    @ abc
    @ d e f
    ? 1
    This prose should
    be ignored, even if it has $
    the | magic @ characters
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(
      s.test_cases[0],
      'echo 2',
      [1, 5],
      stdout: '2',
      stderr: "abc\nd e f",
      exit_code: 1
    )
  end

  suite('test after prose', %[
    This prose should
    be ignored, even if it has $
    the | magic @ characters
    $ echo 2
    | 2
    @ abc
    @ d e f
    ? 1
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(
      s.test_cases[0],
      'echo 2',
      [4, 8],
      stdout: '2',
      stderr: "abc\nd e f",
      exit_code: 1
    )
  end

  suite('intermingled', %[
    This prose should
    $ echo 2
    be ignored, even if it has $
    | 2
    @ abc
    the | magic @ characters
    blah blah blah
    @ d e f
    ? 1
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(
      s.test_cases[0],
      'echo 2',
      [2, 9],
      stdout: '2',
      stderr: "abc\nd e f",
      exit_code: 1
    )
  end

  suite('intermingled', %[
     $ This prose should
    $ echo 2
     | be ignored even though it
    | 2
    | 3
    @ abc
     ? starts with the | magic @ characters
    blah blah blah
      @ because it is indented
    ? 1
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(
      s.test_cases[0],
      'echo 2',
      [2, 10],
      stdout: "2\n3",
      stderr: 'abc',
      exit_code: 1
    )
  end
end
