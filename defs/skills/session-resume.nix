_: {
  skills.session-resume = {
    description = "Resume where you left off by reading the latest session file";
    content = ''
      At the start of a new session, check for a session file in
      `''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/sessions/*/$(basename $PWD)/`
      and read the most recent one. Use it to:
      - Understand what was accomplished previously
      - Continue incomplete work
      - Check the current branch matches expectations
      Use Bash to read the file: `ls -t ~/.local/share/nix-agents/sessions/*/$(basename $PWD)/*.json 2>/dev/null | head -1 | xargs cat 2>/dev/null`
    '';
  };
}
