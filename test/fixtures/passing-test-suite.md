# This is a file full of passing tests

```sh
$ echo 1
| 1

$ echo 1 >&2
@ 1

$ exit 3
? 3

$ echo 1; echo 2; echo 3; exit 1
| 1
| 2
| 3
? 1

$ echo 1; \
  echo 2; \
  echo 3 >&2; \
  exit 4
| 1
| 2
@ 3
? 4
```