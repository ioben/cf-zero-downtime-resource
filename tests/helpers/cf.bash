# Use environment variable to configure CF CLI's API endpoint, account, org and
# space.
function cf_login {
  : ${CF_API?The CF_API environment variable must be set}
  : ${CF_USERNAME?The CF_USER environment variable must be set}
  : ${CF_PASSWORD?The CF_PASS environment variable must be set}
  : ${CF_ORG?The CF_ORG environment variable must be set}
  : ${CF_SPACE?The CF_SPACE environment variable must be set}

  cf_api="$(cf api "$CF_API")"

  if grep -q 'Not logged in.' <<< "$cf_api"; then
    cf auth
  fi

  cf t -o "$CF_ORG" -s "$CF_SPACE"
}

function cf_cleanup {
  APPS="$(cf apps | awk -v "app=$1" 'substr($1, 1, length(app)) == app { print $1 }')"

  function delete_if_exists {
    if grep -qF "$1" <<< "$APPS"; then
      cf delete -r -f "$@"
    fi
  }

  delete_if_exists "$1-venerable"
  delete_if_exists "$1-failed"
  delete_if_exists "$1"
}
