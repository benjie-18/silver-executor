# Silver Executor

A small Luau editor, console, and **capability-gated** runner for a Roblox client host. The repository was empty when work began: the large code sample in the task was not present on disk and contained unresolved syntax/API issues. This implementation is a coherent, testable replacement rather than a claim that the pasted memory injector works.

**Important:** In a normal Roblox LocalScript, `loadstring` is not available. The interface therefore runs in **editor-only mode** unless a trusted host explicitly provides a compiler. No CoreScript swap, thread hijack, offsets download, privilege escalation, sandbox, or remote execution endpoint is included. Do not run untrusted scripts: a host compiler executes with its host's privileges.

## Quick start

1. Use Rojo to sync `default.project.json` to a Roblox Studio test place, or manually copy `src/` as a folder named `Silver` into `StarterPlayerScripts` and ensure `Bootstrap.client.lua` becomes a LocalScript named `Bootstrap` and `Main.lua` becomes a ModuleScript named `Main`, alongside the module folders. Run the place in client mode.
2. The UI opens in `PlayerGui` in experiences where you install it and allow client UI scripts. Write Luau in the editor, use New tab/Close tab, Undo/Redo, Find, and Clear log. **Ctrl+Shift+L** toggles visibility on desktop; a small Silver button reopens the window on touch devices. The toolbar and tabs scroll horizontally, and the window scrolls vertically on small screens.
3. Run works only when the host has a `loadstring` capability; otherwise the console explains why it cannot execute. Stop cancels the managed task, **not** arbitrary child tasks or side effects.

For tests, install the [official Luau CLI](https://github.com/luau-lang/luau#installation), then run `luau test/run_tests.lua` from the repository root. See [docs/README.md](docs/README.md) for architecture and [docs/LIMITATIONS.md](docs/LIMITATIONS.md) for exact boundaries.

## Sources and verification

Design decisions were checked against the upstream [Luau language/CLI README](https://github.com/luau-lang/luau/blob/master/README.md) and [Rojo README](https://github.com/rojo-rbx/rojo/blob/master/README.md). The official Luau CLI provides file execution and `luau-analyze`; Rojo maps filesystem scripts to instances. See [docs/TESTING.md](docs/TESTING.md) for verification performed and [docs/REVERSE.md](docs/REVERSE.md) for the rejected reverse-engineering assumptions in the supplied draft.
