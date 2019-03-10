# Given input with containing a JSON array or object among other output, parse
# out the JSON and run jq against only it.
function dirty_jq {
  cat - | awk '/^\[$/,/^\]$/ { print $0 }; /^\{$/,/^\}$/ { print $0 }' | jq "$@"
}

function jq_vars {
  source="$(jq -n \
    --arg api "$CF_API" \
    --arg user "$CF_USERNAME" \
    --arg pass "$CF_PASSWORD" \
    --arg org "$CF_ORG" \
    --arg space "$CF_SPACE" \
    '{
      "api": $api,
      "username": $user,
      "password": $pass,
      "organization": $org,
      "space": $space
  }')"
  empty_source="$(jq -n '{
      "api": "",
      "username": "",
      "password": "",
      "organization": null,
      "space": null
    }')"

  jq \
    --argjson empty_source "$empty_source" \
    --argjson source "$source" \
    "$@"
}
