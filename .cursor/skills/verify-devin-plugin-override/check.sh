#!/usr/bin/env bash
# One command for verify-devin-plugin-override. See SKILL.md.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
JAR="${TLA2TOOLS:-}"
if [ -z "$JAR" ] && [ -f /tmp/tla/tla2tools.jar ]; then
  JAR=/tmp/tla/tla2tools.jar
fi
[ -n "$JAR" ] && [ -f "$JAR" ] || {
  printf 'FAIL: set TLA2TOOLS to tla2tools.jar 1.7.4\n' >&2
  exit 2
}
command -v java >/dev/null 2>&1 || { printf 'FAIL: java is missing\n' >&2; exit 2; }

say() { printf '%s\n' "$*"; }

say "== shell =="
bash "$REPO/plugins/types/devin/verify-override.sh"

run_tlc() { # config expect: pass|fail-nomerge
  local cfg="$1" expect="$2" out status
  set +e
  out="$(cd "$HERE" && java -cp "$JAR" tlc2.TLC -config "$cfg" DevinOverride.tla 2>&1)"
  status=$?
  set -e
  printf '%s\n' "$out" | tail -n 20
  if [ "$expect" = pass ]; then
    [ "$status" -eq 0 ] || { printf 'FAIL: %s exited %s\n' "$cfg" "$status" >&2; exit 1; }
    printf '%s\n' "$out" | grep -q "No error has been found" || {
      printf 'FAIL: %s did not report a clean TLC run\n' "$cfg" >&2
      exit 1
    }
  else
    [ "$status" -ne 0 ] || { printf 'FAIL: %s passed, but NoMerge must fail when Merge is TRUE\n' "$cfg" >&2; exit 1; }
    printf '%s\n' "$out" | grep -q "Invariant NoMerge is violated" || {
      printf 'FAIL: %s failed without a NoMerge violation\n' "$cfg" >&2
      exit 1
    }
  fi
}

say ""
say "== TLC Merge = FALSE =="
run_tlc DevinOverride.cfg pass
say ""
say "== TLC Merge = TRUE (must violate NoMerge) =="
run_tlc DevinOverrideMerge.cfg fail-nomerge
say ""
say "PASS: shell override and both TLC configs."
