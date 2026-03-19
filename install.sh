#!/usr/bin/env bash
set -euo pipefail

DEFAULT_FROM_BASE="https://raw.githubusercontent.com/Fasand/codex-auth/main"

usage() {
  cat <<USAGE
Usage: install.sh [options]

Install or update codex-auth from a local checkout or from:
  $DEFAULT_FROM_BASE

Options:
  --prefix <dir>            Install under this prefix (default: ~/.local)
  --bin-dir <dir>           Install the executable here
  --completion-dir <dir>    Install Bash completion here
  --from <base-url>         Download files from this raw base URL
  --check-deps              Report dependency status and exit
  --install-deps            Best-effort install supported dependencies
  --skip-completions        Install only the executable
  --yes                     Assume yes for installer prompts
  -h, --help                Show this help

Examples:
  ./install.sh
  ./install.sh --check-deps
  ./install.sh --install-deps
  bash <(curl -fsSL $DEFAULT_FROM_BASE/install.sh)
  bash <(curl -fsSL $DEFAULT_FROM_BASE/install.sh) --install-deps
  bash <(curl -fsSL $DEFAULT_FROM_BASE/install.sh) --from https://raw.githubusercontent.com/someone/codex-auth/main
USAGE
}

die() {
  echo "install.sh: $*" >&2
  exit 1
}

note() {
  echo "$*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

use_color() {
  [[ -n "${NO_COLOR:-}" ]] && return 1
  [[ "${FORCE_COLOR:-}" == "1" || "${FORCE_COLOR:-}" == "true" || "${FORCE_COLOR:-}" == "always" ]] && return 0
  [[ -t 1 ]]
}

paint() {
  local code=$1
  local text=$2
  if use_color; then
    printf '\033[%sm%s\033[0m' "$code" "$text"
  else
    printf '%s' "$text"
  fi
}

status_icon() {
  local state=$1
  case "$state" in
    ok) printf '%s' "✅" ;;
    missing) printf '%s' "❌" ;;
    *) printf '%s' "$state" ;;
  esac
}

print_status_line() {
  local state=$1
  local label=$2
  local detail=${3:-}
  printf '  [%s] %s' "$(status_icon "$state")" "$label"
  if [[ -n "$detail" ]]; then
    printf ' — %s' "$detail"
  fi
  printf '\n'
}

join_by() {
  local sep=$1
  shift || true
  local out=""
  local item
  for item in "$@"; do
    if [[ -n "$out" ]]; then
      out+="$sep"
    fi
    out+="$item"
  done
  printf '%s\n' "$out"
}

append_unique() {
  local array_name=$1
  local value=$2
  eval "local current=(\"\${${array_name}[@]:-}\")"
  local item
  for item in "${current[@]}"; do
    [[ "$item" == "$value" ]] && return 0
  done
  eval "${array_name}+=(\"$value\")"
}

print_section() {
  local title=$1
  shift || true
  echo "$title"
  if [[ $# -eq 0 ]]; then
    echo "  (none)"
    return 0
  fi
  local item
  for item in "$@"; do
    echo "  - $item"
  done
}

array_contains() {
  local needle=$1
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux) echo "linux" ;;
    *) echo "other" ;;
  esac
}

detect_package_manager() {
  if have_cmd brew; then
    echo "brew"
  elif have_cmd apt-get; then
    echo "apt-get"
  elif have_cmd dnf; then
    echo "dnf"
  elif have_cmd pacman; then
    echo "pacman"
  else
    echo ""
  fi
}

bash_completion_available() {
  local path
  for path in \
    /usr/share/bash-completion/bash_completion \
    /etc/bash_completion \
    /opt/homebrew/etc/profile.d/bash_completion.sh \
    /usr/local/etc/profile.d/bash_completion.sh
  do
    [[ -f "$path" ]] && return 0
  done
  return 1
}

package_for_feature() {
  local manager=$1
  local feature=$2
  case "$manager:$feature" in
    apt-get:python3) echo "python3" ;;
    apt-get:curl) echo "curl" ;;
    apt-get:fzf) echo "fzf" ;;
    apt-get:bash-completion) echo "bash-completion" ;;
    dnf:python3) echo "python3" ;;
    dnf:curl) echo "curl" ;;
    dnf:fzf) echo "fzf" ;;
    dnf:bash-completion) echo "bash-completion" ;;
    pacman:python3) echo "python" ;;
    pacman:curl) echo "curl" ;;
    pacman:fzf) echo "fzf" ;;
    pacman:bash-completion) echo "bash-completion" ;;
    brew:python3) echo "python" ;;
    brew:curl) echo "curl" ;;
    brew:fzf) echo "fzf" ;;
    brew:bash-completion) echo "bash-completion@2" ;;
    *) return 1 ;;
  esac
}

install_packages() {
  local manager=$1
  shift
  [[ $# -gt 0 ]] || return 0

  case "$manager" in
    apt-get)
      if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        apt-get update
        apt-get install -y "$@"
      elif have_cmd sudo; then
        sudo apt-get update
        sudo apt-get install -y "$@"
      else
        die "Need sudo or root privileges to install packages with apt-get"
      fi
      ;;
    dnf)
      if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        dnf install -y "$@"
      elif have_cmd sudo; then
        sudo dnf install -y "$@"
      else
        die "Need sudo or root privileges to install packages with dnf"
      fi
      ;;
    pacman)
      if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        pacman -Sy --noconfirm "$@"
      elif have_cmd sudo; then
        sudo pacman -Sy --noconfirm "$@"
      else
        die "Need sudo or root privileges to install packages with pacman"
      fi
      ;;
    brew)
      brew install "$@"
      ;;
    *)
      die "Unsupported package manager: $manager"
      ;;
  esac
}

prefix="${PREFIX:-$HOME/.local}"
bin_dir=""
completion_dir=""
from_base="${CODEX_AUTH_INSTALL_FROM:-$DEFAULT_FROM_BASE}"
skip_completions=0
check_deps_only=0
install_deps=0
auto_yes=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      [[ $# -ge 2 ]] || die "Missing value for --prefix"
      prefix=$2
      shift 2
      ;;
    --bin-dir)
      [[ $# -ge 2 ]] || die "Missing value for --bin-dir"
      bin_dir=$2
      shift 2
      ;;
    --completion-dir)
      [[ $# -ge 2 ]] || die "Missing value for --completion-dir"
      completion_dir=$2
      shift 2
      ;;
    --from)
      [[ $# -ge 2 ]] || die "Missing value for --from"
      from_base=$2
      shift 2
      ;;
    --check-deps)
      check_deps_only=1
      shift
      ;;
    --install-deps)
      install_deps=1
      shift
      ;;
    --skip-completions)
      skip_completions=1
      shift
      ;;
    --yes)
      auto_yes=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

bin_dir=${bin_dir:-$prefix/bin}
completion_dir=${completion_dir:-$prefix/share/bash-completion/completions}
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
local_root=""
if [[ -f "$script_dir/bin/codex-auth" && -f "$script_dir/completions/codex-auth.bash" ]]; then
  local_root=$script_dir
fi
remote_mode=1
if [[ -n "$local_root" ]]; then
  remote_mode=0
fi

os_name=$(detect_os)
package_manager=$(detect_package_manager)

declare -a missing_required_runtime=()
declare -a missing_manual_prereqs=()
declare -a missing_optional=()
declare -a installable_features=()
declare -a installable_packages=()

collect_dependency_state() {
  missing_required_runtime=()
  missing_manual_prereqs=()
  missing_optional=()
  installable_features=()
  installable_packages=()

  if ! have_cmd python3; then
    missing_required_runtime+=("python3")
    append_unique installable_features "python3"
  fi

  if ! have_cmd codex; then
    missing_manual_prereqs+=("codex CLI (manual prerequisite)")
  fi

  if [[ $remote_mode -eq 1 ]] && ! have_cmd curl; then
    missing_required_runtime+=("curl (required for remote install/update)")
    append_unique installable_features "curl"
  fi

  if ! have_cmd fzf; then
    missing_optional+=("fzf (optional interactive picker)")
    append_unique installable_features "fzf"
  fi

  if [[ $skip_completions -eq 0 ]] && ! bash_completion_available; then
    missing_optional+=("bash-completion support (optional auto-loading for completions)")
    append_unique installable_features "bash-completion"
  fi

  local feature package
  if [[ -n "$package_manager" ]]; then
    for feature in "${installable_features[@]}"; do
      if package=$(package_for_feature "$package_manager" "$feature" 2>/dev/null); then
        append_unique installable_packages "$package"
      fi
    done
  fi
}

print_dependency_report() {
  collect_dependency_state
  printf 'Dependency check (%s, %s, %s)\n' "$os_name" "${package_manager:-no package manager detected}" "$([[ $remote_mode -eq 1 ]] && echo remote || echo local-checkout)"
  echo "Required"
  if array_contains "python3" "${missing_required_runtime[@]}"; then
    print_status_line "missing" "python3"
  else
    print_status_line "ok" "python3"
  fi
  if array_contains "codex CLI (manual prerequisite)" "${missing_manual_prereqs[@]}"; then
    print_status_line "missing" "codex CLI" "manual prerequisite"
  else
    print_status_line "ok" "codex CLI"
  fi
  if [[ $remote_mode -eq 1 ]]; then
    if array_contains "curl (required for remote install/update)" "${missing_required_runtime[@]}"; then
      print_status_line "missing" "curl" "required for remote install/update"
    else
      print_status_line "ok" "curl" "required for remote install/update"
    fi
  fi

  echo "Optional"
  if have_cmd column; then
    print_status_line "ok" "column" "prettier tables"
  else
    print_status_line "missing" "column" "plain aligned table fallback is built in"
  fi
  if array_contains "fzf (optional interactive picker)" "${missing_optional[@]}"; then
    print_status_line "missing" "fzf" "interactive picker"
  else
    print_status_line "ok" "fzf" "interactive picker"
  fi
  if [[ $skip_completions -eq 0 ]]; then
    if array_contains "bash-completion support (optional auto-loading for completions)" "${missing_optional[@]}"; then
      print_status_line "missing" "bash-completion" "auto-loading completions"
    else
      print_status_line "ok" "bash-completion" "auto-loading completions"
    fi
  fi

  if [[ ${#installable_packages[@]} -gt 0 ]]; then
    printf 'Install with --install-deps: %s\n' "$(join_by ', ' "${installable_packages[@]}")"
  fi
  if [[ ${#missing_manual_prereqs[@]} -gt 0 ]]; then
    echo "Manual step: install the Codex CLI yourself."
  fi
  if [[ ${#missing_required_runtime[@]} -gt 0 || ${#missing_manual_prereqs[@]} -gt 0 ]]; then
    return 1
  fi
  return 0
}

offer_or_install_dependencies() {
  collect_dependency_state
  [[ ${#installable_packages[@]} -gt 0 ]] || return 0

  if [[ $install_deps -eq 1 ]]; then
    note "Installing supported dependencies with ${package_manager:-unknown package manager}: $(join_by ', ' "${installable_packages[@]}")"
    install_packages "$package_manager" "${installable_packages[@]}"
    return 0
  fi

  if [[ -t 0 && -t 1 && $auto_yes -eq 1 ]]; then
    install_deps=1
    offer_or_install_dependencies
    return 0
  fi

  if [[ -t 0 && -t 1 && -n "$package_manager" ]]; then
    echo
    echo "Missing supported dependencies detected: $(join_by ', ' "${installable_packages[@]}")"
    read -r -p "Attempt to install them now with ${package_manager}? [y/N] " reply
    case "$reply" in
      y|Y|yes|YES)
        install_deps=1
        offer_or_install_dependencies
        return 0
        ;;
    esac
  fi

  return 0
}

fetch_file() {
  local source_url=$1
  local destination=$2
  require_cmd curl
  curl -fsSL "$source_url" -o "$destination"
}

if [[ $check_deps_only -eq 1 ]]; then
  if print_dependency_report; then
    exit 0
  else
    exit 1
  fi
fi

offer_or_install_dependencies
collect_dependency_state

if [[ ${#missing_required_runtime[@]} -gt 0 || ${#missing_manual_prereqs[@]} -gt 0 ]]; then
  echo
  print_dependency_report || true
  echo
  if [[ ${#installable_packages[@]} -gt 0 && -n "$package_manager" ]]; then
    echo "Re-run with --install-deps to install supported dependencies automatically."
  fi
  if [[ ${#missing_manual_prereqs[@]} -gt 0 ]]; then
    echo "The Codex CLI remains a manual prerequisite and is not installed by this script."
  fi
  die "Cannot continue until the required prerequisites are available"
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

executable_src="$workdir/codex-auth"
completion_src="$workdir/codex-auth.bash"

if [[ -n "$local_root" ]]; then
  cp "$local_root/bin/codex-auth" "$executable_src"
  if [[ $skip_completions -eq 0 ]]; then
    cp "$local_root/completions/codex-auth.bash" "$completion_src"
  fi
else
  from_base=${from_base%/}
  fetch_file "$from_base/bin/codex-auth" "$executable_src"
  if [[ $skip_completions -eq 0 ]]; then
    fetch_file "$from_base/completions/codex-auth.bash" "$completion_src"
  fi
fi

mkdir -p "$bin_dir"
install -m 0755 "$executable_src" "$bin_dir/codex-auth"
echo "Installed codex-auth to $bin_dir/codex-auth"

if [[ $skip_completions -eq 0 ]]; then
  mkdir -p "$completion_dir"
  install -m 0644 "$completion_src" "$completion_dir/codex-auth"
  echo "Installed Bash completion to $completion_dir/codex-auth"
fi

if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
  echo
  echo "Add this directory to your PATH if needed:"
  echo "  export PATH=\"$bin_dir:\$PATH\""
fi

if [[ $skip_completions -eq 0 ]]; then
  echo
  if bash_completion_available; then
    echo "Bash completion support looks available on this system."
    echo "If completions do not load automatically, add this to ~/.bashrc:"
  else
    echo "Bash completion support was not detected."
    echo "You can still source the completion file manually by adding this to ~/.bashrc:"
  fi
  echo "  source \"$completion_dir/codex-auth\""
fi

echo
echo "To update later, run the same install command again."
