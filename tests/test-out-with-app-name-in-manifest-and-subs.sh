#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "test: Should deploy using app name in manifest"

# this function allows us to see the stderr output in red. Make it easy to see if 
color()(set -o pipefail;"$@" 2>&1>&3|sed $'s,.*,\e[31m&\e[m,'>&2)3>&1

cat <<JSON | color ${DIR}/../out.js ${DIR}
{
  "source": {
    "api": "",
    "username": "",
    "password": "",
    "organization": null,
    "space": null
  },
  "params": {
    "path": "app",
    "manifest": "manifest-good.yml"
  }
}
JSON

test "$(cf app cf-zero-downtime-test | awk '/^instances:/{print $2}')" == "1/1"
