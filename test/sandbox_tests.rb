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

  def test_sandbox_template
    assert_passing('template sandbox populated', %[
      $ [ -f empty-file ]
    ], sandbox_template_dir: fixtures_dir)
  end

  def test_multiple_sandbox_templates
    assert_passing('modifications to template files in one suite', %[
      $ echo 1 > empty-file
      $ cat empty-file
      | 1
    ], sandbox_template_dir: fixtures_dir)

    assert_passing('do not effect the files in another', %[
      $ cat empty-file
    ], sandbox_template_dir: fixtures_dir)
  end
end
