require_relative 'test_helper'

class CommandTests < SlightishTest
  def passing_suite_path
    File.join(fixtures_dir, 'passing-test-suite.md')
  end

  def mixed_suite_path
    File.join(fixtures_dir, 'mixed-suite.md')
  end

  def sandbox_template_suite_path
    File.join(fixtures_dir, 'sandbox-template-suite.md')
  end

  def test_passing_suite_exit_code
    # A passing suite should output some stuff on stdout
    # and not raise a SystemExit
    out, err = capture_io do
      assert_nil(Slightish::Command.run([passing_suite_path]))
    end

    assert_empty(err)
    refute_empty(out)
  end

  def test_failing_suite_exit_code
    # A failing suite should raise SystemExit with status code 1
    # and output some stuff on stdout
    out, err = capture_io do
      exc = assert_raises(SystemExit) do
        Slightish::Command.run([mixed_suite_path])
      end

      assert_equal(exc.status, 1)
    end

    assert_empty(err)
    refute_empty(out)
  end

  def test_multiple_files_exit_code
    # Multiple files should be excepted and we should exit with
    # status code 1 if any of them fail
    out, err = capture_io do
      exc = assert_raises(SystemExit) do
        Slightish::Command.run([passing_suite_path, mixed_suite_path])
      end

      assert_equal(exc.status, 1)
    end

    assert_empty(err)
    refute_empty(out)
  end

  def test_sandbox_env_var
    ENV['SLIGHTISH_TEMPLATE_DIR'] = fixtures_dir
    out, err = capture_io do
      assert_nil(Slightish::Command.run([sandbox_template_suite_path]))
    end

    assert_empty(err)
    refute_empty(out)
  ensure
    ENV.delete('SLIGHTISH_TEMPLATE_DIR')
  end

  def test_no_arguments
    out, err = capture_io do
      exc = assert_raises(SystemExit) { Slightish::Command.run([]) }
      assert_equal(exc.status, 2)
    end

    refute_empty(err)
    assert_empty(out)
  end

  def test_short_help_arg
    out, err = capture_io do
      exc = assert_raises(SystemExit) { Slightish::Command.run(['-h', 'blah']) }
      assert_equal(exc.status, 2)
    end

    refute_empty(err)
    assert_empty(out)
  end

  def test_long_help_arg
    out, err = capture_io do
      exc = assert_raises(SystemExit) { Slightish::Command.run(['blah', '--help']) }
      assert_equal(exc.status, 2)
    end

    refute_empty(err)
    assert_empty(out)
  end
end
