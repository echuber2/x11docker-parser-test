#!/bin/bash

Jqbin="$(command -v jq)"
Pythonbin="$(command -v python3)"

# The proposed new versions

parseNew () {
  local Parserscript
  local Jsonstring Keystring Output

  [[ "$Jqbin" ]] && {
    Jsonstring="${1:-}" ; shift
    # If we have an array, get the first item
    [[ $("$Jqbin" -r 'type' <<< "$Jsonstring" 2>/dev/null) == array ]] && Keystring=".[0]" || Keystring=""
    # Recursively find key using the sequence of keys
    while [ $# -gt 0 ]; do
      Keystring="$Keystring.${1:-}"
      shift
    done
    Output="$("$Jqbin" "$Keystring" <<< "$Jsonstring")"
    # If we have an array, single-quote each item and join with spaces
    if [[ $("$Jqbin" -r 'type' <<< "$Output" 2>/dev/null) == array ]]; then
      Output="$("$Jqbin" -r $'map(tostring | "\'" + . + "\'") | join(" ")' <<< "$Output" )"
    fi
    # If we have a string, output the raw contents without quotes
    if [[ $("$Jqbin" -r 'type' <<< "$Output" 2>/dev/null) == string ]]; then
        Output="$("$Jqbin" -r '.' <<< "$Output")"
    fi
    [ "$Output" = "null" ] && Output=""
    echo "$Output"
    return
  }
}

ParserscriptNew="#! $Pythonbin"$'
import json,sys

def parse_inspect(*args):
    """
    parse output of docker|podman|nerdctl inspect
    args:
     0: ignored
     1: string containing inspect output
     2..n: json keys. For second level keys provide e.g. "Config","Cmd"
    Prints key value as a string.
    Prints empty string if key not found.
    A list is printed as a string with \'\' around each element.
    """

    output=""
    inspect=args[1]
    inspect=inspect.strip()

    obj=json.loads(inspect)

    if "\'list\'" in str(type(obj)):
        obj = obj[0]

    for arg in args[2:]: # recursively find the desired object. Command.Cmd is found with args "Command" , "Cmd"
        try:
            obj=obj[arg]
        except:
            obj=""

    objtype=str(type(obj))
    if "\'list\'" in objtype:
        for i in obj:
            output += "\'" + str(i) + "\' "
        output = output.strip()
    else:
        output = str(obj)

    if output == "None":
        output=""

    print(output)

parse_inspect(*sys.argv)
'

# The old versions from https://github.com/mviereck/x11docker

parse () {
  local Parserscript
  local Jsonstring Keystring Output

  command -v jq >/dev/null && {
    Jsonstring="${1:-}" ; shift
    [ "${Jsonstring:0:1}" = "[" ] && Keystring=".[]" || Keystring=""
    while [ $# -gt 0 ]; do
      Keystring="$Keystring.${1:-}"
      shift
    done
    Output="$(jq "$Keystring" <<< "$Jsonstring")"
    while [ "${Output:0:1}" = "[" ]; do
      Output="$(jq '.[]' <<< "$Output" )"
    done
    [ "$Output" = "null" ] && Output=""
    [ "${Output:0:1}" = '"' ] && Output="${Output:1:-1}"
    echo "$Output"
    return
  }
}

Parserscript="#! $Pythonbin
$(cat << EOF
import json,sys

def parse_inspect(*args):
    """
    parse output of docker|podman|nerdctl inspect
    args:
     0: ignored
     1: string containing inspect output
     2..n: json keys. For second level keys provide e.g. "Config","Cmd"
    Prints key value as a string.
    Prints empty string if key not found.
    A list is printed as a string with '' around each element.
    """

    output=""
    inspect=args[1]
    inspect=inspect.strip()
    if inspect[0] == "[" :
        inspect=inspect[1:-2] # remove enclosing [ ]

    obj=json.loads(inspect)

    for arg in args[2:]: # recursively find the desired object. Command.Cmd is found with args "Command" , "Cmd"
        try:
            obj=obj[arg]
        except:
            obj=""

    objtype=str(type(obj))
    if "'list'" in objtype:
        for i in obj:
            output=output+"'"+str(i)+"' "
    else:
        output=str(obj)

    if output == "None":
        output=""

    print(output)

parse_inspect(*sys.argv)
EOF
  )"

ALL_KEYS=(
  "Config Cmd"
  "Config Cmd"
  "Config Cmd"
  "State Pid"
  "State FakeKey"
)

ALL_TESTS=(
'[
  {
    "Config": {
      "Cmd": "/bin/sh"
    }
  }
]'
'[
  {
    "Config": {
      "Cmd": [
        "/bin/sh"
      ]
    }
  }
]'
'[
  {
    "Config": {
      "Cmd": [
        "/bin/sh",
        "-c",
        "start"
      ]
    }
  }
]'
'[
  {
    "State": {
      "Pid": 123
    }
  }
]'
'[
  {
    "State": {
      "RealKey": 123
    }
  }
]'
)

i=0
for TEST in "${ALL_TESTS[@]}" ; do

  KEYS="${ALL_KEYS[$i]}"
  ((i++))

  echo
  echo "------- Test $i -------"
  echo
  echo "Test input: $TEST"
  echo
  echo "Test keys: $KEYS"
  echo
  echo "-- Old --"
  echo "jq: <$(parse "$TEST" $KEYS)>"
  RESULT=$(echo "$Parserscript" | $Pythonbin - "$TEST" $KEYS)
  echo "py: <$RESULT>"

  echo
  echo "-- New --"
  echo "jq: <$(parseNew "$TEST" $KEYS)>"
  RESULT=$(echo "$ParserscriptNew" | $Pythonbin - "$TEST" $KEYS)
  echo "py: <$RESULT>"

done
