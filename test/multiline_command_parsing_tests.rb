require_relative 'test_helper'

class MultilineCommandParsingTests < SlightishTest
  suite('basic multiline', %[
    $ echo "this is\\
      a multiline command"
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo "this is  a multiline command"', [1, 2])
  end

  suite('more than one continuation', %[
    $ echo "this is\\
     a multiline command\\
     that continues\\
       a few times"
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(s.test_cases[0], 'echo "this is a multiline command that continues   a few times"', [1, 4])
  end

  suite('consumes magic lines', %[
    $ the next line will be consumed even though it's special\\
    | gotcha!
    @ but not this one
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(
      s.test_cases[0],
      'the next line will be consumed even though it\'s special| gotcha!',
      [1, 3],
      stderr: 'but not this one'
    )
  end

  suite('continuation at EOF', %[
    $ continuations at EOF are ignored\\
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(s.test_cases[0], 'continuations at EOF are ignored', [1, 1])
  end

  suite('bad continuation', %[
    $ the slash must be the final character of the line\\ 
    | or it is ignored
  ]).should do |s|
    assert_equal(1, s.test_cases.length)
    assert_case(s.test_cases[0], 'the slash must be the final character of the line\\ ', [1, 2], stdout: 'or it is ignored')
  end
end
