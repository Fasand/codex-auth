_codex_auth_profile_names() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local profiles_dir="$codex_home/accounts/profiles"
  local d
  [[ -d "$profiles_dir" ]] || return 0
  for d in "$profiles_dir"/*; do
    [[ -d "$d" ]] || continue
    basename "$d"
  done
}

_codex_auth_completion() {
  local cur prev first
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]:-}"
  prev="${COMP_WORDS[COMP_CWORD-1]:-}"
  first="${COMP_WORDS[1]:-}"

  local commands="list current save switch add refresh-usage refresh update rename remove rm delete help"
  local profiles
  profiles="$(_codex_auth_profile_names | tr '\n' ' ')"

  case "$prev" in
    save|switch|add|remove|rm|delete)
      COMPREPLY=( $(compgen -W "$profiles" -- "$cur") )
      return 0
      ;;
    list|current)
      COMPREPLY=( $(compgen -W "--utc" -- "$cur") )
      return 0
      ;;
    refresh-usage|refresh)
      COMPREPLY=( $(compgen -W "--all --utc $profiles" -- "$cur") )
      return 0
      ;;
    --utc)
      if [[ "$first" == "refresh-usage" || "$first" == "refresh" ]]; then
        COMPREPLY=( $(compgen -W "--all $profiles" -- "$cur") )
        return 0
      fi
      ;;
  esac

  if [[ "$first" == "rename" ]]; then
    if [[ "$COMP_CWORD" -eq 2 ]]; then
      COMPREPLY=( $(compgen -W "$profiles" -- "$cur") )
      return 0
    fi
    return 0
  fi

  if [[ "$COMP_CWORD" -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    return 0
  fi
}

complete -F _codex_auth_completion codex-auth
