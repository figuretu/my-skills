#!/usr/bin/env bash
set -euo pipefail

# Default agents (used for uninstall — always clean from all)
DEFAULT_AGENTS=(claude-code codex)
# Default agents for private skills (repo-level install)
PRIVATE_DEFAULT_AGENTS=(claude-code)

# Locate the my-skills repo: zoxide → $MY_SKILLS_DIR env var → fail
_resolve_repo() {
    local dir
    dir="$(zoxide query my-skills 2>/dev/null)" && [[ -d "$dir" ]] && { echo "$dir"; return; }
    [[ -n "${MY_SKILLS_DIR:-}" && -d "$MY_SKILLS_DIR" ]] && { echo "$MY_SKILLS_DIR"; return; }
    echo "ERROR: cannot locate my-skills repo" >&2
    return 1
}

# Resolve a skill's location: returns "public" or "private"
# Sets SKILL_BASE_DIR to the directory containing the skill (repo root or repo/private)
_resolve_skill() {
    local skill_name="$1" repo
    repo="$(_resolve_repo)"
    if [[ -f "$repo/$skill_name/SKILL.md" ]]; then
        SKILL_SCOPE="public"
        SKILL_BASE_DIR="$repo"
    elif [[ -f "$repo/private/$skill_name/SKILL.md" ]]; then
        SKILL_SCOPE="private"
        SKILL_BASE_DIR="$repo/private"
    else
        SKILL_SCOPE=""
        SKILL_BASE_DIR=""
    fi
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
    _resolve_skill "$name"
    echo "--- local ---"
    if [[ "$SKILL_SCOPE" == "public" ]]; then
        echo "found (public): $repo/$name/SKILL.md"
    elif [[ "$SKILL_SCOPE" == "private" ]]; then
        echo "found (private): $repo/private/$name/SKILL.md"
    else
        echo "not found"
    fi
    echo "--- installed (global) ---"
    npx skills ls -g 2>/dev/null | grep -i "$name" || echo "not installed globally"
    echo "--- installed (repo-level) ---"
    npx skills ls 2>/dev/null | grep -i "$name" || echo "not installed in current repo"
    ;;

install)
    # Install (or reinstall) a skill from the local repo
    name="${2:?Usage: $0 install <skill-name>}"
    repo="$(_resolve_repo)"
    _resolve_skill "$name"
    if [[ -z "$SKILL_SCOPE" ]]; then
        echo "ERROR: skill '$name' not found in $repo/ or $repo/private/" >&2
        exit 1
    fi
    if [[ "$SKILL_SCOPE" == "private" ]]; then
        # Private skills: repo-level install (no -g), skip install-rules.json
        agents_str=$(printf -- '-a %s ' "${PRIVATE_DEFAULT_AGENTS[@]}")
        echo "Installing $name (private, repo-level) from $SKILL_BASE_DIR ..."
        echo "Agents: ${PRIVATE_DEFAULT_AGENTS[*]}"
        npx skills add "$SKILL_BASE_DIR" $agents_str -s "$name" -y
        echo "--- verify ---"
        npx skills ls -a claude-code | grep -i "$name" || echo "WARNING: not found after install"
    else
        # Public skills: global install per install-rules.json
        echo "Installing $name (public, global) from $SKILL_BASE_DIR ..."
        echo "Agents: $(_agents_for_skill "$name" | tr '\n' ' ')"
        npx skills add "$SKILL_BASE_DIR" -g $(_install_agent_flags "$name") -s "$name" -y
        echo "--- verify ---"
        npx skills ls -g -a claude-code | grep -i "$name" || echo "WARNING: not found after install"
    fi
    ;;

uninstall)
    # Uninstall a skill globally (or repo-level for private skills)
    name="${2:?Usage: $0 uninstall <skill-name>}"
    _resolve_skill "$name"
    if [[ "$SKILL_SCOPE" == "private" ]]; then
        echo "Uninstalling $name (repo-level) ..."
        npx skills remove "$name" $(_default_agent_flags) -y
    else
        echo "Uninstalling $name (global) ..."
        npx skills remove "$name" -g $(_default_agent_flags) -y
    fi
    ;;

stage)
    # Git-add skill directory + README.md, then show status
    name="${2:?Usage: $0 stage <skill-name>}"
    repo="$(_resolve_repo)"
    _resolve_skill "$name"
    if [[ "$SKILL_SCOPE" == "private" ]]; then
        # Stage in the private sub-repo
        git -C "$repo/private" add "$name/" README.md 2>/dev/null || git -C "$repo/private" add "$name/"
        git -C "$repo/private" status --short
    else
        git -C "$repo" add "$name/" README.md
        git -C "$repo" status --short
    fi
    ;;

help|*)
    cat <<EOF
Usage: $0 <command> [skill-name]

Commands:
  locate-repo          Find and output the my-skills repo path
  check <name>         Check local existence (public + private) + install status
  install <name>       Install/reinstall skill (public: global per install-rules.json; private: repo-level)
  uninstall <name>     Uninstall skill (public: global; private: repo-level)
  stage <name>         Git-add skill dir + README.md in the correct repo, show status

Skills in the repo root are public (global install).
Skills in private/ are private (repo-level install, no install-rules.json).
EOF
    ;;
esac
