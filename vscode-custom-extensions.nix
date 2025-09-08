# Some vscode extensions not available in nixpkgs.vscode-extensions.
# TODO: Contribute these to nixpkgs. https://github.com/nix-community/nix-vscode-extensions?tab=readme-ov-file#contribute
{
  lib,
  callPackage,
  vscode-utils,
  ...
}: let
  mkConfig = vscode-utils.buildVscodeMarketplaceExtension;
in {
  ahmadawais.shades-of-purple = mkConfig {
    mktplcRef = {
      name = "shades-of-purple";
      publisher = "ahmadawais";
      version = "7.3.2";
      hash = "sha256-m3S54YzkgAFgeKuhz+39FvkdejpLwMPaxsLCd17iBYM=";
    };
    meta = {
      description = "A professional vscode theme suite with hand-picked & bold shades of purple for your VS Code editor and terminal apps";
      downloadPage = "https://marketplace.visualstudio.com/items?itemName=ahmadawais.shades-of-purple";
      homepage = "https://github.com/ahmadawais/shades-of-purple-vscode";
      changelog = "https://github.com/ahmadawais/shades-of-purple-vscode/blob/master/changelog.md";
      license = lib.licenses.mit;
      maintainers = [];
      platforms = lib.platforms.all;
    };
  };

  ktnrg45.vscode-cython = mkConfig {
    mktplcRef = {
      name = "vscode-cython";
      publisher = "ktnrg45";
      version = "1.0.3";
      hash = "sha256-aK1OFwRc5skLokuEFiZkGVgqaI22PTXGF1E16cx0EDQ=";
    };
    meta = {
      description = "vscode Cython syntax checker + highlighter, Go to Definitions, type analysis, and more.";
      downloadPage = "https://marketplace.visualstudio.com/items?itemName=ktnrg45.vscode-cython";
      homepage = "https://github.com/ktnrg45/vs-code-cython";
      changelog = "https://github.com/ktnrg45/vs-code-cython/blob/master/CHANGELOG.md";
      license = lib.licenses.mit;
      maintainers = [];
      platforms = lib.platforms.all;
    };
  };

  liviuschera.noctis = mkConfig {
    mktplcRef = {
      name = "noctis";
      publisher = "liviuschera";
      version = "10.43.3";
      hash = "sha256-RMYeW1J3VNiqYGj+2+WzC5X4Al9k5YWmwOyedFnOc1I=";
    };
    meta = {
      description = "Noctis is a collection of vscode light & dark themes with a well balanced blend of warm and cold colors.";
      downloadPage = "https://marketplace.visualstudio.com/items?itemName=liviuschera.noctis";
      homepage = "https://github.com/liviuschera/noctis";
      changelog = "https://github.com/liviuschera/noctis/blob/master/CHANGELOG.md";
      license = lib.licenses.mit;
      maintainers = [];
      platforms = lib.platforms.all;
    };
  };

  wesbos.theme-cobalt2 = mkConfig {
    mktplcRef = {
      name = "theme-cobalt2";
      publisher = "wesbos";
      version = "2.5.0";
      hash = "sha256-niIsC1J1pX93GwM6Fff/spk/p8qvBVDRxR7EO/tfcHc=";
    };
    meta = {
      description = "Official Cobalt2 Theme for VS Code by Wes Bos";
      downloadPage = "https://marketplace.visualstudio.com/items?itemName=wesbos.theme-cobalt2";
      homepage = "https://github.com/wesbos/cobalt2-vscode";
      changelog = "https://github.com/wesbos/cobalt2-vscode/tags";
      license = lib.licenses.mit;
      maintainers = [];
      platforms = lib.platforms.all;
    };
  };
}
