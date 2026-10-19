#!/bin/sh
# Prove the installation, not just that the CLI starts.
set -eu

echo "== versions"
rea --version
ps -axo pid= >/dev/null && echo "ps: procps ok"
java -version 2>&1 | head -1
echo "GHIDRA_INSTALL_DIR=${GHIDRA_INSTALL_DIR:-unset}"

echo "== the server speaks the protocol"
rea mcp doctor | head -12

echo "== a real analysis, through the MCP surface"
W=$(mktemp -d)
printf 'int add(int a,int b){return a+b;}\nint main(){return add(2,3);}\n' > "$W/probe.c"
gcc -O0 -o "$W/probe" "$W/probe.c"
rea analyze "$W/probe" --provider ghidra --format json > "$W/out.json"
grep -q '"provider":{"id":"ghidra"' "$W/out.json" \
  && echo "PASS: analysis completed with Ghidra evidence" \
  || { echo "FAIL: analysis did not name Ghidra"; cat "$W/out.json"; exit 1; }
