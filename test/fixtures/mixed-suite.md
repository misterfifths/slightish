# This file has some passing and some failing tests

```sh
$ echo 'this fails'
| because it expects the wrong output

$ exit 1
? 2

$ echo 'but this is ok' >&2; echo 'good, even' >&2
@ but this is ok
@ good even

$ echo 'this is not\
  so good'
| this is not
| so good
```