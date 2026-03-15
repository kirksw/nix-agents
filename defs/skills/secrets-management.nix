{
  skills.secrets-management = {
    description = "Manage secrets in nix-agents and SOPS-encrypted nixfiles repos. Use when adding, editing, or referencing secrets in configuration or wiring credential providers.";
    content = ''
      # Secrets Management

      ## nix-agents Provider System

      nix-agents has a built-in credential provider system that resolves secrets at
      wrapper runtime without storing them in the Nix store. Define providers in your
      module and reference them from profiles.

      ### Provider Definition

      ```nix
      # In your flake module or preset
      providers.anthropic-key = {
        credentialSource = "env";          # env | protonpass | apple-keychain | sops
        credentialRef = "ANTHROPIC_API_KEY_WORK";  # env var to read from
        envVar = "ANTHROPIC_API_KEY";      # env var the tool expects
      };
      ```

      ### Credential Sources

      | Source          | credentialRef format           | Example                          |
      |-----------------|-------------------------------|----------------------------------|
      | `env`           | env var name to copy from      | `"ANTHROPIC_KEY_PROD"`           |
      | `protonpass`    | item name in vault             | `"Anthropic/work-api-key"`       |
      | `apple-keychain`| keychain service name          | `"anthropic-api-work"`           |
      | `sops`          | `"file:key"` (sops path:attr)  | `"secrets/api.yaml:anthropic"`   |

      ### Wiring a Provider to a Profile

      ```nix
      profiles.work = {
        pathPrefixes = [ "~/work/" ];
        providers = [ "anthropic-key" ];  # resolved at runtime for this profile
        # …other profile fields
      };
      ```

      Credential resolution runs before the tool launches and never writes values
      to the Nix store. Failures are silent — the tool launches with whatever env
      vars are already set if a backend is unavailable.

      ## SOPS-Nix (for nixfiles-style repos)

      ### Adding New Secrets

      1. Add secret definition to the appropriate module:
      ```nix
      sops.secrets = {
        "path/to/secret" = {
          sopsFile = "''${self}/secrets/<category>/<name>.yaml";
          key = "secret-key";
          mode = "0400";
        };
      };
      ```

      2. Reference in configuration:
      ```nix
      environmentFile = config.sops.secrets."path/to/secret".path;
      ```

      ### Editing Secrets

      ```bash
      sops secrets/<category>/<name>.yaml
      ```

      ### Secret File Structure

      Place secrets in `secrets/`:
      - `secrets/api/*.yaml` — API keys
      - `secrets/git/*.yaml` — Git credentials
      - `secrets/aws/*.yaml` — AWS credentials

      ### Validation

      When adding new secret files, verify `.sops.yaml` rules ensure the file is
      encrypted for the correct recipients.

      ## Rules

      - NEVER commit plaintext secrets
      - NEVER store secrets in Nix expressions or the store (use provider system)
      - Always use `sops` for editing SOPS-managed files
      - Set appropriate file modes (0400 for secrets)
    '';
    version = "1.0.0";
    resources = { };
    src = null;
  };
}
