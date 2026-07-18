#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
EXPECTED_VERSION="0.10.2"

# Keep the daily update check inert for every test; update-check tests
# re-enable it explicitly with CODEX_AUTH_NO_UPDATE_CHECK=0.
export CODEX_AUTH_NO_UPDATE_CHECK=1

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

make_fake_crontab_dir() {
  local dir
  dir=$(mktemp -d)
  cat > "$dir/crontab" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
crontab_file=${CODEX_AUTH_FAKE_CRONTAB_FILE:?}
case "${1:-}" in
  -l)
    [[ $# -eq 1 ]] || exit 2
    [[ -f "$crontab_file" ]] || exit 1
    cat "$crontab_file"
    ;;
  "")
    exit 2
    ;;
  *)
    [[ $# -eq 1 ]] || exit 2
    cp "$1" "$crontab_file"
    ;;
esac
SCRIPT
  chmod +x "$dir/crontab"
  printf '%s\n' "$dir"
}

make_failing_crontab_dir() {
  local dir
  dir=$(mktemp -d)
  cat > "$dir/crontab" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-l" ]]; then
  echo "permission denied reading crontab" >&2
  exit 1
fi
exit 2
SCRIPT
  chmod +x "$dir/crontab"
  printf '%s\n' "$dir"
}

make_stub_whiptail_dir() {
  local dir
  dir=$(mktemp -d)
  cat > "$dir/whiptail" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${CODEX_AUTH_WHIPTAIL_LOG:?}"
args=" $* "
if [[ "$args" == *" --menu "* ]]; then
  if [[ "$args" == *"Touch target"* ]]; then
    printf 'all\n' >&2
  elif [[ "$args" == *"Schedule"* ]]; then
    printf 'custom\n' >&2
  else
    printf 'all\n' >&2
  fi
  exit 0
fi
if [[ "$args" == *" --inputbox "* ]]; then
  printf '30 8 * * 1,3,5\n' >&2
  exit 0
fi
if [[ "$args" == *" --yesno "* ]]; then
  exit 0
fi
exit 0
SCRIPT
  chmod +x "$dir/whiptail"
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

make_jwt() {
  local email=$1
  local subject=$2
  local exp=$3
  local iat=${4:-1770000000}
  local aud=${5:-https://api.openai.com/v1}
  local auth_provider=${6:-password}
  python3 - "$email" "$subject" "$exp" "$iat" "$aud" "$auth_provider" <<'PY'
import base64
import json
import sys

email, subject, exp, iat, aud, auth_provider = sys.argv[1:7]

def b64(obj):
    raw = json.dumps(obj, separators=(',', ':')).encode()
    return base64.urlsafe_b64encode(raw).decode().rstrip('=')

header = {'alg': 'none', 'typ': 'JWT'}
payload = {
    'email': email,
    'email_verified': True,
    'sub': subject,
    'aud': [aud],
    'iss': 'https://auth.openai.com',
    'iat': int(iat),
    'exp': int(exp),
    'auth_provider': auth_provider,
}
print(f"{b64(header)}.{b64(payload)}.")
PY
}

create_profile_fixture_with_jwts() {
  local home_dir=$1
  local profile_name=$2
  local email=$3
  local account_id=$4
  local id_exp=$5
  local access_exp=$6
  local id_token access_token
  id_token=$(make_jwt "$email" "sub_$profile_name" "$id_exp" 1770000000 "app_EMoamEEZ73f0CkXaXp7hrann")
  access_token=$(make_jwt "$email" "sub_$profile_name" "$access_exp" 1770000000 "https://api.openai.com/v1")
  mkdir -p "$home_dir/accounts/profiles/$profile_name"
  cat > "$home_dir/accounts/profiles/$profile_name/auth.json" <<JSON
{"auth_mode":"chatgpt","last_refresh":"2026-06-04T10:28:41Z","tokens":{"access_token":"$access_token","id_token":"$id_token","refresh_token":"refresh_$profile_name","account_id":"$account_id"}}
JSON
  cat > "$home_dir/accounts/profiles/$profile_name/meta.json" <<JSON
{"profileName":"$profile_name","email":"$email","accountId":"$account_id","tokenExpiresAt":"2026-06-04T11:28:41Z"}
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

write_usage_error_fixture() {
  local home_dir=$1
  local profile_name=$2
  local summary=$3
  local fetched_at=${4:-2026-03-27T23:10:00Z}
  cat > "$home_dir/accounts/profiles/$profile_name/usage.json" <<JSON
{
  "fetchedAt":"$fetched_at",
  "derived":{
    "five_hour_remaining_percent":42,
    "weekly_remaining_percent":93
  },
  "lastRefreshError":{
    "failedAt":"2026-03-27T23:15:00Z",
    "summary":"$summary",
    "message":"Unable to refresh usage for '$profile_name': $summary"
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

write_session_rate_limit_rollout_fixture() {
  local home_dir=$1
  local relative_dir=$2
  local rollout_name=$3
  local timestamp=$4
  local primary_used=$5
  local secondary_used=$6
  mkdir -p "$home_dir/sessions/$relative_dir"
  {
    printf '{"timestamp":"%s","type":"session_meta","payload":{"id":"%s"}}\n' "$timestamp" "$rollout_name"
    printf '{"timestamp":"%s","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000,"cached_input_tokens":0,"output_tokens":100,"reasoning_output_tokens":0,"total_tokens":1100},"model_context_window":272000},"rate_limits":{"primary":{"used_percent":%s,"resets_at":1774656360},"secondary":{"used_percent":%s,"resets_at":1774829160},"plan_type":"plus"}}}\n' \
      "$timestamp" "$primary_used" "$secondary_used"
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
  local bare_tokens=${3:-}
  python3 -u - "$port_file" "$fail_tokens" "$bare_tokens" >/dev/null 2>&1 <<'PY' &
import http.server
import json
import socketserver
import sys

port_file = sys.argv[1]
fail_tokens = {token for token in sys.argv[2].split(',') if token}
bare_tokens = {token for token in sys.argv[3].split(',') if token}

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        auth = self.headers.get("Authorization", "")
        token = auth.removeprefix("Bearer ").strip()
        if token in bare_tokens:
            payload = json.dumps({"plan_type": "plus"}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
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
  assert_contains "$output" "stats [--utc] [--recompute] [--period <today|7d|14d|30d|all>]"
  assert_contains "$output" "statistics [--utc] [--recompute] [--period <today|7d|14d|30d|all>]"
}

test_help_mentions_refresh_alias_and_utc_flag() {
  local output
  output=$(bash "$ROOT_DIR/bin/codex-auth" help)
  assert_contains "$output" "refresh-usage [--utc] [--with-stats] [<name>|--all]"
  assert_contains "$output" "refresh [--utc] [--with-stats] [<name>|--all]"
  assert_contains "$output" "token-status [--utc] [<name>|--all]"
  assert_contains "$output" "touch <name>|--all"
  assert_contains "$output" "cron [list|setup|add|delete|run]"
  assert_contains "$output" "list [--utc] [--with-stats]"
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
  assert_contains "$changelog" "## $EXPECTED_VERSION - 2026-07-18"
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
  assert_contains "$completion" "token-status"
  assert_contains "$completion" "touch"
  assert_contains "$completion" "cron"
  assert_contains "$completion" "stats"
  assert_contains "$completion" "statistics"
  assert_contains "$completion" "--utc"
  assert_contains "$completion" "--period"
  assert_contains "$completion" "--with-stats"
  assert_contains "$completion" "--recompute"
  assert_contains "$completion" "--time"
  assert_contains "$completion" "--schedule"
  assert_not_contains "$completion" "--weekdays"
}

test_save_tracks_id_and_access_token_expiry_in_meta() {
  local home_dir port_file server_pid usage_url id_token access_token
  home_dir=$(mktemp -d)
  port_file=$(mktemp)
  server_pid=$(start_mock_usage_server "$port_file")
  trap 'kill "$server_pid" 2>/dev/null || true' RETURN
  wait_for_file "$port_file" || fail "mock usage server did not start"
  usage_url="http://127.0.0.1:$(cat "$port_file")/usage"
  mkdir -p "$home_dir"
  id_token=$(make_jwt "alpha@example.com" "sub_alpha" 1780572521 1780568921 "app_EMoamEEZ73f0CkXaXp7hrann")
  access_token=$(make_jwt "alpha@example.com" "sub_alpha" 1781432921 1780568921 "https://api.openai.com/v1")
  cat > "$home_dir/auth.json" <<JSON
{"auth_mode":"chatgpt","last_refresh":"2026-06-04T10:28:41Z","tokens":{"access_token":"$access_token","id_token":"$id_token","refresh_token":"refresh_alpha","account_id":"acct_alpha"}}
JSON

  CODEX_HOME="$home_dir" CODEX_AUTH_USAGE_URL="$usage_url" /bin/bash "$ROOT_DIR/bin/codex-auth" save alpha >/dev/null

  python3 - "$home_dir/accounts/profiles/alpha/meta.json" <<'PY' || fail "expected meta.json to track both token expirations"
import json
import sys
meta = json.load(open(sys.argv[1]))
assert meta["idTokenExpiresAt"] == "2026-06-04T11:28:41Z"
assert meta["accessTokenExpiresAt"] == "2026-06-14T10:28:41Z"
assert meta["tokenExpiresAt"] == "2026-06-04T11:28:41Z"
assert meta["hasRefreshToken"] is True
PY
  kill "$server_pid" 2>/dev/null || true
  trap - RETURN
}

test_switch_round_trip_preserves_the_saved_snapshot_byte_for_byte() {
  # DEV-259: rule out the "wrong slot / corrupted persistence" hypothesis.
  # save A -> switch to B -> switch back to A must restore A's exact tokens,
  # including the refresh token ("the tokens don't live through").
  local home_dir codex_dir output
  home_dir=$(mktemp -d)
  codex_dir=$(make_stub_codex_dir)
  mkdir -p "$home_dir"
  local id_token access_token
  id_token=$(make_jwt "alpha@example.com" "sub_alpha" 1790000000 1770000000 "app_EMoamEEZ73f0CkXaXp7hrann")
  access_token=$(make_jwt "alpha@example.com" "sub_alpha" 1790000000 1770000000 "https://api.openai.com/v1")
  cat > "$home_dir/auth.json" <<JSON
{"auth_mode":"chatgpt","last_refresh":"2026-06-04T10:28:41Z","tokens":{"access_token":"$access_token","id_token":"$id_token","refresh_token":"refresh_alpha_R1","account_id":"acct_alpha"}}
JSON

  PATH="$codex_dir:$PATH" CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" save alpha >/dev/null 2>&1
  # A pristine copy of what account A looked like when it was saved.
  local saved_alpha
  saved_alpha=$(mktemp)
  cp "$home_dir/accounts/profiles/alpha/auth.json" "$saved_alpha"

  # A second, distinct account to switch to and back from.
  create_profile_fixture_with_jwts "$home_dir" "beta" "beta@example.com" "acct_beta" 1790000000 1790000000

  PATH="$codex_dir:$PATH" CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" switch beta >/dev/null 2>&1
  PATH="$codex_dir:$PATH" CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" switch alpha >/dev/null 2>&1

  cmp -s "$saved_alpha" "$home_dir/auth.json" \
    || fail "switch away and back must restore account alpha's snapshot byte-for-byte"
  python3 - "$home_dir/auth.json" <<'PY' || fail "restored live auth.json must carry alpha's original refresh token"
import json, sys
tokens = json.load(open(sys.argv[1]))["tokens"]
assert tokens["refresh_token"] == "refresh_alpha_R1", tokens.get("refresh_token")
assert tokens["account_id"] == "acct_alpha", tokens.get("account_id")
PY
  rm -f "$saved_alpha"
}

test_switch_warns_when_restored_snapshot_token_is_expired() {
  # DEV-259: when the restored snapshot is already expired, Codex is forced onto
  # the refresh token on first use; if that token was rotated upstream the switch
  # silently hands over a dead session. The switch must say so instead.
  local home_dir now output
  home_dir=$(mktemp -d)
  now="2026-06-01T00:00:00Z"   # epoch 1780272000
  # Stale: access token expired well before "now".
  create_profile_fixture_with_jwts "$home_dir" "stale" "stale@example.com" "acct_stale" 1770000000 1779000000
  # Healthy: both tokens valid past "now".
  create_profile_fixture_with_jwts "$home_dir" "fresh" "fresh@example.com" "acct_fresh" 1790000000 1790000000

  output=$(NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_NOW="$now" \
    /bin/bash "$ROOT_DIR/bin/codex-auth" switch stale 2>&1)
  assert_contains "$output" "Restored snapshot for 'stale' access token expired"
  assert_contains "$output" "codex-auth touch stale"

  output=$(NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_NOW="$now" \
    /bin/bash "$ROOT_DIR/bin/codex-auth" switch fresh 2>&1)
  assert_not_contains "$output" "Restored snapshot for 'fresh'"

  # Switch away first so the live auth no longer matches 'fresh' — otherwise the
  # pre-switch save-back would re-copy the live (still refresh-token-bearing)
  # auth over the snapshot we are about to hand-edit.
  NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_NOW="$now" \
    /bin/bash "$ROOT_DIR/bin/codex-auth" switch stale >/dev/null 2>&1
  # A snapshot missing its refresh token can never be revived by a refresh.
  python3 - "$home_dir/accounts/profiles/fresh/auth.json" <<'PY'
import json, sys
p = sys.argv[1]
obj = json.load(open(p))
obj["tokens"].pop("refresh_token", None)
json.dump(obj, open(p, "w"))
PY
  output=$(NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_NOW="$now" \
    /bin/bash "$ROOT_DIR/bin/codex-auth" switch fresh 2>&1)
  assert_contains "$output" "Restored snapshot for 'fresh' has no refresh token"
}

test_token_status_reports_both_token_expirations() {
  local home_dir output
  home_dir=$(mktemp -d)
  create_profile_fixture_with_jwts "$home_dir" "alpha" "alpha@example.com" "acct_alpha" 1780572521 1781432921
  create_profile_fixture_with_jwts "$home_dir" "beta" "beta@example.com" "acct_beta" 1770000100 1770000200

  output=$(NO_COLOR=1 CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" token-status --utc)

  assert_contains "$output" "PROFILE"
  assert_contains "$output" "ID TOKEN"
  assert_contains "$output" "ACCESS TOKEN"
  assert_contains "$output" "alpha"
  assert_contains "$output" "beta"
  assert_contains "$output" "alpha@example.com"
  assert_contains "$output" "2026-06-04 11:28Z"
  assert_contains "$output" "2026-06-14 10:28Z"
  assert_contains "$output" "2026-06-04 10:28Z"
  assert_contains "$output" "refresh=yes"

  output=$(NO_COLOR=1 CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" token-status --utc alpha)
  assert_contains "$output" "alpha"
  assert_not_contains "$output" "beta"
}

test_token_status_uses_color_and_active_marker_when_enabled() {
  local home_dir output
  home_dir=$(mktemp -d)
  # Far-future expiries (2100-01-01): this test asserts live "valid" status,
  # so near-term epochs would turn into a time bomb as real time passes.
  create_profile_fixture_with_jwts "$home_dir" "alpha" "alpha@example.com" "acct_alpha" 4102444800 4102448400
  create_profile_fixture_with_jwts "$home_dir" "beta" "beta@example.com" "acct_beta" 1770000100 1770000200
  cp "$home_dir/accounts/profiles/alpha/auth.json" "$home_dir/auth.json"
  printf 'alpha\n' > "$home_dir/accounts/current_profile"

  output=$(CODEX_AUTH_FORCE_COLOR=1 CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" token-status --utc)

  assert_contains "$output" $'\033[1;97mPROFILE\033[0m'
  assert_contains "$output" $'\033[1;93m*\033[0m'
  assert_contains "$output" $'\033[32mvalid'
  assert_contains "$output" $'\033[31mexpired'
}

test_touch_profile_runs_minimal_codex_exec_saves_token_and_restores_current_profile() {
  local home_dir stub_dir output log_file
  home_dir=$(mktemp -d)
  stub_dir=$(mktemp -d)
  log_file="$stub_dir/codex.log"
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"
  create_profile_fixture "$home_dir" "beta" "beta@example.com" "acct_beta" "token_beta"
  cp "$home_dir/accounts/profiles/alpha/auth.json" "$home_dir/auth.json"
  printf 'alpha\n' > "$home_dir/accounts/current_profile"
  cat > "$stub_dir/codex" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$CODEX_STUB_LOG"
if [[ "${1:-}" == "exec" ]]; then
  printf 'codex noisy stderr\n' >&2
  python3 - "$CODEX_HOME/auth.json" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
obj = json.loads(path.read_text())
account_id = obj.get("tokens", {}).get("account_id", "unknown")
obj.setdefault("tokens", {})["access_token"] = f"refreshed_{account_id}"
obj["last_refresh"] = "2026-06-04T12:00:00Z"
path.write_text(json.dumps(obj), encoding="utf-8")
PY
  printf 'hi\n'
fi
SCRIPT
  chmod +x "$stub_dir/codex"

  output=$(PATH="$stub_dir:$PATH" CODEX_HOME="$home_dir" CODEX_STUB_LOG="$log_file" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" touch beta 2>&1)

  assert_contains "$output" "Touching beta"
  assert_contains "$output" "Restored profile 'alpha'"
  assert_contains "$output" "Tokens refreshed for 'beta'"
  assert_not_contains "$output" "Switched to"
  assert_not_contains "$output" "codex noisy stderr"
  assert_contains "$(cat "$log_file")" "exec"
  assert_contains "$(cat "$log_file")" "--ephemeral"
  assert_contains "$(cat "$log_file")" "--ignore-user-config"
  assert_contains "$(cat "$log_file")" "--ignore-rules"
  assert_contains "$(cat "$log_file")" "--skip-git-repo-check"
  assert_contains "$(cat "$log_file")" "--sandbox read-only"
  assert_not_contains "$(cat "$log_file")" "model_reasoning_effort"
  [[ "$(cat "$home_dir/accounts/current_profile")" == "alpha" ]] || fail "expected touch to restore current profile marker"
  assert_contains "$(cat "$home_dir/auth.json")" "token_alpha"
  assert_contains "$(cat "$home_dir/accounts/profiles/beta/auth.json")" "refreshed_acct_beta"
}

test_touch_reports_when_codex_does_not_rotate_tokens() {
  local home_dir stub_dir output log_file
  home_dir=$(mktemp -d)
  stub_dir=$(mktemp -d)
  log_file="$stub_dir/codex.log"
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"
  cp "$home_dir/accounts/profiles/alpha/auth.json" "$home_dir/auth.json"
  printf 'alpha\n' > "$home_dir/accounts/current_profile"
  cat > "$stub_dir/codex" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$CODEX_STUB_LOG"
if [[ "${1:-}" == "exec" ]]; then
  printf 'hi\n'
fi
SCRIPT
  chmod +x "$stub_dir/codex"

  output=$(PATH="$stub_dir:$PATH" CODEX_HOME="$home_dir" CODEX_STUB_LOG="$log_file" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" touch alpha 2>&1)

  assert_contains "$output" "Touching alpha"
  assert_contains "$output" "Tokens unchanged for 'alpha'"
  assert_contains "$output" "Codex did not rotate tokens during this run"
}

test_touch_refuses_to_run_when_touch_lock_exists() {
  local home_dir stub_dir output status=0
  home_dir=$(mktemp -d)
  stub_dir=$(make_stub_codex_dir)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"
  mkdir -p "$home_dir/accounts/touch.lock"

  output=$(PATH="$stub_dir:$PATH" CODEX_HOME="$home_dir" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" touch alpha 2>&1) || status=$?

  [[ $status -ne 0 ]] || fail "expected touch to fail when another touch lock exists"
  assert_contains "$output" "Another codex-auth touch operation is already running"
}

test_cron_add_lists_and_deletes_managed_touch_job() {
  local home_dir stub_codex_dir fake_crontab_dir crontab_file output list_output delete_output crontab_body
  home_dir=$(mktemp -d)
  crontab_file=$(mktemp)
  stub_codex_dir=$(make_stub_codex_dir)
  fake_crontab_dir=$(make_fake_crontab_dir)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"
  create_profile_fixture "$home_dir" "beta" "beta@example.com" "acct_beta" "token_beta"
  printf '# unmanaged user job\n5 4 * * * echo keep\n' > "$crontab_file"

  output=$(PATH="$fake_crontab_dir:$stub_codex_dir:$PATH" CODEX_HOME="$home_dir" CODEX_AUTH_FAKE_CRONTAB_FILE="$crontab_file" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" cron add --time 08:30 --yes 2>&1)

  assert_contains "$output" "Installed codex-auth touch cron job 'daily-0830-all'"
  assert_contains "$output" "Cron: 30 8 * * *"
  assert_contains "$output" "Touch command: codex-auth touch --all"
  crontab_body=$(cat "$crontab_file")
  assert_contains "$crontab_body" "# unmanaged user job"
  assert_contains "$crontab_body" "# BEGIN codex-auth touch daily-0830-all"
  assert_contains "$crontab_body" "# schedule: daily at 08:30"
  assert_contains "$crontab_body" "# target: --all"
  assert_contains "$crontab_body" "30 8 * * *"
  assert_contains "$crontab_body" "cron run daily-0830-all --all"
  assert_contains "$crontab_body" "CODEX_HOME="
  assert_contains "$crontab_body" "PATH="
  assert_not_contains "$crontab_body" "CODEX_AUTH_CODEX_BIN="
  assert_contains "$crontab_body" "touch.log"
  assert_contains "$crontab_body" "# END codex-auth touch daily-0830-all"

  list_output=$(PATH="$fake_crontab_dir:$stub_codex_dir:$PATH" CODEX_HOME="$home_dir" CODEX_AUTH_FAKE_CRONTAB_FILE="$crontab_file" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" cron list)
  assert_contains "$list_output" "CODEX-AUTH TOUCH CRON JOBS"
  assert_contains "$list_output" "daily-0830-all"
  assert_contains "$list_output" "daily at 08:30"
  assert_contains "$list_output" "all profiles"

  delete_output=$(PATH="$fake_crontab_dir:$stub_codex_dir:$PATH" CODEX_HOME="$home_dir" CODEX_AUTH_FAKE_CRONTAB_FILE="$crontab_file" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" cron delete daily-0830-all --yes 2>&1)
  assert_contains "$delete_output" "Deleted codex-auth touch cron job 'daily-0830-all'"
  crontab_body=$(cat "$crontab_file")
  assert_contains "$crontab_body" "# unmanaged user job"
  assert_not_contains "$crontab_body" "daily-0830-all"
}

test_cron_command_keeps_codex_symlink_directory_in_path() {
  local home_dir fake_crontab_dir crontab_file command_dir command_dir_physical real_dir real_dir_physical output crontab_body
  home_dir=$(mktemp -d)
  crontab_file=$(mktemp)
  fake_crontab_dir=$(make_fake_crontab_dir)
  command_dir=$(mktemp -d)
  real_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"
  cat > "$real_dir/codex.js" <<'SCRIPT'
#!/usr/bin/env node
SCRIPT
  chmod +x "$real_dir/codex.js"
  ln -s "$real_dir/codex.js" "$command_dir/codex"
  command_dir_physical=$(CDPATH= cd -- "$command_dir" && pwd -P)
  real_dir_physical=$(CDPATH= cd -- "$real_dir" && pwd -P)

  output=$(PATH="$fake_crontab_dir:$command_dir:$PATH" CODEX_HOME="$home_dir" CODEX_AUTH_FAKE_CRONTAB_FILE="$crontab_file" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" cron add --time 08:30 --yes 2>&1)

  assert_contains "$output" "Installed codex-auth touch cron job 'daily-0830-all'"
  crontab_body=$(cat "$crontab_file")
  assert_contains "$crontab_body" "PATH=$command_dir_physical:"
  assert_not_contains "$crontab_body" "PATH=$real_dir_physical:"
  assert_not_contains "$crontab_body" "CODEX_AUTH_CODEX_BIN="
}

test_cron_refuses_to_overwrite_when_crontab_cannot_be_read() {
  local home_dir stub_codex_dir failing_crontab_dir output status=0
  home_dir=$(mktemp -d)
  stub_codex_dir=$(make_stub_codex_dir)
  failing_crontab_dir=$(make_failing_crontab_dir)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"

  output=$(PATH="$failing_crontab_dir:$stub_codex_dir:$PATH" CODEX_HOME="$home_dir" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" cron add --time 08:30 --yes 2>&1) || status=$?

  [[ $status -ne 0 ]] || fail "expected cron add to fail when the current crontab cannot be read"
  assert_contains "$output" "permission denied reading crontab"
  assert_not_contains "$output" "Installed codex-auth touch cron job"
}

test_cron_delete_preserves_unrelated_lines_after_malformed_managed_block() {
  local home_dir stub_codex_dir fake_crontab_dir crontab_file output status=0 crontab_body
  home_dir=$(mktemp -d)
  crontab_file=$(mktemp)
  stub_codex_dir=$(make_stub_codex_dir)
  fake_crontab_dir=$(make_fake_crontab_dir)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"
  cat > "$crontab_file" <<'CRON'
# BEGIN codex-auth touch broken-job
# schedule: daily at 08:30
30 8 * * * echo broken
5 4 * * * echo keep
CRON

  output=$(PATH="$fake_crontab_dir:$stub_codex_dir:$PATH" CODEX_HOME="$home_dir" CODEX_AUTH_FAKE_CRONTAB_FILE="$crontab_file" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" cron delete broken-job --yes 2>&1) || status=$?

  [[ $status -ne 0 ]] || fail "expected malformed managed block deletion to fail safely"
  assert_contains "$output" "No matching codex-auth touch cron job found"
  crontab_body=$(cat "$crontab_file")
  assert_contains "$crontab_body" "echo broken"
  assert_contains "$crontab_body" "echo keep"
}

test_cron_add_supports_specific_profile_and_custom_schedule() {
  local home_dir stub_codex_dir fake_crontab_dir crontab_file output crontab_body
  home_dir=$(mktemp -d)
  crontab_file=$(mktemp)
  stub_codex_dir=$(make_stub_codex_dir)
  fake_crontab_dir=$(make_fake_crontab_dir)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"

  output=$(PATH="$fake_crontab_dir:$stub_codex_dir:$PATH" CODEX_HOME="$home_dir" CODEX_AUTH_FAKE_CRONTAB_FILE="$crontab_file" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" cron add --time 07:15 --profile alpha --yes 2>&1)

  assert_contains "$output" "Installed codex-auth touch cron job 'daily-0715-alpha'"
  assert_contains "$output" "Cron: 15 7 * * *"
  assert_contains "$output" "Touch command: codex-auth touch alpha"
  crontab_body=$(cat "$crontab_file")
  assert_contains "$crontab_body" "# schedule: daily at 07:15"
  assert_contains "$crontab_body" "# target: alpha"
  assert_contains "$crontab_body" "15 7 * * *"
  assert_contains "$crontab_body" "cron run daily-0715-alpha alpha"

  output=$(PATH="$fake_crontab_dir:$stub_codex_dir:$PATH" CODEX_HOME="$home_dir" CODEX_AUTH_FAKE_CRONTAB_FILE="$crontab_file" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" cron add --schedule "30 8 * * 1,3,5" --id mwf-0830 --yes 2>&1)
  assert_contains "$output" "Installed codex-auth touch cron job 'mwf-0830'"
  assert_contains "$output" "30 8 * * 1,3,5"
  assert_contains "$output" "Touch command: codex-auth touch --all"
  crontab_body=$(cat "$crontab_file")
  assert_contains "$crontab_body" "# schedule: custom: 30 8 * * 1,3,5"
  assert_contains "$crontab_body" "# BEGIN codex-auth touch mwf-0830"
}

test_cron_setup_wizard_installs_default_daily_all_job() {
  local home_dir stub_codex_dir fake_crontab_dir crontab_file output crontab_body
  home_dir=$(mktemp -d)
  crontab_file=$(mktemp)
  stub_codex_dir=$(make_stub_codex_dir)
  fake_crontab_dir=$(make_fake_crontab_dir)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"

  output=$(printf '\n\n09:05\n\n' | PATH="$fake_crontab_dir:$stub_codex_dir:$PATH" CODEX_HOME="$home_dir" CODEX_AUTH_FAKE_CRONTAB_FILE="$crontab_file" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" cron setup 2>&1)

  assert_contains "$output" "No codex-auth touch cron jobs found."
  assert_contains "$output" "Touch target"
  assert_contains "$output" "Schedule"
  assert_contains "$output" "Daily at a time"
  assert_contains "$output" "Custom cron expression"
  assert_not_contains "$output" "Weekdays"
  assert_contains "$output" "Cron: 5 9 * * *"
  assert_contains "$output" "Installed codex-auth touch cron job 'daily-0905-all'"
  crontab_body=$(cat "$crontab_file")
  assert_contains "$crontab_body" "# BEGIN codex-auth touch daily-0905-all"
  assert_contains "$crontab_body" "5 9 * * *"
  assert_contains "$crontab_body" "cron run daily-0905-all --all"
}

test_cron_setup_wizard_supports_whiptail_when_available() {
  local home_dir stub_codex_dir fake_crontab_dir stub_whiptail_dir crontab_file whiptail_log output crontab_body
  home_dir=$(mktemp -d)
  crontab_file=$(mktemp)
  whiptail_log=$(mktemp)
  stub_codex_dir=$(make_stub_codex_dir)
  fake_crontab_dir=$(make_fake_crontab_dir)
  stub_whiptail_dir=$(make_stub_whiptail_dir)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"

  output=$(PATH="$stub_whiptail_dir:$fake_crontab_dir:$stub_codex_dir:$PATH" CODEX_HOME="$home_dir" CODEX_AUTH_FAKE_CRONTAB_FILE="$crontab_file" CODEX_AUTH_FORCE_WHIPTAIL=1 CODEX_AUTH_WHIPTAIL_LOG="$whiptail_log" /bin/bash "$ROOT_DIR/bin/codex-auth" cron setup 2>&1)

  assert_contains "$output" "30 8 * * 1,3,5"
  assert_contains "$output" "Installed codex-auth touch cron job 'custom-all'"
  assert_contains "$(cat "$whiptail_log")" "--menu Touch target"
  assert_contains "$(cat "$whiptail_log")" "--menu Schedule"
  assert_contains "$(cat "$whiptail_log")" "--inputbox"
  assert_contains "$(cat "$whiptail_log")" "--yesno"
  crontab_body=$(cat "$crontab_file")
  assert_contains "$crontab_body" "# schedule: custom: 30 8 * * 1,3,5"
  assert_contains "$crontab_body" "cron run custom-all --all"
}

test_cron_setup_numbered_fallback_uses_color_when_forced() {
  local home_dir stub_codex_dir fake_crontab_dir crontab_file output
  home_dir=$(mktemp -d)
  crontab_file=$(mktemp)
  stub_codex_dir=$(make_stub_codex_dir)
  fake_crontab_dir=$(make_fake_crontab_dir)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"

  output=$(printf '\n\n09:10\n\n' | PATH="$fake_crontab_dir:$stub_codex_dir:$PATH" CODEX_HOME="$home_dir" CODEX_AUTH_FAKE_CRONTAB_FILE="$crontab_file" CODEX_AUTH_FORCE_COLOR=1 CODEX_AUTH_DISABLE_WHIPTAIL=1 /bin/bash "$ROOT_DIR/bin/codex-auth" cron setup 2>&1)

  assert_contains "$output" $'\033['
  assert_contains "$output" "Touch target"
  assert_contains "$output" "Schedule"
  assert_contains "$output" "Installed codex-auth touch cron job 'daily-0910-all'"
}

test_cron_run_prints_timestamps_and_invokes_touch() {
  local home_dir stub_dir output log_file
  home_dir=$(mktemp -d)
  stub_dir=$(mktemp -d)
  log_file="$stub_dir/codex.log"
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"
  cp "$home_dir/accounts/profiles/alpha/auth.json" "$home_dir/auth.json"
  printf 'alpha\n' > "$home_dir/accounts/current_profile"
  cat > "$stub_dir/codex" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$CODEX_STUB_LOG"
if [[ "${1:-}" == "exec" ]]; then
  printf 'hi\n'
fi
SCRIPT
  chmod +x "$stub_dir/codex"

  output=$(PATH="$stub_dir:$PATH" CODEX_HOME="$home_dir" CODEX_STUB_LOG="$log_file" NO_COLOR=1 /bin/bash "$ROOT_DIR/bin/codex-auth" cron run manual-test alpha 2>&1)

  assert_contains "$output" "START codex-auth touch alpha (job=manual-test)"
  assert_contains "$output" "Touching alpha"
  assert_contains "$output" "Tokens unchanged for 'alpha'"
  assert_contains "$output" "END codex-auth touch alpha (job=manual-test status=0)"
  assert_contains "$(cat "$log_file")" "exec"
}

test_cron_implementation_avoids_nonportable_bash_and_date_flags() {
  local script
  script=$(cat "$ROOT_DIR/bin/codex-auth")
  assert_not_contains "$script" "read -e -r -i"
  assert_not_contains "$script" "date -Is"
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

make_remote_release_fixture() {
  local version=$1
  local remote_dir
  remote_dir=$(mktemp -d)
  mkdir -p "$remote_dir/bin" "$remote_dir/completions"
  sed "s/^APP_VERSION=.*/APP_VERSION=\"$version\"/" "$ROOT_DIR/bin/codex-auth" > "$remote_dir/bin/codex-auth"
  cp "$ROOT_DIR/install.sh" "$remote_dir/install.sh"
  cp "$ROOT_DIR/completions/codex-auth.bash" "$remote_dir/completions/codex-auth.bash"
  printf '%s\n' "$version" > "$remote_dir/VERSION"
  printf '%s\n' "$remote_dir"
}

test_update_command_reuses_the_installer_without_cloning() {
  local prefix stub_codex_dir remote_dir output
  prefix=$(mktemp -d)
  stub_codex_dir=$(make_stub_codex_dir)
  remote_dir=$(make_remote_release_fixture "9.9.9")
  PATH="$stub_codex_dir:$PATH" CODEX_AUTH_INSTALL_FROM="file://$ROOT_DIR" bash <(cat "$ROOT_DIR/install.sh") --prefix "$prefix" --skip-completions >/dev/null
  output=$(PATH="$stub_codex_dir:$PATH" NO_COLOR=1 CODEX_AUTH_INSTALL_FROM="file://$remote_dir" "$prefix/bin/codex-auth" update 2>&1)
  assert_contains "$output" "Updated codex-auth $EXPECTED_VERSION → 9.9.9"
  assert_not_contains "$output" "Installing codex-auth"
  [[ -x "$prefix/bin/codex-auth" ]] || fail "expected executable to still exist after codex-auth update"
  [[ "$("$prefix/bin/codex-auth" --version)" == "9.9.9" ]] || fail "expected updated binary to report 9.9.9"
}

test_update_command_reports_already_up_to_date() {
  local prefix stub_codex_dir output
  prefix=$(mktemp -d)
  stub_codex_dir=$(make_stub_codex_dir)
  PATH="$stub_codex_dir:$PATH" CODEX_AUTH_INSTALL_FROM="file://$ROOT_DIR" bash <(cat "$ROOT_DIR/install.sh") --prefix "$prefix" --skip-completions >/dev/null
  output=$(PATH="$stub_codex_dir:$PATH" NO_COLOR=1 CODEX_AUTH_INSTALL_FROM="file://$ROOT_DIR" "$prefix/bin/codex-auth" update 2>&1)
  assert_contains "$output" "codex-auth $EXPECTED_VERSION is already up to date."
  assert_not_contains "$output" "Updated codex-auth"
  [[ "$("$prefix/bin/codex-auth" --version)" == "$EXPECTED_VERSION" ]] || fail "expected binary version to stay $EXPECTED_VERSION"
}

test_update_check_prompts_once_and_declining_runs_command() {
  local home_dir remote_dir output
  home_dir=$(mktemp -d)
  remote_dir=$(mktemp -d)
  printf '9.9.9\n' > "$remote_dir/VERSION"
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha"

  output=$(printf 'n\n' | NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_NO_UPDATE_CHECK=0 CODEX_AUTH_FORCE_UPDATE_CHECK=1 CODEX_AUTH_INSTALL_FROM="file://$remote_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" list 2>&1)
  assert_contains "$output" "codex-auth 9.9.9 is available (current $EXPECTED_VERSION). Update now?"
  assert_contains "$output" "PROFILE"
  [[ -f "$home_dir/accounts/update-check" ]] || fail "expected update-check cache to be written"

  # Within the TTL window the check is skipped entirely.
  output=$(NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_NO_UPDATE_CHECK=0 CODEX_AUTH_FORCE_UPDATE_CHECK=1 CODEX_AUTH_INSTALL_FROM="file://$remote_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" list < /dev/null 2>&1)
  assert_not_contains "$output" "is available"
  assert_contains "$output" "PROFILE"
}

test_update_check_failures_never_block_the_command() {
  local home_dir output status=0
  home_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha"

  output=$(NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_NO_UPDATE_CHECK=0 CODEX_AUTH_FORCE_UPDATE_CHECK=1 CODEX_AUTH_INSTALL_FROM="file:///nonexistent-codex-auth-remote" /bin/bash "$ROOT_DIR/bin/codex-auth" list < /dev/null 2>&1) || status=$?
  [[ $status -eq 0 ]] || fail "expected list to succeed when the update check cannot reach the remote"
  assert_not_contains "$output" "is available"
  assert_contains "$output" "PROFILE"
  [[ -f "$home_dir/accounts/update-check" ]] || fail "expected failed check attempt to be cached to avoid retry storms"
}

test_update_check_skipped_when_not_interactive() {
  local home_dir remote_dir output
  home_dir=$(mktemp -d)
  remote_dir=$(mktemp -d)
  printf '9.9.9\n' > "$remote_dir/VERSION"
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha"

  output=$(printf 'n\n' | NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_NO_UPDATE_CHECK=0 CODEX_AUTH_INSTALL_FROM="file://$remote_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" list 2>&1)
  assert_not_contains "$output" "is available"
  assert_contains "$output" "PROFILE"
  [[ ! -f "$home_dir/accounts/update-check" ]] || fail "expected no update-check cache for non-interactive runs"
}

test_update_check_accepting_updates_and_skips_the_command() {
  local prefix stub_codex_dir remote_dir home_dir output
  prefix=$(mktemp -d)
  home_dir=$(mktemp -d)
  stub_codex_dir=$(make_stub_codex_dir)
  remote_dir=$(make_remote_release_fixture "9.9.9")
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha"
  PATH="$stub_codex_dir:$PATH" CODEX_AUTH_INSTALL_FROM="file://$ROOT_DIR" bash <(cat "$ROOT_DIR/install.sh") --prefix "$prefix" --skip-completions >/dev/null

  output=$(printf '\n' | PATH="$stub_codex_dir:$PATH" NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_NO_UPDATE_CHECK=0 CODEX_AUTH_FORCE_UPDATE_CHECK=1 CODEX_AUTH_INSTALL_FROM="file://$remote_dir" "$prefix/bin/codex-auth" list 2>&1)
  assert_contains "$output" "codex-auth 9.9.9 is available (current $EXPECTED_VERSION). Update now?"
  assert_contains "$output" "Updated codex-auth $EXPECTED_VERSION → 9.9.9"
  assert_contains "$output" "Re-run your command"
  assert_not_contains "$output" "PROFILE"
  [[ "$("$prefix/bin/codex-auth" --version)" == "9.9.9" ]] || fail "expected updated binary to report 9.9.9, got: $("$prefix/bin/codex-auth" --version)"
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

test_list_groups_profiles_with_refresh_errors_at_the_end() {
  local home_dir output zeta_line beta_line
  home_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha"
  create_profile_fixture "$home_dir" "beta" "beta@example.com" "acct_beta"
  create_profile_fixture "$home_dir" "zeta" "zeta@example.com" "acct_zeta"
  write_usage_fixture "$home_dir" "alpha" 84 1774656360 61 1774829160
  write_usage_error_fixture "$home_dir" "beta" "token_expired: token expired for token_beta"
  write_usage_fixture "$home_dir" "zeta" 92 1774656360 88 1774829160

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" list)
  assert_not_contains "$output" "ISSUE"
  assert_contains "$output" "Refresh issue: 1 profile needs attention"
  assert_contains "$output" "↳ issue: token_expired: token expired for token_beta"
  assert_contains "$output" "token_expired: token expired for token_beta"
  assert_contains "$output" "----"
  zeta_line=$(printf '%s\n' "$output" | grep -n 'zeta@example.com' | cut -d: -f1)
  beta_line=$(printf '%s\n' "$output" | grep -n 'beta@example.com' | cut -d: -f1)
  [[ -n "$zeta_line" && -n "$beta_line" ]] || fail "expected beta and zeta rows in list output"
  (( zeta_line < beta_line )) || fail "expected failed beta profile to be grouped after healthy zeta profile"

  output=$(TZ=Europe/Prague CODEX_AUTH_FORCE_COLOR=1 CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" list)
  assert_contains "$output" $'\033[31mbeta\033[0m'
  assert_contains "$output" $'\033[31m↳ issue: token_expired: token expired for token_beta\033[0m'
}

test_list_shows_refresh_issue_heading_when_all_profiles_have_errors() {
  local home_dir output
  home_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "beta" "beta@example.com" "acct_beta"
  write_usage_error_fixture "$home_dir" "beta" "token_expired: token expired for token_beta"

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" list)
  assert_contains "$output" "Refresh issue: 1 profile needs attention"
  assert_contains "$output" "beta@example.com"
  assert_contains "$output" "↳ issue: token_expired: token expired for token_beta"
}

test_refresh_without_args_refreshes_all_profiles_without_prompting() {
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

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_USAGE_URL="$usage_url" /bin/bash "$ROOT_DIR/bin/codex-auth" refresh-usage < /dev/null 2>&1)
  assert_not_contains "$output" "Do you want to refresh usage for all profiles?"
  assert_contains "$output" "Refreshing 1/2: alpha..."
  assert_contains "$output" "Refreshing 2/2: beta..."
  assert_contains "$output" "Refreshed alpha"
  assert_contains "$output" "Refreshed beta"
  assert_not_contains "$output" "Refreshing 1/2 ["
  assert_contains "$output" "alpha"
  assert_contains "$output" "beta"
  assert_contains "$output" "84%"
  assert_contains "$output" "61%"
  assert_not_contains "$output" "Session usage:"
  [[ -f "$home_dir/accounts/profiles/alpha/usage.json" ]] || fail "expected alpha usage.json to be written"
  [[ -f "$home_dir/accounts/profiles/beta/usage.json" ]] || fail "expected beta usage.json to be written"

  kill "$server_pid" >/dev/null 2>&1 || true
  trap - RETURN
}

test_refresh_live_fallback_syncs_snapshot_when_live_account_matches() {
  local home_dir port_file server_pid output usage_url
  home_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "beta" "beta@example.com" "acct_beta" "token_beta"
  printf 'beta\n' > "$home_dir/accounts/current_profile"
  cat > "$home_dir/auth.json" <<'JSON'
{"tokens":{"access_token":"token_live_beta","account_id":"acct_beta"}}
JSON

  port_file=$(mktemp)
  server_pid=$(start_mock_usage_server "$port_file" "token_beta")
  trap 'kill "$server_pid" >/dev/null 2>&1 || true' RETURN
  wait_for_file "$port_file" || fail "mock usage server did not start"
  usage_url="http://127.0.0.1:$(cat "$port_file")/usage"

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_USAGE_URL="$usage_url" /bin/bash "$ROOT_DIR/bin/codex-auth" refresh beta 2>&1)
  assert_contains "$output" "snapshot was stale — auto-synced from live Codex session"
  assert_contains "$output" "Refreshed beta"
  assert_contains "$(cat "$home_dir/accounts/profiles/beta/auth.json")" "token_live_beta"

  kill "$server_pid" >/dev/null 2>&1 || true
  trap - RETURN
}

test_refresh_live_fallback_requires_matching_live_account() {
  local home_dir port_file server_pid output usage_url status=0
  home_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "beta" "beta@example.com" "acct_beta" "token_beta"
  printf 'beta\n' > "$home_dir/accounts/current_profile"
  cat > "$home_dir/auth.json" <<'JSON'
{"tokens":{"access_token":"token_live_other","account_id":"acct_other"}}
JSON

  port_file=$(mktemp)
  server_pid=$(start_mock_usage_server "$port_file" "token_beta")
  trap 'kill "$server_pid" >/dev/null 2>&1 || true' RETURN
  wait_for_file "$port_file" || fail "mock usage server did not start"
  usage_url="http://127.0.0.1:$(cat "$port_file")/usage"

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_USAGE_URL="$usage_url" /bin/bash "$ROOT_DIR/bin/codex-auth" refresh beta 2>&1) || status=$?
  [[ $status -ne 0 ]] || fail "expected refresh to fail when live auth belongs to another account"
  assert_contains "$output" "token_expired"
  assert_contains "$(cat "$home_dir/accounts/profiles/beta/auth.json")" "token_beta"
  assert_not_contains "$(cat "$home_dir/accounts/profiles/beta/auth.json")" "token_live_other"

  kill "$server_pid" >/dev/null 2>&1 || true
  trap - RETURN
}

test_refresh_marks_session_backfilled_percents_as_approximate() {
  local home_dir port_file server_pid output usage_url now_iso
  home_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_bare_alpha"
  cp "$home_dir/accounts/profiles/alpha/auth.json" "$home_dir/auth.json"
  now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  write_session_rate_limit_rollout_fixture "$home_dir" "2026/07/12" "rollout-live" "$now_iso" 16 39

  port_file=$(mktemp)
  server_pid=$(start_mock_usage_server "$port_file" "" "token_bare_alpha")
  trap 'kill "$server_pid" >/dev/null 2>&1 || true' RETURN
  wait_for_file "$port_file" || fail "mock usage server did not start"
  usage_url="http://127.0.0.1:$(cat "$port_file")/usage"

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_USAGE_URL="$usage_url" /bin/bash "$ROOT_DIR/bin/codex-auth" refresh alpha 2>&1)
  assert_contains "$output" "Refreshed alpha"
  assert_contains "$output" "~84%"
  assert_contains "$output" "~61%"

  kill "$server_pid" >/dev/null 2>&1 || true
  trap - RETURN
}

test_list_marks_fallback_endpoint_usage_as_approximate() {
  local home_dir output
  home_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"
  cat > "$home_dir/accounts/profiles/alpha/usage.json" <<'JSON'
{
  "fetchedAt":"2026-03-27T23:10:00Z",
  "plan_type":"plus",
  "endpoint":"fallback",
  "backend_derived":{
    "five_hour_remaining_percent":84,
    "weekly_remaining_percent":61
  },
  "derived":{
    "five_hour_remaining_percent":84,
    "weekly_remaining_percent":61
  }
}
JSON
  output=$(NO_COLOR=1 CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" list)
  assert_contains "$output" "~84%"
  assert_contains "$output" "~61%"

  # Legacy usage.json without the endpoint field: infer fallback from the URL.
  cat > "$home_dir/accounts/profiles/alpha/usage.json" <<'JSON'
{
  "fetchedAt":"2026-03-27T23:10:00Z",
  "plan_type":"plus",
  "url":"https://chatgpt.com/backend-api/wham/usage",
  "backend_derived":{
    "five_hour_remaining_percent":84,
    "weekly_remaining_percent":61
  },
  "derived":{
    "five_hour_remaining_percent":84,
    "weekly_remaining_percent":61
  }
}
JSON
  output=$(NO_COLOR=1 CODEX_HOME="$home_dir" /bin/bash "$ROOT_DIR/bin/codex-auth" list)
  assert_contains "$output" "~84%"
  assert_contains "$output" "~61%"
}

test_refresh_ignores_stale_session_snapshots() {
  local home_dir port_file server_pid output usage_url
  home_dir=$(mktemp -d)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_bare_alpha"
  cp "$home_dir/accounts/profiles/alpha/auth.json" "$home_dir/auth.json"
  write_session_rate_limit_rollout_fixture "$home_dir" "2026/07/10" "rollout-old" "2026-07-10T10:00:00Z" 16 39

  port_file=$(mktemp)
  server_pid=$(start_mock_usage_server "$port_file" "" "token_bare_alpha")
  trap 'kill "$server_pid" >/dev/null 2>&1 || true' RETURN
  wait_for_file "$port_file" || fail "mock usage server did not start"
  usage_url="http://127.0.0.1:$(cat "$port_file")/usage"

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_USAGE_URL="$usage_url" CODEX_AUTH_NOW="2026-07-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" refresh alpha 2>&1)
  assert_contains "$output" "Refreshed alpha"
  assert_not_contains "$output" "84%"
  assert_not_contains "$output" "61%"
  assert_not_contains "$output" "~"

  kill "$server_pid" >/dev/null 2>&1 || true
  trap - RETURN
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
  assert_contains "$output" "Refresh issue: 2 profiles need attention"
  assert_contains "$output" "↳ issue: token_expired: token expired for token_beta"
  assert_contains "$output" "↳ issue: token_expired: token expired for token_gamma"
  assert_not_contains "$output" "ISSUE"
  assert_contains "$output" "token_expired: token expired for token_beta"
  assert_contains "$output" "token_expired: token expired for token_gamma"
  assert_not_contains "$output" "profiles failed to refresh. See issue lines above."
  assert_not_contains "$output" "profile failed to refresh. See issue lines above."
  assert_contains "$output" "To repair a profile token, run: codex-auth switch <profile> && codex logout && codex login && codex-auth save <profile>"
  assert_not_contains "$output" "beta: Unable to refresh usage for 'beta': token_expired:"
  assert_not_contains "$output" "gamma: Unable to refresh usage for 'gamma': token_expired:"
  assert_contains "$output" "PROFILE"
  assert_contains "$output" "alpha@example.com"
  assert_contains "$output" "beta@example.com"
  assert_contains "$output" "gamma@example.com"
  [[ -f "$home_dir/accounts/profiles/alpha/usage.json" ]] || fail "expected alpha usage.json to be written"
  [[ -f "$home_dir/accounts/profiles/beta/usage.json" ]] || fail "expected beta usage.json to record refresh failure"
  [[ -f "$home_dir/accounts/profiles/gamma/usage.json" ]] || fail "expected gamma usage.json to record refresh failure"
  python3 - "$home_dir/accounts/profiles/beta/usage.json" <<'PY' || fail "expected beta usage.json to include lastRefreshError"
import json
import sys
from pathlib import Path

usage = json.loads(Path(sys.argv[1]).read_text())
assert usage["lastRefreshError"]["summary"].startswith("token_expired:")
PY

  kill "$server_pid" >/dev/null 2>&1 || true
  trap - RETURN
}

test_list_skips_session_stats_by_default_and_with_stats_opts_in() {
  local home_dir pricing_file pricing_cache output stats_output
  home_dir=$(mktemp -d)
  pricing_file=$(mktemp)
  pricing_cache="$home_dir/accounts/pricing-cache.json"
  create_profile_fixture "$home_dir" "demo" "demo@example.com" "acct_demo"
  write_usage_fixture "$home_dir" "demo" 88 1774656360 77 1774829160
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-a" "2026-04-12T08:05:00Z" "gpt-5.4" 1000 200 100 40 1100
  write_rollout_fixture "$home_dir" "2026/04/08" "rollout-b" "2026-04-08T08:05:00Z" "gpt-5.3-codex" 2000 500 200 80 2200
  write_pricing_fixture "$pricing_file"

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_PRICING_URL="file://$pricing_file" CODEX_AUTH_NOW="2026-04-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" list)
  assert_contains "$output" "demo"
  assert_not_contains "$output" "Session usage:"
  [[ ! -f "$pricing_cache" ]] || fail "expected default list to avoid creating pricing cache"

  stats_output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_PRICING_URL="file://$pricing_file" CODEX_AUTH_NOW="2026-04-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" list --with-stats)
  assert_contains "$stats_output" "Session usage: today 1 session"
  assert_contains "$stats_output" '$0.0036 API-eq'
  assert_contains "$stats_output" "1.1k tokens"
  assert_contains "$stats_output" "Session usage: 7d    2 sessions"
  assert_contains "$stats_output" '$0.0091 API-eq'
}

test_refresh_with_stats_flag_includes_session_footer() {
  local home_dir port_file server_pid output usage_url pricing_file
  home_dir=$(mktemp -d)
  pricing_file=$(mktemp)
  create_profile_fixture "$home_dir" "alpha" "alpha@example.com" "acct_alpha" "token_alpha"
  cp "$home_dir/accounts/profiles/alpha/auth.json" "$home_dir/auth.json"
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-a" "2026-04-12T08:05:00Z" "gpt-5.4" 1000 200 100 40 1100
  write_pricing_fixture "$pricing_file"

  port_file=$(mktemp)
  server_pid=$(start_mock_usage_server "$port_file")
  trap 'kill "$server_pid" >/dev/null 2>&1 || true' RETURN
  wait_for_file "$port_file" || fail "mock usage server did not start"
  usage_url="http://127.0.0.1:$(cat "$port_file")/usage"

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_USAGE_URL="$usage_url" CODEX_AUTH_PRICING_URL="file://$pricing_file" CODEX_AUTH_NOW="2026-04-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" refresh-usage --all --with-stats 2>&1)
  assert_contains "$output" "Refreshed alpha"
  assert_contains "$output" "Session usage: today 1 session"
  assert_contains "$output" '$0.0036 API-eq'

  kill "$server_pid" >/dev/null 2>&1 || true
  trap - RETURN
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

test_default_pricing_cache_ttl_keeps_week_old_prices_fresh() {
  local home_dir pricing_file cache_file output
  home_dir=$(mktemp -d)
  pricing_file=$(mktemp)
  cache_file="$home_dir/accounts/pricing-cache.json"
  mkdir -p "$home_dir/accounts"
  create_profile_fixture "$home_dir" "demo" "demo@example.com" "acct_demo"
  write_pricing_fixture_multi_section "$pricing_file"
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-53" "2026-04-12T08:07:00Z" "gpt-5.3-codex" 1000000 0 0 0 1000000
  cat > "$cache_file" <<'JSON'
{
  "cache_schema_version": 3,
  "tier": "standard",
  "fetched_at": "2026-04-06T12:00:00Z",
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

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_PRICING_URL="file://$pricing_file" CODEX_AUTH_NOW="2026-04-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" stats --period today)
  assert_contains "$output" 'gpt-5.3-codex → gpt-5.4'
  assert_contains "$output" 'status: fresh-cache'
}

test_stats_reuses_session_cache_and_recompute_bypasses_it() {
  local home_dir pricing_file cache_file output recompute_output rollout_file
  home_dir=$(mktemp -d)
  pricing_file=$(mktemp)
  cache_file="$home_dir/accounts/session-stats-cache.json"
  create_profile_fixture "$home_dir" "demo" "demo@example.com" "acct_demo"
  write_pricing_fixture "$pricing_file"
  write_rollout_fixture "$home_dir" "2026/04/12" "rollout-a" "2026-04-12T08:05:00Z" "gpt-5.4" 1000 200 100 40 1100
  rollout_file="$home_dir/sessions/2026/04/12/rollout-a.jsonl"
  mkdir -p "$home_dir/accounts"
  python3 - "$rollout_file" "$cache_file" <<'PY'
import json
import sys
from pathlib import Path
rollout_file = Path(sys.argv[1])
cache_file = Path(sys.argv[2])
stat = rollout_file.stat()
cache = {
    "cache_schema_version": 1,
    "sessions_dir": str(rollout_file.parents[3]),
    "entries": {
        "2026/04/12/rollout-a.jsonl": {
            "size": stat.st_size,
            "mtime_ns": stat.st_mtime_ns,
            "events": [{
                "timestamp": "2026-04-12T08:05:00Z",
                "session_id": "rollout-a",
                "model": "gpt-5.4",
                "input_tokens": 9000,
                "cached_input_tokens": 0,
                "output_tokens": 900,
                "reasoning_output_tokens": 90,
                "total_tokens": 9900
            }]
        }
    }
}
cache_file.write_text(json.dumps(cache), encoding="utf-8")
PY

  output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_PRICING_URL="file://$pricing_file" CODEX_AUTH_NOW="2026-04-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" stats --period today)
  assert_contains "$output" "9.9k"
  assert_contains "$output" "Stats cache:"

  recompute_output=$(TZ=Europe/Prague NO_COLOR=1 CODEX_HOME="$home_dir" CODEX_AUTH_PRICING_URL="file://$pricing_file" CODEX_AUTH_NOW="2026-04-12T12:00:00Z" /bin/bash "$ROOT_DIR/bin/codex-auth" stats --period today --recompute)
  assert_contains "$recompute_output" "1.1k"
  assert_not_contains "$recompute_output" "9.9k"
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
  test_update_command_reports_already_up_to_date
  test_update_check_prompts_once_and_declining_runs_command
  test_update_check_failures_never_block_the_command
  test_update_check_skipped_when_not_interactive
  test_update_check_accepting_updates_and_skips_the_command
  test_list_works_with_minimal_path
  test_list_uses_local_timezone_by_default_and_utc_when_requested
  test_list_groups_profiles_with_refresh_errors_at_the_end
  test_list_shows_refresh_issue_heading_when_all_profiles_have_errors
  test_refresh_without_args_refreshes_all_profiles_without_prompting
  test_refresh_live_fallback_syncs_snapshot_when_live_account_matches
  test_refresh_live_fallback_requires_matching_live_account
  test_refresh_marks_session_backfilled_percents_as_approximate
  test_list_marks_fallback_endpoint_usage_as_approximate
  test_refresh_ignores_stale_session_snapshots
  test_refresh_continues_after_profile_failures_and_summarizes
  test_save_tracks_id_and_access_token_expiry_in_meta
  test_switch_round_trip_preserves_the_saved_snapshot_byte_for_byte
  test_switch_warns_when_restored_snapshot_token_is_expired
  test_token_status_reports_both_token_expirations
  test_token_status_uses_color_and_active_marker_when_enabled
  test_touch_profile_runs_minimal_codex_exec_saves_token_and_restores_current_profile
  test_touch_reports_when_codex_does_not_rotate_tokens
  test_touch_refuses_to_run_when_touch_lock_exists
  test_cron_add_lists_and_deletes_managed_touch_job
  test_cron_command_keeps_codex_symlink_directory_in_path
  test_cron_refuses_to_overwrite_when_crontab_cannot_be_read
  test_cron_delete_preserves_unrelated_lines_after_malformed_managed_block
  test_cron_add_supports_specific_profile_and_custom_schedule
  test_cron_setup_wizard_installs_default_daily_all_job
  test_cron_setup_wizard_supports_whiptail_when_available
  test_cron_setup_numbered_fallback_uses_color_when_forced
  test_cron_run_prints_timestamps_and_invokes_touch
  test_cron_implementation_avoids_nonportable_bash_and_date_flags
  test_list_skips_session_stats_by_default_and_with_stats_opts_in
  test_refresh_with_stats_flag_includes_session_footer
  test_stats_reports_overview_daily_and_model_breakdown
  test_statistics_alias_and_all_period_cap_daily_rows
  test_stats_uses_standard_pricing_tier_and_explains_cost_methodology
  test_stats_uses_exact_pricing_for_models_found_later_on_the_pricing_page
  test_default_pricing_cache_ttl_keeps_week_old_prices_fresh
  test_stats_reuses_session_cache_and_recompute_bypasses_it
  test_stats_invalidates_old_pricing_cache_schema
  test_workflow_uses_node24_ready_checkout
  test_install_script_avoids_unsafe_array_expansion_in_dependency_report
  test_changelog_tracks_the_current_release_newest_first
  test_agents_md_captures_repo_workflow
  test_completion_lists_update_command
}

main "$@"
