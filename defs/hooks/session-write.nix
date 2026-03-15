# Session tracking hooks: write JSON session files on start/end.
# Usage: import this file as a function receiving pkgs, then merge into your module list.
# Example (in flake.nix or preset):
#   modules = defaultModules ++ [ (import ./defs/hooks/session-write.nix { inherit pkgs; }) ];
{ pkgs }:
{
  hooks = [
    {
      event = "session-start";
      package = pkgs.jq;
      command = ''
        SESSION_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/sessions/''${NAX_PROFILE:-default}/$(basename "$PWD")"
        mkdir -p "$SESSION_DIR"
        SESSION_FILE="$SESSION_DIR/$(date -u +%Y-%m-%dT%H-%M-%S).json"
        SESSION_ID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$$")"
        SKILL_VERSIONS="$(cat "''${NAX_SKILL_VERSIONS:-/dev/null}" 2>/dev/null || echo '{}')"
        jq -n \
          --arg id "$SESSION_ID" \
          --arg profile "''${NAX_PROFILE:-default}" \
          --arg project "$PWD" \
          --arg ts "$(date -u +%FT%TZ)" \
          --argjson skillVersions "$SKILL_VERSIONS" \
          '{
            version: 1,
            sessionId: $id,
            profile: $profile,
            project: $project,
            startedAt: $ts,
            endedAt: null,
            branch: null,
            lastCommit: null,
            durationSec: null,
            tokenUsage: null,
            skillVersions: $skillVersions,
            accomplished: [],
            incomplete: [],
            events: []
          }' > "$SESSION_FILE"
        _NAX_STATE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/state/''${NAX_WRAPPER_PID:-$$}"
        mkdir -p "$_NAX_STATE_DIR"
        echo "$SESSION_FILE" > "$_NAX_STATE_DIR/current-session"
        echo "$SESSION_ID" > "$_NAX_STATE_DIR/session-id"
      '';
    }
    {
      event = "session-end";
      package = pkgs.jq;
      command = ''
        SESSION_FILE="$(cat "''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/state/''${NAX_WRAPPER_PID:-$$}/current-session" 2>/dev/null)"
        if [ -z "$SESSION_FILE" ] || [ ! -f "$SESSION_FILE" ]; then exit 0; fi
        BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
        COMMIT="$(git rev-parse --short HEAD 2>/dev/null)"
        STARTED="$(jq -r .startedAt "$SESSION_FILE")"
        START_EPOCH="$(date -d "$STARTED" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$STARTED" +%s 2>/dev/null || echo 0)"
        DURATION="$(( $(date +%s) - START_EPOCH ))"
        jq \
          --arg end "$(date -u +%FT%TZ)" \
          --arg branch "$BRANCH" \
          --arg commit "$COMMIT" \
          --argjson dur "$DURATION" \
          '.endedAt = $end | .branch = $branch | .lastCommit = $commit | .durationSec = $dur' \
          "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"
        rm -rf "''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/state/''${NAX_WRAPPER_PID:-$$}"
      '';
    }
  ];
}
