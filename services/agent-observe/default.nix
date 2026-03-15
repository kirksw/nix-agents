{
  pkgs,
  lib,
  ...
}:
pkgs.buildNpmPackage {
  pname = "agent-observe";
  version = "0.1.0";

  src = ./.;

  npmDepsHash = "sha256-S9hnr5bzJKdiFmgBWcohJFlpj74vbnBJl6r1v5HI5M4=";

  # Node 22 is required for the built-in node:sqlite module (--experimental-sqlite).
  # Do not downgrade to an earlier Node release.
  nativeBuildInputs = [ pkgs.nodejs_22 ];

  buildPhase = ''
    runHook preBuild
    npm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/agent-observe $out/bin
    cp -r dist $out/lib/agent-observe/
    cp package.json $out/lib/agent-observe/
    # Use makeWrapper / printf to avoid heredoc indentation corrupting the shebang.
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      "exec ${pkgs.nodejs_22}/bin/node --experimental-sqlite $out/lib/agent-observe/dist/main.js \"\$@\"" \
      > $out/bin/agent-observe
    chmod +x $out/bin/agent-observe
    runHook postInstall
  '';

  meta = {
    description = "Session observability service for nix-agents";
    mainProgram = "agent-observe";
  };
}
