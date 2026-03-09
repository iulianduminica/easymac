# Macwin Toolset – Consolidation Roadmap

Legend: Priority P0 (critical), P1 (high), P2 (normal), P3 (nice-to-have)
Status markers: [ ] not started / [x] done / [-] deferred / [~] partial

---
## Phase 0 – Foundation & Decisions (P0)
- [x] Choose master app name (Macwin Toolset)
- [x] Select bundle identifier (com.mac.macwintoolset)
- [x] Decide login item strategy (direct mainApp register/unregister for now)
- [x] Confirm minimum macOS target (13.0+ assumed)
- [x] Decide icon strategy (placeholder generated gear icon)

## Phase 1 – Repository Restructure (P0)
- [x] Add `main.swift` hub entrypoint
- [x] Create `/Modules/` directory
- [x] Introduce `ModuleProtocol`
- [x] Implement `ModuleRegistry`
- [x] Move existing logic into `CutPasteModule.swift`, `DockClickModule.swift`, `TrashKeyModule.swift`

## Phase 2 – Shared Services (P0/P1)
- [x] EventRouter (single CGEventTap) 
- [x] Debounce helper
- [x] PermissionsManager skeleton
- [x] AppleScript utility
- [x] Notifications service (modern path + rate limiting + formatting)
- [x] Logging wrapper (os.Logger categories + stdout mirror optional)
- [x] Finder selection helper
- [x] File operations helper

## Phase 3 – Module Refactor (P1)
- [x] TrashKeyModule migrated
- [x] CutPasteModule migrated
- [x] DockClickModule advanced logic port (geometry, AX, minimize/restore cycle, behavior submenu)
- [x] Normalize notification wording (TrashKey & CutPaste standardized; DockClick intentionally silent for now)
- [x] Standardize About dialogs using shared template

## Phase 4 – Unified Menu (P1)
- [x] Hub status bar menu baseline
  - [x] Overall status header
  - [x] Per-module submenu structure
  - [x] Permissions summary item
  - [x] Preferences placeholder
  - [x] About Hub
  - [x] Quit
- [x] Persist module enabled state via UserDefaults

## Phase 5 – Permissions & Onboarding (P1)
- [x] Launch-time aggregated permission check sheet
- [x] Re-check timer + automatic event tap recovery (basic) & manual recovery menu action
- [x] Graceful deferral path (remind later / don't ask)

## Phase 6 – Build System Unification (P1)
- [x] Optional `--modules` slim build flag
- [-] Login helper target scaffold (future)
- [x] Move icon generation logic into `scripts/icons/` directory
## Phase 7 – Quality & Consistency (P2)
- [x] Enhanced health diagnostics (menu status + manual recovery)
- [x] Central key code & bundle constants file
- [x] Replace print()/manual logs with logging wrapper (legacy mains removed)
- [x] Extract AppleScript string constants / separators (Finder + Dock scripts centralized)
- [ ] Add unit-testable pure functions (conflict naming, path filtering)

## Phase 8 – Extensibility Hooks (P2)
- [x] Document `ModuleProtocol` in `Docs/modules.md`
- [x] Add `TemplateModule.swift` skeleton
- [x] Future dynamic bundle scanning design note

## Phase 9 – Hardening & Edge Cases (P2)
- [ ] CGEventTap failure fallback & user guidance
- [x] Finder not running scenarios (auto launch before selection scripts)
- [x] Dock enumeration retries (basic implemented; consider richer diagnostics)
- [ ] Prevent double actions across modules (global debounce composition)

## Phase 10 – Optional Enhancements (P3)
- [ ] SwiftUI Preferences window (per-module toggles)
- [ ] Usage counters + diagnostics export
- [ ] Export/import JSON settings
- [x] Global "Pause All Modules" toggle
- [ ] Security / sandboxing future notes
  (Moved items implemented: Preferences window, usage counters, export/import, diagnostics export)
- [x] SwiftUI Preferences window (per-module toggles)
- [x] Usage counters + diagnostics export
- [x] Export/import JSON settings
- [x] Security / sandboxing future notes

---
## Completed Quick Wins
1. EventRouter
2. AppleScript + Finder selection utility
3. PermissionsManager skeleton
4. Initial module wrappers (all migrated)
5. Unified build script
6. Advanced DockClick port with minimize/hide cycle
7. Notification rate limiting & standardized title prefix
8. Constants centralization (key codes, bundle IDs)
9. Module submenus & Preferences placeholder
10. Standardized About dialogs helper

---
## Risk / Watch List
- Event ordering & consume vs pass-through interplay across modules
- Finder selection latency around Delete key capture
- Dock geometry after space/monitor changes (retry logic present but can expand)
- Race conditions on rapid cut+paste destination changes
- Accessibility permission prompt timing and user guidance clarity

---
## Constants Centralized
- Key codes: Delete=117, X=7, V=9
- Bundle IDs: Finder=com.apple.finder, Dock=com.apple.dock
- AppleScript list separator: "|"

---
## Definition of Done (Revalidated)
P0: Achieved – Hub launches, 3 modules active, unified tap, features functional (Delete→trash, Dock click minimize/hide/restore, Cut/Paste move), shared logging & menu baseline.
P1 Target: Permissions onboarding sheet, build script extended options, early resiliency improvements.
P2+: Quality, documentation, extensibility & resilience.

(Keep this file updated as tasks evolve.)
