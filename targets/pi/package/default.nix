{
  lib,
  stdenv,
  fetchzip,
  makeWrapper,
  writeShellScript,
  curl,
  jq,
  nix,
  testers,
}:

let
  versions = lib.importJSON ./versions.json;

  archMap = {
    aarch64 = "arm64";
    x86_64 = "x64";
  };

  nixArch = stdenv.hostPlatform.parsed.cpu.name;
  os = if stdenv.hostPlatform.isDarwin then "darwin" else "linux";
  arch = archMap.${nixArch} or (throw "Unsupported architecture: ${nixArch}");

  supportedCombinations = versions.piCodingAgentVersions.urls or { };
  isSupported = supportedCombinations ? ${os} && supportedCombinations.${os} ? ${arch};
  versionInfo =
    if isSupported then
      versions.piCodingAgentVersions.urls.${os}.${arch}
    else
      throw "Unsupported platform: ${os}-${arch}";

  inherit (versionInfo) url hash;
  inherit (versions.piCodingAgentVersions) version;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "pi-coding-agent";
  inherit version;

  src = fetchzip {
    inherit url;
    sha256 = hash;
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/pi-coding-agent
    cp -r . $out/lib/pi-coding-agent/

    mkdir -p $out/bin
    makeWrapper $out/lib/pi-coding-agent/pi $out/bin/pi \
      --set-default PI_PACKAGE_DIR "$out/lib/pi-coding-agent"

    runHook postInstall
  '';

  passthru = {
    tests.version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "pi --version";
    };
    updateScript = writeShellScript "update-pi-coding-agent" ''
      set -euo pipefail

      SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
      VERSION_JSON="$SCRIPT_DIR/versions.json"

      RELEASE_INFO=$(${lib.getExe curl} -fsSL https://api.github.com/repos/badlogic/pi-mono/releases/latest)
      VERSION=$(echo "$RELEASE_INFO" | ${lib.getExe jq} -r '.tag_name' | sed 's/^v//')

      echo "Latest version: $VERSION"

      DARWIN_ARM64_URL="https://github.com/badlogic/pi-mono/releases/download/v$VERSION/pi-darwin-arm64.tar.gz"
      DARWIN_X64_URL="https://github.com/badlogic/pi-mono/releases/download/v$VERSION/pi-darwin-x64.tar.gz"
      LINUX_X64_URL="https://github.com/badlogic/pi-mono/releases/download/v$VERSION/pi-linux-x64.tar.gz"

      echo "Fetching hash for darwin-arm64..."
      DARWIN_ARM64_HASH=$(${lib.getExe nix} hash convert --hash-algo sha256 --to nix32 \
        $(nix-prefetch-url --unpack --type sha256 "$DARWIN_ARM64_URL" 2>&1 | tail -1))

      echo "Fetching hash for darwin-x64..."
      DARWIN_X64_HASH=$(${lib.getExe nix} hash convert --hash-algo sha256 --to nix32 \
        $(nix-prefetch-url --unpack --type sha256 "$DARWIN_X64_URL" 2>&1 | tail -1))

      echo "Fetching hash for linux-x64..."
      LINUX_X64_HASH=$(${lib.getExe nix} hash convert --hash-algo sha256 --to nix32 \
        $(nix-prefetch-url --unpack --type sha256 "$LINUX_X64_URL" 2>&1 | tail -1))

      ${lib.getExe jq} -n \
        --arg version "$VERSION" \
        --arg darwin_arm64_url "$DARWIN_ARM64_URL" \
        --arg darwin_arm64_hash "$DARWIN_ARM64_HASH" \
        --arg darwin_x64_url "$DARWIN_X64_URL" \
        --arg darwin_x64_hash "$DARWIN_X64_HASH" \
        --arg linux_x64_url "$LINUX_X64_URL" \
        --arg linux_x64_hash "$LINUX_X64_HASH" \
        '{
          piCodingAgentVersions: {
            version: $version,
            urls: {
              darwin: {
                arm64: {
                  url: $darwin_arm64_url,
                  hash: $darwin_arm64_hash
                },
                x64: {
                  url: $darwin_x64_url,
                  hash: $darwin_x64_hash
                }
              },
              linux: {
                x64: {
                  url: $linux_x64_url,
                  hash: $linux_x64_hash
                }
              }
            }
          }
        }' > "$VERSION_JSON"

      echo "Updated to version $VERSION"
    '';
  };

  meta = {
    description = "Pi - a minimal terminal coding agent harness";
    homepage = "https://pi.dev";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.kirksw ];
    mainProgram = "pi";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
