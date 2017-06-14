require 'minitest'
require 'stringio'

class SlightishTest < Minitest::Test
  def fixtures_dir
    File.expand_path('../../fixtures', __FILE__)
  end

  def unheredoc(str)
    # Strips whitespace-only leading and trailing lines,
    # and removes the minimum shared indentation from all lines
    str = str.sub(/\A\s*\n/, '').sub(/^\s*\z/, '').chomp
    str.gsub(/^#{str.scan(/^\s*/).min_by(&:length)}/, '')
  end

  def with_suite(str, sandbox_template_dir: nil)
    str = unheredoc(str)
    suite = Slightish::TestSuite.new('immediate', str, sandbox_template_dir: sandbox_template_dir)
    yield suite if block_given?
    suite
  end

  def assert_passing(description, str, sandbox_template_dir: nil)
    with_suite(str, sandbox_template_dir: sandbox_template_dir) do |suite|
      suite.run
      assert(suite.passed?, description)
    end
  end

  def assert_failing(description, str, sandbox_template_dir: nil)
    with_suite(str, sandbox_template_dir: sandbox_template_dir) do |suite|
      suite.run
      assert(suite.failed?, description)
    end
  end

  def assert_case(test_case, command, lines, stdout: nil, stderr: nil, exit_code: 0)
    assert_equal(command, test_case.raw_command)

    assert_equal(lines[0], test_case.start_line)
    assert_equal(lines[1], test_case.end_line)

    if stdout.nil?
      assert_nil(test_case.raw_expected_output)
    else
      assert_equal(stdout, test_case.raw_expected_output)
    end

    if stderr.nil?
      assert_nil(test_case.raw_expected_error_output)
    else
      assert_equal(stderr, test_case.raw_expected_error_output)
    end

    assert_equal(exit_code, test_case.expected_exit_code)
  end

  class SuiteObject
    def initialize(parent, description, str)
      @parent = parent
      @description = description
      @str = str
      @sandbox_template_dir = nil
    end

    def should_pass
      @parent._add_passing_suite(@description, @str, sandbox_template_dir: @sandbox_template_dir)
    end

    def should_fail
      @parent._add_failing_suite(@description, @str, sandbox_template_dir: @sandbox_template_dir)
    end

    def should_raise(type = SyntaxError)
      @parent._add_raising_suite(type, @description, @str, sandbox_template_dir: @sandbox_template_dir)
    end

    def should(&block)
      @parent._add_suite(@description, @str, @sandbox_template_dir, block)
    end

    def sandbox_template_dir(dir)
      @sandbox_template_dir = dir
      self
    end
  end

  def self.suite(description, str)
    SuiteObject.new(self, description, str)
  end

  def self.add_expand_test(description, before_expand, after_expand)
    method_name = _method_for_description(description)
    define_method(method_name) { assert_equal(after_expand, before_expand.expand) }
  end

  def self.add_case_failure_test(description, suite_str, expected_failure_descriptions, sandbox_template_dir: nil)
    method_name = _method_for_description(description)
    define_method(method_name) do
      with_suite(suite_str, sandbox_template_dir: sandbox_template_dir) do |suite|
        suite.run

        if expected_failure_descriptions.is_a?(Array)
          suite.test_cases.each_with_index do |test, i|
            assert_equal(unheredoc(expected_failure_descriptions[i]), test.failure_description)
          end
        else
          assert_equal(unheredoc(expected_failure_descriptions), suite.test_cases[0].failure_description)
        end
      end
    end
  end

  def self._method_for_description(description)
    ('test_' + description.gsub(/\s+/, '_')).downcase.to_sym
  end

  def self._add_passing_suite(description, str, sandbox_template_dir: nil)
    method_name = _method_for_description(description)
    define_method(method_name) { assert_passing(description, str, sandbox_template_dir: sandbox_template_dir) }
  end

  def self._add_failing_suite(description, str, sandbox_template_dir: nil)
    method_name = _method_for_description(description)
    define_method(method_name) { assert_failing(description, str, sandbox_template_dir: sandbox_template_dir) }
  end

  def self._add_raising_suite(exc_type, description, str, sandbox_template_dir: nil)
    method_name = _method_for_description(description)
    define_method(method_name) do
      assert_raises(exc_type) { with_suite(str, sandbox_template_dir: sandbox_template_dir) }
    end
  end

  def self._add_suite(description, str, sandbox_template_dir, proc)
    method_name = _method_for_description(description)
    define_method(method_name) do
      with_suite(str, sandbox_template_dir: sandbox_template_dir) do |suite|
        instance_exec(suite, &proc)
      end
    end
  end
end
