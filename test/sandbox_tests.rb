require_relative 'test_helper'

class SandboxTests < SlightishTest
  def test_per_suite_sandbox
    suite_a = with_suite('$ touch a_file')
    suite_b = with_suite(%[
      $ [ -f a_file ]
      ? 1
    ])

    # make a_file in the sandbox of the first suite
    suite_a.run
    assert(suite_a.passed?)

    # and it should not exist in the second
    suite_b.run
    assert(suite_b.passed?)
  end

  # TODO: sandbox_template_dir
end
