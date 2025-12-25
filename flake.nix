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
          runtimeInputs = [ prev.deno ];
          text = ''
            export DENO_NO_UPDATE_CHECK=1
            exec deno run -A \
              --unstable-kv \
              --config=${self}/deno.json \
              --frozen --lock=${self}/deno.lock \
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
