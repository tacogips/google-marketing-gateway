#!/bin/sh
set -eu
temporary_root="$(mktemp -d "$PWD/.google-marketing-gateway-auth.XXXXXX")"
cleanup() { rm -rf "$temporary_root"; }
trap cleanup EXIT HUP INT TERM
token_store="$temporary_root/selected-token.json"
config="$temporary_root/profiles.json"
printf '%s\n' '{"profiles":[{"id":"smoke","product":"analytics-data","capability":"reader","oauthScopes":["https://www.googleapis.com/auth/analytics.readonly"],"accessTokenEnvironmentVariable":"SMOKE_TOKEN","oauthClientJSONPath":"'"$temporary_root"'/client.json","tokenStorePath":"'"$token_store"'"}]}' > "$config"
test ! -e "$token_store"
output="$(swift run google-marketing-gateway-reader auth logout --profile smoke --config "$config")"
test ! -e "$token_store"
printf '%s' "$output" | rg '"removed"[[:space:]]*:[[:space:]]*false' >/dev/null
