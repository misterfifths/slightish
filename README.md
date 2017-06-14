# Slightish

*Literate testing of shell scripts*

[![Build Status](https://travis-ci.org/misterfifths/slightish.svg?branch=master)](https://travis-ci.org/misterfifths/slightish) [![Coverage Status](https://coveralls.io/repos/github/misterfifths/slightish/badge.svg?branch=master)](https://coveralls.io/github/misterfifths/slightish?branch=master) [![npm](https://img.shields.io/gem/v/slightish.svg)](https://rubygems.org/gems/slightish)


### What's this then?

A spiritual successor to [tush](https://github.com/darius/tush), *slightish* is a simple tool for testing command line tools using a simple syntax.

### Installation

*slightish* can be install through RubyGems, the Ruby package manager. Run the following command, optionally prefixing it with `sudo` if your environment requires it (you'll get some sort of permissions error if so).

```sh
gem install slightish
```

### Writing tests

Write your tests interspersed among your documentation, in whatever file type you please (Markdown, plain text, HTML, etc.). For example, *this very file* can be used as a test. Blocks of text that look like shell transcripts are executed and tested:

```sh
$ echo 'this is a test'
| this is a test
```

You can also compare stderr and exit codes:

```sh
$ echo stdout; echo stderr >&2; echo "more stdout"; exit 2
| stdout
| more stdout
@ stderr
? 2
```

That example covers 90% of the functionality. The syntax in detail works like this:

- Lines that start with `$ ` are interpreted as commands to run in the shell. The `$` must be in the first column of the file and must be followed by a space.
- Lines starting with `| ` specify the stdout of the most recent command. As with `$ `, the `|` must be in the first column and must be followed by a space. You may specify more than one `| ` line to test for multiline output.
- Lines starting with `@ ` specify the stderr of the most recent command. You may also specify more than one `@ ` line per command.
- A line of the form `? <positive integer>` specifies the expected exit code of the most recent command. You may omit a `? ` line for an expected exit code of zero.

Specifying any of the above magic lines out of order is a syntax error; you must specify a command (`$ `), and then optionally stdout (`| `), stderr (`@ `), and the exit code (`? `). If a command is expected to produce no output and have an exit code of zero, you may omit everything but the `$ ` line:

```sh
# This passes because it exits with code 0 and produces no output
$ echo
```

### Running tests

Once you've written tests, pass the filenames to the `slightish` command:

```sh
slightish my-first-test.md my-second-test
```

This will run all the tests in all the specified files, and output details about any failures. The command will exit with status code 1 if any tests fail.

As a demonstration, let's add a failing test:

```sh
$ exit 2
| 1
```

Now if we run `slightish` on this file, we get this output:

```
❌  README.md:64-65
Expected stdout:
1
Actual stdout: empty

Expected exit code: 0
Actual exit code: 2

----------
README.md 	11 passed	1 failed

Total tests: 12
Passed: 11
Failed: 1
```

### More features

#### Command and variable expansion

Environmental variables in your command, stdout, and stderr are all expanded. The syntax is `$VARIABLE` or `${VARIABLE}`. Note that escaping and quoting of such strings is *not* supported; they will be expanded regardless.

```sh
$ echo $USER
| $USER

$ echo "${HOME}/dir"
| ${HOME}/dir
```

Nonexistent environmental variables will not be expanded, and the original string will be passed through unaltered:

```sh
$ echo '$_TOTAL_NONSENSE_'
| $_TOTAL_NONSENSE_
```

Subcommands are also expanded, using the syntax `$(cmd)` or `` `cmd` ``. Only the stdout of subcommands is captured. If a subcommand produces output on stderr, or has a nonzero exit status, a warning is printed.

```sh
$ echo "$(pwd)"
| `pwd`

$ echo `whoami`
| $USER
```

#### Sandboxes

Each test file is run in its own sandbox directory, so you can safely write to files if your tests require it:

```sh
$ echo 'hello world' > test-file
$ cat test-file
| hello world
```

All sandbox directories are deleted at the end of testing.

If you have a directory of files that your tests require ("fixtures"), you can specify it as the template for sandboxes, and its contents are copied to each sandbox before tests begin. This is done by setting the environmental variable `SLIGHTISH_TEMPLATE_DIR` before invoking the `slightish` command.

Since sandboxes ensure (or at least attempt to ensure) that each test file is independent of the others, the tests in each test files are run in parallel to speed up the process. Commands within each test file are run in order, however.

#### Multiline commands

If you need to specify a long command, you can split it onto multiple lines by ending the `$ ` line with a backslash:

```sh
$ echo "This is a \
very long string \
that I wish to print."
| This is a very long string that I wish to print.
```

Note that the backslash must be the final character on the line, or else it is not treated as a continuation.

### More examples

The [tests for jutil](https://github.com/misterfifths/jutil/tree/master/tests), a tool to manipulate JSON on the command line, were written in tush/slightish syntax.

Also see [tests for adolfopa/cstow](https://github.com/adolfopa/cstow/blob/master/src/TESTS.md).

### Acknowledgements

Thanks to [darius](https://github.com/darius) for the original [tush](https://github.com/darius/tush), the syntax of which I adopted. Thanks also to [adolfopa](https://github.com/adolfopa/) for his [fork](https://github.com/adolfopa/tush) which added support for multiline commands.

### Future plans

In no particular order,

- Regex matching for stdout and stderr
- Expose some things (sandbox template dir) as command line arguments
- More responsive and prettier output
- Fail fast mode
- Smarter threading?
- Bless
- Diff output
