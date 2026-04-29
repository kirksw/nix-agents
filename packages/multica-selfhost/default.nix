{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  writeShellApplication,
  coreutils,
  curl,
  docker,
  docker-compose,
  gnused,
  openssl,
  multica,
}:

let
  version = "0.2.15";

  src = fetchFromGitHub {
    owner = "multica-ai";
    repo = "multica";
    rev = "v${version}";
    hash = "sha256-zeGE71M1T9LB2CawTw0UW/java2dw45t740OezhAYhI=";
  };

  assets = stdenvNoCC.mkDerivation {
    pname = "multica-selfhost-assets";
    inherit version src;

    installPhase = ''
      runHook preInstall

      install -Dm644 docker-compose.selfhost.yml "$out/share/multica/selfhost/docker-compose.selfhost.yml"
      install -Dm644 docker-compose.selfhost.build.yml "$out/share/multica/selfhost/docker-compose.selfhost.build.yml"
      install -Dm644 .env.example "$out/share/multica/selfhost/env.example"
      install -Dm644 SELF_HOSTING.md "$out/share/doc/multica/SELF_HOSTING.md"
      install -Dm644 SELF_HOSTING_ADVANCED.md "$out/share/doc/multica/SELF_HOSTING_ADVANCED.md"

      runHook postInstall
    '';
  };
in
writeShellApplication {
  name = "multica-selfhost";

  runtimeInputs = [
    coreutils
    curl
    docker
    docker-compose
    gnused
    openssl
    multica
  ];

  text = ''
    set -euo pipefail

    asset_dir="${assets}/share/multica/selfhost"
    home_dir="''${HOME:?HOME must be set}"
    install_dir="''${MULTICA_INSTALL_DIR:-''${MULTICA_SELFHOST_DIR:-$home_dir/.multica/server}}"
    env_file="$install_dir/.env"
    compose_file="$asset_dir/docker-compose.selfhost.yml"

    info() {
      printf '==> %s\n' "$*"
    }

    ok() {
      printf 'ok: %s\n' "$*"
    }

    warn() {
      printf 'warning: %s\n' "$*" >&2
    }

    fail() {
      printf 'error: %s\n' "$*" >&2
      exit 1
    }

    usage() {
      cat <<USAGE
    Usage: multica-selfhost [start|stop|restart|status|logs|setup-cli|doctor]

    Commands:
      start      Create state under ~/.multica/server and start Docker Compose
      stop       Stop Docker Compose services
      restart    Restart Docker Compose services
      status     Show Docker Compose service status and daemon status
      logs       Show Docker Compose logs; pass service names after --
      setup-cli  Run 'multica setup self-host' with the packaged CLI
      doctor     Check Docker availability and backend health

    Environment:
      MULTICA_INSTALL_DIR    Override the mutable server state directory
      MULTICA_SELFHOST_DIR   Alias for MULTICA_INSTALL_DIR
      MULTICA_IMAGE_TAG      Image tag consumed by .env / Docker Compose
    USAGE
    }

    compose() {
      if docker compose version >/dev/null 2>&1; then
        docker compose --env-file "$env_file" --project-directory "$install_dir" -f "$compose_file" "$@"
      elif docker-compose version >/dev/null 2>&1; then
        docker-compose --env-file "$env_file" --project-directory "$install_dir" -f "$compose_file" "$@"
      else
        fail "Docker Compose is not available. Install Docker Compose v2 or docker-compose."
      fi
    }

    ensure_env() {
      mkdir -p "$install_dir"

      if [ ! -f "$env_file" ]; then
        info "Creating $env_file from Multica v${version} defaults"
        cp "$asset_dir/env.example" "$env_file"
        jwt="$(openssl rand -hex 32)"
        sed -i "s/^JWT_SECRET=.*/JWT_SECRET=$jwt/" "$env_file"
        ok "generated random JWT_SECRET"
      else
        ok "using existing $env_file"
      fi
    }

    env_value() {
      key="$1"
      if [ -f "$env_file" ]; then
        sed -n "s/^$key=//p" "$env_file" | tail -n 1
      fi
    }

    health_url() {
      port="$(env_value PORT)"
      port="''${port:-8080}"
      printf 'http://localhost:%s/health' "$port"
    }

    check_docker() {
      command -v docker >/dev/null 2>&1 || fail "Docker is not installed or is not on PATH."
      docker info >/dev/null 2>&1 || fail "Docker is installed but not running."
      ok "Docker is available"
    }

    wait_for_backend() {
      url="''${MULTICA_SELFHOST_HEALTH_URL:-$(health_url)}"
      info "Waiting for backend at $url"

      ready=false
      for _ in $(seq 1 45); do
        if curl -sf "$url" >/dev/null 2>&1; then
          ready=true
          break
        fi
        sleep 2
      done

      if [ "$ready" = true ]; then
        ok "Multica backend is healthy"
      else
        warn "backend is still starting; inspect logs with: multica-selfhost logs backend"
      fi
    }

    start_server() {
      check_docker
      ensure_env
      info "Pulling official Multica self-host images"
      compose pull
      info "Starting Multica services"
      compose up -d
      wait_for_backend

      frontend_port="$(env_value FRONTEND_PORT)"
      frontend_port="''${frontend_port:-3000}"
      backend_port="$(env_value PORT)"
      backend_port="''${backend_port:-8080}"

      printf '\nFrontend: http://localhost:%s\n' "$frontend_port"
      printf 'Backend:  http://localhost:%s\n' "$backend_port"
      printf 'State:    %s\n\n' "$install_dir"
      printf 'Next:     multica-selfhost setup-cli\n'
    }

    stop_server() {
      ensure_env
      compose down
      if multica daemon stop >/dev/null 2>&1; then
        ok "Multica daemon stopped"
      fi
    }

    command="''${1:-start}"
    case "$command" in
      start)
        start_server
        ;;
      stop)
        stop_server
        ;;
      restart)
        stop_server
        start_server
        ;;
      status)
        ensure_env
        compose ps
        multica daemon status || true
        ;;
      logs)
        shift
        ensure_env
        compose logs "$@"
        ;;
      setup-cli)
        shift
        multica setup self-host "$@"
        ;;
      doctor)
        check_docker
        ensure_env
        if curl -sf "$(health_url)" >/dev/null 2>&1; then
          ok "backend health check passed"
        else
          warn "backend health check failed"
        fi
        ;;
      --help|-h|help)
        usage
        ;;
      *)
        usage
        fail "unknown command: $command"
        ;;
    esac
  '';

  passthru = {
    inherit assets version;
  };

  meta = {
    description = "Stateful helper for running the Multica self-host server with Docker Compose";
    homepage = "https://github.com/multica-ai/multica";
    license = lib.licenses.asl20;
    mainProgram = "multica-selfhost";
    platforms = lib.platforms.unix;
  };
}
