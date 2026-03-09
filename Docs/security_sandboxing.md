# Security & Sandboxing Notes

Current app runs unsandboxed to leverage Accessibility & AppleEvents.

## Potential Hardening Steps
1. Codesigning + Notarization with appropriate entitlements (Accessibility client, AppleEvents).
2. Transition to sandbox with `com.apple.security.temporary-exception.apple-events` only if feasible for Finder operations (may limit Dock AX usage).
3. Separate higher-risk automation (AppleScript execution) into helper XPC service with stricter entitlement scope.
4. Validate dynamic modules (future) via signature + hash allow-list.

## Data & Privacy
- No network transmission; all usage stats stay local.
- Exported diagnostics JSON explicitly user-driven.
- Avoid logging file paths beyond last path component (consider future truncation policy).

## Permission Guidance Improvements (Future)
- In-app inline indicators (green/yellow dot) vs relying on notifications.
- “Test Permissions” button to attempt a harmless AX and notification send.

## Threat Model (Simplified)
- Primary risk: malicious third-party module executing arbitrary AppleScript.
- Mitigation: signed module requirement + user confirmation dialog on first load.

These notes will evolve as distribution & dynamic loading features progress.
