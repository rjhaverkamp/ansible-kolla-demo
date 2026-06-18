#!/usr/bin/env bash
# Minimal template rendering for cloud-init. Source me; do not execute.

# render_template FILE: expand ${VAR} tokens from the environment and print the result.
render_template() {
  local file=$1
  [[ -f $file ]] || die "template not found: $file"
  if command -v envsubst >/dev/null 2>&1; then
    envsubst <"$file"
    return 0
  fi
  # Pure-bash fallback: expand only ${NAME} tokens; unknown names render empty.
  local line token name
  while IFS= read -r line || [[ -n $line ]]; do
    while [[ $line =~ (\$\{([A-Za-z_][A-Za-z0-9_]*)\}) ]]; do
      token=${BASH_REMATCH[1]}
      name=${BASH_REMATCH[2]}
      line=${line//"$token"/${!name-}}
    done
    printf '%s\n' "$line"
  done <"$file"
}
