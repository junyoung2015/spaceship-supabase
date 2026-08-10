#!/usr/bin/env zsh
#
# spaceship-supabase - trustworthy local Supabase link context for Spaceship
# https://github.com/junyoung2015/spaceship-supabase
#
# MIT License
# Copyright (c) 2025 Eddie Sohn

# This plugin intentionally supports Zsh only.  The prompt path is local,
# read-only, and uses no external commands or Supabase CLI invocations.
if [[ -z ${ZSH_VERSION-} ]]; then
  print -ru2 -- 'spaceship-supabase: requires Zsh 5.2 or newer'
  return 1
fi

autoload -Uz is-at-least
if ! is-at-least 5.2; then
  print -ru2 -- 'spaceship-supabase: requires Zsh 5.2 or newer'
  return 1
fi

# These are shell modules, not external programs.  zsh/stat is required for
# the fail-closed filesystem checks; zsh/files and zsh/system are used only by
# explicit label-management helpers, never while rendering a prompt.
typeset -g _SPACESHIP_SUPABASE_STAT_READY=true
zmodload zsh/stat 2>/dev/null || _SPACESHIP_SUPABASE_STAT_READY=false
typeset -g _SPACESHIP_SUPABASE_FILES_READY=true
# Explicitly request the zf_* names. Zsh 5.2 can load zsh/files without
# exposing those aliases through a plain module load, while later Zsh releases
# commonly make them visible automatically. zf_chmod was added after 5.2, so
# creation modes are enforced directly by zf_mkdir and sysopen below.
zmodload -F zsh/files b:zf_mkdir b:zf_mv b:zf_rm 2>/dev/null || _SPACESHIP_SUPABASE_FILES_READY=false
typeset -g _SPACESHIP_SUPABASE_SYSTEM_READY=true
zmodload zsh/system 2>/dev/null || _SPACESHIP_SUPABASE_SYSTEM_READY=false
zmodload zsh/datetime 2>/dev/null

# Public configuration.  An explicitly empty setting remains empty so invalid
# user configuration fails closed instead of silently gaining a new meaning.
SPACESHIP_SUPABASE_SHOW="${SPACESHIP_SUPABASE_SHOW-true}"
SPACESHIP_SUPABASE_ASYNC="${SPACESHIP_SUPABASE_ASYNC-true}"
SPACESHIP_SUPABASE_COLOR="${SPACESHIP_SUPABASE_COLOR-cyan}"
SPACESHIP_SUPABASE_SYMBOL="${SPACESHIP_SUPABASE_SYMBOL-🔷 }"
SPACESHIP_SUPABASE_PREFIX="${SPACESHIP_SUPABASE_PREFIX-}"
SPACESHIP_SUPABASE_SUFFIX="${SPACESHIP_SUPABASE_SUFFIX-${SPACESHIP_PROMPT_DEFAULT_SUFFIX-}}"
SPACESHIP_SUPABASE_FORMAT="${SPACESHIP_SUPABASE_FORMAT-ref}"
SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH="${SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH-false}"
SPACESHIP_SUPABASE_CONFIG_REMOTE="${SPACESHIP_SUPABASE_CONFIG_REMOTE-}"
SPACESHIP_SUPABASE_USE_LABELS="${SPACESHIP_SUPABASE_USE_LABELS-true}"
SPACESHIP_SUPABASE_LABEL_FILE="${SPACESHIP_SUPABASE_LABEL_FILE-${XDG_STATE_HOME:-$HOME/.local/state}/spaceship-supabase/labels.tsv}"
SPACESHIP_SUPABASE_DEBUG="${SPACESHIP_SUPABASE_DEBUG-false}"

# This association carries only the current render's validated values.  It is
# cleared and rebuilt on every render; it is deliberately not a value cache.
typeset -gA _SPACESHIP_SUPABASE_CONTEXT

_spaceship_supabase_debug() {
  emulate -L zsh

  [[ ${SPACESHIP_SUPABASE_DEBUG-} == true ]] || return 0

  # Never echo a path, a config line, a label, or any other untrusted value.
  case ${1-} in
    ROOT_INVALID|ROOT_NOT_FOUND|STATE_INVALID|CONFIG_INVALID|LABEL_STORE_INVALID|\
    LOCAL_DB_BRANCH_INVALID|\
    UNSUPPORTED_FORMAT|RENDERER_UNAVAILABLE|NO_LIVE_REF|LABEL_INVALID|\
    LABEL_WRITE_FAILED|HELPER_USAGE)
      print -ru2 -- "spaceship-supabase: ${1}"
      ;;
  esac
}

_spaceship_supabase_trim_hspace() {
  emulate -L zsh
  setopt extendedglob

  REPLY=${1-}
  REPLY=${REPLY##[[:blank:]]##}
  REPLY=${REPLY%%[[:blank:]]##}
}

_spaceship_supabase_validate_ref() {
  emulate -L zsh
  setopt extendedglob
  local LC_ALL=C

  REPLY=''
  [[ ${#1} -eq 20 && $1 == [a-z]## ]] || return 1
  REPLY=$1
}

_spaceship_supabase_validate_local_db_branch() {
  emulate -L zsh
  setopt extendedglob
  local LC_ALL=C

  REPLY=''
  [[ ${#1} -ge 1 && ${#1} -le 128 ]] || return 1
  [[ $1 == [A-Za-z0-9][A-Za-z0-9._/-]# ]] || return 1
  REPLY=$1
}

_spaceship_supabase_validate_remote() {
  emulate -L zsh
  setopt extendedglob
  local LC_ALL=C

  REPLY=''
  [[ ${#1} -ge 1 && ${#1} -le 64 ]] || return 1
  [[ $1 == [A-Za-z0-9][A-Za-z0-9._-]# ]] || return 1
  REPLY=$1
}

_spaceship_supabase_validate_label() {
  emulate -L zsh
  setopt extendedglob
  local LC_ALL=C

  REPLY=''
  [[ ${#1} -ge 1 && ${#1} -le 64 ]] || return 1
  [[ $1 != *%* && $1 != *$'\n'* && $1 != *$'\r'* && $1 != *$'\t'* ]] || return 1
  [[ $1 == [[:print:]]## ]] || return 1
  REPLY=$1
}

_spaceship_supabase_validate_timestamp() {
  emulate -L zsh
  setopt extendedglob
  local LC_ALL=C

  REPLY=''
  [[ ${#1} -ge 1 && ${#1} -le 20 && $1 == [0-9]## ]] || return 1
  REPLY=$1
}

_spaceship_supabase_lstat_exists() {
  emulate -L zsh

  [[ $_SPACESHIP_SUPABASE_STAT_READY == true && -n ${1-} ]] || return 1
  local -a state
  zstat -L -A state +mode "$1" 2>/dev/null
}

_spaceship_supabase_safe_component() {
  emulate -L zsh

  # Arguments: selected root, path, directory|file, maximum file size.
  local root=${1-}
  local path=${2-}
  local expected=${3-}
  local limit=${4-0}
  local canonical
  local -a state
  local -i mode size

  REPLY=''
  [[ $_SPACESHIP_SUPABASE_STAT_READY == true && -n $root && -n $path ]] || return 1
  [[ $path == "$root" || $path == "$root"/* ]] || return 1

  # Root is canonical before this helper is called.  A differing canonical
  # target means that an expected component (or an ancestor below root) is a
  # symlink, so reject it rather than following it.
  canonical=${path:A}
  [[ $canonical == "$path" ]] || return 1

  zstat -L -A state +mode "$path" 2>/dev/null || return 1
  mode=${state[1]:-0}

  case $expected in
    directory)
      (( (mode & 8#170000) == 8#40000 )) || return 1
      [[ -r $path && -x $path ]] || return 1
      ;;
    file)
      (( (mode & 8#170000) == 8#100000 )) || return 1
      [[ -r $path ]] || return 1
      zstat -L -A state +size "$path" 2>/dev/null || return 1
      size=${state[1]:--1}
      (( size >= 0 && size <= limit )) || return 1
      ;;
    *)
      return 1
      ;;
  esac

  REPLY=$path
}

_spaceship_supabase_safe_private_directory() {
  emulate -L zsh

  local path=${1-}
  local -a state
  local -i mode owner

  REPLY=''
  [[ $_SPACESHIP_SUPABASE_STAT_READY == true && -n $path ]] || return 1
  zstat -L -A state +mode "$path" 2>/dev/null || return 1
  mode=${state[1]:-0}
  (( (mode & 8#170000) == 8#40000 && (mode & 8#77) == 0 )) || return 1
  zstat -L -A state +uid "$path" 2>/dev/null || return 1
  owner=${state[1]:--1}
  (( owner == EUID )) || return 1
  [[ -r $path && -x $path ]] || return 1
  REPLY=$path
}

_spaceship_supabase_safe_private_file() {
  emulate -L zsh

  local path=${1-}
  local -a state
  local -i mode owner size

  REPLY=''
  [[ $_SPACESHIP_SUPABASE_STAT_READY == true && -n $path ]] || return 1
  zstat -L -A state +mode "$path" 2>/dev/null || return 1
  mode=${state[1]:-0}
  (( (mode & 8#170000) == 8#100000 && (mode & 8#77) == 0 )) || return 1
  zstat -L -A state +uid "$path" 2>/dev/null || return 1
  owner=${state[1]:--1}
  (( owner == EUID )) || return 1
  zstat -L -A state +size "$path" 2>/dev/null || return 1
  size=${state[1]:--1}
  (( size >= 0 && size <= 131072 )) || return 1
  [[ -r $path ]] || return 1
  REPLY=$path
}

_spaceship_supabase_safe_project_root() {
  emulate -L zsh

  local root=${1-}

  REPLY=''
  [[ -n $root && $root == /* ]] || return 1
  root=${root:A}

  _spaceship_supabase_safe_component "$root" "$root" directory || return 1
  _spaceship_supabase_safe_component "$root" "$root/supabase" directory || return 1
  _spaceship_supabase_safe_component "$root" "$root/supabase/config.toml" file 262144 || return 1

  REPLY=$root
}

_spaceship_supabase_find_supabase_root() {
  emulate -L zsh

  local current parent marker supabase_dir
  local -i depth

  REPLY=''

  # A set override is strict.  It is never a hint that can fall back to PWD.
  if (( ${+SUPABASE_WORKDIR} )); then
    current=$SUPABASE_WORKDIR
    [[ -n $current ]] || {
      _spaceship_supabase_debug ROOT_INVALID
      return 1
    }
    [[ $current == /* ]] || current="$PWD/$current"
    current=${current:A}
    _spaceship_supabase_safe_project_root "$current" || {
      _spaceship_supabase_debug ROOT_INVALID
      return 1
    }
    REPLY=$current
    return 0
  fi

  current=${PWD:A}
  for (( depth = 0; depth <= 32; depth++ )); do
    marker="$current/supabase/config.toml"

    # Do not walk past an unsafe nearer boundary: it could otherwise cause a
    # parent project's identity to appear in a child project by mistake.
    if _spaceship_supabase_lstat_exists "$marker"; then
      _spaceship_supabase_safe_project_root "$current" || {
        _spaceship_supabase_debug ROOT_INVALID
        return 1
      }
      REPLY=$current
      return 0
    fi

    # A nearer `supabase` entry that cannot safely be traversed is an unsafe
    # boundary, not evidence that a parent project should be rendered. This
    # also covers a broken directory symlink whose `config.toml` cannot be
    # lstat'd at all.
    supabase_dir="$current/supabase"
    if _spaceship_supabase_lstat_exists "$supabase_dir"; then
      _spaceship_supabase_safe_component "$current" "$supabase_dir" directory || {
        _spaceship_supabase_debug ROOT_INVALID
        return 1
      }
    fi

    [[ $current == / ]] && break
    parent=${current:h}
    [[ $parent != "$current" ]] || break
    current=$parent
  done

  _spaceship_supabase_debug ROOT_NOT_FOUND
  return 1
}

_spaceship_supabase_read_one_line() {
  emulate -L zsh

  # Arguments: a previously-safe regular file and its maximum byte size.
  local path=${1-}
  local limit=${2-0}
  local line=''
  local -a state
  local -i mode size read_status count=0

  REPLY=''
  [[ $_SPACESHIP_SUPABASE_STAT_READY == true && -n $path ]] || return 1
  zstat -L -A state +mode "$path" 2>/dev/null || return 1
  mode=${state[1]:-0}
  (( (mode & 8#170000) == 8#100000 )) || return 1
  zstat -L -A state +size "$path" 2>/dev/null || return 1
  size=${state[1]:--1}
  (( size >= 0 && size <= limit )) || return 1
  [[ -r $path ]] || return 1

  while true; do
    line=''
    IFS= read -r line
    read_status=$?
    if (( read_status != 0 && ${#line} == 0 )); then
      break
    fi

    (( count++ ))
    (( count == 1 )) || return 1

    # A trailing CR is accepted only as the CR half of an actual CRLF line.
    if [[ $line == *$'\r' ]]; then
      (( read_status == 0 )) || return 1
      line=${line%$'\r'}
    fi
    REPLY=$line

    (( read_status == 0 )) || break
  done < "$path"

  (( count == 1 )) || return 1
}

_spaceship_supabase_parse_project_ref() {
  emulate -L zsh

  REPLY=''
  _spaceship_supabase_read_one_line "$1" 64 || return 1
  _spaceship_supabase_validate_ref "$REPLY"
}

_spaceship_supabase_parse_local_db_branch() {
  emulate -L zsh

  REPLY=''
  _spaceship_supabase_read_one_line "$1" 256 || return 1
  _spaceship_supabase_validate_local_db_branch "$REPLY"
}

_spaceship_supabase_read_live_ref() {
  emulate -L zsh

  local root=${1-}
  local ref_path

  REPLY=''
  _spaceship_supabase_safe_project_root "$root" || return 1
  root=$REPLY
  _spaceship_supabase_safe_component "$root" "$root/supabase/.temp" directory || return 1
  ref_path="$root/supabase/.temp/project-ref"
  _spaceship_supabase_safe_component "$root" "$ref_path" file 64 || return 1
  _spaceship_supabase_parse_project_ref "$ref_path"
}

_spaceship_supabase_read_local_db_branch() {
  emulate -L zsh

  local root=${1-}
  local branch_dir branch_path

  REPLY=''
  branch_dir="$root/supabase/.branches"
  _spaceship_supabase_lstat_exists "$branch_dir" || return 2
  _spaceship_supabase_safe_component "$root" "$branch_dir" directory || return 1
  branch_path="$branch_dir/_current_branch"
  _spaceship_supabase_lstat_exists "$branch_path" || return 2
  _spaceship_supabase_safe_component "$root" "$branch_path" file 256 || return 1
  _spaceship_supabase_parse_local_db_branch "$branch_path"
}

_spaceship_supabase_parse_config_remote() {
  emulate -L zsh

  local root=${1-}
  local remote=${2-}
  local config_path line trimmed key value candidate
  local -i read_status seen=0
  local active=false

  REPLY=''
  _spaceship_supabase_validate_remote "$remote" || return 1
  remote=$REPLY
  _spaceship_supabase_safe_project_root "$root" || return 1
  root=$REPLY
  config_path="$root/supabase/config.toml"

  while true; do
    line=''
    IFS= read -r line
    read_status=$?
    if (( read_status != 0 && ${#line} == 0 )); then
      break
    fi

    # TOML accepts CRLF.  A bare final CR is invalid input for this parser.
    if [[ $line == *$'\r' ]]; then
      (( read_status == 0 )) || return 1
      line=${line%$'\r'}
    fi
    _spaceship_supabase_trim_hspace "$line"
    trimmed=$REPLY

    # Any table-looking line ends the selected block unless it is exactly the
    # explicitly requested table.  We never infer or parse another remote.
    if [[ $trimmed == \[* ]]; then
      if [[ $trimmed == "[remotes.$remote]" ]]; then
        active=true
      else
        active=false
      fi
      (( read_status == 0 )) || break
      continue
    fi

    if [[ $active == true && $trimmed == *=* ]]; then
      key=${trimmed%%=*}
      value=${trimmed#*=}
      _spaceship_supabase_trim_hspace "$key"
      key=$REPLY
      [[ $key == project_id ]] || {
        (( read_status == 0 )) || break
        continue
      }
      (( seen == 0 )) || return 1
      seen=1

      # The resulting reference must be a fully quoted literal.  Stripping an
      # inline comment is safe because a valid reference cannot contain '#'.
      value=${value%%\#*}
      _spaceship_supabase_trim_hspace "$value"
      value=$REPLY
      [[ -n $value ]] || return 1
      case ${value[1]} in
        '"')
          [[ ${value[-1]} == '"' ]] || return 1
          candidate=${value#\"}
          candidate=${candidate%\"}
          ;;
        "'")
          [[ ${value[-1]} == "'" ]] || return 1
          candidate=${value#\'}
          candidate=${candidate%\'}
          ;;
        *)
          return 1
          ;;
      esac
      _spaceship_supabase_validate_ref "$candidate" || return 1
      REPLY=$candidate
    fi

    (( read_status == 0 )) || break
  done < "$config_path"

  (( seen == 1 )) && [[ -n $REPLY ]]
}

_spaceship_supabase_label_file_path() {
  emulate -L zsh

  local configured=${SPACESHIP_SUPABASE_LABEL_FILE-}
  local parent physical_parent name

  REPLY=''
  [[ -n $configured && $configured == /* ]] || return 1
  name=${configured:t}
  [[ -n $name && $name != . && $name != .. ]] || return 1
  parent=${configured:h}

  # Normalize lexical components without following links, then reject any
  # symlinked ancestor before an explicit helper can create a missing child
  # beneath it.  Looking only at an existing final parent would miss a path
  # such as `safe/link/missing/labels.tsv`: `${parent:A}` would otherwise
  # silently place state in `link`'s target. macOS exposes the system aliases
  # /var, /tmp, and /etc through /private; permit only that exact, fixed
  # prefix translation and reject every other canonicalization change.
  parent=${parent:a}
  physical_parent=${parent:A}
  if [[ $parent != "$physical_parent" ]]; then
    case $parent in
      /var|/var/*|/tmp|/tmp/*|/etc|/etc/*)
        [[ $physical_parent == "/private$parent" ]] || return 1
        ;;
      *)
        return 1
        ;;
    esac
  fi
  parent=$physical_parent

  # A missing parent is allowed here so the explicit set/clear helper can
  # create it with owner-only permissions; it is checked again after creation.
  if _spaceship_supabase_lstat_exists "$parent"; then
    _spaceship_supabase_safe_private_directory "$parent" || return 1
  fi
  [[ -n $parent && $parent == /* ]] || return 1
  REPLY="$parent/$name"
}

_spaceship_supabase_label_store_status() {
  emulate -L zsh

  local label_file parent

  REPLY='invalid'
  _spaceship_supabase_label_file_path || return 1
  label_file=$REPLY
  parent=${label_file:h}
  _spaceship_supabase_lstat_exists "$parent" || {
    REPLY='absent'
    return 2
  }
  _spaceship_supabase_safe_private_directory "$parent" || return 1
  _spaceship_supabase_lstat_exists "$label_file" || {
    REPLY='absent'
    return 2
  }
  _spaceship_supabase_safe_private_file "$label_file" || return 1
  REPLY='available'
}

_spaceship_supabase_doctor_label_store_state() {
  emulate -L zsh

  REPLY='disabled'
  [[ ${SPACESHIP_SUPABASE_USE_LABELS-} == true ]] || return 0
  _spaceship_supabase_label_store_status
  case $? in
    0) REPLY='available' ;;
    2) REPLY='absent' ;;
    *) REPLY='invalid' ;;
  esac
  return 0
}

_spaceship_supabase_parse_label_record() {
  emulate -L zsh

  local line=${1-}
  local tab=$'\t'
  local version ref label timestamp rest

  REPLY=''
  [[ $line == *"$tab"* ]] || return 1
  version=${line%%"${tab}"*}
  rest=${line#*"${tab}"}
  [[ $rest == *"$tab"* ]] || return 1
  ref=${rest%%"${tab}"*}
  rest=${rest#*"${tab}"}
  [[ $rest == *"$tab"* ]] || return 1
  label=${rest%%"${tab}"*}
  timestamp=${rest#*"${tab}"}
  [[ $timestamp != *"$tab"* ]] || return 1

  [[ $version == v1 ]] || return 1
  _spaceship_supabase_validate_ref "$ref" || return 1
  ref=$REPLY
  _spaceship_supabase_validate_label "$label" || return 1
  label=$REPLY
  _spaceship_supabase_validate_timestamp "$timestamp" || return 1
  timestamp=$REPLY
  REPLY="$ref$tab$label$tab$timestamp"
}

_spaceship_supabase_read_label() {
  emulate -L zsh

  local target_ref=${1-}
  local label_file line encoded record_ref record_label tab=$'\t'
  local -i read_status matches=0

  REPLY=''
  _spaceship_supabase_validate_ref "$target_ref" || return 1
  target_ref=$REPLY
  _spaceship_supabase_label_store_status || return 1
  [[ $REPLY == available ]] || return 1
  _spaceship_supabase_label_file_path || return 1
  label_file=$REPLY

  while true; do
    line=''
    IFS= read -r line
    read_status=$?
    if (( read_status != 0 && ${#line} == 0 )); then
      break
    fi

    _spaceship_supabase_parse_label_record "$line" || {
      (( read_status == 0 )) || break
      continue
    }
    encoded=$REPLY
    record_ref=${encoded%%"${tab}"*}
    encoded=${encoded#*"${tab}"}
    record_label=${encoded%%"${tab}"*}
    if [[ $record_ref == "$target_ref" ]]; then
      (( matches++ ))
      REPLY=$record_label
    fi

    (( read_status == 0 )) || break
  done < "$label_file"

  # A duplicate is ambiguous even when its text happens to be identical.
  (( matches == 1 )) || {
    REPLY=''
    return 1
  }
  _spaceship_supabase_validate_label "$REPLY"
}

_spaceship_supabase_resolve_live_context() {
  emulate -L zsh

  local root ref

  _SPACESHIP_SUPABASE_CONTEXT=()
  _spaceship_supabase_find_supabase_root || return 1
  root=$REPLY
  _spaceship_supabase_read_live_ref "$root" || {
    _spaceship_supabase_debug STATE_INVALID
    return 1
  }
  ref=$REPLY

  _SPACESHIP_SUPABASE_CONTEXT[root]=$root
  _SPACESHIP_SUPABASE_CONTEXT[ref]=$ref
  _SPACESHIP_SUPABASE_CONTEXT[source]=live
}

_spaceship_supabase_resolve_context() {
  emulate -L zsh

  local root ref remote branch branch_status

  _SPACESHIP_SUPABASE_CONTEXT=()
  _spaceship_supabase_find_supabase_root || return 1
  root=$REPLY

  if _spaceship_supabase_read_live_ref "$root"; then
    ref=$REPLY
    _SPACESHIP_SUPABASE_CONTEXT[source]=live
  else
    remote=${SPACESHIP_SUPABASE_CONFIG_REMOTE-}
    [[ -n $remote ]] || {
      _spaceship_supabase_debug STATE_INVALID
      return 1
    }
    _spaceship_supabase_parse_config_remote "$root" "$remote" || {
      _spaceship_supabase_debug CONFIG_INVALID
      return 1
    }
    ref=$REPLY
    _spaceship_supabase_validate_remote "$remote" || return 1
    remote=$REPLY
    _SPACESHIP_SUPABASE_CONTEXT[source]=configured
    _SPACESHIP_SUPABASE_CONTEXT[remote]=$remote
  fi

  _SPACESHIP_SUPABASE_CONTEXT[root]=$root
  _SPACESHIP_SUPABASE_CONTEXT[ref]=$ref

  # A local database branch is relevant only to a verified live link.  Its
  # absence is normal.  An unsafe optional branch layout is fail-closed for
  # that decoration only: the independently validated live project ref stays
  # visible, but no branch bytes reach the renderer.
  if [[ ${_SPACESHIP_SUPABASE_CONTEXT[source]} == live && ${SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH-} == true ]]; then
    _spaceship_supabase_read_local_db_branch "$root"
    branch_status=$?
    case $branch_status in
      0) _SPACESHIP_SUPABASE_CONTEXT[branch]=$REPLY ;;
      2) ;;
      *)
        _spaceship_supabase_debug LOCAL_DB_BRANCH_INVALID
        ;;
    esac
  fi

  # Labels are optional decoration.  A malformed, absent, or duplicate record
  # cannot prevent a trusted ref from rendering and cannot create one.
  if [[ ${SPACESHIP_SUPABASE_USE_LABELS-} == true && ${SPACESHIP_SUPABASE_FORMAT-} == label+ref ]]; then
    if _spaceship_supabase_read_label "$ref"; then
      _SPACESHIP_SUPABASE_CONTEXT[label]=$REPLY
    fi
  fi
}

_spaceship_supabase_render() {
  emulate -L zsh

  local ref=${1-}
  local source=${2-}
  local remote=${3-}
  local branch=${4-}
  local label=${5-}
  local display

  _spaceship_supabase_validate_ref "$ref" || return 0
  ref=$REPLY
  case ${SPACESHIP_SUPABASE_FORMAT-} in
    ref)
      display=$ref
      ;;
    label+ref)
      if _spaceship_supabase_validate_label "$label"; then
        label=$REPLY
        display="$label ($ref)"
      else
        display=$ref
      fi
      ;;
    *)
      _spaceship_supabase_debug UNSUPPORTED_FORMAT
      return 0
      ;;
  esac

  if [[ $source == configured ]]; then
    _spaceship_supabase_validate_remote "$remote" || return 0
    display+=" · configured:$REPLY"
  elif [[ $source != live ]]; then
    return 0
  fi

  if [[ -n $branch ]]; then
    _spaceship_supabase_validate_local_db_branch "$branch" || return 0
    display+=" (local-db:$REPLY)"
  fi

  if ! (( ${+functions[spaceship::section::v4]} )); then
    _spaceship_supabase_debug RENDERER_UNAVAILABLE
    return 0
  fi

  spaceship::section::v4 \
    --color "$SPACESHIP_SUPABASE_COLOR" \
    --prefix "$SPACESHIP_SUPABASE_PREFIX" \
    --suffix "$SPACESHIP_SUPABASE_SUFFIX" \
    --symbol "$SPACESHIP_SUPABASE_SYMBOL" \
    "$display"
}

# Spaceship section entrypoint.  It reads local state afresh on every call.
spaceship_supabase() {
  emulate -L zsh

  [[ ${SPACESHIP_SUPABASE_SHOW-} == true ]] || return 0
  _spaceship_supabase_resolve_context || return 0
  _spaceship_supabase_render \
    "${_SPACESHIP_SUPABASE_CONTEXT[ref]-}" \
    "${_SPACESHIP_SUPABASE_CONTEXT[source]-}" \
    "${_SPACESHIP_SUPABASE_CONTEXT[remote]-}" \
    "${_SPACESHIP_SUPABASE_CONTEXT[branch]-}" \
    "${_SPACESHIP_SUPABASE_CONTEXT[label]-}"
}

_spaceship_supabase_collect_label_records() {
  emulate -L zsh

  local label_file=${1-}
  local line encoded tab=$'\t'
  local -i read_status

  reply=()
  [[ -n $label_file ]] || return 1
  _spaceship_supabase_lstat_exists "$label_file" || return 0
  _spaceship_supabase_safe_private_file "$label_file" || return 1

  while true; do
    line=''
    IFS= read -r line
    read_status=$?
    if (( read_status != 0 && ${#line} == 0 )); then
      break
    fi
    if _spaceship_supabase_parse_label_record "$line"; then
      encoded=$REPLY
      # Reconstruct a canonical v1 record.  Invalid records are intentionally
      # not carried forward into an explicit user-owned state update.
      reply+=("v1$tab$encoded")
    fi
    (( read_status == 0 )) || break
  done < "$label_file"
}

_spaceship_supabase_write_label_records() (
  emulate -L zsh

  local label_file=${1-}
  local parent temp fd record
  local -i attempt=0 write_failed=0
  shift || return 1

  # The subshell keeps this explicit state-management hardening from changing
  # the caller's umask.  Prompt rendering never enters this helper.
  umask 077

  [[ $_SPACESHIP_SUPABASE_FILES_READY == true && $_SPACESHIP_SUPABASE_SYSTEM_READY == true ]] || return 1
  [[ -n $label_file ]] || return 1
  parent=${label_file:h}

  if ! _spaceship_supabase_lstat_exists "$parent"; then
    # zsh/files builtins in Zsh 5.2 do not implement a `--` end-of-options
    # marker. Every state path is validated as absolute above, so it cannot be
    # mistaken for an option.
    zf_mkdir -p -m 700 "$parent" 2>/dev/null || return 1
  fi
  _spaceship_supabase_safe_private_directory "$parent" || return 1

  # Existing state must already be safe.  We do not overwrite a symlink,
  # group-readable file, or someone else's state file.
  if _spaceship_supabase_lstat_exists "$label_file"; then
    _spaceship_supabase_safe_private_file "$label_file" || return 1
  fi

  while (( attempt < 16 )); do
    (( attempt++ ))
    temp="${label_file}.tmp.${$}.${RANDOM}"
    if sysopen -u fd -w -m 600 -o creat,excl,nofollow,cloexec "$temp" 2>/dev/null; then
      break
    fi
    temp=''
  done
  [[ -n $temp ]] || return 1

  for record in "$@"; do
    print -ru "$fd" -- "$record" || {
      write_failed=1
      break
    }
  done
  exec {fd}>&-

  if (( write_failed )); then
    zf_rm -f "$temp" 2>/dev/null
    return 1
  fi

  zf_mv "$temp" "$label_file" 2>/dev/null || {
    zf_rm -f "$temp" 2>/dev/null
    return 1
  }
)

_spaceship_supabase_label_error() {
  emulate -L zsh
  case ${1-} in
    NO_LIVE_REF|LABEL_INVALID|LABEL_STORE_INVALID|LABEL_WRITE_FAILED|HELPER_USAGE)
      print -ru2 -- "spaceship-supabase: ${1}"
      ;;
  esac
}

# Manual, user-owned label management.  These helpers are the only code path
# that creates or modifies the label file; prompt rendering is read-only.
spaceship_supabase_label() {
  emulate -L zsh

  local action=${1-}
  local label_file ref label timestamp tab=$'\t'
  local encoded record_ref
  local -a records filtered

  case $action in
    set)
      [[ $# -eq 2 ]] || {
        _spaceship_supabase_label_error HELPER_USAGE
        return 1
      }
      _spaceship_supabase_validate_label "$2" || {
        _spaceship_supabase_label_error LABEL_INVALID
        return 1
      }
      label=$REPLY
      _spaceship_supabase_resolve_live_context || {
        _spaceship_supabase_label_error NO_LIVE_REF
        return 1
      }
      ref=${_SPACESHIP_SUPABASE_CONTEXT[ref]}
      ;;
    clear)
      [[ $# -eq 1 ]] || {
        _spaceship_supabase_label_error HELPER_USAGE
        return 1
      }
      _spaceship_supabase_resolve_live_context || {
        _spaceship_supabase_label_error NO_LIVE_REF
        return 1
      }
      ref=${_SPACESHIP_SUPABASE_CONTEXT[ref]}
      ;;
    list)
      [[ $# -eq 1 ]] || {
        _spaceship_supabase_label_error HELPER_USAGE
        return 1
      }
      _spaceship_supabase_label_store_status
      case $? in
        0) ;;
        2) return 0 ;;
        *)
          _spaceship_supabase_label_error LABEL_STORE_INVALID
          return 1
          ;;
      esac
      _spaceship_supabase_label_file_path || return 1
      label_file=$REPLY
      _spaceship_supabase_collect_label_records "$label_file" || {
        _spaceship_supabase_label_error LABEL_STORE_INVALID
        return 1
      }
      records=("${reply[@]}")
      # Print only a ref once.  A duplicate ref is ambiguous and is omitted.
      local -a seen_refs ambiguous_refs remaining_refs
      local seen_ref
      for encoded in "${records[@]}"; do
        encoded=${encoded#v1"${tab}"}
        record_ref=${encoded%%"${tab}"*}
        if (( ${seen_refs[(Ie)$record_ref]} )); then
          ambiguous_refs+=("$record_ref")
        else
          seen_refs+=("$record_ref")
        fi
      done
      for encoded in "${records[@]}"; do
        encoded=${encoded#v1"${tab}"}
        record_ref=${encoded%%"${tab}"*}
        (( ${ambiguous_refs[(Ie)$record_ref]} )) && continue
        # Print the first (and only) safe record for the ref.
        (( ${seen_refs[(Ie)$record_ref]} )) || continue
        remaining_refs=()
        for seen_ref in "${seen_refs[@]}"; do
          [[ $seen_ref == "$record_ref" ]] || remaining_refs+=("$seen_ref")
        done
        seen_refs=("${remaining_refs[@]}")
        print -r -- "$record_ref$tab${encoded#*"${tab}"}"
      done
      return 0
      ;;
    *)
      _spaceship_supabase_label_error HELPER_USAGE
      return 1
      ;;
  esac

  _spaceship_supabase_label_file_path || {
    _spaceship_supabase_label_error LABEL_STORE_INVALID
    return 1
  }
  label_file=$REPLY

  # An absent store is a valid empty store.  An existing unsafe store is not.
  _spaceship_supabase_label_store_status
  case $? in
    0)
      _spaceship_supabase_collect_label_records "$label_file" || {
        _spaceship_supabase_label_error LABEL_STORE_INVALID
        return 1
      }
      records=("${reply[@]}")
      ;;
    2)
      records=()
      ;;
    *)
      _spaceship_supabase_label_error LABEL_STORE_INVALID
      return 1
      ;;
  esac

  filtered=()
  for encoded in "${records[@]}"; do
    encoded=${encoded#v1"${tab}"}
    record_ref=${encoded%%"${tab}"*}
    [[ $record_ref == "$ref" ]] && continue
    filtered+=("v1$tab$encoded")
  done

  if [[ $action == set ]]; then
    timestamp=${EPOCHSECONDS:-0}
    _spaceship_supabase_validate_timestamp "$timestamp" || timestamp=0
    filtered+=("v1$tab$ref$tab$label$tab$timestamp")
  fi

  _spaceship_supabase_write_label_records "$label_file" "${filtered[@]}" || {
    _spaceship_supabase_label_error LABEL_WRITE_FAILED
    return 1
  }
}

# Read-only local diagnostics.  Default output intentionally omits filesystem
# paths, project IDs, labels, and raw config input.  --verbose shows only
# already allowlisted values.
spaceship_supabase_doctor() {
  emulate -L zsh

  local verbose=false root ref remote configured_ref live_state config_state store_state
  local branch label

  case $# in
    0) ;;
    1)
      [[ $1 == --verbose ]] || {
        _spaceship_supabase_label_error HELPER_USAGE
        return 1
      }
      verbose=true
      ;;
    *)
      _spaceship_supabase_label_error HELPER_USAGE
      return 1
      ;;
  esac

  print -r -- 'spaceship-supabase doctor'
  if ! _spaceship_supabase_find_supabase_root; then
    print -r -- 'root: not-detected'
    print -r -- 'source: none'
    print -r -- 'live-link: missing-or-invalid'
    print -r -- 'configured-map: not-requested'
    _spaceship_supabase_doctor_label_store_state
    print -r -- "label-store: $REPLY"
    print -r -- 'remediation: run supabase link in the intended project, then retry.'
    return 0
  fi
  root=$REPLY
  print -r -- 'root: detected'

  if _spaceship_supabase_read_live_ref "$root"; then
    ref=$REPLY
    live_state=valid
  else
    live_state=missing-or-invalid
  fi
  print -r -- "live-link: $live_state"

  remote=${SPACESHIP_SUPABASE_CONFIG_REMOTE-}
  if [[ -z $remote ]]; then
    config_state=not-requested
  elif _spaceship_supabase_parse_config_remote "$root" "$remote"; then
    configured_ref=$REPLY
    config_state=valid
  else
    config_state=missing-or-invalid
  fi
  print -r -- "configured-map: $config_state"

  if [[ $live_state == valid ]]; then
    print -r -- 'source: live'
  elif [[ $config_state == valid ]]; then
    ref=$configured_ref
    print -r -- 'source: configured'
  else
    print -r -- 'source: none'
  fi

  _spaceship_supabase_doctor_label_store_state
  store_state=$REPLY
  print -r -- "label-store: $store_state"

  if [[ $verbose == true ]]; then
    if _spaceship_supabase_validate_ref "$ref"; then
      print -r -- "ref: $REPLY"
      if [[ $live_state == valid && ${SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH-} == true ]]; then
        if _spaceship_supabase_read_local_db_branch "$root"; then
          branch=$REPLY
          print -r -- "local-db: $branch"
        fi
      fi
      if [[ $config_state == valid ]] && _spaceship_supabase_validate_remote "$remote"; then
        print -r -- "remote: $REPLY"
      fi
      if [[ $store_state == available ]] && _spaceship_supabase_read_label "$ref"; then
        label=$REPLY
        print -r -- "label: $label"
      fi
    fi
  fi

  print -r -- 'remediation: run supabase link in the intended project, then retry.'
}
