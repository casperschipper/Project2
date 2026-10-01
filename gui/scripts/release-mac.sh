#!/bin/sh
# Build the macOS app signed with the Developer ID certificate and notarized
# by Apple, so it opens on other Macs without Gatekeeper warnings. Tauri does
# the signing, notarizing and stapling when the APPLE_* variables are set.
#
# Needs, in the login keychain: the "Developer ID Application" certificate
# with its private key, and an app-specific password for the Apple ID, stored
# once with
#   security add-generic-password -a <apple id> -s projekt2-notarize -w
# The Apple ID and password are read from that entry, so neither is in the repo.
set -eu
service=projekt2-notarize

if ! security find-generic-password -s "$service" >/dev/null 2>&1; then
  echo "No '$service' entry in the keychain; see the comment in $0." >&2
  exit 1
fi

export APPLE_SIGNING_IDENTITY="${APPLE_SIGNING_IDENTITY:-Developer ID Application: Casper Schipper (6QF6HV63R7)}"
export APPLE_TEAM_ID="${APPLE_TEAM_ID:-6QF6HV63R7}"
APPLE_ID=$(security find-generic-password -s "$service" | sed -n 's/^ *"acct"<blob>="\(.*\)"$/\1/p')
APPLE_PASSWORD=$(security find-generic-password -s "$service" -w)
export APPLE_ID APPLE_PASSWORD

npm run app:build:mac
