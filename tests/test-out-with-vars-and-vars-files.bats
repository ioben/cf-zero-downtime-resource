#!/usr/bin/env bats
# vi: set ft=sh :

load helpers/cf
load helpers/jq
load helpers/bats

function setup {
  run_first cf_login

  export RAND="$(< /dev/urandom tr -dc 'a-zA-Z0-9' | head -c 32)"
}

function teardown {
  run_last cf_cleanup "cf-zero-downtime-test"
}

@test "Deploy with inline manifest substituting variables" {
  JSON="$(jq_vars --arg rand "$RAND" -n '{
    "source": $empty_source,
    "params": {
      "name": "cf-zero-downtime-test",
      "path": "app",
      "manifest": {
        "applications": [
          {
            "name": "cf-zero-downtime-test",
            "buildpack": "nodejs_buildpack",
            "memory": "64M",
            "health-check-type": "http",
            "health-check-http-endpoint": "/good"
          }
        ]
      },
      "environment_variables": {
        "random_value": "((value))"
      },
      "vars": {
        "value": $rand
      }
    }
  }')"

  "$BATS_TEST_DIRNAME/../out.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"

  test "$(cf app cf-zero-downtime-test | awk '/^instances:/{print $2}')" == "1/1"
  test "$(cf env cf-zero-downtime-test | awk '/^random_value:/ { print $2 }')" == "$RAND"
}

@test "Deploy with inline manifest substituting variables from files" {
  JSON="$(jq_vars --arg temp_dir "$BATS_TMPDIR" -n '{
    "source": $empty_source,
    "params": {
      "name": "cf-zero-downtime-test",
      "path": "app",
      "manifest": {
        "applications": [
          {
            "name": "cf-zero-downtime-test",
            "buildpack": "nodejs_buildpack",
            "memory": "64M",
            "health-check-type": "http",
            "health-check-http-endpoint": "/good"
          }
        ]
      },
      "environment_variables": {
        "random_value": "((value))",
        "file_1_var": "((file_1_var))",
        "file_2_var": "((file_2_var))"
      },
      "vars_files": [
        $temp_dir + "/vars-file-1.yml",
        $temp_dir + "/vars-file-2.yml"
      ]
    }
  }')"

  cat <<EOF > "$BATS_TMPDIR/vars-file-1.yml"
---
value: incorrect
file_1_var: file_1_val
EOF

  cat <<EOF > "$BATS_TMPDIR/vars-file-2.yml"
---
value: $RAND
file_2_var: file_2_val
EOF

  "$BATS_TEST_DIRNAME/../out.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"

  env="$(cf env cf-zero-downtime-test)"
  test "$(awk '/^random_value:/ { print $2 }' <<< "$env")" == "$RAND"
  test "$(awk '/^file_1_var:/ { print $2 }' <<< "$env")" == "file_1_val"
  test "$(awk '/^file_2_var:/ { print $2 }' <<< "$env")" == "file_2_val"
}

@test "Deploy with inline manifest substituting variables from inline and files" {
  JSON="$(jq_vars --arg rand "$RAND" --arg temp_dir "$BATS_TMPDIR" -n '{
    "source": $empty_source,
    "params": {
      "name": "cf-zero-downtime-test",
      "path": "app",
      "manifest": {
        "applications": [
          {
            "name": "cf-zero-downtime-test",
            "buildpack": "nodejs_buildpack",
            "memory": "64M",
            "health-check-type": "http",
            "health-check-http-endpoint": "/good"
          }
        ]
      },
      "environment_variables": {
        "random_value": "((value))",
        "file_1_var": "((file_1_var))",
        "file_2_var": "((file_2_var))",
        "inline_var": "((inline_var))"
      },
      "vars_files": [
        $temp_dir + "/vars-file-1.yml",
        $temp_dir + "/vars-file-2.yml"
      ],
      "vars": {
        "value": $rand,
        "inline_var": "inline_val"
      }
    }
  }')"

  cat <<EOF > "$BATS_TMPDIR/vars-file-1.yml"
---
value: incorrect
file_1_var: file_1_val
EOF

  cat <<EOF > "$BATS_TMPDIR/vars-file-2.yml"
---
value: still_incorrect
file_2_var: file_2_val
EOF

  "$BATS_TEST_DIRNAME/../out.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"

  test "$(cf app cf-zero-downtime-test | awk '/^instances:/{print $2}')" == "1/1"

  env="$(cf env cf-zero-downtime-test)"
  test "$(awk '/^random_value:/ { print $2 }' <<< "$env")" == "$RAND"
  test "$(awk '/^file_1_var:/ { print $2 }' <<< "$env")" == "file_1_val"
  test "$(awk '/^file_2_var:/ { print $2 }' <<< "$env")" == "file_2_val"
  test "$(awk '/^inline_var:/ { print $2 }' <<< "$env")" == "inline_val"
}
