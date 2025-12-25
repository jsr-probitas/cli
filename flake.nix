{
  description = "Probitas CLI - Command-line interface for Probitas";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Overlay that adds probitas to pkgs
      overlay = final: prev: {
        probitas = prev.writeShellApplication {
          name = "probitas";
          runtimeInputs = [ prev.deno prev.coreutils ];
          text = ''
            export DENO_NO_UPDATE_CHECK=1

            # Copy lock file to writable location to avoid /nix/store read-only errors
            TEMP_LOCK=$(mktemp)
            cp ${self}/deno.lock "$TEMP_LOCK"
            trap 'rm -f "$TEMP_LOCK"' EXIT

            exec deno run -A \
              --unstable-kv \
              --config=${self}/deno.json \
              --lock="$TEMP_LOCK" \
              ${self}/mod.ts "$@"
          '';
        };
      };
    in
    {
      # Overlay for easy integration
      overlays.default = overlay;
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          inherit (pkgs) probitas;
          default = pkgs.probitas;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = pkgs.probitas;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            deno
          ];

          shellHook = ''
            echo "Entering Probitas CLI development environment"
          '';
        };
      }
    );
}
