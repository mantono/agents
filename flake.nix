{
  description = "Development environment with Claude Code, GitHub CLI, and GitHub Copilot";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true; # Needed for some packages
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            claude-code           # Claude code
            gh                    # GitHub CLI
            github-copilot-cli    # GitHub Copilot CLI
            # Note: claude-cli may not be in nixpkgs yet
            # You may need to add it manually or use a different method
          ];

          shellHook = ''
            echo "Development environment loaded!"
            echo "Available tools:"
            echo "  - gh (GitHub CLI): $(gh --version 2>/dev/null | head -n1)"
            echo "  - github-copilot: $(github-copilot --version 2>/dev/null || echo 'installed')"
          '';
        };
      }
    );
}
