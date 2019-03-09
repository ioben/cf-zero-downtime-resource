#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEMP_DIR="$(mktemp -d -p "$DIR")"

if [[ -z "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
  echo "Failed to create temporary directory"
  exit 1
fi

function cleanup {
  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

echo "test: Should deploy using app name in manifest after performing variable substitutions"

# this function allows us to see the stderr output in red. Make it easy to see if
color()(set -o pipefail;"$@" 2>&1>&3|sed $'s,.*,\e[31m&\e[m,'>&2)3>&1

cat <<JSON | color ${DIR}/../out.js ${DIR} | tee "$TEMP_DIR/out"
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
    "manifest": {
      "applications": [
        {
          "name": "cf-zero-downtime-((env))",
          "buildpack": "nodejs_buildpack",
          "memory": "64M",
          "health-check-type": "http",
          "health-check-http-endpoint": "/good"
        }
      ]
    },
    "vars": {
      "env": "test"
    }
  }
}
JSON

guid="$(jq -r '.version.guid' "$TEMP_DIR/out")"
app_info="$(cf curl "/v2/apps/$guid")"

test "$(jq -r '.entity.name' <<< "$app_info")" == "cf-zero-downtime-test"
test "$(jq -r '.entity.instances' <<< "$app_info")" == "1"
test "$(jq -r '.entity.state' <<< "$app_info")" == "STARTED"
