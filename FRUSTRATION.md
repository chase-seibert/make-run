# Frustration Log

Record recurring failure modes and useful workarounds here.

## SwiftPM inside the managed workspace sandbox

`swift build` and `swift test` can fail before compiling with `sandbox-exec: sandbox_apply: Operation not permitted` because SwiftPM tries to create its own nested sandbox. Re-run the same narrowly scoped Makefile target with workspace sandbox escalation; changing SwiftPM cache flags does not address the nested-sandbox failure.

## Do not force-source `.bashrc` after login startup

The first Terminal launcher used `bash -lic` and then explicitly sourced `~/.bashrc`. A self-referential `.bashrc` caused infinite recursion, a Bash segmentation fault, and exit code 139 before Make started. Match normal Bash login semantics: use `bash -lic` and let `.bash_profile` decide whether to source `.bashrc`.

## Do not identify a SwiftUI window by its navigation title

The main window title follows the selected project, so looking for a window titled `Make Run` failed and triggered an inappropriate `NSDocumentController.newDocument` fallback. Use the app's key/main normal window for activation, and route closed-window recreation through SwiftUI's New Window command.

## Relaunch can race LaunchServices

Calling `open` immediately after terminating the prior app process can intermittently fail with LaunchServices error `-600`. Use `open -n` in the Makefile run target to request a fresh instance explicitly.

## NSTextView scrolling before SwiftUI layout is ineffective

Calling `scrollRangeToVisible` during `updateNSView` can occur while the representable still has a zero or provisional viewport. AppKit accepts the request, then subsequent SwiftUI layout changes the wrapped document height and leaves the view above the bottom. Defer the initial scroll from an `NSScrollView` subclass until it is in a window with a nonzero clip size, force text layout, and pin the clip origin geometrically.

## Do not assign to an `@Observable` property from its own observer

Clamping `fontScale` by assigning back to it inside `didSet` recursively re-entered Observation's generated setter and caused a stack-overflow crash. Store the tracked value separately and clamp incoming values in a computed setter without assigning to the computed property itself.
