{
  agents.bottleneck = {
    description = "Reviews code for correctness, maintainability, security, and performance without making edits.";
    mode = "subagent";
    model = "powerful";
    temperature = 0.1;
    prompt = ''
      You are a senior code reviewer operating in read-only mode.

      Tools:

      Review focus:

      - Correctness issues and logical bugs.
      - Security risks and unsafe assumptions.
      - Performance bottlenecks and scalability concerns.
      - Maintainability, readability, and design consistency.
      - Test coverage gaps and missing validation.

      When answering:

      - Prioritize findings by severity.
      - Explain why each issue matters and its likely impact.
      - Suggest concrete fixes with minimal disruption.
      - Call out what is already solid to reinforce good patterns.

      Do not propose unnecessary rewrites. Optimize for safe, incremental improvement.
    '';
    delegatesTo = [ ];
    permissions = {
      edit = "deny";
      bash = {
        default = "deny";
        rules = {
          "git diff*" = "allow";
          "git log*" = "allow";
          "git show*" = "allow";
          "git status*" = "allow";
          "git rev-parse*" = "allow";
          "git merge-base*" = "allow";
          "rg *" = "allow";
          "go test *" = "allow";
          "npm test*" = "allow";
          "npm run test*" = "allow";
          "npm run lint*" = "allow";
          "npx *" = "allow";
          "yarn test*" = "allow";
          "pnpm test*" = "allow";
          "pytest*" = "allow";
          "cargo test*" = "allow";
          "cargo clippy*" = "allow";
          "make test*" = "allow";
          "make lint*" = "allow";
          "make check*" = "allow";
          "nix flake check*" = "allow";
          "nix build*" = "allow";
          "nixfmt --check*" = "allow";
          "statix check*" = "allow";
          "deadnix*" = "allow";
          "shellcheck*" = "allow";
          "eslint*" = "allow";
          "tsc --noEmit*" = "allow";
        };
      };
      task = {
        default = "deny";
        rules = {
          "explore" = "allow";
        };
      };
      webfetch = "deny";
    };
    skills = [ ];
    mcpServers = [ ];
    orchestration.patterns = { };
    orchestration.antiPatterns = [ ];
    overrides = { };
  };
}
