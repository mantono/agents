let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/archive/1128e89fd5e11bb25aedbfc287733c6502202ea9.tar.gz";
  pkgs = import nixpkgs { config = {}; overlays = []; };
in

pkgs.mkShellNoCC {
  packages = with pkgs; [
    unstable.claude-code
    unstable.gh
    unstable.github-copilot-cli
  ];
}
