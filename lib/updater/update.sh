set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

echo "==> Checking pi-coding-agent..."

# Fetch latest release from GitHub API
LATEST_TAG="$(curl -fsSL \
  "https://api.github.com/repos/badlogic/pi-mono/releases/latest" \
  | jq -r .tag_name | sed 's/^v//')"

CURRENT="$(jq -r '.piCodingAgentVersions.version // .version // empty' \
  "$REPO_ROOT/targets/pi/package/versions.json" 2>/dev/null || echo 'unknown')"

if [ "$LATEST_TAG" = "$CURRENT" ]; then
  echo "  pi-coding-agent: already at $CURRENT"
else
  echo "  pi-coding-agent: $CURRENT -> $LATEST_TAG"
  # Note: updating hashes requires downloading and computing nix hash
  # For now, update version and emit a warning about manual hash update
  echo "  WARNING: Hash update required. Download new releases and run:"
  echo "    nix hash file --type sha256 <downloaded-file>"
  echo "  Then update targets/pi/package/versions.json manually."
  echo "  (Automated hash prefetch deferred -- requires nix-prefetch-url or nix store prefetch-file)"
fi

echo ""
echo "==> Updating llm-agents flake input..."
if nix flake update llm-agents --flake "$REPO_ROOT" 2>&1; then
  # Check if flake.lock changed
  if git -C "$REPO_ROOT" diff --quiet flake.lock 2>/dev/null; then
    echo "  llm-agents: already up to date"
  else
    echo "  llm-agents: updated (see git diff flake.lock for details)"
  fi
else
  echo "  WARNING: nix flake update llm-agents failed (network or auth issue)"
fi

echo ""
echo "==> Running nix flake check..."
if nix flake check "$REPO_ROOT"; then
  echo ""
  echo "==> All checks passed. Review changes with: git diff"
else
  echo ""
  echo "==> nix flake check FAILED. Review errors above."
  exit 1
fi
