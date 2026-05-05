{pkgs, ...}: let
  user = "efrem";
  HOME = "/home/${user}";
  colorscheme = pkgs.writeText "embark-tc.micro" ''
    color-link default "#cbe3e7,#1e1c31"
    color-link statusline "#cbe3e7,#1e1c31"
    color-link tabbar "#8A889D,#1e1c31"
    color-link indent-char "#585273"
    color-link line-number "#585273"
    color-link current-line-number "#91ddff,#100E23"
    color-link gutter-error "#F02E6E"
    color-link gutter-warning "#F2B482"
    color-link color-column "#2F2A47"
    color-link diff-added "#2D5059"
    color-link diff-modified "#38325A"
    color-link diff-deleted "#5E3859"

    color-link message "#cbe3e7,#1e1c31"
    color-link error-message "#F02E6E,#100E23"
    color-link statusline.normal "#cbe3e7,#1e1c31"
    color-link tabbar.active "#cbe3e7,#3E3859"
    color-link tabbar.inactive "#8A889D,#1e1c31"

    color-link cursor "#1e1c31,#91ddff"
    # color-link cursor-line "#cbe3e7,#100E23"
    color-link cursor-line-number "#91ddff,#100E23,bold"

    color-link selection "#,#3E3859"
    color-link search "#100E23,#ffe6b3"
    color-link infow "#,#ffe6b3"

    color-link comment "#8A889D,italic"
    color-link identifier "#cbe3e7"
    color-link constant "#d4bfff"
    color-link constant.number "#F2B482"
    color-link constant.string "#ffe6b3"
    color-link constant.specialChar "#63f2f1"
    color-link constant.boolean "#F2B482"
    color-link statement "#A1EFD3"
    color-link symbol "#ffe6b3"
    color-link preproc "#A1EFD3"
    color-link type "#d4bfff"
    color-link special "#ABF8F7"
    color-link underlined "#91ddff,underline"
    color-link error "#F02E6E"
    color-link todo "#F2B482,bold"

    color-link function "#F48FB1"
    color-link function.call "#91ddff"
    color-link keyword "#A1EFD3"
    color-link keyword.control "#A1EFD3"
    color-link operator "#63f2f1"
    color-link label "#78a8ff"

    color-link title "#78a8ff,bold"
    color-link header "#91ddff"
    color-link bold "#,bold"
    color-link italic "#,italic"
    color-link micro.url "#8A889D,underline"
  '';
  settings = pkgs.writeText "micro-settings.json" ''
    {
        "colorscheme": "embark-tc"
    }
  '';
in {
  systemd.tmpfiles.rules = [
    "d  ${HOME}/.config/micro/colorschemes       755 ${user} users -"
    "L+ ${HOME}/.config/micro/colorschemes/embark-tc.micro 644 - - - ${colorscheme}"
    "L+ ${HOME}/.config/micro/settings.json      644 - - - ${settings}"
  ];
}
