#!/usr/bin/env bash
set -euo pipefail

# Target agents for install/uninstall
AGENTS=(claude-code codex)

# Locate the my-skills repo: zoxide → $MY_SKILLS_DIR env var → fail
_resolve_repo() {
    local dir
    dir="$(zoxide query my-skills 2>/dev/null)" && [[ -d "$dir" ]] && { echo "$dir"; return; }
    [[ -n "${MY_SKILLS_DIR:-}" && -d "$MY_SKILLS_DIR" ]] && { echo "$MY_SKILLS_DIR"; return; }
    echo "ERROR: cannot locate my-skills repo" >&2
    return 1
}

_agent_flags() {
    for agent in "${AGENTS[@]}"; do
        printf -- '-a %s ' "$agent"
    done
}

case "${1:-help}" in

locate-repo)
    # Find and output the my-skills repo path
    _resolve_repo
    ;;

check)
    # Check if a skill exists locally and/or is installed globally
    name="${2:?Usage: $0 check <skill-name>}"
    repo="$(_resolve_repo)"
    echo "--- local ---"
    if [[ -f "$repo/$name/SKILL.md" ]]; then
        echo "found: $repo/$name/SKILL.md"
    else
        echo "not found"
    fi
    echo "--- installed ---"
    npx skills ls -g 2>/dev/null | grep -i "$name" || echo "not installed"
    ;;

install)
    # Install (or reinstall) a skill from the local repo
    name="${2:?Usage: $0 install <skill-name>}"
    repo="$(_resolve_repo)"
    echo "Installing $name from $repo ..."
    npx skills add "$repo" -g $(_agent_flags) -s "$name" -y
    echo "--- verify ---"
    npx skills ls -g -a claude-code | grep -i "$name" || echo "WARNING: not found after install"
    ;;

uninstall)
    # Uninstall a skill globally from all agents
    name="${2:?Usage: $0 uninstall <skill-name>}"
    echo "Uninstalling $name ..."
    npx skills remove "$name" -g $(_agent_flags) -y
    ;;

stage)
    # Git-add skill directory + README.md, then show status
    name="${2:?Usage: $0 stage <skill-name>}"
    repo="$(_resolve_repo)"
    git -C "$repo" add "$name/" README.md
    git -C "$repo" status --short
    ;;

help|*)
    cat <<EOF
Usage: $0 <command> [skill-name]

Commands:
  locate-repo          Find and output the my-skills repo path
  check <name>         Check local existence + global install status
  install <name>       Install/reinstall skill from local repo (claude-code + codex)
  uninstall <name>     Uninstall skill globally from all agents
  stage <name>         Git-add skill dir + README.md, show status
EOF
    ;;
esac
