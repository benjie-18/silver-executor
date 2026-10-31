# Architecture and operation

`default.project.json` maps `src` into `StarterPlayerScripts/Silver`; `Bootstrap.client.lua` calls `Main.lua`, which wires the document model, bounded console, execution capability probe, and UI. Modules are organized into `Core`, `Engine`, `UI/Editor`, `Api`, and `Inject`. `Inject.probe` is only a capability detector. There is no memory writer.

The responsive window has horizontally scrollable controls/tabs, a minimum-height vertical canvas and a touch-accessible reopen button. The editor uses a native Roblox `TextBox` rather than synthesizing key events: Roblox handles caret, selection, keyboard layout, and paste. Each tab owns a `Document`; changes are checkpointed for undo. Find is literal and logs a count while selecting the first match. Search's pure module additionally supports whole-word, case-sensitive, opt-in Lua patterns, and replace-all with a single undo step; the UI exposes find only. Console messages are bounded by `consoleLimit`.

The runner compiles source using a compiler function available to the host, runs it in a managed task, and logs compilation and runtime errors. It does not wrap `print` or `warn`, sandbox globals, interrupt CPU-bound Luau, or revoke spawned tasks. The top-level UI's Run command caps the source at `maxSourceBytes` (default 250,000). `Execution.new` itself accepts a compiler argument for testability; in a normal Roblox client this is nil.

Configuration is currently limited to `theme`, `consoleLimit`, and `maxSourceBytes`. Config can read/write a caller-supplied storage table; the default client startup uses `_G`, which is session-local, not disk persistence. `ThemeManager.get` requires Roblox `Color3` and is only invoked by the UI.

References: [Luau README / CLI usage](https://github.com/luau-lang/luau/blob/master/README.md), [Rojo filesystem synchronization](https://github.com/rojo-rbx/rojo/blob/master/README.md). These are documentation references, not runtime dependencies.
