{
  pkgs,
  lib,
  ...
}:
pkgs.python3Packages.buildPythonApplication {
  pname = "swe-pruner-mcp";
  version = "0.1.0";
  format = "pyproject";

  src = ./.;

  build-system = with pkgs.python3Packages; [
    hatchling
  ];

  dependencies = with pkgs.python3Packages; [
    mcp
    torch
    transformers
    huggingface-hub
    pydantic
  ];

  nativeBuildInputs = [ pkgs.makeWrapper ];
  propagatedBuildInputs = [ pkgs.ripgrep ];

  pythonImportsCheck = [ "swe_pruner_mcp.server" ];

  postFixup = ''
    wrapProgram "$out/bin/swe-pruner-mcp" \
      --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.ripgrep ]}"
  '';

  meta = {
    description = "MCP server for SWE-Pruner context-aware code pruning";
    mainProgram = "swe-pruner-mcp";
  };
}
