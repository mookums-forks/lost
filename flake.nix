{
  description = "Open-source Star Tracker";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    zig.url = "github:mitchellh/zig-overlay";
    zls.url = "github:zigtools/zls/0.13.0";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    let
      overlays = [
        (final: prev: rec {
          zigpkgs = inputs.zig.packages.${prev.system};
          zig = zigpkgs."0.13.0";
          zls = inputs.zls.packages.${prev.system}.zls.overrideAttrs
            (old: { nativeBuildInputs = [ zig ]; });
          lost = prev.callPackage ./nix/package.nix { };
        })
      ];

      systems = builtins.attrNames inputs.zig.packages;
    in flake-utils.lib.eachSystem systems (system:
      let pkgs = import nixpkgs { inherit overlays system; };
      in {
        packages.default = pkgs.lost;
        packages.lost = pkgs.lost;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            gcc
            clang-tools
            zig
            zls
            gnumake
            pkg-config
            bear
            gdb
            valgrind
            man
            groff
            imagemagick
            cpplint
            doxygen
            graphviz
            unixtools.xxd
            eigen
            cairo
          ];

          shellHook = ''
            # Won't find libasan without this.
            export ZIG_LIBASAN_PATH="${pkgs.gcc.cc.lib}/lib"
          '';
        };

        devShell = self.devShells.${system}.default;
      });
}
