bats_require_minimum_version 1.5.0
bats_load_library bats-support
bats_load_library bats-assert

@test "greets in JSON" {
  run -0 "$BATS_TEST_DIRNAME/../bin/greet"
  assert_equal "$(jq -r .greeting <<<"$output")" hello
}
