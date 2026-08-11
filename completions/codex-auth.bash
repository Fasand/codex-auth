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

_codex_auth_cron_job_ids() {
  crontab -l 2>/dev/null | sed -n 's/^# BEGIN codex-auth touch //p'
}

_codex_auth_completion() {
  local cur prev first
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]:-}"
  prev="${COMP_WORDS[COMP_CWORD-1]:-}"
  first="${COMP_WORDS[1]:-}"

  local commands="list current save switch add refresh-usage refresh refresh-tokens token-status touch cron stats statistics update rename remove rm delete help"
  local profiles
  profiles="$(_codex_auth_profile_names | tr '\n' ' ')"

  if [[ "$first" == "cron" ]]; then
    local subcmd="${COMP_WORDS[2]:-}"
    local cron_jobs
    cron_jobs="$(_codex_auth_cron_job_ids | tr '\n' ' ')"

    if [[ "$COMP_CWORD" -eq 2 ]]; then
      COMPREPLY=( $(compgen -W "list setup add delete remove rm run help" -- "$cur") )
      return 0
    fi

    case "$subcmd" in
      add)
        case "$prev" in
          --profile)
            COMPREPLY=( $(compgen -W "$profiles" -- "$cur") )
            return 0
            ;;
          --time|--schedule|--id)
            return 0
            ;;
        esac
        COMPREPLY=( $(compgen -W "--time --daily --schedule --all --profile --id --yes -y" -- "$cur") )
        return 0
        ;;
      delete|remove|rm)
        COMPREPLY=( $(compgen -W "--all --yes -y $cron_jobs" -- "$cur") )
        return 0
        ;;
      run)
        if [[ "$COMP_CWORD" -eq 3 ]]; then
          COMPREPLY=( $(compgen -W "$cron_jobs" -- "$cur") )
          return 0
        fi
        COMPREPLY=( $(compgen -W "--all $profiles" -- "$cur") )
        return 0
        ;;
    esac

    return 0
  fi

  case "$prev" in
    save|switch|add|remove|rm|delete)
      COMPREPLY=( $(compgen -W "$profiles" -- "$cur") )
      return 0
      ;;
    touch)
      COMPREPLY=( $(compgen -W "--all $profiles" -- "$cur") )
      return 0
      ;;
    refresh-tokens)
      COMPREPLY=( $(compgen -W "--all --force $profiles" -- "$cur") )
      return 0
      ;;
    list)
      COMPREPLY=( $(compgen -W "--utc --with-stats" -- "$cur") )
      return 0
      ;;
    current)
      COMPREPLY=( $(compgen -W "--utc" -- "$cur") )
      return 0
      ;;
    refresh-usage|refresh)
      COMPREPLY=( $(compgen -W "--all --utc --with-stats $profiles" -- "$cur") )
      return 0
      ;;
    token-status)
      COMPREPLY=( $(compgen -W "--all --utc $profiles" -- "$cur") )
      return 0
      ;;
    stats|statistics)
      COMPREPLY=( $(compgen -W "--utc --period --recompute" -- "$cur") )
      return 0
      ;;
    --period)
      if [[ "$first" == "stats" || "$first" == "statistics" ]]; then
        COMPREPLY=( $(compgen -W "today 7d 14d 30d all" -- "$cur") )
        return 0
      fi
      ;;
    --utc)
      if [[ "$first" == "refresh-usage" || "$first" == "refresh" ]]; then
        COMPREPLY=( $(compgen -W "--all --with-stats --utc $profiles" -- "$cur") )
        return 0
      fi
      if [[ "$first" == "token-status" ]]; then
        COMPREPLY=( $(compgen -W "--all --utc $profiles" -- "$cur") )
        return 0
      fi
      if [[ "$first" == "list" ]]; then
        COMPREPLY=( $(compgen -W "--utc --with-stats" -- "$cur") )
        return 0
      fi
      if [[ "$first" == "stats" || "$first" == "statistics" ]]; then
        COMPREPLY=( $(compgen -W "--period --recompute --utc" -- "$cur") )
        return 0
      fi
      ;;
    --with-stats)
      if [[ "$first" == "refresh-usage" || "$first" == "refresh" ]]; then
        COMPREPLY=( $(compgen -W "--all --with-stats --utc $profiles" -- "$cur") )
        return 0
      fi
      if [[ "$first" == "list" ]]; then
        COMPREPLY=( $(compgen -W "--utc --with-stats" -- "$cur") )
        return 0
      fi
      ;;
    --recompute)
      if [[ "$first" == "stats" || "$first" == "statistics" ]]; then
        COMPREPLY=( $(compgen -W "--period --recompute --utc" -- "$cur") )
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

  if [[ "$first" == "touch" ]]; then
    COMPREPLY=( $(compgen -W "--all $profiles" -- "$cur") )
    return 0
  fi

  if [[ "$first" == "refresh-tokens" ]]; then
    COMPREPLY=( $(compgen -W "--all --force $profiles" -- "$cur") )
    return 0
  fi

  if [[ "$COMP_CWORD" -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    return 0
  fi
}

complete -F _codex_auth_completion codex-auth
