# macOS App Development Standards & Approach

## 🎯 Development Philosophy

I build **production-ready macOS applications** that are polished, professional, and user-friendly. Every app should feel like it belongs in the macOS ecosystem with native UI patterns and expected functionality.

## 📁 Project Structure Standards

Every macOS app project must include these core files:

### Required Files:
- **`main.swift`** - Single-file Swift application with comprehensive header
- **`Info.plist`** - Complete app bundle metadata 
- **`build.sh`** - Automated build script with icon generation
- **Auto-generated icon** - Professional .icns file created programmatically

### File Organization:
```
project/
├── main.swift          # Main application code
├── Info.plist          # App bundle configuration
├── build.sh            # Automated build script
└── build/              # Generated during build
    └── AppName.app/    # Final application bundle
```

## 💻 Code Quality Standards

### Header Documentation:
Every `main.swift` must start with:
```swift
/*
 * AppName - Brief Description
 * 
 * Created by: mac (Your Name Here)
 * Date: [Current Month] 2025
 * Version: 1.0
 * 
 * Description: Detailed explanation of what the app does,
 * its purpose, and how it works.
 * 
 * Features:
 * - Feature 1 with brief explanation
 * - Feature 2 with brief explanation
 * - Feature 3 with brief explanation
 * 
 * License: Personal use - Created for learning and productivity
 */
```

### Code Organization:
- Clean, well-commented Swift code
- Proper error handling with detailed logging
- Debug output that helps troubleshoot issues
- Modular functions with clear responsibilities

## 🎨 Visual & UX Standards

### Icons:
- **Always include a custom icon** - never ship without one
- Icons generated programmatically in build script using Swift/CoreGraphics
- Professional gradients, modern design aesthetic
- All required sizes (16x16 to 1024x1024) automatically generated
- Converted to .icns format during build process

### Menu Bar Integration (when applicable):
- Clean, intuitive menu structure
- Status indicators showing app state
- Professional menu organization with separators
- Consistent iconography and text

## 🔧 Essential App Features

### Must-Have Features for Every App:
1. **Login Items Management**
   - "Add to/Remove from Login Items" toggle
   - Smart detection of current status
   - User feedback via notifications

2. **Professional About Dialog**
   - App name, version, and creator
   - Feature list and usage instructions
   - Required permissions explanation
   - Copyright notice
   - Optional GitHub/project link

3. **Menu Structure Template:**
   ```
   ├── [App Status Indicator]        [Non-clickable status]
   ├── ─────────────────────────────  [Separator]
   ├── [Primary App Functions]       [Main features]
   ├── ─────────────────────────────  [Separator]
   ├── Add to/Remove from Login Items [Auto-start toggle]
   ├── ─────────────────────────────  [Separator]
   ├── About [AppName]               [Info dialog]
   ├── ─────────────────────────────  [Separator]
   └── Quit [AppName]                [Exit with cleanup]
   ```

## 🚀 Build Process Standards

### Automated Build Script (`build.sh`):
- **Icon Generation**: Programmatically create all icon sizes
- **Compilation**: Swift compilation with proper error handling
- **Bundle Creation**: Complete .app bundle with all resources
- **Permission Setup**: Executable permissions and signing preparation
- **Cleanup**: Remove temporary files, keep only final .app
- **User Feedback**: Clear build status and success confirmation

### Build Script Features:
```bash
#!/bin/bash
# Professional header with creator info
# Clean previous builds
# Generate icons programmatically 
# Compile Swift code with error checking
# Create proper app bundle structure
# Include all resources (icons, plists)
# Set proper permissions
# Clean up temporary files
# Provide clear success/failure feedback
```

## 📋 Info.plist Standards

### Required Entries:
```xml
- CFBundleExecutable: App executable name
- CFBundleIdentifier: Unique bundle ID (com.yourname.appname)
- CFBundleName: App display name
- CFBundleDisplayName: User-visible name
- CFBundleVersion: Build version
- CFBundleShortVersionString: User-visible version
- CFBundleIconFile: Icon filename (without extension)
- NSHumanReadableCopyright: Copyright notice
- LSUIElement: true (for menu bar apps)
- NSAppleScriptEnabled: true (if using AppleScript)
- NSAppleEventsUsageDescription: Clear permission explanation
```

## 🛡️ Permission Handling

### Accessibility & Automation:
- Check permissions before attempting to use them
- Provide clear prompts and explanations
- Handle permission failures gracefully
- Guide users through permission setup process

### Permission Types to Consider:
- Accessibility (for global key monitoring)
- Automation (for controlling other apps)
- Notifications (for user feedback)
- Screen Recording (for screenshot apps)
- File System Access (for file manipulation apps)

## ⚡ Advanced System Integration

### Event Monitoring Approaches:
**For Simple Key Detection:**
```swift
// Basic NSEvent monitoring (read-only)
NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
    // Can observe but not block events
}
```

**For Event Interception & Blocking:**
```swift
// CGEventTap for true event interception
let eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,  // Get events FIRST
    options: .defaultTap,        // Can filter/block events
    eventsOfInterest: CGEventMask(eventMask),
    callback: eventCallback,
    userInfo: contextPtr
)
```

### Critical Timing Considerations:
- **Race Conditions**: System apps often process events faster than your monitoring
- **Event Ordering**: Use `.headInsertEventTap` to get events before other apps
- **State Management**: Capture state before system changes it
- **Debouncing**: Prevent rapid-fire event processing with time checks

### AppleScript Integration:
- Always include comprehensive error handling
- Use proper variable names (avoid reserved keywords like `item`)
- Test scripts independently before integration
- Handle edge cases (empty selections, permissions, etc.)

### System Event Patterns:
```swift
// Pattern for complex system integration
func handleSystemEvent() {
    // 1. Capture current state immediately
    let currentState = captureState()
    
    // 2. Process with error handling
    guard processState(currentState) else { return }
    
    // 3. Block/modify original event if needed
    return blockOriginalEvent ? nil : passThrough
}
```

## 🎯 User Experience Priorities

### Core UX Principles:
1. **Intuitive Operation** - Users should understand the app immediately
2. **Clear Feedback** - Always confirm actions with notifications/status updates
3. **Error Resilience** - Handle edge cases gracefully with helpful messages
4. **Native Feel** - Use standard macOS UI patterns and behaviors
5. **Professional Polish** - Every detail should feel finished and intentional

### Notification Standards:
- Success confirmations for completed actions
- Error messages with actionable guidance
- Status updates for long-running operations
- Consistent tone and messaging style

## 🔬 Development Approach

### Problem-Solving Mindset:
- **Identify Real Needs**: Build apps that solve actual productivity problems
- **Research Native Solutions**: Understand how macOS handles similar functionality
- **Implement Properly**: Use appropriate APIs and follow macOS conventions
- **Test Thoroughly**: Verify functionality across different scenarios
- **Polish Extensively**: Refine until it feels like a commercial app

### Advanced Debugging Strategies:
- Extensive debug logging for troubleshooting complex interactions
- Event timing analysis for race condition identification
- State capture at critical moments
- Permission validation at multiple checkpoints
- AppleScript result verification and parsing

### Code Quality Focus:
- Extensive debug logging for troubleshooting
- Proper error handling with user-friendly messages
- Clean, readable code structure
- Comprehensive comments explaining complex logic
- Modular design for maintainability

## 🏗️ Architecture Patterns

### System Integration Apps:
```swift
class SystemIntegrationApp {
    // Core system interfaces
    var eventMonitoring: EventMonitoringProtocol
    var stateManagement: StateManagerProtocol
    var userInterface: UIManagerProtocol
    
    // Critical patterns
    func handleSystemEvent() {
        // 1. Immediate state capture
        // 2. Validation and processing  
        // 3. User feedback
        // 4. System state management
    }
}
```

### Menu Bar App Template:
- Status item with dynamic icons
- Contextual menu with app controls
- Permission management integration
- Graceful startup/shutdown handling

## 📦 Deployment Ready

### Final App Characteristics:
- **Self-Contained**: No external dependencies
- **Professional Appearance**: Custom icon, proper branding
- **User-Friendly**: Clear instructions and intuitive operation  
- **Robust**: Handles errors and edge cases gracefully
- **Native Integration**: Feels like it belongs on macOS
- **Production Quality**: Ready for daily use without issues
- **System-Aware**: Properly integrates with macOS security and permissions

## 🚀 Advanced Integration Examples

### TrashKey Project Lessons:
- **Event Interception**: CGEventTap for blocking system events
- **Timing Challenges**: Capturing state before system processes events
- **Multi-App Coordination**: Working with Finder's internal state
- **Permission Complexity**: Accessibility requirements for system-level access
- **State Synchronization**: Maintaining consistency between app and system

### Common Integration Patterns:
1. **File System Operations**: Use FileManager with proper error handling
2. **Inter-App Communication**: AppleScript for system app control
3. **Global Event Monitoring**: CGEventTap for true system integration
4. **Permission Management**: Proactive checking and user guidance
5. **State Management**: Immediate capture before system changes

---

## 🚀 Quick Start Template

When starting a new app project, use this approach:

1. **Define the Problem**: What specific productivity issue does this solve?
2. **Research System APIs**: What macOS frameworks and permissions are needed?
3. **Design the Solution**: How should the user interact with this functionality?
4. **Plan the Implementation**: What are the technical challenges and timing considerations?
5. **Create the Structure**: Set up main.swift, Info.plist, build.sh
6. **Implement Core Features**: Build the primary functionality first
7. **Add Standard Features**: Login items, About dialog, proper menus
8. **Handle Edge Cases**: Test with complex scenarios and error conditions
9. **Generate Professional Assets**: Automated icon creation and build process
10. **Test & Polish**: Ensure it works reliably in real-world scenarios

The goal is always to create apps that users will want to keep running and recommend to others.