{
  description = "Even more minimal devShell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      # Boilerplate to make the rest of the flake more readable
      # Do not inject system into these attributes
      flatAttrs = [
        "overlays"
        "nixosModules"
      ];
      # Inject a system attribute if the attribute is not one of the above
      injectSystem =
        system:
        lib.mapAttrs (name: value: if builtins.elem name flatAttrs then value else { ${system} = value; });
      # Combine the above for a list of 'systems'
      forSystems =
        systems: f:
        lib.attrsets.foldlAttrs (
          acc: system: value:
          lib.attrsets.recursiveUpdate acc (injectSystem system value)
        ) { } (lib.genAttrs systems f);
    in
    forSystems [ "x86_64-linux" "aarch64-linux" ] (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        mkdir-minimal =
          let
            src = pkgs.writeTextFile {
              name = "mkdir.c";
              text = ''
                #include <sys/stat.h>
                int main(int argc, char* argv[]) {
                  if (argc != 2) return 1;
                  return mkdir(argv[1], 0755);
                }
              '';
            };
          in
          pkgs.stdenv.mkDerivation {
            name = "mkdir";
            dontUnpack = true;
            buildPhase = ''
              ${pkgs.stdenv.cc.targetPrefix}cc ${src} -o mkdir
            '';
            installPhase = ''
              install -m755 -D -t $out/bin mkdir
            '';
          };

        cat-minimal = pkgs.writeShellApplication {
          name = "cat";
          text = ''
            echo "$(<"''${1}" )"
          '';
        };

        # Just an experiment
        # https://fzakaria.com/2021/08/02/a-minimal-nix-shell.html
        stdenv-minimal = pkgs.stdenvNoCC.override {
          cc = null;
          preHook = "";
          allowedRequisites = null;
          # We can replace coreutils with only the two commands we need
          # TODO: In some situations we may need printf as well
          # initialPath = pkgs.lib.filter (
          #   a: pkgs.lib.hasPrefix "coreutils" a.name
          # ) pkgs.stdenvNoCC.initialPath;
          initialPath = [
            mkdir-minimal
            cat-minimal
          ];
          extraNativeBuildInputs = [ ];
        };

        mkShell-minimal = pkgs.mkShell.override {
          stdenv = stdenv-minimal;
        };

        devshell = mkShell-minimal {
          name = "minimal";
          packages = [ ];
          # Remove these dirty hacks from the user path now that the setup has happened
          shellHook = ''
            export PATH="$(echo "$PATH" | sed -e 's|${lib.getBin mkdir-minimal}/bin:||')"
            export PATH="$(echo "$PATH" | sed -e 's|${lib.getBin cat-minimal}/bin:||')"
          '';
        };

      in
      {
        devShells.default = devshell;

        formatter = pkgs.nixfmt-tree;
      }
    );
}
