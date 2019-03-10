#!/usr/bin/env bats
# vi: set ft=sh :

load helpers/cf
load helpers/jq
load helpers/bats

function teardown {
  run_first cf_login
  run_last cf_cleanup "cf-zero-downtime-test"
}

@test "Test static out" {
  JSON="$(jq_vars -n '{
    "source": $empty_source,
    "params": {
      "name": "cf-zero-downtime-test",
      "path": "app-good",
      "manifest": "manifest-static.yml",
      "environment_variables": {
        "TEST": "This is a test"
      }
    }
  }')"

  "$BATS_TEST_DIRNAME/../out.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"
}

@test "Test static check" {
  JSON="$(jq_vars -n '{
    "source": $empty_source,
    "params": {
      "name": "cf-zero-downtime-test"
    }
  }')"

  "$BATS_TEST_DIRNAME/../check.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"
}

@test "Test static in" {
  guid="$(cf app cf-zero-downtime-test --guid)"

  JSON="$(jq_vars --arg guid "$guid" -n '{
    "source": $empty_source,
    "version": {
      "guid": $guid
    }
  }')"

  "$BATS_TEST_DIRNAME/../in.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"
}
