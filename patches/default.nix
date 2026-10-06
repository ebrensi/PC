# Registry of every local fix to a nixpkgs package. patches/module.nix turns
# each entry into an overlay, and nags on rebuild once an entry's `checked`
# date is more than a month behind the pinned nixpkgs.
#
# To review: run `check-patches` (from `nix develop`), drop entries that are no
# longer needed, and bump `checked` on the ones that still are.
#
# Entry fields:
#   checked   date (YYYY-MM-DD) the fix was last confirmed necessary
#   dropWhen  "unpatched-builds": a build fix; check-patches builds the stock
#               package and reports whether the fix can go.
#             "upstream-fixed": a behavior fix; the stock package builds either
#               way, so check `upstream` by hand.
#   upstream  (upstream-fixed only) where to look for the fix
#   override  prev: old: { ... } — passed to prev.<name>.overrideAttrs
{
  # abseil-cpp 20260817 requires C++20 (absl/types/compare.h uses
  # std::partial_ordering), but ET's CMakeLists.txt hardcodes C++17, so the
  # build dies in the precompiled header.
  eternal-terminal = {
    checked = "2026-10-01";
    dropWhen = "unpatched-builds";
    override = _: old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace CMakeLists.txt \
            --replace-fail "set(CMAKE_CXX_STANDARD 17)" "set(CMAKE_CXX_STANDARD 20)"
        '';
    };
  };

  # nixpkgs' buildUBoot now rewrites -Wno-graph_child_address to
  # -Eno-node_name_not_empty for dtc 1.8, but nixos-apple-silicon filters out
  # the DTC= make flag, so u-boot falls back to its bundled dtc 1.7.2, which
  # rejects the unknown check. Put DTC= back to build with nixpkgs' dtc.
  # m1-only: the overlay is lazy, so other hosts never evaluate it.
  uboot-asahi = {
    checked = "2026-10-05";
    dropWhen = "upstream-fixed";
    upstream = "https://github.com/nix-community/nixos-apple-silicon/issues/557 (stop filtering DTC= in uboot-asahi)";
    override = prev: old: {
      makeFlags = ["DTC=${prev.lib.getExe prev.buildPackages.dtc}"] ++ old.makeFlags;
    };
  };

  # foot 1.27.0 crashes (SIGSEGV) when a key event arrives with no focused
  # terminal. keyboard_key() passes seat->kbd_focus straight to
  # key_press_release() without a NULL check, and key_press_release() then
  # dereferences it (term->conf). fdm_shutdown() clears seat->kbd_focus as
  # soon as a window is destroyed, so the key *release* that follows closing
  # a window lands on a NULL term. cosmic-comp reliably delivers that
  # release, so this fires on nearly every window close.
  #
  # In server mode the crash kills the server process, which takes *every*
  # foot window down at once. Patch adds the missing NULL guards.
  foot = {
    checked = "2026-09-30";
    dropWhen = "upstream-fixed";
    upstream = "https://codeberg.org/dnkl/foot/src/branch/master/input.c (NULL check on seat->kbd_focus in keyboard_key)";
    override = _: old: {
      patches = (old.patches or []) ++ [./foot-null-kbd-focus.patch];
    };
  };

  # Kodi 21's GBM backend picks a 10-bit (XRGB2101010) GUI framebuffer whenever
  # the plane lists that format. RK3588's VOP2 lists it but only scans 10bpc
  # out as AFBC, and Kodi allocates it linear, so every page flip is rejected
  # ("Only support 10bpc format with afbc"; Kodi logs "Failed to get a new FBO")
  # and the screen stays on the text console. Force the 8-bit GUI plane.
  # tv-only: the overlay is lazy, so other hosts never evaluate it.
  kodi-gbm = {
    checked = "2026-10-05";
    dropWhen = "upstream-fixed";
    upstream = "Kodi 22 reworked GUI plane format selection (xbmc/xbmc b20ec4eb6c, xbmc/windowing/gbm/drm/DRMUtils.cpp)";
    override = _: old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace xbmc/windowing/gbm/drm/DRMUtils.cpp \
            --replace-fail "if (m_gui_plane->SupportsFormat(DRM_FORMAT_XRGB2101010))" "if (false)"
        '';
    };
  };
}
