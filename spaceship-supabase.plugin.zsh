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
# explicit helpers, never while rendering a prompt.
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
SPACESHIP_SUPABASE_USE_SYNCED_DECORATIONS="${SPACESHIP_SUPABASE_USE_SYNCED_DECORATIONS-false}"
SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE="${SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE-${XDG_STATE_HOME:-$HOME/.local/state}/spaceship-supabase/decorations.tsv}"
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
    SYNCED_DECORATION_STORE_INVALID|\
    LOCAL_DB_BRANCH_INVALID|\
    UNSUPPORTED_FORMAT|RENDERER_UNAVAILABLE|NO_LIVE_REF|LABEL_INVALID|\
    LABEL_WRITE_FAILED|SYNC_USAGE|SYNC_NO_LIVE_REF|SYNC_CLI_NOT_FOUND|\
    SYNC_CLI_VERSION_UNSUPPORTED|SYNC_CLI_FAILED|SYNC_OUTPUT_INVALID|\
    SYNC_NO_MATCH|SYNC_AMBIGUOUS_MATCH|SYNC_NAME_INVALID|SYNC_CANCELLED|\
    SYNC_DECORATION_STORE_INVALID|SYNC_WRITE_FAILED|SYNC_REF_CHANGED|\
    SYNC_TIME_UNAVAILABLE|HELPER_USAGE)
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

_spaceship_supabase_private_state_file_path() {
  emulate -L zsh

  local configured=${1-}
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

_spaceship_supabase_label_file_path() {
  emulate -L zsh

  _spaceship_supabase_private_state_file_path "${SPACESHIP_SUPABASE_LABEL_FILE-}"
}

_spaceship_supabase_synced_decoration_file_path() {
  emulate -L zsh

  _spaceship_supabase_private_state_file_path "${SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE-}"
}

_spaceship_supabase_private_store_status() {
  emulate -L zsh

  local state_file=${1-}
  local parent

  REPLY='invalid'
  [[ -n $state_file && $state_file == /* ]] || return 1
  parent=${state_file:h}
  _spaceship_supabase_lstat_exists "$parent" || {
    REPLY='absent'
    return 2
  }
  _spaceship_supabase_safe_private_directory "$parent" || return 1
  _spaceship_supabase_lstat_exists "$state_file" || {
    REPLY='absent'
    return 2
  }
  _spaceship_supabase_safe_private_file "$state_file" || return 1
  REPLY='available'
}

_spaceship_supabase_label_store_status() {
  emulate -L zsh

  local label_file

  REPLY='invalid'
  _spaceship_supabase_label_file_path || return 1
  label_file=$REPLY
  _spaceship_supabase_private_store_status "$label_file"
}

_spaceship_supabase_synced_decoration_store_status() {
  emulate -L zsh

  local decoration_file

  REPLY='invalid'
  _spaceship_supabase_synced_decoration_file_path || return 1
  decoration_file=$REPLY
  _spaceship_supabase_private_store_status "$decoration_file"
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

_spaceship_supabase_doctor_synced_decoration_store_state() {
  emulate -L zsh

  # Doctor is an explicit local diagnostic, not prompt rendering. It may report
  # redacted state health even when the separate prompt-display opt-in is off.
  REPLY='invalid'
  _spaceship_supabase_synced_decoration_store_status
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

_spaceship_supabase_validate_synced_decoration_kind() {
  emulate -L zsh

  REPLY=''
  [[ ${1-} == project ]] || return 1
  REPLY=project
}

_spaceship_supabase_validate_synced_decoration_source() {
  emulate -L zsh

  REPLY=''
  [[ ${1-} == 'supabase-cli:projects-list' ]] || return 1
  REPLY='supabase-cli:projects-list'
}

_spaceship_supabase_parse_synced_decoration_record() {
  emulate -L zsh

  local line=${1-}
  local tab=$'\t'
  local version ref kind project_name source timestamp rest

  REPLY=''
  [[ $line == *"$tab"* ]] || return 1
  version=${line%%"${tab}"*}
  rest=${line#*"${tab}"}
  [[ $rest == *"$tab"* ]] || return 1
  ref=${rest%%"${tab}"*}
  rest=${rest#*"${tab}"}
  [[ $rest == *"$tab"* ]] || return 1
  kind=${rest%%"${tab}"*}
  rest=${rest#*"${tab}"}
  [[ $rest == *"$tab"* ]] || return 1
  project_name=${rest%%"${tab}"*}
  rest=${rest#*"${tab}"}
  [[ $rest == *"$tab"* ]] || return 1
  source=${rest%%"${tab}"*}
  timestamp=${rest#*"${tab}"}
  [[ $timestamp != *"$tab"* ]] || return 1

  [[ $version == v1 ]] || return 1
  _spaceship_supabase_validate_ref "$ref" || return 1
  ref=$REPLY
  _spaceship_supabase_validate_synced_decoration_kind "$kind" || return 1
  kind=$REPLY
  _spaceship_supabase_validate_label "$project_name" || return 1
  project_name=$REPLY
  _spaceship_supabase_validate_synced_decoration_source "$source" || return 1
  source=$REPLY
  _spaceship_supabase_validate_timestamp "$timestamp" || return 1
  timestamp=$REPLY
  REPLY="$ref$tab$kind$tab$project_name$tab$source$tab$timestamp"
}

_spaceship_supabase_read_synced_decoration() {
  emulate -L zsh

  local target_ref=${1-}
  local decoration_file line encoded record_ref tab=$'\t'
  local -i read_status matches=0

  REPLY=''
  _spaceship_supabase_validate_ref "$target_ref" || return 1
  target_ref=$REPLY
  _spaceship_supabase_synced_decoration_store_status || return 1
  [[ $REPLY == available ]] || return 1
  _spaceship_supabase_synced_decoration_file_path || return 1
  decoration_file=$REPLY

  while true; do
    line=''
    IFS= read -r line
    read_status=$?
    if (( read_status != 0 && ${#line} == 0 )); then
      break
    fi

    _spaceship_supabase_parse_synced_decoration_record "$line" || {
      (( read_status == 0 )) || break
      continue
    }
    encoded=$REPLY
    record_ref=${encoded%%"${tab}"*}
    if [[ $record_ref == "$target_ref" ]]; then
      (( matches++ ))
      REPLY=$encoded
    fi

    (( read_status == 0 )) || break
  done < "$decoration_file"

  # A duplicate record is ambiguous even when every visible field agrees.
  (( matches == 1 )) || {
    REPLY=''
    return 1
  }
}

_spaceship_supabase_collect_synced_decoration_records() {
  emulate -L zsh

  local decoration_file=${1-}
  local line encoded record_ref tab=$'\t'
  local -a seen_refs
  local -i read_status

  reply=()
  [[ -n $decoration_file ]] || return 1
  _spaceship_supabase_lstat_exists "$decoration_file" || return 0
  _spaceship_supabase_safe_private_file "$decoration_file" || return 1

  while true; do
    line=''
    IFS= read -r line
    read_status=$?
    if (( read_status != 0 && ${#line} == 0 )); then
      break
    fi
    _spaceship_supabase_parse_synced_decoration_record "$line" || return 1
    encoded=$REPLY
    record_ref=${encoded%%"${tab}"*}
    (( ${seen_refs[(Ie)$record_ref]} )) && return 1
    seen_refs+=("$record_ref")
    reply+=("v1$tab$encoded")
    (( read_status == 0 )) || break
  done < "$decoration_file"
}

# This is not a general JSON API.  It is a bounded native walker for exactly
# the two `supabase projects list` forms we support.  It structurally skips
# surplus CLI fields so that `ref` and `name` are read only at a top-level
# project record. Escaped field values are never decoded or accepted as names.
_spaceship_supabase_projects_json_ws() {
  emulate -L zsh
  while (( json_index <= json_length )) && [[ ${json_text[$json_index]} == [$' '$'\t'$'\r'$'\n'] ]]; do
    (( json_index++ ))
  done
}

_spaceship_supabase_projects_json_string() {
  emulate -L zsh
  local LC_ALL=C
  local char escaped value=''
  local -i index

  REPLY=''
  json_escaped=0
  [[ ${json_text[$json_index]} == '"' ]] || return 1
  (( json_index++ ))
  while (( json_index <= json_length )); do
    char=${json_text[$json_index]}
    case $char in
      '"') (( json_index++ )); REPLY=$value; return 0 ;;
      \\)
        json_escaped=1
        (( json_index++ )); (( json_index <= json_length )) || return 1
        escaped=${json_text[$json_index]}
        case $escaped in
          '"'|\\|/|b|f|n|r|t) (( json_index++ )) ;;
          u)
            (( json_index++ ))
            for (( index = 0; index < 4; index++ )); do
              (( json_index <= json_length )) && [[ ${json_text[$json_index]} == [0-9A-Fa-f] ]] || return 1
              (( json_index++ ))
            done
            ;;
          *) return 1 ;;
        esac
        ;;
      *) [[ $char != [[:cntrl:]] ]] || return 1; value+=$char; (( json_index++ )) ;;
    esac
  done
  return 1
}

_spaceship_supabase_projects_json_scalar() {
  emulate -L zsh
  local token='' char number='^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$'

  while (( json_index <= json_length )); do
    char=${json_text[$json_index]}
    [[ $char == [A-Za-z0-9+.-] ]] || break
    token+=$char
    (( json_index++ ))
  done
  [[ $token == true || $token == false || $token == null || $token =~ $number ]]
}

_spaceship_supabase_projects_json_skip_value() {
  emulate -L zsh
  local -i depth=${1-0}

  (( depth <= 16 )) || return 1
  _spaceship_supabase_projects_json_ws
  case ${json_text[$json_index]} in
    '{') _spaceship_supabase_projects_json_skip_object "$depth" ;;
    '[') _spaceship_supabase_projects_json_skip_array "$depth" ;;
    '"') _spaceship_supabase_projects_json_string ;;
    *) _spaceship_supabase_projects_json_scalar ;;
  esac
}

_spaceship_supabase_projects_json_skip_array() {
  emulate -L zsh
  local -i depth=${1-0}

  [[ ${json_text[$json_index]} == '[' ]] || return 1
  (( json_index++ )); _spaceship_supabase_projects_json_ws
  [[ ${json_text[$json_index]} == ']' ]] && { (( json_index++ )); return 0; }
  while true; do
    _spaceship_supabase_projects_json_skip_value "$(( depth + 1 ))" || return 1
    _spaceship_supabase_projects_json_ws
    case ${json_text[$json_index]} in
      ',') (( json_index++ )); _spaceship_supabase_projects_json_ws ;;
      ']') (( json_index++ )); return 0 ;;
      *) return 1 ;;
    esac
  done
}

_spaceship_supabase_projects_json_skip_object() {
  emulate -L zsh
  local -i depth=${1-0}

  [[ ${json_text[$json_index]} == '{' ]] || return 1
  (( json_index++ )); _spaceship_supabase_projects_json_ws
  [[ ${json_text[$json_index]} == '}' ]] && { (( json_index++ )); return 0; }
  while true; do
    _spaceship_supabase_projects_json_string || return 1
    _spaceship_supabase_projects_json_ws
    [[ ${json_text[$json_index]} == ':' ]] || return 1
    (( json_index++ ))
    _spaceship_supabase_projects_json_skip_value "$(( depth + 1 ))" || return 1
    _spaceship_supabase_projects_json_ws
    case ${json_text[$json_index]} in
      ',') (( json_index++ )); _spaceship_supabase_projects_json_ws ;;
      '}') (( json_index++ )); return 0 ;;
      *) return 1 ;;
    esac
  done
}

_spaceship_supabase_projects_json_read_record() {
  emulate -L zsh
  local key value='' key_escaped value_escaped read_status
  local ref='' name='' ref_seen=false name_seen=false target_invalid=false

  json_record_match=0
  json_record_name=''
  [[ ${json_text[$json_index]} == '{' ]] || return 1
  (( json_index++ )); _spaceship_supabase_projects_json_ws
  [[ ${json_text[$json_index]} == '}' ]] && { (( json_index++ )); return 0; }
  while true; do
    _spaceship_supabase_projects_json_string
    read_status=$?
    (( read_status == 0 )) || return 1
    key=$REPLY
    key_escaped=$json_escaped
    _spaceship_supabase_projects_json_ws
    [[ ${json_text[$json_index]} == ':' ]] || return 1
    (( json_index++ )); _spaceship_supabase_projects_json_ws
    if [[ $key_escaped == 0 && ( $key == ref || $key == name ) ]]; then
      value=''; value_escaped=1
      if [[ ${json_text[$json_index]} == '"' ]]; then
        _spaceship_supabase_projects_json_string
        read_status=$?
        (( read_status == 0 )) || return 1
        value=$REPLY
        value_escaped=$json_escaped
      else
        _spaceship_supabase_projects_json_skip_value 1 || return 1
      fi
      case $key in
        ref)
          [[ $ref_seen == false ]] || target_invalid=true
          ref_seen=true
          [[ $value_escaped == 0 ]] && ref=$value || ref=''
          ;;
        name)
          [[ $name_seen == false ]] || target_invalid=true
          name_seen=true
          [[ $value_escaped == 0 ]] && name=$value || name=''
          ;;
      esac
    else
      _spaceship_supabase_projects_json_skip_value 1 || return 1
    fi
    _spaceship_supabase_projects_json_ws
    case ${json_text[$json_index]} in
      ',') (( json_index++ )); _spaceship_supabase_projects_json_ws ;;
      '}') (( json_index++ )); break ;;
      *) return 1 ;;
    esac
  done

  _spaceship_supabase_validate_ref "$ref" || return 0
  [[ $ref == "$json_target_ref" ]] || return 0
  _spaceship_supabase_validate_label "$name" || target_invalid=true
  [[ $target_invalid == false ]] || return 2
  json_record_name=$REPLY
  json_record_match=1
}

_spaceship_supabase_projects_json_read_array() {
  emulate -L zsh
  local matched_name=''
  local -i matches=0 record_status

  REPLY=''
  [[ ${json_text[$json_index]} == '[' ]] || return 4
  (( json_index++ )); _spaceship_supabase_projects_json_ws
  [[ ${json_text[$json_index]} == ']' ]] && { (( json_index++ )); return 2; }
  while true; do
    _spaceship_supabase_projects_json_read_record
    record_status=$?
    case $record_status in
      0) (( json_record_match )) && { (( matches++ )); matched_name=$json_record_name; } ;;
      2) return 4 ;;
      *) return 4 ;;
    esac
    _spaceship_supabase_projects_json_ws
    case ${json_text[$json_index]} in
      ',') (( json_index++ )); _spaceship_supabase_projects_json_ws ;;
      ']') (( json_index++ )); break ;;
      *) return 4 ;;
    esac
  done
  case $matches in
    0) return 2 ;;
    1) REPLY=$matched_name; return 0 ;;
    *) return 3 ;;
  esac
}

_spaceship_supabase_projects_json_read_envelope() {
  emulate -L zsh
  local key key_escaped result_status=4 matched_name='' read_status

  [[ ${json_text[$json_index]} == '{' ]] || return 4
  (( json_index++ )); _spaceship_supabase_projects_json_ws
  _spaceship_supabase_projects_json_string
  read_status=$?
  (( read_status == 0 )) || return 4
  key=$REPLY; key_escaped=$json_escaped
  [[ $key_escaped == 0 && $key == projects ]] || return 4
  _spaceship_supabase_projects_json_ws
  [[ ${json_text[$json_index]} == ':' ]] || return 4
  (( json_index++ )); _spaceship_supabase_projects_json_ws
  _spaceship_supabase_projects_json_read_array
  result_status=$?; matched_name=$REPLY
  _spaceship_supabase_projects_json_ws
  [[ ${json_text[$json_index]} == '}' ]] || return 4
  (( json_index++ ))
  REPLY=$matched_name
  return "$result_status"
}

_spaceship_supabase_find_project_name_in_json() {
  emulate -L zsh
  local LC_ALL=C
  local json_text=${1-} json_target_ref=${2-} matched_name=''
  local -i json_index=1 json_length=${#json_text} json_escaped=0
  local -i json_record_match=0 result_status=4
  local json_record_name=''

  REPLY=''
  (( json_length >= 2 && json_length <= 131072 )) || return 4
  _spaceship_supabase_validate_ref "$json_target_ref" || return 4
  json_target_ref=$REPLY
  _spaceship_supabase_projects_json_ws
  case ${json_text[$json_index]} in
    '[') _spaceship_supabase_projects_json_read_array ;;
    '{') _spaceship_supabase_projects_json_read_envelope ;;
    *) return 4 ;;
  esac
  result_status=$?; matched_name=$REPLY
  _spaceship_supabase_projects_json_ws
  (( json_index > json_length )) || return 4
  REPLY=$matched_name
  return "$result_status"
}

_spaceship_supabase_capture_cli_output() {
  emulate -L zsh
  setopt extendedglob localtraps
  local LC_ALL=C

  local root=${1-}
  local limit=${2-0}
  # This is an internal-only timeout argument. Production callers below pass
  # the fixed 15-second budget; focused tests may exercise a shorter budget
  # without exposing a user configuration switch.
  local timeout_seconds=${3-0}
  local cli_path='' chunk='' child_pid='' temp='' fd=''
  local -i attempt=0 bytes=0 child_status=0 cleanup_status=1 poll_status=0
  local -i file_size=-1 interrupted=0 read_status=0
  # Keep a fixed cap independent of the parser's smaller per-command limit.
  # `ulimit -f` measures 512-byte blocks, so this is exactly 1 MiB.
  local -i capture_file_blocks=2048 capture_poll_centiseconds=10
  local -i capture_kill_grace_centiseconds=10
  # A function-local SECONDS timer cannot be inherited from or changed by the
  # caller. It is the direct-child watchdog's fixed wall-clock budget.
  local -i SECONDS=0
  shift 3 || return 1

  REPLY=''
  _spaceship_supabase_safe_project_root "$root" || return 4
  root=$REPLY
  REPLY=''
  [[ $limit == [0-9]## ]] && (( limit >= 1 && limit <= 131072 )) || return 4
  [[ $timeout_seconds == [0-9]## ]] && (( timeout_seconds >= 1 && timeout_seconds <= 15 )) || return 4
  # This explicit helper needs zsh/files for secure cleanup and zsh/system for
  # descriptor-only I/O. Load zsh/zselect here, not during normal plugin setup:
  # its bounded direct-child poller is never part of prompt rendering.
  [[ $_SPACESHIP_SUPABASE_FILES_READY == true && $_SPACESHIP_SUPABASE_SYSTEM_READY == true ]] || return 1
  builtin zmodload zsh/zselect 2>/dev/null || return 1
  cli_path=${commands[supabase]-}
  [[ -n $cli_path && -x $cli_path ]] || return 2

  # Zsh 5.2 inserts a relay process for `coproc { ... }`. An unbounded CLI can
  # fill that relay's pipe before the reader observes its output limit, so this
  # helper captures a direct child through a private descriptor instead. The
  # direct child's fixed resource cap bounds its output file independently of
  # the parser's 64-byte or 128-KiB accepted-output limit.
  #
  # Numeric signal names are accepted by Zsh 5.2. `localtraps` restores the
  # caller's handlers, while the body observes the fixed signal status and
  # reaches the cleanup block below.
  builtin trap 'interrupted=129' 1
  builtin trap 'interrupted=130' 2
  builtin trap 'interrupted=143' 15

  # `/tmp` is the fixed OS temporary directory rather than an environment
  # supplied path. O_EXCL and O_NOFOLLOW make each retry an owner-only
  # regular file. It is immediately unlinked while its descriptor remains
  # open; all later I/O uses that descriptor, never a shell redirection or
  # filesystem path. From here on, every exit passes through the cleanup below
  # while the local child PID and descriptor are still available.
  while (( attempt < 16 )); do
    (( attempt++ ))
    temp="/tmp/spaceship-supabase-cli.${EUID}.${$}.${RANDOM}"
    if builtin sysopen -u fd -r -w -m 600 -o creat,excl,nofollow "$temp" 2>/dev/null; then
      if [[ -z $fd ]] || ! builtin zf_rm -f "$temp" 2>/dev/null; then
        cleanup_status=1
      else
        temp=''
        if (( interrupted != 0 )); then
          cleanup_status=$interrupted
        else
          cleanup_status=-1
        fi
      fi
      break
    fi
    temp=''
    fd=''
    if (( interrupted != 0 )); then
      cleanup_status=$interrupted
      break
    fi
  done

  while [[ -n $fd && $cleanup_status == -1 ]]; do
    (( interrupted == 0 )) || {
      cleanup_status=$interrupted
      break
    }

    (
      # The root was established as a safe absolute directory above. Keep this
      # compatible with Zsh 5.2, whose `cd` builtin does not accept `--`.
      builtin cd "$root" || exit 126
      unset SUPABASE_WORKDIR
      # Setting the hard and soft limits prevents the launched CLI from
      # raising its own ceiling after exec. `-f` is specified in 512-byte
      # blocks by Zsh, so this caps one captured output stream at 1 MiB.
      builtin ulimit -HSf "$capture_file_blocks" 2>/dev/null || exit 125
      # `exec` makes child_pid the CLI itself, not a relay or wrapper process.
      exec "$cli_path" "$@" 1>&"$fd" 2>/dev/null
    ) &
    child_pid=$!
    if [[ -z $child_pid ]]; then
      cleanup_status=1
      break
    fi
    # If a signal lands in the small window after `$!` becomes available but
    # before polling begins, preserve the direct child's PID for the unified
    # cleanup block instead of entering any wait primitive.
    if (( interrupted != 0 )); then
      cleanup_status=$interrupted
      break
    fi

    # Poll the direct child rather than blocking in `wait`: a CLI can ignore
    # SIGXFSZ after reaching the fixed file-size ceiling, or emit no output at
    # all. Every 100ms this parent-side watchdog checks both the held FD's
    # shared file position and a local 15-second deadline. Zsh records a
    # finished background child's status, so `kill -0` becomes false before
    # the later `wait` retrieves that cached status.
    while builtin kill -0 "$child_pid" 2>/dev/null; do
      if (( interrupted != 0 )); then
        cleanup_status=$interrupted
        break
      fi
      # `systell` is a Zsh math function. Assigning its expression to this
      # integer parameter avoids invoking an external stat utility or parser.
      file_size="systell($fd)"
      if (( file_size < 0 )); then
        cleanup_status=1
        break
      fi
      if (( file_size > limit )); then
        REPLY=''
        cleanup_status=3
        break
      fi
      if (( SECONDS >= timeout_seconds )); then
        cleanup_status=1
        break
      fi
      builtin zselect -t "$capture_poll_centiseconds" 2>/dev/null
      poll_status=$?
      if (( interrupted != 0 )); then
        cleanup_status=$interrupted
        break
      fi
      # A timeout returns 1. Any other error fails closed and reaches the
      # direct-child cleanup below rather than risking an unbounded busy loop.
      if (( poll_status != 0 && poll_status != 1 )); then
        cleanup_status=1
        break
      fi
    done
    (( cleanup_status == -1 )) || break

    # A signal can arrive after `$!` is assigned but before `wait` starts.
    # Observe it immediately before the only blocking primitive so cleanup
    # terminates and reaps a quiet direct child instead of waiting forever.
    if (( interrupted != 0 )); then
      cleanup_status=$interrupted
      break
    fi
    builtin wait "$child_pid" 2>/dev/null
    child_status=$?
    if (( interrupted != 0 )); then
      cleanup_status=$interrupted
      break
    fi
    # A completed wait has reaped the direct child regardless of its exit
    # status. Clearing now avoids ever signaling a PID that the OS could reuse.
    child_pid=''

    if ! builtin sysseek -u "$fd" -w end 0; then
      cleanup_status=1
      break
    fi
    (( interrupted == 0 )) || {
      cleanup_status=$interrupted
      break
    }
    file_size="systell($fd)"
    if (( file_size < 0 )); then
      cleanup_status=1
      break
    fi
    if (( file_size > limit )); then
      REPLY=''
      cleanup_status=3
      break
    fi
    if (( child_status != 0 )); then
      cleanup_status=1
      break
    fi

    if ! builtin sysseek -u "$fd" -w start 0; then
      cleanup_status=1
      break
    fi
    while true; do
      chunk=''
      # The completed file was size-checked above. Keep a byte counter as a
      # defense in depth before any remote bytes enter the parser's buffer.
      builtin sysread -i "$fd" -s 4096 chunk
      read_status=$?
      if (( interrupted != 0 )); then
        cleanup_status=$interrupted
        break
      fi
      if (( read_status != 0 && ${#chunk} == 0 )); then
        if (( read_status == 5 )); then
          cleanup_status=0
        else
          cleanup_status=1
        fi
        break
      fi
      (( read_status == 0 )) || {
        REPLY=''
        cleanup_status=1
        break
      }
      (( bytes += ${#chunk} ))
      if (( bytes > limit )); then
        REPLY=''
        cleanup_status=3
        break
      fi
      REPLY+=$chunk
    done
    break
  done

  # Unlike a function EXIT trap, this cleanup runs before the function's
  # locals unwind. Every value is created by this helper; no project path, CLI
  # text, or remote data is evaluated as cleanup code.
  if [[ -n $child_pid ]]; then
    # Give a well-behaved CLI a brief chance to leave, then force-reap a
    # SIGTERM-ignoring direct child. `child_pid` stays nonempty until `wait`
    # consumes its status, so it cannot refer to a reused PID here.
    builtin kill -15 "$child_pid" 2>/dev/null || true
    builtin zselect -t "$capture_kill_grace_centiseconds" 2>/dev/null || true
    if builtin kill -0 "$child_pid" 2>/dev/null; then
      builtin kill -9 "$child_pid" 2>/dev/null || true
    fi
    builtin wait "$child_pid" 2>/dev/null || true
    child_pid=''
  fi
  if [[ -n $fd ]]; then
    exec {fd}>&-
  fi
  if [[ -n $temp ]]; then
    builtin zf_rm -f "$temp" 2>/dev/null || true
  fi
  return "$cleanup_status"
}

_spaceship_supabase_cli_output_style() {
  emulate -L zsh
  setopt extendedglob
  local LC_ALL=C

  local version=${1-}
  local major minor patch
  local -a parts

  REPLY=''
  (( ${#version} >= 5 && ${#version} <= 64 )) || return 1
  if [[ $version == *$'\n' ]]; then
    version=${version%$'\n'}
    if [[ $version == *$'\r' ]]; then
      version=${version%$'\r'}
    fi
  fi
  [[ $version != *$'\n'* && $version != *$'\r'* && $version != *$'\t'* && $version != *' '* ]] || return 1
  version=${version#v}
  parts=("${(@s:.:)version}")
  (( ${#parts[@]} == 3 )) || return 1
  major=${parts[1]}
  minor=${parts[2]}
  patch=${parts[3]}
  [[ ${#major} -le 3 && ${#minor} -le 6 && ${#patch} -le 6 ]] || return 1
  [[ $major == [0-9]## && $minor == [0-9]## && $patch == [0-9]## ]] || return 1
  (( 10#$major == 2 )) || return 1

  # v2.72.7 uses the older global flag.  v2.111.0 and v2.113.0 advertise
  # --output-format json, whose stable result is the projects envelope.
  if (( 10#$minor >= 111 )); then
    REPLY='output-format'
  else
    REPLY='output'
  fi
}

_spaceship_supabase_discover_project_name() {
  emulate -L zsh

  local root=${1-}
  local target_ref=${2-}
  local version style output
  local -i result_status

  REPLY=''
  _spaceship_supabase_capture_cli_output "$root" 64 15 --version
  result_status=$?
  case $result_status in
    0) version=$REPLY ;;
    2) return 10 ;;
    3) return 12 ;;
    *) return 11 ;;
  esac
  _spaceship_supabase_cli_output_style "$version" || return 13
  style=$REPLY

  case $style in
    output-format)
      _spaceship_supabase_capture_cli_output "$root" 131072 15 projects list --output-format json
      ;;
    output)
      _spaceship_supabase_capture_cli_output "$root" 131072 15 projects list --output json
      ;;
    *) return 13 ;;
  esac
  result_status=$?
  case $result_status in
    0) output=$REPLY ;;
    2) return 10 ;;
    3) return 12 ;;
    *) return 11 ;;
  esac
  _spaceship_supabase_find_project_name_in_json "$output" "$target_ref"
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

  local root ref remote branch branch_status synced encoded
  local synced_kind synced_name tab=$'\t'

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

  # Synced project metadata is a separately owned, opt-in snapshot.  It is
  # consulted only after a live identity and manual-label precedence are
  # established; it never decorates a configured mapping or recovers a ref.
  if [[ ${_SPACESHIP_SUPABASE_CONTEXT[source]} == live && ${SPACESHIP_SUPABASE_FORMAT-} == label+ref && -z ${_SPACESHIP_SUPABASE_CONTEXT[label]-} && ${SPACESHIP_SUPABASE_USE_SYNCED_DECORATIONS-} == true ]]; then
    if _spaceship_supabase_read_synced_decoration "$ref"; then
      synced=$REPLY
      synced=${synced#*"${tab}"}
      synced_kind=${synced%%"${tab}"*}
      synced=${synced#*"${tab}"}
      synced_name=${synced%%"${tab}"*}
      _SPACESHIP_SUPABASE_CONTEXT[synced_kind]=$synced_kind
      _SPACESHIP_SUPABASE_CONTEXT[synced_name]=$synced_name
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
  local synced_name=${6-}
  local synced_kind=${7-}
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
      elif [[ $source == live ]] && _spaceship_supabase_validate_synced_decoration_kind "$synced_kind"; then
        synced_kind=$REPLY
        if _spaceship_supabase_validate_label "$synced_name"; then
          synced_name=$REPLY
          display="$synced_name ($ref) · synced:$synced_kind"
        else
          display=$ref
        fi
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
    "${_SPACESHIP_SUPABASE_CONTEXT[label]-}" \
    "${_SPACESHIP_SUPABASE_CONTEXT[synced_name]-}" \
    "${_SPACESHIP_SUPABASE_CONTEXT[synced_kind]-}"
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

_spaceship_supabase_write_private_records() (
  emulate -L zsh

  local state_file=${1-}
  local parent temp fd record
  local -i attempt=0 write_failed=0
  shift || return 1

  # The subshell keeps this explicit state-management hardening from changing
  # the caller's umask.  Prompt rendering never enters this helper.
  umask 077

  [[ $_SPACESHIP_SUPABASE_FILES_READY == true && $_SPACESHIP_SUPABASE_SYSTEM_READY == true ]] || return 1
  [[ -n $state_file && $state_file == /* ]] || return 1
  parent=${state_file:h}

  # If an interrupt arrives after opening the temporary file, do not leave an
  # ambiguous partial record behind.  The completed rename clears `temp` so
  # the EXIT trap never touches a successfully published state file.
  trap '[[ -z ${temp-} ]] || zf_rm -f "$temp" 2>/dev/null || true' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  if ! _spaceship_supabase_lstat_exists "$parent"; then
    # zsh/files builtins in Zsh 5.2 do not implement a `--` end-of-options
    # marker. Every state path is validated as absolute above, so it cannot be
    # mistaken for an option.
    zf_mkdir -p -m 700 "$parent" 2>/dev/null || return 1
  fi
  _spaceship_supabase_safe_private_directory "$parent" || return 1

  # Existing state must already be safe.  We do not overwrite a symlink,
  # group-readable file, or someone else's state file.
  if _spaceship_supabase_lstat_exists "$state_file"; then
    _spaceship_supabase_safe_private_file "$state_file" || return 1
  fi

  while (( attempt < 16 )); do
    (( attempt++ ))
    temp="${state_file}.tmp.${$}.${RANDOM}"
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

  zf_mv "$temp" "$state_file" 2>/dev/null || {
    zf_rm -f "$temp" 2>/dev/null
    return 1
  }
  temp=''
)

_spaceship_supabase_label_error() {
  emulate -L zsh
  case ${1-} in
    NO_LIVE_REF|LABEL_INVALID|LABEL_STORE_INVALID|LABEL_WRITE_FAILED|HELPER_USAGE)
      print -ru2 -- "spaceship-supabase: ${1}"
      ;;
  esac
}

_spaceship_supabase_sync_error() {
  emulate -L zsh

  case ${1-} in
    SYNC_USAGE|SYNC_NO_LIVE_REF|SYNC_CLI_NOT_FOUND|SYNC_CLI_VERSION_UNSUPPORTED|\
    SYNC_CLI_FAILED|SYNC_OUTPUT_INVALID|SYNC_NO_MATCH|SYNC_AMBIGUOUS_MATCH|\
    SYNC_NAME_INVALID|SYNC_CANCELLED|SYNC_DECORATION_STORE_INVALID|\
    SYNC_WRITE_FAILED|SYNC_REF_CHANGED|SYNC_TIME_UNAVAILABLE)
      print -ru2 -- "spaceship-supabase: ${1}"
      ;;
  esac
}

_spaceship_supabase_sync_project_preview() {
  emulate -L zsh

  local project_name=${1-}
  local ref=${2-}

  _spaceship_supabase_validate_label "$project_name" || return 1
  project_name=$REPLY
  _spaceship_supabase_validate_ref "$ref" || return 1
  ref=$REPLY
  print -r -- 'spaceship-supabase sync project'
  print -r -- "preview: $project_name ($ref) · synced:project"
  print -r -- 'source: supabase-cli:projects-list'
  print -r -- 'action: save separate synced decoration'
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

  _spaceship_supabase_write_private_records "$label_file" "${filtered[@]}" || {
    _spaceship_supabase_label_error LABEL_WRITE_FAILED
    return 1
  }
}

# Explicit, user-invoked top-level project-name discovery.  This is the only
# v0.2 path allowed to run the installed Supabase CLI, and it always proves the
# current live ref again before publishing a separate synced-decoration record.
spaceship_supabase_sync() {
  emulate -L zsh

  local action=${1-}
  local assume_yes=false confirmation=''
  local root ref initial_root initial_ref project_name decoration_file
  local timestamp encoded record record_ref tab=$'\t'
  local kind='project' source='supabase-cli:projects-list'
  local -a records filtered
  local -i result_status

  case $# in
    1)
      [[ $action == project ]] || {
        _spaceship_supabase_sync_error SYNC_USAGE
        return 1
      }
      ;;
    2)
      [[ $action == project && $2 == --yes ]] || {
        _spaceship_supabase_sync_error SYNC_USAGE
        return 1
      }
      assume_yes=true
      ;;
    *)
      _spaceship_supabase_sync_error SYNC_USAGE
      return 1
      ;;
  esac

  _spaceship_supabase_resolve_live_context || {
    _spaceship_supabase_sync_error SYNC_NO_LIVE_REF
    return 1
  }
  initial_root=${_SPACESHIP_SUPABASE_CONTEXT[root]}
  initial_ref=${_SPACESHIP_SUPABASE_CONTEXT[ref]}

  _spaceship_supabase_discover_project_name "$initial_root" "$initial_ref"
  result_status=$?
  case $result_status in
    0) project_name=$REPLY ;;
    2)
      _spaceship_supabase_sync_error SYNC_NO_MATCH
      return 1
      ;;
    3)
      _spaceship_supabase_sync_error SYNC_AMBIGUOUS_MATCH
      return 1
      ;;
    4|12)
      _spaceship_supabase_sync_error SYNC_OUTPUT_INVALID
      return 1
      ;;
    10)
      _spaceship_supabase_sync_error SYNC_CLI_NOT_FOUND
      return 1
      ;;
    13)
      _spaceship_supabase_sync_error SYNC_CLI_VERSION_UNSUPPORTED
      return 1
      ;;
    *)
      _spaceship_supabase_sync_error SYNC_CLI_FAILED
      return 1
      ;;
  esac
  _spaceship_supabase_validate_label "$project_name" || {
    _spaceship_supabase_sync_error SYNC_NAME_INVALID
    return 1
  }
  project_name=$REPLY
  _spaceship_supabase_sync_project_preview "$project_name" "$initial_ref" || {
    _spaceship_supabase_sync_error SYNC_OUTPUT_INVALID
    return 1
  }

  if [[ $assume_yes != true ]]; then
    print -rn -- 'Save this synced decoration? [y/N] '
    IFS= read -r confirmation || confirmation=''
    print -r -- ''
    case $confirmation in
      y|Y|yes|YES) ;;
      *)
        _spaceship_supabase_sync_error SYNC_CANCELLED
        return 1
        ;;
    esac
  fi

  # A Supabase relink, a root-boundary change, or a malformed ref that occurs
  # while the user reviews the preview makes the proposal stale.  Never write
  # a decoration in that case.
  _spaceship_supabase_resolve_live_context || {
    _spaceship_supabase_sync_error SYNC_REF_CHANGED
    return 1
  }
  root=${_SPACESHIP_SUPABASE_CONTEXT[root]}
  ref=${_SPACESHIP_SUPABASE_CONTEXT[ref]}
  [[ $root == "$initial_root" && $ref == "$initial_ref" ]] || {
    _spaceship_supabase_sync_error SYNC_REF_CHANGED
    return 1
  }

  _spaceship_supabase_synced_decoration_file_path || {
    _spaceship_supabase_sync_error SYNC_DECORATION_STORE_INVALID
    return 1
  }
  decoration_file=$REPLY
  _spaceship_supabase_synced_decoration_store_status
  case $? in
    0)
      _spaceship_supabase_collect_synced_decoration_records "$decoration_file" || {
        _spaceship_supabase_sync_error SYNC_DECORATION_STORE_INVALID
        return 1
      }
      records=("${reply[@]}")
      ;;
    2)
      records=()
      ;;
    *)
      _spaceship_supabase_sync_error SYNC_DECORATION_STORE_INVALID
      return 1
      ;;
  esac

  timestamp=${EPOCHSECONDS-}
  _spaceship_supabase_validate_timestamp "$timestamp" || {
    _spaceship_supabase_sync_error SYNC_TIME_UNAVAILABLE
    return 1
  }
  timestamp=$REPLY
  # Avoid arithmetic on externally supplied/implementation-sized timestamp
  # strings. The strict decimal validator ran above; this only rejects zero.
  [[ $timestamp == *[1-9]* ]] || {
    _spaceship_supabase_sync_error SYNC_TIME_UNAVAILABLE
    return 1
  }

  filtered=()
  for record in "${records[@]}"; do
    encoded=${record#v1"${tab}"}
    record_ref=${encoded%%"${tab}"*}
    [[ $record_ref == "$ref" ]] && continue
    filtered+=("$record")
  done
  filtered+=("v1$tab$ref$tab$kind$tab$project_name$tab$source$tab$timestamp")

  # The file walk and timestamp work above can take longer than the first
  # recheck. Prove the proposal is still for this exact live root/ref at the
  # last possible point before the atomic rename can publish it.
  _spaceship_supabase_resolve_live_context || {
    _spaceship_supabase_sync_error SYNC_REF_CHANGED
    return 1
  }
  root=${_SPACESHIP_SUPABASE_CONTEXT[root]}
  ref=${_SPACESHIP_SUPABASE_CONTEXT[ref]}
  [[ $root == "$initial_root" && $ref == "$initial_ref" ]] || {
    _spaceship_supabase_sync_error SYNC_REF_CHANGED
    return 1
  }

  _spaceship_supabase_write_private_records "$decoration_file" "${filtered[@]}" || {
    _spaceship_supabase_sync_error SYNC_WRITE_FAILED
    return 1
  }
  print -r -- 'spaceship-supabase: SYNC_SAVED'
}

# Read-only local diagnostics.  Default output intentionally omits filesystem
# paths, project IDs, labels, and raw config input.  --verbose shows only
# already allowlisted values.
spaceship_supabase_doctor() {
  emulate -L zsh

  local verbose=false root ref remote configured_ref live_state config_state store_state sync_store_state sync_state
  local branch label sync_encoded sync_kind sync_name sync_source sync_timestamp tab=$'\t'

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
    _spaceship_supabase_doctor_synced_decoration_store_state
    print -r -- "synced-decoration-store: $REPLY"
    print -r -- 'synced-decoration: unavailable'
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

  _spaceship_supabase_doctor_synced_decoration_store_state
  sync_store_state=$REPLY
  print -r -- "synced-decoration-store: $sync_store_state"
  sync_state='unavailable'
  if [[ $live_state == valid && $sync_store_state == available ]] && _spaceship_supabase_read_synced_decoration "$ref"; then
    sync_encoded=$REPLY
    sync_encoded=${sync_encoded#*"${tab}"}
    sync_kind=${sync_encoded%%"${tab}"*}
    sync_encoded=${sync_encoded#*"${tab}"}
    sync_name=${sync_encoded%%"${tab}"*}
    sync_encoded=${sync_encoded#*"${tab}"}
    sync_source=${sync_encoded%%"${tab}"*}
    sync_timestamp=${sync_encoded#*"${tab}"}
    sync_state='available'
  elif [[ $sync_store_state == disabled ]]; then
    sync_state='disabled'
  fi
  print -r -- "synced-decoration: $sync_state"

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
      if [[ $sync_state == available ]]; then
        # Values were accepted by the synced-record parser before reaching this
        # diagnostic.  Deliberately omit the project name: verbose doctor is
        # allowed to reveal provenance, not a remote-derived prompt label.
        print -r -- "synced-kind: $sync_kind"
        print -r -- "synced-source: $sync_source"
        print -r -- "synced-saved-at: $sync_timestamp"
        if [[ ${SPACESHIP_SUPABASE_USE_LABELS-} == true && $store_state == available ]] && _spaceship_supabase_read_label "$ref"; then
          print -r -- 'synced-status: shadowed'
        else
          print -r -- 'synced-status: available'
        fi
      fi
    fi
  fi

  print -r -- 'remediation: run supabase link in the intended project, then retry.'
}
