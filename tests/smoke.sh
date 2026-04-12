#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
EXPECTED_VERSION="0.5.1"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack=$1
  local needle=$2
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack=$1
  local needle=$2
  [[ "$haystack" != *"$needle"* ]] || fail "expected output to not contain: $needle"
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

create_profile_fixture() {
  local home_dir=$1
  local profile_name=$2
  local email=$3
  local account_id=$4
  local token=${5:-token_$profile_name}
  mkdir -p "$home_dir/accounts/profiles/$profile_name"
  cat > "$home_dir/accounts/profiles/$profile_name/auth.json" <<JSON
{"tokens":{"access_token":"$token","account_id":"$account_id"}}
JSON
  cat > "$home_dir/accounts/profiles/$profile_name/meta.json" <<JSON
{"profileName":"$profile_name","email":"$email","accountId":"$account_id"}
JSON
}

write_usage_fixture() {
  local home_dir=$1
  local profile_name=$2
  local five_hour_remaining=$3
  local five_hour_reset=$4
  local weekly_remaining=$5
  local weekly_reset=$6
  local fetched_at=${7:-2026-03-27T23:10:00Z}
  cat > "$home_dir/accounts/profiles/$profile_name/usage.json" <<JSON
{
  "fetchedAt":"$fetched_at",
  "plan_type":"plus",
  "derived":{
    "five_hour_remaining_percent":$five_hour_remaining,
    "five_hour_reset_at":$five_hour_reset,
    "weekly_remaining_percent":$weekly_remaining,
    "weekly_reset_at":$weekly_reset
  }
}
JSON
}

write_rollout_fixture() {
  local home_dir=$1
  local relative_dir=$2
  local rollout_name=$3
  local timestamp=$4
  local model=$5
  local input_tokens=$6
  local cached_input_tokens=$7
  local output_tokens=$8
  local reasoning_output_tokens=$9
  local total_tokens=${10:-}
  [[ -n "$total_tokens" ]] || total_tokens=$((input_tokens + output_tokens))
  mkdir -p "$home_dir/sessions/$relative_dir"
  {
    printf '{"timestamp":"%s","type":"session_meta","payload":{"id":"%s"}}\n' "$timestamp" "$rollout_name"
    if [[ -n "$model" ]]; then
      printf '{"timestamp":"%s","type":"turn_context","payload":{"model":"%s"}}\n' "$timestamp" "$model"
    fi
    printf '{"timestamp":"%s","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":%s,"cached_input_tokens":%s,"output_tokens":%s,"reasoning_output_tokens":%s,"total_tokens":%s}}}}\n' \
      "$timestamp" "$input_tokens" "$cached_input_tokens" "$output_tokens" "$reasoning_output_tokens" "$total_tokens"
  } > "$home_dir/sessions/$relative_dir/$rollout_name.jsonl"
}

write_pricing_fixture() {
  local path=$1
  cat > "$path" <<'HTML'
<div props="{&quot;rows&quot;:[1,[[1,[[0,&quot;gpt-5.4 (&lt;272K context length)&quot;],[0,2.5],[0,0.25],[0,15]]],[1,[[0,&quot;gpt-5.3-codex&quot;],[0,1.75],[0,0.175],[0,14]]]]]}"></div>
HTML
}

write_pricing_fixture_with_priority() {
  local path=$1
  cat > "$path" <<'HTML'
<div data-value="standard"><astro-island props="{&quot;tier&quot;:[0,&quot;standard&quot;],&quot;rows&quot;:[1,[[1,[[0,&quot;gpt-5.4 (&lt;272K context length)&quot;],[0,2.5],[0,0.25],[0,15]]],[1,[[0,&quot;gpt-5.3-codex&quot;],[0,1.75],[0,0.175],[0,14]]]]]}"></astro-island></div>
<div data-value="priority"><astro-island props="{&quot;tier&quot;:[0,&quot;priority&quot;],&quot;rows&quot;:[1,[[1,[[0,&quot;gpt-5.4 (&lt;272K context length)&quot;],[0,5],[0,0.5],[0,30]]],[1,[[0,&quot;gpt-5.3-codex&quot;],[0,3.5],[0,0.35],[0,28]]]]]}"></astro-island></div>
HTML
}

write_pricing_fixture_multi_section() {
  local path=$1
  cat > "$path" <<'HTML'
<div data-value="standard"><astro-island props="{&quot;tier&quot;:[0,&quot;standard&quot;],&quot;rows&quot;:[1,[[1,[[0,&quot;gpt-5.4 (&lt;272K context length)&quot;],[0,2.5],[0,0.25],[0,15]]],[1,[[0,&quot;gpt-5.4-mini&quot;],[0,0.75],[0,0.075],[0,4.5]]],[1,[[0,&quot;gpt-5.4-nano&quot;],[0,0.2],[0,0.02],[0,1.25]]]]]}"></astro-island></div>
<div data-value="priority"><astro-island props="{&quot;tier&quot;:[0,&quot;priority&quot;],&quot;rows&quot;:[1,[[1,[[0,&quot;gpt-5.4 (&lt;272K context length)&quot;],[0,5],[0,0.5],[0,30]]],[1,[[0,&quot;gpt-5.4-mini&quot;],[0,1.5],[0,0.15],[0,9]]],[1,[[0,&quot;gpt-5.4-nano&quot;],[0,0.4],[0,0.04],[0,2.5]]]]]}"></astro-island></div>
<div data-value="standard"><astro-island props="{&quot;tier&quot;:[0,&quot;standard&quot;],&quot;rows&quot;:[1,[[1,[[0,&quot;gpt-5.3-codex&quot;],[0,1.75],[0,0.175],[0,14]]],[1,[[0,&quot;gpt-5.2-codex&quot;],[0,1.75],[0,0.175],[0,14]]],[1,[[0,&quot;gpt-5.1-codex-max&quot;],[0,1.25],[0,0.125],[0,10]]],[1,[[0,&quot;gpt-5.1-codex-mini&quot;],[0,0.25],[0,0.025],[0,2]]]]]}"></astro-island></div>
HTML
}

start_mock_usage_server() {
  local port_file=$1
  local fail_tokens=${2:-}
  python3 -u - "$port_file" "$fail_tokens" >/dev/null 2>&1 <<'PY' &
import http.server
import json
import socketserver
import sys

port_file = sys.argv[1]
fail_tokens = {token for token in sys.argv[2].split(',') if token}

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        auth = self.headers.get("Authorization", "")
        token = auth.removeprefix("Bearer ").strip()
        if token in fail_tokens:
            body = {
                "status": 401,
                "error": {
                    "code": "token_expired",
                    "message": f"token expired for {token}",
                },
            }
            payload = json.dumps(body).encode("utf-8")
            self.send_response(401)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        body = {
            "plan_type": "plus",
            "rate_limit": {
                "primary_window": {
                    "used_percent": 16,
                    "reset_at": 1774656360,
                    "reset_after_seconds": 3600,
                },
                "secondary_window": {
                    "used_percent": 39,
                    "reset_at": 1774829160,
                    "reset_after_seconds": 86400,
                },
            },
        }
        payload = json.dumps(body).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format, *args):
        return

with socketserver.TCPServer(("127.0.0.1", 0), Handler) as httpd:
    with open(port_file, "w", encoding="utf-8") as fh:
        fh.write(str(httpd.server_address[1]))
    httpd.serve_forever()
PY
  echo $!
}

wait_for_file() {
  local path=$1
  local attempts=${2:-50}
  local i
  for ((i = 0; i < attempts; i++)); do
    [[ -s "$path" ]] && return 0
    sleep 0.1
  done
  return 1
}

test_install_help_mentions_dependency_flags() {
  local output
  output=$(bash "$ROOT_DIR/install.sh" --help)
  assert_contains "$output" "--check-deps"
  assert_contains "$output" "--install-deps"
}

test_help_mentions_update_command() {
  local output
  output=$(bash "$ROOT_DIR/bin/codex-auth" help)
  assert_contains "$output" "update"
  assert_contains "$output" "stats [--utc] [--period <today|7d|14d|30d|all>]"
  assert_contains "$output" "statistics [--utc] [--period <today|7d|14d|30d|all>]"
}

test_help_mentions_refresh_alias_and_utc_flag() {
  local output
  output=$(bash "$ROOT_DIR/bin/codex-auth" help)
  assert_contains "$output" "refresh-usage [--utc] [<name>|--all]"
  assert_contains "$output" "refresh [--utc] [<name>|--all]"
  assert_contains "$output" "list [--utc]"
  assert_contains "$output" "current [--utc]"
}

test_readme_points_to_the_default_installer_command() {
  local readme
  readme=$(cat "$ROOT_DIR/README.md")
  assert_contains "$readme" "bash <(curl -fsSL https://raw.githubusercontent.com/Fasand/codex-auth/main/install.sh)"
  assert_contains "$readme" "See [CHANGELOG.md](CHANGELOG.md) for release history."
}

test_readme_lists_both_update_options() {
  local readme
  readme=$(cat "$ROOT_DIR/README.md")
  assert_contains "$readme" "codex-auth update"
  assert_contains "$readme" "bash <(curl -fsSL https://raw.githubusercontent.com/Fasand/codex-auth/main/install.sh)"
}

test_readme_documents_installing_a_specific_tagged_version() {
  local readme
  readme=$(cat "$ROOT_DIR/README.md")
  assert_contains "$readme" "Install a specific tagged version"
  assert_contains "$readme" "https://raw.githubusercontent.com/Fasand/codex-auth/0.3.0/install.sh"
  assert_contains "$readme" "--from https://raw.githubusercontent.com/Fasand/codex-auth/0.3.0"
}

test_version_flag_reports_the_current_version() {
  local output
  output=$(bash "$ROOT_DIR/bin/codex-auth" --version)
  [[ "$output" == "$EXPECTED_VERSION" ]] || fail "expected version $EXPECTED_VERSION, got: $output"
}

test_dependency_check_reports_runtime_requirements() {
  local stub_codex_dir output line_count
  stub_codex_dir=$(make_stub_codex_dir)
  output=$(PATH="$stub_codex_dir:$PATH" bash "$ROOT_DIR/install.sh" --check-deps --skip-completions)
  assert_contains "$output" "Dependency check ("
  assert_contains "$output" "python3"
  assert_contains "$output" "codex CLI"
  line_count=$(printf '%s\n' "$output" | wc -l | tr -d ' ')
  [[ "$line_count" -le 10 ]] || fail "expected compact dependency output, got $line_count lines"
}

test_dependency_check_uses_clear_red_green_status_markers() {
  local output
  output=$(PATH="/usr/bin:/bin" FORCE_COLOR=1 bash "$ROOT_DIR/install.sh" --check-deps --skip-completions 2>&1 || true)
  assert_contains "$output" "❌"
  assert_contains "$output" "codex CLI"
}

test_workflow_uses_node24_ready_checkout() {
  local workflow
  workflow=$(cat "$ROOT_DIR/.github/workflows/smoke.yml")
  assert_contains "$workflow" "actions/checkout@v6"
  assert_contains "$workflow" "pull_request:"
  assert_contains "$workflow" "branches:"
  assert_contains "$workflow" "- main"
  if [[ "$workflow" == *"feat/**"* || "$workflow" == *"fix/**"* || "$workflow" == *"chore/**"* ]]; then
    fail "expected workflow to avoid duplicate branch-pattern push triggers"
  fi
}

test_install_script_avoids_unsafe_array_expansion_in_dependency_report() {
  local script
  script=$(cat "$ROOT_DIR/install.sh")
  if [[ "$script" == *'array_contains "python3" "${missing_required_runtime[@]}"'* ]]; then
    fail "expected install.sh to avoid direct empty-array expansion in dependency checks"
  fi
  assert_contains "$script" 'array_contains "python3" "missing_required_runtime"'
  assert_contains "$script" 'local count=0'
  assert_contains "$script" 'eval "count=\${#${array_name}[@]}"'
}

test_changelog_tracks_the_current_release_newest_first() {
  local changelog
  changelog=$(cat "$ROOT_DIR/CHANGELOG.md")
  assert_contains "$changelog" "## $EXPECTED_VERSION - 2026-04-12"
  assert_contains "$changelog" "## 0.2.2 - 2026-03-19"
}

test_agents_md_captures_repo_workflow() {
  local agents
  agents=$(cat "$ROOT_DIR/AGENTS.md")
  assert_contains "$agents" 'Do not work directly on `main`.'
  assert_contains "$agents" 'Every PR should include a short self-test command'
  assert_contains "$agents" 'Maintain `CHANGELOG.md` newest-first.'
  assert_contains "$agents" 'For each `0.x` minor line, keep tags for `0.x.0` and the latest `0.x.y` release in that line.'
  assert_contains "$agents" 'If a newer patch release becomes the latest in a `0.x` line, delete the superseded latest patch tag and create the new latest patch tag for that line.'
}

test_completion_lists_update_command() {
  local completion
  completion=$(cat "$ROOT_DIR/completions/codex-auth.bash")
  assert_contains "$completion" "update"
  assert_contains "$completion" "refresh"
  assert_contains "$completion" "stats"
  assert_contains "$completion" "statistics"
  assert_contains "$completion" "--utc"
  assert_contains "$completion" "--period"
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

test_update_command_reuses_the_installer_without_cloning() {
  local prefix stub_codex_dir
  prefix=$(mktemp -d)
  stub_codex_dir=$(make_stub_codex_dir)
  PATH="$stub_codex_dir:$PATH" CODEX_AUTH_INSTALL_FROM="file://$ROOT_DIR" bash <(cat "$ROOT_DIR/install.sh") --prefix "$prefix" --skip-completions >/dev/null
  PATH="$stub_codex_dir:$PATH" CODEX_AUTH_INSTALL_FROM="file://$ROOT_DIR" "$prefix/bin/codex-auth" update >/dev/null
  [[ -x "$prefix/bin/codex-auth" ]] || fail "expected executable to still exist after codex-auth update"
}

test_list_works_with_minimal_path() {
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

  output=$(PATH="$stub_dir" CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" list 2>&1) || fail "expected list to work with a minimal PATH"
  assert_contains "$output" "demo"
}

test_list_uses_local_timezone_by_default_and_utc_when_requested() {
  local home_dir output utc_output
  home_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "encor" "encor@example.com" "acct_encor"
  cp "$home_dir/accounts/profiles/encor/auth.json" "$home_dir/auth.json"
  write_usage_fixture "$home_dir" "encor" 84 1774656360 61 1774829160

  # The script captures a fixed offset from the current moment (CET or CEST),
  # so compute the expected local time dynamically to stay DST-safe.
  local expected_local
  expected_local=$(TZ=Europe/Prague python3 -c "
import datetime as dt
local_tz = dt.datetime.now().astimezone().tzinfo
ts = dt.datetime.fromtimestamp(1774656360, tz=dt.timezone.utc)
loc = ts.astimezone(local_tz)
print(loc.strftime('%H:%M ') + (loc.tzname() or 'UTC'))
")

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" list)
  assert_contains "$output" "$expected_local"
  assert_contains "$output" "28 Mar"
  assert_not_contains "$output" "00:06Z"

  utc_output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" list --utc)
  assert_contains "$utc_output" "00:06Z"
}

test_refresh_without_args_prompts_and_lists_all_profiles() {
  local home_dir port_file server_pid output usage_url
  home_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"
  create_profile_fixture "$home_dir" "beta" "beta@example.com" "acct_beta" "token_beta"
  cp "$home_dir/accounts/profiles/alpha/auth.json" "$home_dir/auth.json"

  port_file=$(mktemp)
  server_pid=$(start_mock_usage_server "$port_file")
  trap 'kill "$server_pid" >/dev/null 2>&1 || true' RETURN
  wait_for_file "$port_file" || fail "mock usage server did not start"
  usage_url="http://127.0.0.1:$(cat "$port_file")/usage"

  output=$(printf '\n' | TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_USAGE_URL="$usage_url" /bin/bash "$ROOT_DIR/bin/codex-auth" refresh-usage 2>&1)
  assert_contains "$output" "Do you want to refresh usage for all profiles?"
  assert_contains "$output" "Refreshing 1/2: alpha..."
  assert_contains "$output" "Refreshing 2/2: beta..."
  assert_contains "$output" "Refreshed alpha"
  assert_contains "$output" "Refreshed beta"
  assert_not_contains "$output" "Refreshing 1/2 ["
  assert_contains "$output" "alpha"
  assert_contains "$output" "beta"
  assert_contains "$output" "84%"
  assert_contains "$output" "61%"
  [[ -f "$home_dir/accounts/profiles/alpha/usage.json" ]] || fail "expected alpha usage.json to be written"
  [[ -f "$home_dir/accounts/profiles/beta/usage.json" ]] || fail "expected beta usage.json to be written"

  kill "$server_pid" >/dev/null 2>&1 || true
  trap - RETURN
}

test_refresh_cancel_shows_usage_instruction() {
  local home_dir output
  home_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"
  cp "$home_dir/accounts/profiles/alpha/auth.json" "$home_dir/auth.json"

  output=$(printf 'n\n' | NO_COLOR=1 CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" refresh 2>&1 || true)
  assert_contains "$output" "Do you want to refresh usage for all profiles?"
  assert_contains "$output" "Use 'codex-auth refresh-usage <profile>' for one profile"
}

test_refresh_continues_after_profile_failures_and_summarizes() {
  local home_dir port_file server_pid output usage_url status=0
  home_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"
  create_profile_fixture "$home_dir" "beta" "beta@example.com" "acct_beta" "token_beta"
  create_profile_fixture "$home_dir" "gamma" "gamma@example.com" "acct_gamma" "token_gamma"
  cp "$home_dir/accounts/profiles/alpha/auth.json" "$home_dir/auth.json"

  port_file=$(mktemp)
  server_pid=$(start_mock_usage_server "$port_file" "token_beta,token_gamma")
  trap 'kill "$server_pid" >/dev/null 2>&1 || true' RETURN
  wait_for_file "$port_file" || fail "mock usage server did not start"
  usage_url="http://127.0.0.1:$(cat "$port_file")/usage"

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_USAGE_URL="$usage_url" /bin/bash "$ROOT_DIR/bin/codex-auth" refresh --all 2>&1) || status=$?
  [[ $status -ne 0 ]] || fail "expected refresh --all to exit non-zero when some profiles fail"
  assert_contains "$output" "Refreshing 1/3: alpha..."
  assert_contains "$output" "Refreshing 2/3: beta..."
  assert_contains "$output" "Refreshing 3/3: gamma..."
  assert_contains "$output" "Refreshed alpha"
  assert_contains "$output" "Failed beta"
  assert_contains "$output" "Failed gamma"
  assert_not_contains "$output" "Refreshing 1/3 ["
  assert_contains "$output" "2 profiles failed to refresh:"
  assert_contains "$output" "beta: Unable to refresh usage for 'beta': token_expired:"
  assert_contains "$output" "gamma: Unable to refresh usage for 'gamma': token_expired:"
  assert_contains "$output" "PROFILE"
  assert_contains "$output" "alpha@example.com"
  assert_contains "$output" "beta@example.com"
  assert_contains "$output" "gamma@example.com"
  [[ -f "$home_dir/accounts/profiles/alpha/usage.json" ]] || fail "expected alpha usage.json to be written"
  [[ ! -f "$home_dir/accounts/profiles/beta/usage.json" ]] || fail "expected beta usage.json to be absent after failure"
  [[ ! -f "$home_dir/accounts/profiles/gamma/usage.json" ]] || fail "expected gamma usage.json to be absent after failure"

  kill "$server_pid" >/dev/null 2>&1 || true
  trap - RETURN
}

test_list_shows_compact_session_usage_footer() {
  local home_dir pricing_file output
  home_dir=$(mktemp -d)
  pricing_file=$(mktemp)
  create_profile_fixture "$home_dir" "demo" "demo@example.com" "acct_demo"
  write_usage_fixture "$home_dir" "demo" 88 1774656360 77 1774829160
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-a" "2026-04-12T08:05:00Z" "gpt-5.4" 1000 200 100 40 1100
  write_rollout_fixture "$home_dir" "2026/04/08" "rollout-b" "2026-04-08T08:05:00Z" "gpt-5.3-codex" 2000 500 200 80 2200
  write_pricing_fixture "$pricing_file"

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_PRICING_URL="file://$pricing_file" CODEX_AUTH_NOW="2026-04-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" list)
  assert_contains "$output" "Session usage: today 1 session"
  assert_contains "$output" '$0.0036 API-eq'
  assert_contains "$output" "1.1k tokens"
  assert_contains "$output" "Session usage: 7d    2 sessions"
  assert_contains "$output" '$0.0091 API-eq'
}

test_stats_reports_overview_daily_and_model_breakdown() {
  local home_dir pricing_file output
  home_dir=$(mktemp -d)
  pricing_file=$(mktemp)
  create_profile_fixture "$home_dir" "demo" "demo@example.com" "acct_demo"
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-a" "2026-04-12T08:05:00Z" "gpt-5.4" 1000 200 100 40 1100
  write_rollout_fixture "$home_dir" "2026/04/08" "rollout-b" "2026-04-08T08:05:00Z" "gpt-5.3-codex" 2000 500 200 80 2200
  write_rollout_fixture "$home_dir" "2026/03/20" "rollout-c" "2026-03-20T08:05:00Z" "" 1500 300 150 70 1650
  write_pricing_fixture "$pricing_file"

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_PRICING_URL="file://$pricing_file" CODEX_AUTH_NOW="2026-04-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" stats)
  assert_contains "$output" "Session statistics (local time)"
  assert_contains "$output" "All (24d)"
  assert_contains "$output" "API-eq / day"
  assert_contains "$output" '$0.0013'
  assert_contains "$output" "Daily activity (30d)"
  assert_contains "$output" "Model breakdown (30d)"
  assert_contains "$output" "gpt-5.3-codex"
  assert_contains "$output" "unknown*"
  assert_contains "$output" "Unknown-model events use fallback pricing from gpt-5.4"
  assert_contains "$output" "Reasoning output is shown separately for visibility"
}

test_statistics_alias_and_all_period_cap_daily_rows() {
  local home_dir pricing_file output count i day rel_dir timestamp
  home_dir=$(mktemp -d)
  pricing_file=$(mktemp)
  create_profile_fixture "$home_dir" "demo" "demo@example.com" "acct_demo"
  write_pricing_fixture "$pricing_file"
  for i in $(seq 0 34); do
    day=$(python3 - <<PY
import datetime as dt
print((dt.date(2026, 4, 12) - dt.timedelta(days=$i)).isoformat())
PY
)
    rel_dir=${day//-//}
    timestamp="${day}T08:05:00Z"
    write_rollout_fixture "$home_dir" "$rel_dir" "rollout-$i" "$timestamp" "gpt-5.4" 1000 100 100 10 1100
  done

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_PRICING_URL="file://$pricing_file" CODEX_AUTH_NOW="2026-04-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" statistics --period all)
  assert_contains "$output" "Daily activity (All (35d)), latest 31 days shown"
  count=$(printf '%s\n' "$output" | grep -c '^2026-')
  [[ "$count" -eq 31 ]] || fail "expected 31 daily rows in all-period view, got $count"
}

test_stats_uses_standard_pricing_tier_and_explains_cost_methodology() {
  local home_dir pricing_file output
  home_dir=$(mktemp -d)
  pricing_file=$(mktemp)
  create_profile_fixture "$home_dir" "demo" "demo@example.com" "acct_demo"
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-a" "2026-04-12T08:05:00Z" "gpt-5.4" 1000 200 100 40 1100
  write_pricing_fixture_with_priority "$pricing_file"

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_PRICING_URL="file://$pricing_file" CODEX_AUTH_NOW="2026-04-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" stats --period today)
  assert_contains "$output" '$0.0036'
  assert_not_contains "$output" '$0.0072'
  assert_contains "$output" "Cost methodology:"
  assert_contains "$output" "(input tokens - cached input tokens) × input rate"
  assert_contains "$output" "cached input tokens × cached-input rate"
  assert_contains "$output" "output tokens × output rate"
}

test_stats_uses_exact_pricing_for_models_found_later_on_the_pricing_page() {
  local home_dir pricing_file output
  home_dir=$(mktemp -d)
  pricing_file=$(mktemp)
  create_profile_fixture "$home_dir" "demo" "demo@example.com" "acct_demo"
  write_pricing_fixture_multi_section "$pricing_file"
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-54mini" "2026-04-12T08:05:00Z" "gpt-5.4-mini" 1000000 0 0 0 1000000
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-54nano" "2026-04-12T08:06:00Z" "gpt-5.4-nano" 1000000 0 0 0 1000000
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-53" "2026-04-12T08:07:00Z" "gpt-5.3-codex" 1000000 0 0 0 1000000
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-52" "2026-04-12T08:08:00Z" "gpt-5.2-codex" 1000000 0 0 0 1000000
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-51mini" "2026-04-12T08:09:00Z" "gpt-5.1-codex-mini" 1000000 0 0 0 1000000
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-51max" "2026-04-12T08:10:00Z" "gpt-5.1-codex-max" 1000000 0 0 0 1000000

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_PRICING_URL="file://$pricing_file" CODEX_AUTH_NOW="2026-04-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" stats --period today)
  assert_contains "$output" '$5.95'
  assert_contains "$output" 'gpt-5.3-codex'
  assert_contains "$output" 'gpt-5.2-codex'
  assert_contains "$output" 'gpt-5.1-codex-mini'
  assert_contains "$output" 'gpt-5.1-codex-max'
  assert_contains "$output" '$0.025'
  assert_contains "$output" '$0.175'
  assert_not_contains "$output" 'gpt-5.3-codex → gpt-5.4'
  assert_not_contains "$output" 'gpt-5.2-codex → gpt-5.4'
  assert_not_contains "$output" 'gpt-5.1-codex-mini → gpt-5.4'
  assert_not_contains "$output" 'gpt-5.1-codex-max → gpt-5.4'
}

test_stats_invalidates_old_pricing_cache_schema() {
  local home_dir pricing_file cache_file output
  home_dir=$(mktemp -d)
  pricing_file=$(mktemp)
  cache_file=$(mktemp)
  create_profile_fixture "$home_dir" "demo" "demo@example.com" "acct_demo"
  write_pricing_fixture_multi_section "$pricing_file"
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-53" "2026-04-12T08:07:00Z" "gpt-5.3-codex" 1000000 0 0 0 1000000
  cat > "$cache_file" <<'JSON'
{
  "cache_schema_version": 2,
  "tier": "standard",
  "fetched_at": "2026-04-12T12:00:00Z",
  "fallback_model": "gpt-5.4",
  "models": {
    "gpt-5.4": {
      "input": 2.5,
      "cached_input": 0.25,
      "output": 15
    }
  }
}
JSON

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_PRICING_URL="file://$pricing_file" CODEX_AUTH_PRICING_CACHE_PATH="$cache_file" CODEX_AUTH_NOW="2026-04-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" stats --period today)
  assert_contains "$output" 'gpt-5.3-codex'
  assert_contains "$output" '$1.75'
  assert_not_contains "$output" 'gpt-5.3-codex → gpt-5.4'
}

main() {
  test_install_help_mentions_dependency_flags
  test_help_mentions_update_command
  test_help_mentions_refresh_alias_and_utc_flag
  test_readme_points_to_the_default_installer_command
  test_readme_lists_both_update_options
  test_readme_documents_installing_a_specific_tagged_version
  test_version_flag_reports_the_current_version
  test_dependency_check_reports_runtime_requirements
  test_dependency_check_uses_clear_red_green_status_markers
  test_remote_style_install_works_without_from_flag
  test_re_running_the_installer_updates_in_place
  test_update_command_reuses_the_installer_without_cloning
  test_list_works_with_minimal_path
  test_list_uses_local_timezone_by_default_and_utc_when_requested
  test_refresh_without_args_prompts_and_lists_all_profiles
  test_refresh_cancel_shows_usage_instruction
  test_refresh_continues_after_profile_failures_and_summarizes
  test_list_shows_compact_session_usage_footer
  test_stats_reports_overview_daily_and_model_breakdown
  test_statistics_alias_and_all_period_cap_daily_rows
  test_stats_uses_standard_pricing_tier_and_explains_cost_methodology
  test_stats_uses_exact_pricing_for_models_found_later_on_the_pricing_page
  test_stats_invalidates_old_pricing_cache_schema
  test_workflow_uses_node24_ready_checkout
  test_install_script_avoids_unsafe_array_expansion_in_dependency_report
  test_changelog_tracks_the_current_release_newest_first
  test_agents_md_captures_repo_workflow
  test_completion_lists_update_command
}

main "$@"
