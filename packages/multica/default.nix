{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "0.2.15";

  sources = {
    x86_64-darwin = {
      platform = "darwin-amd64";
      hash = "sha256-r+oTiLyLNpfv3cqPU4gOmUCBLqY5GP2f9rGnjW1oaxI=";
    };
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-Jmd7yPqesP80/mzzm6lxEBD5NdizHmHay75joTuPTxg=";
    };
    x86_64-linux = {
      platform = "linux-amd64";
      hash = "sha256-sYkhi78Mj/fezh2V8J3j2gYeMs4sWg21xCAFug8l8J0=";
    };
    aarch64-linux = {
      platform = "linux-arm64";
      hash = "sha256-c8NXbVCmII2DvJcObhTtszn+C4Qyk3+Tt3N0vOZp9bM=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "multica is not supported on ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "multica";
  inherit version;

  src = fetchurl {
    url = "https://github.com/multica-ai/multica/releases/download/v${version}/multica-cli-${version}-${source.platform}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 multica "$out/bin/multica"
    install -Dm644 LICENSE "$out/share/licenses/multica/LICENSE"
    install -Dm644 README.md "$out/share/doc/multica/README.md"
    install -Dm644 README.zh-CN.md "$out/share/doc/multica/README.zh-CN.md"

    runHook postInstall
  '';

  installCheckPhase = ''
    runHook preInstallCheck

    "$out/bin/multica" version

    runHook postInstallCheck
  '';
  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  meta = {
    description = "Open-source managed agents platform CLI";
    homepage = "https://github.com/multica-ai/multica";
    license = lib.licenses.asl20;
    mainProgram = "multica";
    platforms = builtins.attrNames sources;
  };
}
