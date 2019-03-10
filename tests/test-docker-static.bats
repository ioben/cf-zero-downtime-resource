#!/usr/bin/env bats
# vi: set ft=sh :

load helpers/cf
load helpers/jq
load helpers/bats

function setup {
  run_first docker build -t cf-zero-downtime-resource-test "$BATS_TEST_DIRNAME/.."
}

function teardown {
  run_last cf_login
  run_last cf_cleanup "cf-zero-downtime-test"
}

@test "Static Docker app out" {
  JSON="$(jq_vars -n '{
    "source": $source,
    "params": {
      "name": "cf-zero-downtime-test",
      "path": "app-good",
      "manifest": "manifest-static.yml",
      "environment_variables": {
        "TEST": "This is a test"
      }
    }
  }')"

  docker run -v "$BATS_TEST_DIRNAME/apps:/tmp/build" -i cf-zero-downtime-resource-test /opt/resource/out /tmp/build <<< "$JSON"
}

@test "Static Docker app check" {
  JSON="$(jq_vars -n '{
    "source": $source,
    "params": {
      "name": "cf-zero-downtime-test"
    }
  }')"

  docker run -i cf-zero-downtime-resource-test /opt/resource/check <<< "$JSON"
}

@test "Static Docker app in" {
  guid="$(cf app cf-zero-downtime-test --guid)"

  JSON="$(jq_vars --arg guid "$guid" -n '{
    "source": $source,
    "version": {
      "guid": $guid
    },
    "params": {
      "name": "cf-zero-downtime-test"
    }
  }')"

  docker run -v "$BATS_TEST_DIRNAME/apps:/tmp/build" -i cf-zero-downtime-resource-test /opt/resource/in /tmp/build <<< "$JSON"
}
