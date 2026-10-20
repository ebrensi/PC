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
    checked = "2026-10-20";
    dropWhen = "upstream-fixed";
    upstream = "https://codeberg.org/dnkl/foot/src/branch/master/input.c (NULL check on seat->kbd_focus in keyboard_key)";
    override = _: old: {
      patches = (old.patches or []) ++ [./foot-null-kbd-focus.patch];
    };
  };

  # etserver 7.0.0 busy-loops a thread at 100% CPU, forever, for every session
  # whose client drops uncleanly while forwarding is active ($SSH_AUTH_SOCK
  # agent forwarding counts). Dead /tmp/et_forward_sock_* fds stay readable, so
  # runTerminal()'s select/accept loop never blocks. Hit on adder-ws roughly
  # every two weeks. Upstream issue #795, fixed on master by #809 (epoll) and
  # #810 (FD cleanup), but unreleased; neither applies to 7.0.0, so build master.
  #
  # Master needs its submodules and none of nixpkgs' patches (both are already
  # upstream). Drop this once nixpkgs ships a release newer than 7.0.0.
  eternal-terminal = {
    checked = "2026-10-20";
    dropWhen = "upstream-fixed";
    upstream = "https://github.com/MisterTea/EternalTerminal/releases (a release after 7.0.0 contains #809 + #810)";
    override = prev: _: {
      version = "7.0.0-unstable-2026-10-13";
      src = prev.fetchFromGitHub {
        owner = "MisterTea";
        repo = "EternalTerminal";
        rev = "7eb237e6d9822b674f4a527924b5f09117659321";
        fetchSubmodules = true;
        hash = "sha256-dWtEDRSGTHgXIFiL82lK5AxrTaM/v/SIStHGwPcEQ3c=";
      };
      patches = [];
      # Master still reports itself as `et version 7.0.0`.
      preVersionCheck = "version=7.0.0";
      # Catch2 now comes from the submodule.
      preBuild = "";
      preCheck = ''
        export HOME=$(mktemp -d)
      '';
      # Skipped tests can't pass in the build sandbox: the storage-path checks
      # reject '/' because it isn't root-owned there, and the PTY/daemon e2e
      # tests can't hold a real terminal or a lingering background process.
      checkPhase = ''
        runHook preCheck
        ctest --output-on-failure -E '^et-test\.(${prev.lib.concatStringsSep "|" [
          "LargeInputNoDeadlock"
          "Creation"
          "Server fifo accepts a parent writable by the user private group"
          "Telemetry creates private configuration and preserves its id"
          "Telemetry bounds existing configuration reads and migrates permissions"
          "Daemon pid writes create private files and replace stale contents"
          "RouterRestartRealPtySurvives"
          "sessionHasEnded without master EOF while descendant holds PTY slave"
          "Control-mode PTY: .*"
        ]})$'
        runHook postCheck
      '';
    };
  };
}
