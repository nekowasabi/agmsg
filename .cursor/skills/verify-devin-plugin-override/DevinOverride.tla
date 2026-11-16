---- MODULE DevinOverride ----
\* Resolution of the built-in devin type against a plugins/types/devin drop-in.
\* Points at agmsg_type_dir, agmsg_driver_is_trusted, agmsg_type_get,
\* spawn.sh's spawnable and cli gates, and delivery.sh do_set.
\* A winning directory replaces the manifest. Missing keys are not filled
\* from the built-in. An empty delivery_modes key falls through to
\* "monitor turn both off" inside do_set, not inside agmsg_type_get.

EXTENDS TLC

CONSTANTS Merge

VARIABLES place, pin, core, last
vars == <<place, pin, core, last>>

TypeOK ==
  /\ place \in {"none", "full", "keys", "auto"}
  /\ pin \in {"open", "held", "moved"}
  /\ core \in {"manual", "spawnable"}
  /\ last \in {"none", "spawn_yes", "spawn_no", "push_yes", "push_no"}
  /\ (place = "none" => pin = "open")

Source == IF place = "none" \/ pin # "held" THEN "builtin" ELSE "plugin"

Cli ==
  IF Source = "builtin" THEN "devin"
  ELSE IF place = "keys" /\ Merge THEN "devin"
  ELSE IF place = "keys" THEN ""
  ELSE "devin"

Spawnable ==
  IF Source = "builtin" THEN IF core = "spawnable" THEN "yes" ELSE "no"
  ELSE "yes"

MonitorListed ==
  IF Source = "builtin" THEN FALSE
  ELSE IF place = "auto" THEN TRUE
  ELSE IF place = "keys" THEN TRUE
  ELSE FALSE

CanSpawn == Spawnable = "yes" /\ Cli # ""

Init ==
  /\ place = "none"
  /\ pin = "open"
  /\ core = "manual"
  /\ last = "none"

PlaceFull ==
  /\ place' = "full"
  /\ pin' = "open"
  /\ last' = "none"
  /\ UNCHANGED core
  /\ (place # "full" \/ pin # "open" \/ last # "none")

PlaceKeys ==
  /\ place' = "keys"
  /\ pin' = "open"
  /\ last' = "none"
  /\ UNCHANGED core
  /\ (place # "keys" \/ pin # "open" \/ last # "none")

PlaceAuto ==
  /\ place' = "auto"
  /\ pin' = "open"
  /\ last' = "none"
  /\ UNCHANGED core
  /\ (place # "auto" \/ pin # "open" \/ last # "none")

Remove ==
  /\ place # "none"
  /\ place' = "none"
  /\ pin' = "open"
  /\ last' = "none"
  /\ UNCHANGED core

Trust ==
  /\ place # "none"
  /\ pin # "held"
  /\ pin' = "held"
  /\ last' = "none"
  /\ UNCHANGED <<place, core>>

Move ==
  /\ pin = "held"
  /\ pin' = "moved"
  /\ last' = "none"
  /\ UNCHANGED <<place, core>>

Untrust ==
  /\ pin # "open"
  /\ pin' = "open"
  /\ last' = "none"
  /\ UNCHANGED <<place, core>>

CoreUpdate ==
  /\ core = "manual"
  /\ core' = "spawnable"
  /\ last' = "none"
  /\ UNCHANGED <<place, pin>>

AskSpawn ==
  /\ last' = IF CanSpawn THEN "spawn_yes" ELSE "spawn_no"
  /\ last' # last
  /\ UNCHANGED <<place, pin, core>>

AskPush ==
  /\ last' = IF MonitorListed THEN "push_yes" ELSE "push_no"
  /\ last' # last
  /\ UNCHANGED <<place, pin, core>>

Next ==
  \/ PlaceFull
  \/ PlaceKeys
  \/ PlaceAuto
  \/ Remove
  \/ Trust
  \/ Move
  \/ Untrust
  \/ CoreUpdate
  \/ AskSpawn
  \/ AskPush

Spec == Init /\ [][Next]_vars

NoMerge == (Source = "plugin" /\ place = "keys") => Cli = ""

SpawnAgrees ==
  /\ (last = "spawn_yes" => CanSpawn)
  /\ (last = "spawn_no" => ~CanSpawn)
  /\ (last = "push_yes" => MonitorListed)
  /\ (last = "push_no" => ~MonitorListed)

UntrustedIsBuiltin ==
  (place = "none" \/ pin # "held") =>
    /\ Source = "builtin"
    /\ Cli = "devin"
    /\ ~MonitorListed

FullStaysManual ==
  (Source = "plugin" /\ place = "full") => ~MonitorListed

====
