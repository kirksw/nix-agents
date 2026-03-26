_: {
  skills.session-resume = {
    description = "Read the latest session file for the current project at session start. Triggers when: starting a new conversation, or the user says 'resume', 'continue', or 'pick up where we left off'. Do not trigger mid-session.";
    content = ''
      At the start of a new session, check for a session file for the current project:

      ```bash
      ls -t ~/.local/share/nix-agents/sessions/*/$(basename $PWD)/*.json 2>/dev/null | head -1 | xargs cat 2>/dev/null
      ```

      Use the session file to:
      - Understand what was accomplished previously
      - Continue incomplete work
      - Verify the current branch matches expectations

      If no session file exists, proceed normally — do not error or warn.
    '';
    resources = { };
    src = null;
  };
}
