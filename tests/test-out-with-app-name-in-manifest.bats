#!/usr/bin/env bats
# vi: set ft=sh :

load helpers/cf
load helpers/jq
load helpers/bats

function setup {
  run_first cf_login
  env > test
}

@test "Test deploy with app name in manifest" {
  JSON="$(jq_vars -n '{
    "source": $empty_source,
    "params": {
      "path": "app",
      "manifest": "manifest-good.yml"
    }
  }')"

  run "$BATS_TEST_DIRNAME/../out.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"
  test "$status" -eq 0

  guid="$(dirty_jq -r '.version.guid' <<< "$output")"
  app_info="$(cf curl "/v2/apps/$guid")"

  test "$(jq -r '.entity.name' <<< "$app_info")" == "cf-zero-downtime-test"
  test "$(jq -r '.entity.instances' <<< "$app_info")" == "1"
  test "$(jq -r '.entity.state' <<< "$app_info")" == "STARTED"
}

@test "Deploy with app name in manifest after performing variable substitutions" {
  JSON="$(jq_vars -n '{
    "source": $empty_source,
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
  }')"

  run "$BATS_TEST_DIRNAME/../out.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"
  test "$status" -eq 0

  guid="$(dirty_jq -r '.version.guid' <<< "$output")"
  app_info="$(cf curl "/v2/apps/$guid")"

  test "$(jq -r '.entity.name' <<< "$app_info")" == "cf-zero-downtime-test"
  test "$(jq -r '.entity.instances' <<< "$app_info")" == "1"
  test "$(jq -r '.entity.state' <<< "$app_info")" == "STARTED"
}
