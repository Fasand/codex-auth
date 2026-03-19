#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Install or update codex-auth from a local checkout or a raw file base URL.

Options:
  --prefix <dir>            Install under this prefix (default: ~/.local)
  --bin-dir <dir>           Install the executable here
  --completion-dir <dir>    Install Bash completion here
  --from <base-url>         Download files from this raw base URL
  --skip-completions        Install only the executable
  -h, --help                Show this help

Examples:
  ./install.sh
  ./install.sh --prefix /usr/local
  bash <(curl -fsSL https://raw.githubusercontent.com/<owner>/codex-auth/main/install.sh) \
    --from https://raw.githubusercontent.com/<owner>/codex-auth/main
USAGE
}

die() {
  echo "install.sh: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

prefix="${PREFIX:-$HOME/.local}"
bin_dir=""
completion_dir=""
from_base="${CODEX_AUTH_INSTALL_FROM:-}"
skip_completions=0

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
    --skip-completions)
      skip_completions=1
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

fetch_file() {
  local source_url=$1
  local destination=$2
  require_cmd curl
  curl -fsSL "$source_url" -o "$destination"
}

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
  [[ -n "$from_base" ]] || die "Run this script from a codex-auth checkout, or provide --from <base-url>"
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
  echo "If Bash completions do not load automatically, add this to ~/.bashrc:"
  echo "  source \"$completion_dir/codex-auth\""
fi

echo
echo "To update later, run the same install command again."
