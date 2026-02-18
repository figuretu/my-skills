#!/usr/bin/env bash
set -euo pipefail

# Default agents (used for uninstall — always clean from all)
DEFAULT_AGENTS=(claude-code codex)

# Locate the my-skills repo: zoxide → $MY_SKILLS_DIR env var → fail
_resolve_repo() {
    local dir
    dir="$(zoxide query my-skills 2>/dev/null)" && [[ -d "$dir" ]] && { echo "$dir"; return; }
    [[ -n "${MY_SKILLS_DIR:-}" && -d "$MY_SKILLS_DIR" ]] && { echo "$MY_SKILLS_DIR"; return; }
    echo "ERROR: cannot locate my-skills repo" >&2
    return 1
}

# Resolve target agents for a skill from install-rules.json (falls back to DEFAULT_AGENTS)
_agents_for_skill() {
    local skill_name="$1" repo rules_file
    repo="$(_resolve_repo)"
    rules_file="$repo/install-rules.json"
    if [[ ! -f "$rules_file" ]]; then
        printf '%s\n' "${DEFAULT_AGENTS[@]}"
        return
    fi
    python3 - "$rules_file" "$skill_name" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    rules = json.load(f)
cfg = rules.get("skills", {}).get(sys.argv[2])
agents = cfg["agents"] if cfg and "agents" in cfg else rules.get("defaults", {}).get("agents", ["claude-code", "codex"])
for a in agents:
    print(a)
PYEOF
}

# Build -a flags for install (respects install-rules.json)
_install_agent_flags() {
    local skill_name="$1"
    while IFS= read -r agent; do
        printf -- '-a %s ' "$agent"
    done < <(_agents_for_skill "$skill_name")
}

# Build -a flags for uninstall (always targets all default agents)
_default_agent_flags() {
    for agent in "${DEFAULT_AGENTS[@]}"; do
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
    echo "Agents: $(_agents_for_skill "$name" | tr '\n' ' ')"
    npx skills add "$repo" -g $(_install_agent_flags "$name") -s "$name" -y
    echo "--- verify ---"
    npx skills ls -g -a claude-code | grep -i "$name" || echo "WARNING: not found after install"
    ;;

uninstall)
    # Uninstall a skill globally from all agents
    name="${2:?Usage: $0 uninstall <skill-name>}"
    echo "Uninstalling $name ..."
    npx skills remove "$name" -g $(_default_agent_flags) -y
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
  install <name>       Install/reinstall skill (agents per install-rules.json)
  uninstall <name>     Uninstall skill globally from all default agents
  stage <name>         Git-add skill dir + README.md, show status
EOF
    ;;
esac
