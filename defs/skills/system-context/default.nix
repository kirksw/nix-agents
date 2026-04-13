{
  skills.system-context = {
    description = "Local system and nix-agents setup context for this operator. Use when deciding whether a change should happen declaratively in Nix, locating the source of truth for agent/tool configuration, understanding where generated configs and session data live, or reasoning about personal/work bases and profiles on this machine.";
    src = ./.;
    version = "1.0.0";
  };
}
