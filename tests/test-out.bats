#!/usr/bin/env bats
# vi: set ft=sh :

load helpers/cf
load helpers/jq
load helpers/bats

function teardown {
  rm "$BATS_TEST_DIRNAME/app.info" || true

  run_last cf_login
  run_last cf_cleanup "cf-zero-downtime-test"
}

@test "Test good deployment" {
  JSON="$(jq_vars -n '{
    "source": $empty_source,
    "params": {
      "name": "cf-zero-downtime-test",
      "path": "app",
      "manifest": "manifest-good.yml",
      "environment_variables": {
        "TEST": "This is a test"
      }
    }
  }')"

  "$BATS_TEST_DIRNAME/../out.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"
}

@test "Test bad deployment" {
  JSON="$(jq_vars -n '{
    "source": $empty_source,
    "params": {
      "name": "cf-zero-downtime-test",
      "path": "app",
      "manifest": "manifest-bad.yml",
      "environment_variables": {
        "TEST": "This is a test"
      }
    }
  }')"

  run "$BATS_TEST_DIRNAME/../out.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"
  [[ "$status" -ne 0 ]]
}

@test "Test deploy with inline manifest" {
  JSON="$(jq_vars -n '{
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
        "TEST": "This is a test"
      }
    }
  }')"

  "$BATS_TEST_DIRNAME/../out.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"
}

@test "Test deploy with multiline variable" {
  JSON="$(jq_vars -n '{
    "source": $empty_source,
    "params": {
      "name": "cf-zero-downtime-test",
      "path": "app",
      "manifest": "manifest-good.yml",
      "environment_variables": {
        "TEST": "This is a test\nwith\nmultiple lines"
      }
    }
  }')"

  "$BATS_TEST_DIRNAME/../out.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"
}

@test "Test deploy with no env" {
  JSON="$(jq_vars -n '{
    "source": $empty_source,
    "params": {
      "name": "cf-zero-downtime-test",
      "path": "app",
      "manifest": "manifest-good.yml"
    }
  }')"

  "$BATS_TEST_DIRNAME/../out.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"
}

@test "Test deploy with service configuration" {
  if ! cf service my-service; then
    skip "You must create a service named my-service that can accept binding configuration before running this test"
  fi

  JSON="$(jq_vars -n '{
    "source": $empty_source,
    "params": {
      "name": "cf-zero-downtime-test-with-services",
      "path": "app",
      "manifest": "manifest-good.yml",
      "environment_variables": {
        "TEST": "This is a test"
      },
      "services": [
        {
          "name": "my-service",
          "config": {
            "share": "my-share",
            "mount": "/home/cf-zero-downtime-test-with-services/data",
            "uid": "1000",
            "gid": "1000"
          }
        }
      ]
    }
  }')"

  "$BATS_TEST_DIRNAME/../out.js" "$BATS_TEST_DIRNAME/apps" <<< "$JSON"
}
