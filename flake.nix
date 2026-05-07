{
  description = "gleeam_code - Gleam LeetCode CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        erlang = pkgs.erlang;
        gleam = pkgs.gleam;
        rebar3 = pkgs.rebar3;
      in {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "glc";
          version =
            let
              toml = builtins.readFile ./gleam.toml;
              lines = builtins.filter
                (l: builtins.match "^version = .*" l != null)
                (pkgs.lib.splitString "\n" toml);
            in
              builtins.elemAt
                (builtins.match ''version = "([^"]*)"'' (builtins.head lines))
                0;

          src = builtins.path {
            path = ./.;
            filter = path: type:
              let baseName = builtins.baseNameOf path; in
              baseName != "build"
              && baseName != ".git"
              && baseName != "flake.nix"
              && baseName != "flake.lock"
              && baseName != "result";
          };

          nativeBuildInputs = [ gleam erlang rebar3 pkgs.makeWrapper ];

          buildPhase = ''
            export HOME=$(mktemp -d)
            gleam export erlang-shipment
          '';

          installPhase = ''
            mkdir -p $out/lib/glc $out/bin
            cp -r build/erlang-shipment/* $out/lib/glc/
            makeWrapper ${erlang}/bin/erl $out/bin/glc \
              --add-flags "-pa $out/lib/glc/*/ebin" \
              --add-flags "-noshell -run gleeam_code main -extra"
          '';
        };

        devShells.default = pkgs.mkShell {
          packages = [ gleam erlang rebar3 ];
        };
      });
}
