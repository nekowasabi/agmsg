#!/usr/bin/env bash
# Show that a trusted plugins/types/devin replaces the built-in, and that
# a three-key manifest does not inherit cli from the built-in.
# STUB: the Devin CLI is not required and is not launched.
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$PLUGIN_DIR/../../.." && pwd)"
REAL_TMP="${TMPDIR:-/tmp}"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

if command -v devin >/dev/null 2>&1; then
  say "NOTE: a devin binary is on PATH. This script still does not call it."
else
  say "STUB: no devin binary on PATH. spawn.sh is expected to stop at the missing CLI."
fi

new_root() {
  local root
  root="$(TMPDIR="$REAL_TMP" mktemp -d)"
  mkdir -p "$root/scripts" "$root/db" "$root/plugins/types" "$root/teams"
  cp -R "$REPO/scripts/." "$root/scripts/"
  chmod +x "$root/scripts/"*.sh
  if [ -f "$root/scripts/internal/init-db.sh" ]; then
    bash "$root/scripts/internal/init-db.sh" >/dev/null
  fi
  printf '%s\n' "$root"
}

type_get() { # root key
  ( cd "$1" && bash -c "source scripts/lib/type-registry.sh; agmsg_type_get devin $2" )
}
type_dir() { # root
  ( cd "$1" && bash -c "source scripts/lib/type-registry.sh; agmsg_type_dir devin" )
}
cli_tail() { # root
  ( cd "$1" && SKILL_DIR="$1" bash -c "source scripts/lib/type-registry.sh; source scripts/lib/boot-command.sh; agmsg_role_cli_args devin seat '/agmsg actas seat'" )
}

ROOT="$(new_root)"
KEYS=""
PROJ="$(TMPDIR="$REAL_TMP" mktemp -d)"
trap 'rm -rf "$ROOT" "${KEYS:-}" "$PROJ"' EXIT
cp -R "$PLUGIN_DIR" "$ROOT/plugins/types/devin"

say ""
say "== before trust =="
before_dir="$(type_dir "$ROOT")"
say "type dir: $before_dir"
case "$before_dir" in
  */scripts/drivers/types/devin) ;;
  *) fail "untrusted plugin replaced the built-in: $before_dir" ;;
esac
before_spawnable="$(type_get "$ROOT" spawnable)"
say "spawnable: [${before_spawnable}]"
[ -z "$before_spawnable" ] || fail "built-in devin should have an empty spawnable key"
set +e
before_spawn="$(bash "$ROOT/scripts/spawn.sh" devin seat --project "$PROJ" 2>&1)"
before_status=$?
set -e
say "spawn.sh exit $before_status"
say "$before_spawn"
printf '%s\n' "$before_spawn" | grep -q "not supported by spawn yet" || fail "spawn did not refuse the built-in as unsupported"
printf '%s\n' "$before_spawn" | grep -q "not trusted" || fail "untrusted plugin produced no warning"

say ""
say "== trust types/devin =="
bash "$ROOT/scripts/plugin.sh" trust types/devin
say "trusted-plugins:"
cat "$ROOT/db/trusted-plugins"

say ""
say "== after trust =="
after_dir="$(type_dir "$ROOT")"
say "type dir: $after_dir"
case "$after_dir" in
  */plugins/types/devin) ;;
  *) fail "trusted plugin did not replace the built-in: $after_dir" ;;
esac
for key in spawnable cli model_arg prompt_arg delivery_modes; do
  val="$(type_get "$ROOT" "$key")"
  say "$key: [$val]"
done
[ "$(type_get "$ROOT" spawnable)" = yes ] || fail "spawnable was not yes"
[ "$(type_get "$ROOT" cli)" = devin ] || fail "cli was not devin"
[ "$(type_get "$ROOT" model_arg)" = "--model" ] || fail "model_arg was not --model"
[ "$(type_get "$ROOT" prompt_arg)" = "--" ] || fail "prompt_arg was not --"
[ "$(type_get "$ROOT" delivery_modes)" = off ] || fail "delivery_modes was not off"
tail="$(cli_tail "$ROOT")"
say "agmsg_role_cli_args:$tail"
printf '%s\n' "$tail" | grep -q ' -- ' || fail "prompt tail has no -- separator"

set +e
after_spawn="$(bash "$ROOT/scripts/spawn.sh" devin seat --project "$PROJ" --model swe-2-max 2>&1)"
after_status=$?
set -e
say "spawn.sh exit $after_status"
say "$after_spawn"
printf '%s\n' "$after_spawn" | grep -q "not found on PATH" || fail "spawn did not get as far as the missing devin binary"
printf '%s\n' "$after_spawn" | grep -q "not supported by spawn yet" && fail "trusted plugin was still refused as unsupported"

say ""
say "== delivery gate, full manifest =="
set +e
mon="$(bash "$ROOT/scripts/delivery.sh" set monitor devin "$PROJ" 2>&1)"
mon_status=$?
off="$(bash "$ROOT/scripts/delivery.sh" set off devin "$PROJ" 2>&1)"
off_status=$?
set -e
say "set monitor exit $mon_status"
say "$mon"
say "set off exit $off_status"
say "$off"
[ "$mon_status" -ne 0 ] || fail "monitor was accepted for a manual-only manifest"
printf '%s\n' "$mon" | grep -q "not supported" || fail "monitor refusal did not name the mode gate"
[ "$off_status" -eq 0 ] || fail "set off failed"
printf '%s\n' "$off" | grep -q "manual inbox checks only" || fail "set off did not use the plugin plug"

say ""
say "== path pin =="
printf 'types/devin\t/some/other/path\n' > "$ROOT/db/trusted-plugins"
pinned="$(type_dir "$ROOT")"
say "type dir after a mismatched trust path: $pinned"
case "$pinned" in
  */scripts/drivers/types/devin) ;;
  *) fail "a trust row for another path still selected the plugin: $pinned" ;;
esac

say ""
say "== three keys only, no merge =="
KEYS="$(new_root)"
mkdir -p "$KEYS/plugins/types/devin"
printf 'name=devin\nspawnable=yes\nmodel_arg=--model\nprompt_arg=--\n' > "$KEYS/plugins/types/devin/type.conf"
bash "$KEYS/scripts/plugin.sh" trust types/devin
keys_cli="$(type_get "$KEYS" cli)"
keys_spawnable="$(type_get "$KEYS" spawnable)"
keys_modes="$(type_get "$KEYS" delivery_modes)"
say "spawnable: [$keys_spawnable]"
say "cli: [$keys_cli]"
say "delivery_modes: [$keys_modes]"
[ "$keys_spawnable" = yes ] || fail "three-key plugin was not spawnable"
[ -z "$keys_cli" ] || fail "three-key plugin inherited cli [$keys_cli]"
[ -z "$keys_modes" ] || fail "three-key plugin inherited delivery_modes [$keys_modes]"
set +e
keys_spawn="$(bash "$KEYS/scripts/spawn.sh" devin seat --project "$PROJ" 2>&1)"
keys_status=$?
keys_mon="$(bash "$KEYS/scripts/delivery.sh" set monitor devin "$PROJ" 2>&1)"
keys_mon_status=$?
set -e
say "spawn.sh exit $keys_status"
say "$keys_spawn"
say "set monitor exit $keys_mon_status"
say "$keys_mon"
printf '%s\n' "$keys_spawn" | grep -q "neither a 'cli' binary nor a 'spawn' launcher" || fail "missing cli was not refused"
printf '%s\n' "$keys_mon" | grep -q "Unknown agent type" || fail "empty hooks_file did not stop the default writer"

say ""
say "== stub argv, not spawn.sh and not Devin =="
bash "$PLUGIN_DIR/stub-devin.sh" --model swe-2-max -- '/agmsg actas seat'
say "STUB hook file is not installed: $PLUGIN_DIR/hook-boundary.stub.json"
say "plugin _delivery.sh does not write that file."

say ""
say "PASS: trusted plugins/types/devin replaced the built-in. Three keys did not merge."
