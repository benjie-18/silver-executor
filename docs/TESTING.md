# Testing

Install the official Luau command line tools from [upstream releases or build instructions](https://github.com/luau-lang/luau/blob/master/README.md#installation). From the repository root:

```sh
luau test/run_tests.lua
luau-compile --null --only-parse src/Bootstrap.client.lua src/UI/UIManager.lua
```

Nine suites under `test/` cover utilities, document edits and history, search and replacement, tabs, bounded console, execution capability/error/stop behavior, and configuration, and a mocked GUI mount/action integration test, and capability/theme checks. `Harness.lua` counts failures and `MockRoblox.lua` supplies only the scheduler/compiler used by the pure execution tests. `run_tests.lua` fails the process if any test fails. The GUI test uses minimal stand-ins, not a real Roblox client; real Instance behavior and client permissions remain unverified.

Verified in this workspace with upstream Luau CLI 0.745 built from source: **16/16 tests pass**; all Lua source files parsed with `luau-compile --null --only-parse`. No injection or Studio runtime test was performed.

Manual Studio checklist (requires Studio + Rojo): sync `default.project.json`, start a client, check text editing, new/close tab, undo/redo, Find selection, console status, Hide/shortcut, and confirm Run reports unavailable in a standard LocalScript. In any authorized host with a compiler, separately verify compilation/runtime errors and cancellation without assuming process isolation.
