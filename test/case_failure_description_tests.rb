require_relative 'test_helper'

class CaseFailureDescriptionTests < SlightishTest
  add_case_failure_test('a passing suite', %[
    $ echo 1
    | 1
  ], '')

  add_case_failure_test('incorrect stdout', %[
    $ echo 1
    | 2
  ], %[
    Expected stdout:
    2
    Actual stdout:
    1
  ])

  add_case_failure_test('incorrect empty stdout', %[
    $ echo 1
  ], %[
    Expected stdout: empty
    Actual stdout:
    1
  ])

  add_case_failure_test('spurious stdout', %[
    $ echo
    | 1
  ], %[
    Expected stdout:
    1
    Actual stdout: empty
  ])

  add_case_failure_test('incorrect stderr', %[
    $ echo 1 >&2
    @ 2
  ], %[
    Expected stderr:
    2
    Actual stderr:
    1
  ])

  add_case_failure_test('incorrect empty stderr', %[
    $ echo 1 >&2
  ], %[
    Expected stderr: empty
    Actual stderr:
    1
  ])

  add_case_failure_test('spurious stderr', %[
    $ echo 1
    | 1
    @ 2
  ], %[
    Expected stderr:
    2
    Actual stderr: empty
  ])

  add_case_failure_test('incorrect exit code', %[
    $ exit 1
    ? 2
  ], %[
    Expected exit code: 2
    Actual exit code: 1
  ])

  add_case_failure_test('explicit zero exit code', %[
    $ echo
    ? 0
  ], '')

  add_case_failure_test('everything wrong', %[
    $ echo 1 >&2; echo 2; exit 2
    | 1
    @ 2
    ? 3
  ], %[
    Expected stdout:
    1
    Actual stdout:
    2
    
    Expected stderr:
    2
    Actual stderr:
    1
    
    Expected exit code: 3
    Actual exit code: 2
  ])

  add_case_failure_test('multiple tests', %[
    $ echo 2
    | 1
    $ exit 3
    @ 1
  ], [%[
    Expected stdout:
    1
    Actual stdout:
    2
  ], %[
    Expected stderr:
    1
    Actual stderr: empty
    
    Expected exit code: 0
    Actual exit code: 3
  ]])
end
