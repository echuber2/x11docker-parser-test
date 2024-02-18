# x11docker-parser-test
Testing proposed changes to x11docker parser

## Output

Note any inconsistencies between old and new, or between `jq` and `python`.
In particular, note the issue the old `jq` parser has on test 3.

Example output based on the draft 20240217:

```

------- Test 1 -------

Test input: [
  {
    "Config": {
      "Cmd": "/bin/sh"
    }
  }
]

Test keys: Config Cmd

-- Old --
jq: </bin/sh>
py: </bin/sh>

-- New --
jq: </bin/sh>
py: </bin/sh>

------- Test 2 -------

Test input: [
  {
    "Config": {
      "Cmd": [
        "/bin/sh"
      ]
    }
  }
]

Test keys: Config Cmd

-- Old --
jq: </bin/sh>
py: <'/bin/sh' >

-- New --
jq: <'/bin/sh'>
py: <'/bin/sh'>

------- Test 3 -------

Test input: [
  {
    "Config": {
      "Cmd": [
        "/bin/sh",
        "-c",
        "start"
      ]
    }
  }
]

Test keys: Config Cmd

-- Old --
jq: </bin/sh"
"-c"
"start>
py: <'/bin/sh' '-c' 'start' >

-- New --
jq: <'/bin/sh' '-c' 'start'>
py: <'/bin/sh' '-c' 'start'>

------- Test 4 -------

Test input: [
  {
    "State": {
      "Pid": 123
    }
  }
]

Test keys: State Pid

-- Old --
jq: <123>
py: <123>

-- New --
jq: <123>
py: <123>

------- Test 5 -------

Test input: [
  {
    "State": {
      "RealKey": 123
    }
  }
]

Test keys: State FakeKey

-- Old --
jq: <>
py: <>

-- New --
jq: <>
py: <>
```
