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
  # foot 1.27.0 (still unfixed in 1.28.0) crashes (SIGSEGV) when a key event
  # arrives with no focused terminal. keyboard_key() passes seat->kbd_focus straight to
  # key_press_release() without a NULL check, and key_press_release() then
  # dereferences it (term->conf). fdm_shutdown() clears seat->kbd_focus as
  # soon as a window is destroyed, so the key *release* that follows closing
  # a window lands on a NULL term. cosmic-comp reliably delivers that
  # release, so this fires on nearly every window close.
  #
  # In server mode the crash kills the server process, which takes *every*
  # foot window down at once. Patch adds the missing NULL guards.
  foot = {
    checked = "2026-10-15";
    dropWhen = "upstream-fixed";
    upstream = "https://codeberg.org/dnkl/foot/src/branch/master/input.c (NULL check on seat->kbd_focus in keyboard_key)";
    override = _: old: {
      patches = (old.patches or []) ++ [./foot-null-kbd-focus.patch];
    };
  };
}
