{
  description = "Probitas CLI - Command-line interface for Probitas";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        probitas = pkgs.writeShellApplication {
          name = "probitas";
          runtimeInputs = [ pkgs.deno ];
          text = ''
            export DENO_NO_UPDATE_CHECK=1
            exec deno run -A \
              --unstable-kv \
              --config=${self}/deno.json \
              --frozen --lock=${self}/deno.lock \
              ${self}/mod.ts "$@"
          '';
        };
      in
      {
        packages = {
          inherit probitas;
          default = probitas;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = probitas;
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
