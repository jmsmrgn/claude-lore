#!/usr/bin/env bash
# status.sh — post-install verification for claude-lore
# Run at any time to confirm the system is wired correctly.

CONFIG_FILE="$HOME/.claude/lore.conf"
SETTINGS_FILE="$HOME/.claude/settings.json"
AGENT_FILE="$HOME/.claude/agents/memory-writer.md"

# Resolve vault path from lore.conf, fall back to ~/claude-lore
VAULT_DIR=""
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi
if [[ -z "$VAULT_DIR" ]]; then
  VAULT_DIR="$HOME/claude-lore"
fi

echo "claude-lore status"
echo "------------------"

# 1. Vault directory
if [[ -d "$VAULT_DIR" ]]; then
  printf "%-16s%s [found]\n" "Vault:" "$VAULT_DIR"
else
  printf "%-16s%s [NOT FOUND]\n" "Vault:" "$VAULT_DIR"
  echo "  -> Run setup.sh to create the vault, or update VAULT_DIR in ~/.claude/lore.conf"
fi

# 2. Global/CONTEXT.md
CONTEXT_FILE="$VAULT_DIR/Global/CONTEXT.md"
if [[ -f "$CONTEXT_FILE" ]]; then
  if stat --version > /dev/null 2>&1; then
    mtime=$(stat --format="%y" "$CONTEXT_FILE" | cut -d' ' -f1)
  else
    mtime=$(stat -f "%Sm" -t "%Y-%m-%d" "$CONTEXT_FILE")
  fi
  printf "%-16s%s\n" "CONTEXT.md:" "last modified $mtime"
else
  printf "%-16s%s\n" "CONTEXT.md:" "NOT FOUND"
  echo "  -> Create $CONTEXT_FILE and fill in your identity and stack"
fi

# 3. SessionStart hook
SESSION_HOOK_FOUND=0
if [[ -f "$SETTINGS_FILE" ]] && command -v jq > /dev/null 2>&1; then
  HOOK_CMD=$(jq -r '[.hooks.SessionStart[]? | .hooks[]? | select(.type == "command") | .command] | .[]' "$SETTINGS_FILE" 2>/dev/null)
  if echo "$HOOK_CMD" | grep -q "inject-context.sh"; then
    SESSION_HOOK_FOUND=1
  fi
fi
if [[ "$SESSION_HOOK_FOUND" -eq 1 ]]; then
  printf "%-16s%s\n" "SessionStart:" "wired [inject-context.sh]"
else
  printf "%-16s%s\n" "SessionStart:" "NOT FOUND"
  echo "  -> Run setup.sh to inject the hook into ~/.claude/settings.json"
fi

# 4. Stop hook
STOP_HOOK_FOUND=0
if [[ -f "$SETTINGS_FILE" ]] && command -v jq > /dev/null 2>&1; then
  STOP_CMD=$(jq -r '[.hooks.Stop[]? | .hooks[]? | select(.type == "command") | .command] | .[]' "$SETTINGS_FILE" 2>/dev/null)
  if echo "$STOP_CMD" | grep -q "session-checkpoint.sh"; then
    STOP_HOOK_FOUND=1
  fi
fi
if [[ "$STOP_HOOK_FOUND" -eq 1 ]]; then
  printf "%-16s%s\n" "Stop hook:" "wired [session-checkpoint.sh]"
else
  printf "%-16s%s\n" "Stop hook:" "NOT FOUND"
  echo "  -> Run setup.sh to inject the hook into ~/.claude/settings.json"
fi

# 5. memory-writer agent
if [[ -f "$AGENT_FILE" ]]; then
  printf "%-16s%s\n" "memory-writer:" "installed"
else
  printf "%-16s%s\n" "memory-writer:" "NOT FOUND"
  echo "  -> Run setup.sh, or copy agents/memory-writer.md to ~/.claude/agents/"
fi

# 6. Dependencies
if command -v jq > /dev/null 2>&1; then
  printf "%-16s%s\n" "jq:" "$(jq --version 2>/dev/null || echo installed)"
else
  printf "%-16s%s\n" "jq:" "NOT FOUND — install with: brew install jq"
fi

if command -v python3 > /dev/null 2>&1; then
  printf "%-16s%s\n" "python3:" "$(python3 --version 2>&1)"
else
  printf "%-16s%s\n" "python3:" "NOT FOUND — install with: brew install python3"
fi

if command -v claude > /dev/null 2>&1; then
  printf "%-16s%s\n" "claude:" "$(claude --version 2>/dev/null || echo installed)"
else
  printf "%-16s%s\n" "claude:" "NOT FOUND — Claude Code CLI required"
fi

# 7. Checkpoint log (shows if subprocess has run)
LOG_FILE="$HOME/.claude/lore-checkpoint.log"
if [[ -f "$LOG_FILE" ]]; then
  log_size=$(wc -c < "$LOG_FILE" | tr -d ' ')
  printf "%-16s%s\n" "Checkpoint log:" "$LOG_FILE ($log_size bytes)"
else
  printf "%-16s%s\n" "Checkpoint log:" "not yet created (will appear after first session close)"
fi
