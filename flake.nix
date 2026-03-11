{
  description = "Home Assistant Add-on Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Container tools
            podman
            podman-compose
            
            # Home Assistant development tools
            hadolint  # Dockerfile linter
            curl      # For testing endpoints
            jq        # JSON processing
            
            # Build and validation tools
            git
            bash
            
            # Optional: useful for debugging
            yq-go     # YAML processing
          ];

          shellHook = ''
            echo "🏠 Home Assistant Add-on Development Environment"
            echo "Available commands:"
            echo "  build-addon     - Build the Claude Terminal add-on"
            echo "  run-addon       - Run the add-on locally"  
            echo "  validate-addon  - Validate add-on structure"
            echo "  lint-dockerfile - Lint the Dockerfile"
            echo "  test-endpoint   - Test add-on web endpoint"
            echo ""
            echo "To get started: build-addon"
            
            # Create convenience aliases
            alias build-addon='podman build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.21 -t local/claude-terminal ./claude-terminal'
            alias run-addon='podman run -p 7681:7681 -v $(pwd)/config:/config local/claude-terminal'
            alias validate-addon='echo "Note: Home Assistant builder validation requires HA OS environment"'
            alias lint-dockerfile='hadolint ./claude-terminal/Dockerfile'
            alias test-endpoint='curl -X GET http://localhost:7681/ || echo "Add-on not running. Use: run-addon"'
          '';
        };
      });
}