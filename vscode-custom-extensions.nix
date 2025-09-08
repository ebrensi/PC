{
  lib,
  callPackage,
  vscode-utils,
  ...
}: let
  base-configs = {
    ahmadawais.shades-of-purple = vscode-utils.buildVscodeMarketplaceExtension {
      mktplcRef = {
        name = "shades-of-purple";
        publisher = "ahmadawais";
        version = "7.3.2";
        sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };

      meta = {
        description = "A professional theme suite with hand-picked & bold shades of purple for your VS Code editor and terminal apps";
        downloadPage = "https://marketplace.visualstudio.com/items?itemName=ahmadawais.shades-of-purple";
        homepage = "https://github.com/ahmadawais/shades-of-purple-vscode";
        license = licenses.mit;
        maintainers = [];
        platforms = platforms.all;
      };
    };

    ktnrg45.vscode-cython = vscode-utils.buildVscodeMarketplaceExtension {
      mktplcRef = {
        name = "vscode-cython";
        publisher = "ktnrg45";
        version = "	1.0.3";
        sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };

      meta = with lib; {
        description = "Cython syntax checker + highlighter, Go to Definitions, type analysis, and more.";
        downloadPage = "https://marketplace.visualstudio.com/items?itemName=ktnrg45.vscode-cython";
        homepage = "https://github.com/ktnrg45/vs-code-cython";
        license = licenses.mit;
        maintainers = [];
        platforms = platforms.all;
      };
    };

    liviuschera.noctis = vscode-utils.buildVscodeMarketplaceExtension {
      mktplcRef = {
        name = "noctis";
        publisher = "liviuschera";
        version = "10.43.3";
        sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };

      meta = with lib; {
        description = "Noctis is a collection of light & dark themes with a well balanced blend of warm and cold colors.";
        downloadPage = "https://marketplace.visualstudio.com/items?itemName=liviuschera.noctis";
        homepage = "https://github.com/liviuschera/noctis";
        license = licenses.mit;
        maintainers = [];
        platforms = platforms.all;
      };
    };
  };
in
  lib.mapAttrs (_: extDef: callPackage extDef {}) base-configs
