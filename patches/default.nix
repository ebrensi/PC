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
#   package   prev: <derivation> — replaces prev.<name> outright, for fixes
#               overrideAttrs can't express (e.g. swapping a dependency).
#               Use instead of `override`.
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
    checked = "2026-11-08";
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
  # every two weeks. Upstream issue #795, fixed by #809 (epoll) and #810 (FD
  # cleanup), first released in 7.1.0; nixpkgs is still on 7.0.0, so build 7.1.1.
  #
  # 7.1.x needs its submodules and none of nixpkgs' 7.0.0 patches (both are
  # already upstream). Drop this once nixpkgs ships 7.1.0 or newer.
  eternal-terminal = {
    checked = "2026-11-08";
    dropWhen = "upstream-fixed";
    upstream = "https://github.com/MisterTea/EternalTerminal/releases (nixpkgs eternal-terminal >= 7.1.0)";
    override = prev: _: {
      version = "7.1.1";
      src = prev.fetchFromGitHub {
        owner = "MisterTea";
        repo = "EternalTerminal";
        tag = "et-v7.1.1";
        fetchSubmodules = true;
        hash = "sha256-cuPNPNUohRUAq90W29Vhm37OPmcgdYwX2jS/pPIEsOo=";
      };
      patches = [];
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
