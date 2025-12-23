{
  description = "Probitas CLI - Command-line interface for Probitas";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      # Overlay for easy integration
      overlays.default = final: prev: {
        inherit (self.packages.${final.stdenv.hostPlatform.system}) probitas;
      };
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Map Nix platform to npm's os/cpu values (Node.js process.platform/process.arch)
        npmPlatform = {
          os =
            if pkgs.stdenv.hostPlatform.isDarwin then "darwin"
            else if pkgs.stdenv.hostPlatform.isLinux then "linux"
            else null;
          cpu =
            if pkgs.stdenv.hostPlatform.isAarch64 then "arm64"
            else if pkgs.stdenv.hostPlatform.isx86_64 then "x64"
            else null;
        };

        # Use `deno cache --vendor` for deterministic output instead of $DENO_DIR cache.
        # The cache approach (`deno install` alone) is non-deterministic due to:
        # - JSR cache metadata with timestamps (normalizing breaks cache lookup)
        # - SQLite databases with non-deterministic page ordering (deleting causes re-downloads)
        deps = pkgs.stdenvNoCC.mkDerivation {
          name = "probitas-deps";
          src = pkgs.lib.cleanSource ./.;
          nativeBuildInputs = with pkgs; [
            deno
            jq
            writableTmpDirAsHomeHook
          ];
          # Remove os/cpu fields from deno.lock for cross-platform deterministic hash
          postPatch = ''
            jq '
              if .npm then
                .npm |= map_values(del(.os, .cpu))
              else .
              end
            ' deno.lock > deno.lock.tmp
            mv deno.lock.tmp deno.lock
          '';
          installPhase = ''
            runHook preInstall

            mkdir -p $out
            # vendor dependencies for deterministic output
            deno cache --vendor --frozen mod.ts jsr:@probitas/probitas@^0

            cp -r vendor node_modules $out/

            runHook postInstall
          '';
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = "sha256-LjPnrXAGzrDyhPqLlKi01eG9RMRcnbQp4fiqmRMUaTQ=";
        };
      in
      {
        packages = {
          default = self.packages.${system}.probitas;
          probitas = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
            pname = "probitas";
            version = self.shortRev or self.dirtyShortRev or "dev";
            src = pkgs.lib.cleanSource ./.;

            postPatch = ''
              substituteInPlace deno.json \
                --replace-fail '"version": "0.0.0"' '"version": "${finalAttrs.version}"'
            '';

            nativeBuildInputs = with pkgs; [
              deno
              jq
              makeBinaryWrapper
            ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
              autoPatchelfHook
            ];

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/probitas
              cp -r src assets $out/share/probitas/
              cp mod.ts deno.json deno.lock $out/share/probitas/

              cp -r ${deps}/{vendor,node_modules} $out/share/probitas/
              # Make node_modules writable to allow removal of platform-specific packages
              chmod -R +w $out/share/probitas/node_modules

              # Remove npm packages with os/cpu constraints that don't match current platform
              # Uses deno.lock as the source of truth for platform-specific packages
              incompatiblePackages=$(jq -r --arg os "${npmPlatform.os}" --arg cpu "${npmPlatform.cpu}" '
                .npm // {} | to_entries[] |
                select(
                  (.value.os != null and (.value.os | index($os) | not)) or
                  (.value.cpu != null and (.value.cpu | index($cpu) | not))
                ) |
                .key | gsub("/"; "+")
              ' "deno.lock")

              for pkg in $incompatiblePackages; do
                rm -rf "$out/share/probitas/node_modules/.deno/$pkg"
              done

              # Clean up broken symlinks left after removing platform-specific packages
              find "$out/share/probitas/node_modules" -xtype l -delete

              makeWrapper ${pkgs.lib.getExe pkgs.deno} $out/bin/probitas \
                --set DENO_NO_UPDATE_CHECK 1 \
                --add-flags "run -A" \
                --add-flags "--unstable-kv" \
                --add-flags "--vendor" \
                --add-flags "--frozen" \
                --add-flags "--config=$out/share/probitas/deno.json" \
                --add-flags "--lock=$out/share/probitas/deno.lock" \
                --add-flags "$out/share/probitas/mod.ts"

              runHook postInstall
            '';

            doInstallCheck = true;
            nativeInstallCheckInputs = [ pkgs.versionCheckHook ];

            passthru = {
              inherit deps;
              updateDepsHash = pkgs.writeShellScriptBin "update-probitas-deps" ''
                set -euo pipefail
                cd "$(${pkgs.lib.getExe pkgs.git} rev-parse --show-toplevel)"

                fakehash="${pkgs.lib.fakeHash}"
                curhash=$(nix eval .#probitas.deps.outputHash --raw)

                # Replace current hash with fakeHash
                ${pkgs.gnused}/bin/sed -i "s|\"$curhash\"|\"$fakehash\"|" flake.nix

                # Build with fakeHash to get the correct hash from error output
                set +e
                newhash=$(
                  nix build .#probitas.deps --no-link --log-format internal-json 2>&1 >/dev/null \
                    | ${pkgs.gnugrep}/bin/grep "$fakehash" \
                    | ${pkgs.gnugrep}/bin/grep -oP 'sha256-[A-Za-z0-9+/=]+' \
                    | tail -1
                )
                set -e

                if [[ -n "$newhash" ]]; then
                  ${pkgs.gnused}/bin/sed -i "s|\"$fakehash\"|\"$newhash\"|" flake.nix
                  echo "Updated deps hash to: $newhash"
                else
                  ${pkgs.gnused}/bin/sed -i "s|\"$fakehash\"|\"$curhash\"|" flake.nix
                  echo "Failed to get hash, restored original"
                fi
              '';
            };

            meta.mainProgram = "probitas";
          });
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
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
