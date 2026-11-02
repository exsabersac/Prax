#!/usr/bin/env bash
# verify.sh — standing verification entry point (Haskell reference surface).
#
# Runs, in order and failing loudly on the first problem:
#   1. freeze-check          — the frozen Haskell tree is byte-identical to the tag
#   2. cabal build prax-oracle — the one additive surface still compiles
#   3. golden-check          — the four decision-sequence goldens are still DERIVED
#                              from the frozen literals, hashed, and independently
#                              re-derived from the engine's own walk
#   4. cabal test            — the frozen Haskell suite stays green (the pins' source)
#
# The former Rust workspace / baseline tripwire steps were removed with rust/.
# Every remaining step is mandatory; there is no skip path. Run from anywhere
# in the repo.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

step() { printf '\n=== %s ===\n' "$1"; }

step "1/4 freeze-check"
./scripts/freeze-check.sh

step "2/4 cabal build prax-oracle (additive oracle surface)"
cabal build prax-oracle

step "3/4 golden-check (the goldens are derived, never re-captured)"
./scripts/golden-check.sh

step "4/4 cabal test (frozen Haskell suite must stay green)"
cabal test

printf '\nverify: all checks passed.\n'
