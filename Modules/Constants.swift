import Foundation

// Centralized shared constants to reduce magic numbers/strings.
enum AppConst {
    enum KeyCode {
        static let delete: Int64 = 117
        static let x: Int64 = 7
        static let v: Int64 = 9
    }
    enum BundleID {
        static let finder = "com.apple.finder"
        static let dock = "com.apple.dock"
    }
    enum AppleScript {
        static let listSeparator = "|"
        static let finderSelection = """
            tell application \"Finder\"
                try
                    set selectedItems to selection
                    if (count of selectedItems) = 0 then return \"NO_SELECTION\"
                    set filePaths to {}
                    repeat with currentItem in selectedItems
                        try
                            set itemPath to POSIX path of (currentItem as alias)
                            set end of filePaths to itemPath
                        end try
                    end repeat
                    if (count of filePaths) = 0 then return \"NO_VALID_ITEMS\"
                    set AppleScript's text item delimiters to \"|\"
                    set pathString to filePaths as string
                    set AppleScript's text item delimiters to \"\"
                    return pathString
                on error errMsg
                    return \"ERROR: \" & errMsg
                end try
            end tell
        """
        static let finderCurrentDirectory = """
            tell application \"Finder\"
                try
                    set currentFolder to target of front window
                    return POSIX path of (currentFolder as alias)
                on error errMsg
                    return \"ERROR: \" & errMsg
                end try
            end tell
        """
                static let dockEnumeration = """
                tell application \"System Events\"
                    tell process \"Dock\"
                        set outList to {}
                        try
                            set elems to every UI element of list 1
                            repeat with e in elems
                                try
                                    set p to position of e
                                    set s to size of e
                                    set nm to name of e
                                    set sr to subrole of e
                                    if sr is in {\"AXApplicationDockItem\",\"AXTrashDockItem\"} then
                                        set end of outList to {p,s,nm,sr}
                                    end if
                                end try
                            end repeat
                        end try
                        return outList
                    end tell
                end tell
                """
    }
}
