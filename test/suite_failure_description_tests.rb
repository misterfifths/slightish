require_relative 'test_helper'

class SuiteFailureDescriptionTests < SlightishTest
  suite('passing suite', %[
    $ echo 1
    | 1
  ]).should do |s|
    s.run
    assert_empty(s.failure_description)
  end

  suite('failing suite', %[
    $ echo 1
    | 2
  ]).should do |s|
    s.run
    assert_equal("❌  immediate:1-2\n#{s.test_cases[0].failure_description}\n\n", s.failure_description)
  end

  suite('failing single-line test', %[
    $ exit 1
  ]).should do |s|
    s.run
    assert_equal("❌  immediate:1\n#{s.test_cases[0].failure_description}\n\n", s.failure_description)
  end

  suite('suite with multiple failures', %[
    $ echo 1
    | 2
    | 3
    ? 1
    
    $ echo 0
    @ 0
  ]).should do |s|
    s.run

    assert_equal("❌  immediate:1-4\n#{s.test_cases[0].failure_description}\n\n❌  immediate:6-7\n#{s.test_cases[1].failure_description}\n\n", s.failure_description)
  end
end
