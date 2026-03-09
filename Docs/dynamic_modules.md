# Dynamic Module Scanning (Design Note)

Goal: Allow Macwin Toolset to discover additional module bundles dropped into a `ModulesExtra/` folder (or user Application Support directory) without recompilation.

## Concept
1. Define a lightweight bundle convention: `.mwmodule` packages containing a compiled Swift bundle or script metadata.
2. On launch, scan predefined search paths:
   - `~/Library/Application Support/MacwinToolset/Modules/`
   - App bundle `Contents/ExtraModules/`
3. For each candidate, load metadata (Info.plist or JSON) specifying:
   - `id`, `displayName`, required permissions, entry class name.
4. Use `Bundle(path:)` to load and reflectively instantiate the class conforming to `ModuleProtocol`.
5. Insert into `ModuleRegistry` before building menu.

## Security Considerations
- Only load signed bundles (codesign verification) in a hardened build.
- Provide a user preference “Allow Third-Party Modules”.
- Maintain a quarantine list for failed or crashing modules (store crash flag and skip next launch until user re-enables).

## Failure Handling
- If a dynamic module throws on `start()`, catch, log, and mark as disabled.
- Surface error count in diagnostics JSON.

## Minimal Metadata (JSON alternative)
```json
{
  "id": "samplemod",
  "displayName": "Sample Mod",
  "permissions": ["accessibility"],
  "entryClass": "SampleModule"
}
```

## Future Extensions
- Hot reload triggered via menu “Rescan Modules”.
- Module sandboxing via XPC service boundary.
- Version compatibility field (e.g., `requiresCoreVersion`).

This design remains deferred until stability and security policies are finalized.
