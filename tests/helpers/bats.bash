# Normally everything in the setup function is run before every test. Prefix a
# command with run_first, and it'll only be run before all tests in a file.
function run_first {
  if [[ "$BATS_TEST_NUMBER" -eq 1 ]]; then
    "$@"
  fi
}

# Normally everything in the teardown function is run after every test. Prefix a
# command with run_last, and it'll only be run after all tests in a file.
function run_last {
  if [[ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]]; then
    "$@"
  fi
}
