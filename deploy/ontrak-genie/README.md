# OnTrak Genie integration

How REA is deployed inside [OnTrak Genie](https://ontrak.innotel.us) — an Alpine
container that runs a coding agent, now with REA registered as an MCP server.

This directory is **deployment knowledge, not a patch**: it lives on the
`ontrak/genie-integration` branch so `main` stays identical to upstream and a rebase
is always clean.

## What is installed

| Piece | Version / setting | Why |
| --- | --- | --- |
| `rea-agents` | npm global, pinned (`6.7.0` here) | the MCP server and CLI |
| Ghidra | `12.1.4` at `/opt/ghidra`, `GHIDRA_INSTALL_DIR` | native analysis provider |
| JDK | `openjdk21-jdk` (full JDK, `JAVA_HOME` set) | Ghidra is Java; REA checks for the JDK |
| `procps` | Alpine package | REA's Linux process-ownership check needs `ps -axo` |
| `gcompat`, `libstdc++` | Alpine packages | Ghidra's `decompile` helper is glibc-linked |
| Registration | `/root/.agents/mcp.json` | the stdio server, for any client reading that file |

## Three things that only fail on Alpine

Each was measured on the deployment, and each failure message points somewhere
other than its cause:

1. **`ps: unrecognized option: x`.** BusyBox `ps` has no `-axo`, so REA refuses to
   launch an analysis child (`capability_unavailable` / `unsupported_provider`) even
   though no engine is missing. Install `procps`.
2. **`runtime only; accepted a 64-bit full JDK 21 or newer`.** `openjdk21-jre-headless`
   is not enough — REA wants the JDK. Ghidra looks installed, then refuses every
   native launch.
3. **`Exec failed, error: 2 (No such file or directory)`** for a file that exists.
   That is Ghidra's decompiler failing to load its *glibc* interpreter under musl.
   `gcompat` (plus `libstdc++`) fixes it. The JVM logs the import as successful
   right before this, which is what makes it read like a REA bug.

## Registration

`mcp.json` in this directory is what the deployment writes to
`/root/.agents/mcp.json`:

```json
{ "mcpServers": { "rea": { "command": "rea", "args": ["--mcp"] } } }
```

`rea setup` writes the same shape into the config of whichever agent it detects.
A console that reads that shared path therefore needs no separate registration.

## Verify

`verify.sh` checks the server on its own (`rea mcp doctor`: 207 tools, 6 prompts),
then runs a real analysis: `rea analyze` on a compiled probe and `open_binary` +
`analyze_function` through the MCP surface, asserting the evidence names Ghidra as
the provider.

## Optional providers

Ghidra is the only engine installed by default. IDA, JADX, Kuna and JEB are
caller-supplied by design — `rea doctor` lists exactly which variable each one
needs. The Python ELF-layout provider (`REA_PWNTOOLS_PYTHON`) needs pwntools
4.15.0, pyelftools 0.33 and Unicorn 2.1.2 in a dedicated interpreter; Unicorn has no
musl wheel, so it must be built from source.
