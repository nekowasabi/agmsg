---
name: verify-devin-plugin-override
description: "Check that a trusted plugins/types/devin replaces the built-in devin manifest without merging missing keys. Use when editing type-registry.sh, driver-registry.sh, spawn.sh's spawnable or cli gate, delivery.sh do_set, or plugins/types/devin."
---

# Devin plugin override

A trusted `plugins/types/devin` replaces `scripts/drivers/types/devin` as a whole directory. `agmsg_type_get` reads only the winning `type.conf`. A missing key stays missing. It is not filled from the built-in.

The harm is a three-key drop-in (`spawnable=yes`, `model_arg=--model`, `prompt_arg=--`) silently inheriting `cli=devin` and launching a seat the author did not describe, or an untrusted drop-in changing spawn.

## When a change touches this

Read the diff. Run the check when it edits any of these:

- `scripts/lib/type-registry.sh` (`agmsg_type_dir`, `agmsg_type_get`)
- `scripts/lib/driver-registry.sh` (`agmsg_driver_is_trusted`, `agmsg_driver_bases`)
- `scripts/spawn.sh` (the spawnable gate, the `cli` / `spawn` gate)
- `scripts/delivery.sh` (`do_set`'s mode gate, `resolve_hooks_file`)
- `scripts/lib/boot-command.sh` (`agmsg_role_cli_args`)
- `plugins/types/devin/`

## Run

From the repo root:

```bash
bash .cursor/skills/verify-devin-plugin-override/check.sh
```

`check.sh` copies `scripts/` into a temp root, trusts the plugin there, and runs TLC on `DevinOverride.tla`. It needs Java 11 or later and `tla2tools.jar` 1.7.4 (sha256 `936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88`). Set `TLA2TOOLS` to the jar. The Devin CLI is not used. A missing `devin` binary is the expected spawn stop.

Exit 0 means the shell checks passed and the model with `Merge = FALSE` passed. The model with `Merge = TRUE` must fail `NoMerge`. Any other TLC error is a broken check, not a product bug.

## How to read a failure

- `three-key plugin inherited cli` means `agmsg_type_get` filled a missing key from the built-in. That is the bug this check guards. Do not change the plugin so the key is present and call that a fix, unless the product change is meant to merge manifests. A merge is a product change and this skill's model must change with it.
- `untrusted plugin replaced the built-in` means trust gating failed.
- `spawn did not get as far as the missing devin binary` means `spawnable=yes` on the winning manifest did not open the spawn gate.
- TLC naming `NoMerge` on `Merge = FALSE` means the model no longer matches the code, or the code now merges. Read the counterexample with `/statechart`. Do not copy `/statechart` flags into this skill. They change between releases.
- A TLC error that is not an invariant is a modeling or tool failure. Say so. Do not edit product code to make the checker start.

## What is checked

Shell, on a temp copy of this repo's `scripts/`:

- Untrusted `plugins/types/devin` leaves `agmsg_type_dir` on the built-in, and `spawn.sh` says the type is not supported yet.
- After `plugin.sh trust types/devin`, the directory is the plugin, `spawnable` is `yes`, `cli` is `devin`, `prompt_arg` is `--`, and `spawn.sh` stops because `devin` is not on `PATH`.
- `delivery.sh set monitor` is refused when `delivery_modes=off`. `set off` reaches the plug.
- A trust row whose path is not the plugin directory selects the built-in.
- A manifest with only the three spawn keys has an empty `cli`. `spawn.sh` refuses it. `set monitor` dies in `resolve_hooks_file` because `hooks_file` is empty.

TLC, 60 states, on the operators in `DevinOverride.tla`:

- `NoMerge`. A keys-only winning plugin has an empty `cli`.
- `UntrustedIsBuiltin`. Absent, untrusted, or path-mismatched resolution is the built-in.
- `FullStaysManual`. A full plugin keeps monitor off that list.
- `SpawnAgrees`. A recorded spawn or monitor answer matches the current resolution.

`Merge = TRUE` is the broken model. It copies `cli=devin` onto the keys-only plugin. `NoMerge` must fail there. The shortest path is place the three keys, then trust that path.

## What is not checked

Devin actually starting, Devin reading `--` as a prompt, Devin firing `.devin/hooks.v1.json`, and `install.sh` preserving `plugins/` on a real home directory. `hook-boundary.stub.json` is not installed. The chart hides `AskSpawn`, `AskPush`, and a core update that does not change the visible label. Those steps stay inside one chart state. The invariants still cover the answers.

## Keep the sync commit honest

Covered product files were last confirmed against this model at the commit named below. Move that commit forward only after you read the new code and the model still describes it. A skill-only edit does not by itself move it.

Sync commit: `PENDING_SYNC_COMMIT`
