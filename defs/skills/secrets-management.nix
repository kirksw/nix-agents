{
  skills.secrets-management = {
    description = "Manage SOPS-encrypted secrets in nixfiles-v2. Use when adding, editing, or referencing secrets in configuration.";
    content = ''
      # Secrets Management

      This repository uses SOPS-Nix for secret management.

      ## Adding New Secrets

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

      ## Editing Secrets

      Use `sops` to edit encrypted files:
      ```bash
      sops secrets/<category>/<name>.yaml
      ```

      ## Secret File Structure

      Place secrets in `secrets/`:
      - `secrets/api/*.yaml` - API keys
      - `secrets/git/*.yaml` - Git credentials
      - `secrets/aws/*.yaml` - AWS credentials
      - etc.

      ## Validation

      When adding new secret files, validate `.sops.yaml` rules ensure the file is properly encrypted.

      ## Important Rules

      - NEVER commit plaintext secrets
      - Keep secrets under `secrets/` directory
      - Always use `sops` for editing
      - Set appropriate file modes (0400 for secrets)
    '';
    resources = { };
    src = null;
  };
}
