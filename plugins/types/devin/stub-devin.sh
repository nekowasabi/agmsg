#!/usr/bin/env bash
# STUB. This is not the Devin CLI. verify-override.sh runs this only to
# print the argv a spawn would hand to a real `devin`. spawn.sh does not
# call this file unless a directory named on PATH contains an executable
# named `devin`.
printf 'STUB devin argv:'
printf ' %q' "$@"
printf '\n'
