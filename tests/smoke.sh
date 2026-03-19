#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
EXPECTED_VERSION="0.2.0"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack=$1
  local needle=$2
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

make_stub_codex_dir() {
  local dir
  dir=$(mktemp -d)
  cat > "$dir/codex" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  login)
    if [[ "${2:-}" == "status" ]]; then
      exit 0
    fi
    exit 0
    ;;
  logout)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
SCRIPT
  chmod +x "$dir/codex"
  printf '%s\n' "$dir"
}

test_install_help_mentions_dependency_flags() {
  local output
  output=$(bash "$ROOT_DIR/install.sh" --help)
  assert_contains "$output" "--check-deps"
  assert_contains "$output" "--install-deps"
}

test_readme_points_to_the_default_installer_command() {
  local readme
  readme=$(cat "$ROOT_DIR/README.md")
  assert_contains "$readme" "bash <(curl -fsSL https://raw.githubusercontent.com/Fasand/codex-auth/main/install.sh)"
}

test_version_flag_reports_the_current_version() {
  local output
  output=$(bash "$ROOT_DIR/bin/codex-auth" --version)
  [[ "$output" == "$EXPECTED_VERSION" ]] || fail "expected version $EXPECTED_VERSION, got: $output"
}

test_dependency_check_reports_runtime_requirements() {
  local output
  output=$(bash "$ROOT_DIR/install.sh" --check-deps --skip-completions 2>&1 || true)
  assert_contains "$output" "Required runtime"
  assert_contains "$output" "codex CLI"
}

test_remote_style_install_works_without_from_flag() {
  local prefix stub_codex_dir output
  prefix=$(mktemp -d)
  stub_codex_dir=$(make_stub_codex_dir)
  output=$(PATH="$stub_codex_dir:$PATH" CODEX_AUTH_INSTALL_FROM="file://$ROOT_DIR" bash <(cat "$ROOT_DIR/install.sh") --prefix "$prefix" --skip-completions 2>&1)
  assert_contains "$output" "Installed codex-auth"
  [[ -x "$prefix/bin/codex-auth" ]] || fail "expected remote-style install without --from to create the executable"
  [[ "$(PATH="$stub_codex_dir:$PATH" "$prefix/bin/codex-auth" --version)" == "$EXPECTED_VERSION" ]] || fail "expected installed executable to report version $EXPECTED_VERSION"
}

test_re_running_the_installer_updates_in_place() {
  local prefix stub_codex_dir
  prefix=$(mktemp -d)
  stub_codex_dir=$(make_stub_codex_dir)
  PATH="$stub_codex_dir:$PATH" CODEX_AUTH_INSTALL_FROM="file://$ROOT_DIR" bash <(cat "$ROOT_DIR/install.sh") --prefix "$prefix" --skip-completions >/dev/null
  PATH="$stub_codex_dir:$PATH" CODEX_AUTH_INSTALL_FROM="file://$ROOT_DIR" bash <(cat "$ROOT_DIR/install.sh") --prefix "$prefix" --skip-completions >/dev/null
  [[ -x "$prefix/bin/codex-auth" ]] || fail "expected executable to still exist after reinstall"
}

test_list_works_without_column() {
  local home_dir stub_dir output
  home_dir=$(mktemp -d)
  stub_dir=$(mktemp -d)
  mkdir -p "$home_dir/accounts/profiles/demo"
  cat > "$home_dir/accounts/profiles/demo/meta.json" <<'JSON'
{"profileName":"demo","email":"demo@example.com","accountId":"acct_demo"}
JSON
  cat > "$home_dir/accounts/profiles/demo/usage.json" <<'JSON'
{"derived":{"five_hour_remaining_percent":88,"weekly_remaining_percent":77}}
JSON

  for cmd in python3 mkdir sort basename mktemp rm; do
    ln -s "$(command -v "$cmd")" "$stub_dir/$cmd"
  done

  output=$(PATH="$stub_dir" CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" list 2>&1) || fail "expected list to work even when column is unavailable"
  assert_contains "$output" "demo"
}

main() {
  test_install_help_mentions_dependency_flags
  test_readme_points_to_the_default_installer_command
  test_version_flag_reports_the_current_version
  test_dependency_check_reports_runtime_requirements
  test_remote_style_install_works_without_from_flag
  test_re_running_the_installer_updates_in_place
  test_list_works_without_column
}

main "$@"
