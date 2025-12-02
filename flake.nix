{
  description = "Even more minimal devShell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

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
        pkgsDevshell = pkgs.pkgsMusl;

        # Doesn't handle anything fancy, just enough to cover its use in setting up the devShell
        mkdir-minimal =
          let
            src = pkgsDevshell.writeTextFile {
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
          pkgsDevshell.stdenv.mkDerivation {
            name = "mkdir";
            dontUnpack = true;
            buildPhase = ''
              ${pkgsDevshell.stdenv.cc.targetPrefix}cc ${src} -o mkdir
            '';
            installPhase = ''
              install -m755 -D -t $out/bin mkdir
            '';
          };

        # Doesn't handle anything fancy, just enough to cover its use in setting up the devShell
        cat-minimal =
          let
            src = pkgsDevshell.writeTextFile {
              name = "cat.c";
              text = ''
                #include <stdio.h>
                int main(int argc, char* argv[]) {
                  FILE *fptr;
                  fptr = fopen(argv[1], "r");
                  char s[1024];
                  while(fgets(s, 1024, fptr)) {
                    printf("%s", s);
                  }
                  fclose(fptr);
                }
              '';
            };
          in
          pkgsDevshell.stdenv.mkDerivation {
            name = "cat";
            dontUnpack = true;
            buildPhase = ''
              ${pkgsDevshell.stdenv.cc.targetPrefix}cc ${src} -o cat
            '';
            installPhase = ''
              install -m755 -D -t $out/bin cat
            '';
          };

        # Just an experiment
        # https://fzakaria.com/2021/08/02/a-minimal-nix-shell.html
        # https://discourse.nixos.org/t/smaller-stdenv-for-shells/28970
        stdenv-minimal = pkgsDevshell.stdenvNoCC.override {
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
          shell = "${pkgsDevshell.bash}/bin/bash";
          extraNativeBuildInputs = [ ];
        };

        mkShell-minimal = pkgsDevshell.mkShell.override {
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

        make-graph =
          let
            configFile = pkgsDevshell.writeTextFile {
              name = "nix-visualize.ini";
              text = ''
                [minimal]
                aspect_ratio = 1.0
                dpi = 300
                font_scale = 1.5
                edge_alpha = 0.8
                attractive_force_normalization = 1.5
              '';
            };
          in
          pkgs.writeShellApplication {
            name = "make-graph";
            text = ''
              # shellcheck disable=SC2016
              ${lib.getExe pkgs.nix-visualize} "$(nix develop --command bash -c 'echo $NIX_GCROOT')" --output minimal.svg --configfile ${configFile}
              ${lib.getExe pkgs.imagemagick} minimal.svg minimal.png
            '';
          };
      in
      {
        devShells.default = devshell;

        packages.default = make-graph;

        formatter = pkgs.nixfmt-tree;
      }
    );
}
