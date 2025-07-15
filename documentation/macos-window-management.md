# Troubleshooting macOS spaces and window management on Sonoma and Sequoia

Window management on macOS 14 and 15 presents significant challenges for developers, with widespread focus management bugs, space switching failures, and undocumented API behaviors creating fundamental obstacles to building reliable multi-window applications. These issues represent core regressions from macOS 13 that persist despite developer feedback.

## The focus management crisis disrupting development workflows

**macOS 14 introduced a critical WindowServer bug that randomly steals focus from active windows**, causing typed input to disappear and forcing developers to constantly click to restore focus. This bug, which started in Sonoma Beta 1 and continues through macOS 15, makes coding environments nearly unusable, particularly on multi-monitor setups. **The root cause appears to be a WindowServer process defect** that causes active windows to become grayed out without user action, with focus often switching to background apps like Finder unpredictably.

Developers report that this focus bug persists through clean installs and safe mode, indicating a fundamental system-level issue rather than application-specific problems. The only partial workaround involves third-party tools like AutoRaise that enable focus-follows-mouse behavior, though this doesn't fully resolve the underlying WindowServer instability. The severity of this issue has led many developers to threaten platform migration, as it directly impacts productivity in ways that application-level fixes cannot address.

## Space switching failures and the CGError 717863 problem

**macOS 15 introduced breaking changes to space management APIs**, most notably manifesting as `CGError(rawValue: 717863)` when attempting space transitions. This error, related to "compat aside id" API changes, completely breaks window movement between spaces for major window management tools including Amethyst, yabai, and Rectangle. **The Amethyst developer confirmed that "due to changes Apple has made in macOS 15, Amethyst may no longer be able to support moving windows between native spaces"**, forcing users to adopt alternative solutions.

The technical breakdown reveals that keyboard shortcuts to move windows between spaces now fail with windows flickering but not moving to target spaces. Mission Control space switching triggers collection behavior bugs that leave windows stranded on incorrect spaces. These API changes appear deliberate rather than accidental, suggesting Apple is further restricting programmatic space management without providing public alternatives. The window management community has documented workarounds including gesture-based space switching instead of Mission Control and manual re-attachment of child windows after space changes.

Window positioning problems compound these issues, with NSWindow collection behavior inheritance broken for child windows. Developers must now manually set `sheet.collectionBehavior = self.window.collectionBehavior` because child windows created with `addChildWindow:ordered:` no longer automatically inherit parent collection behavior. Frame persistence also fails across app launches in macOS 15, with external monitor configurations lost on disconnect/reconnect cycles.

## NSWindow collection behaviors and undocumented edge cases

The NSWindow collection behavior system remains unchanged in its API surface but exhibits significantly different runtime behavior between macOS 14 and 15. **Stage Manager now respects specific collection behavior flags**, with windows configured as `.auxiliary`, `.moveToActiveSpace`, `.stationary`, or `.transient` avoiding Stage Manager displacement. This interaction isn't documented in Apple's official resources.

Critical collection behavior combinations for multi-space scenarios include `[.canJoinAllSpaces, .fullScreenAuxiliary]` for floating windows that must appear across all spaces and over full-screen apps, and `[.moveToActiveSpace, .transient]` for auxiliary panels that follow the active space when needed. **The key discovery is that combining behaviors often produces undocumented results** - for instance, `.stationary` combined with `.canJoinAllSpaces` creates conflicts that manifest differently depending on whether Stage Manager is enabled.

Window level interactions with spaces remain consistent, with the hierarchy from `NSWindow.Level.normal` (0) through `NSWindow.Level.screenSaver` (101) unchanged. However, **the compositor behavior in macOS 15 shows different CPU utilization patterns** when managing transparency effects across multiple spaces, suggesting internal optimizations that can affect window rendering performance. Developers report that windows with transparency effects now consume more resources when spanning multiple displays with separate spaces enabled.

## Private APIs remain essential for basic functionality

**Apple provides no public API for fundamental space management operations**, forcing developers to rely on private SkyLight framework functions that disqualify apps from Mac App Store distribution. Essential operations like creating or deleting spaces, moving windows between spaces programmatically, detecting the current space, or even receiving notifications when spaces change all require private APIs like `CGSGetActiveSpace()`, `CGSCopySpaces()`, and `CGSSetWorkspace()`.

The detection of current space remains particularly problematic, with the public `NSWorkspaceActiveSpaceDidChangeNotification` deprecated since macOS 10.6 and the `kCGWindowWorkspace` key removed from `CGWindowListCopyWindowInfo()` results. Developers resort to workarounds including preference file monitoring of `com.apple.spaces`, creating transparent tracking windows per space, or cross-referencing visible windows with known space configurations. **These hacks are fragile and break with OS updates**, as evidenced by the CGError 717863 issue in macOS 15.

Community frustration centers on Apple's decade-long refusal to provide public APIs despite Spaces being a core macOS feature. The private API requirement forces developers into a security compromise - tools like yabai require partial System Integrity Protection disabling and inject scripting additions into Dock.app to access the window server. This creates an untenable situation where professional window management tools cannot be distributed through official channels or used in enterprise environments with security restrictions.

## Proven solutions for multi-space window management

Successful window management implementations follow specific patterns to work around system limitations. **For floating windows that must appear across all spaces**, the configuration requires combining NSPanel usage with specific collection behaviors:

```swift
class FloatingPanel: NSPanel {
    override func awakeFromNib() {
        super.awakeFromNib()
        styleMask.insert(.nonactivatingPanel)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        level = .floating
        hidesOnDeactivate = false
    }
}
```

**Modal dialogs and sheets require special handling** to maintain proper space association. When switching spaces via Mission Control (not trackpad gestures), child windows get stuck on the original space while the parent moves. The workaround involves manually re-attaching sheets after space changes and explicitly setting collection behavior inheritance. For cross-space window behavior, developers implement temporary behavior modifications to force windows to the active space before restoring original settings.

Multi-monitor scenarios demand comprehensive display change detection with automatic window repositioning when configurations change. **The key insight is that window frame settings must be applied after windows become visible** and display detection completes, as immediate frame application often fails silently. Successful implementations store window state independently of Apple's restoration system, which fails to maintain space assignments for third-party applications.

## Third-party tools filling Apple's gaps

The developer ecosystem has produced sophisticated window management tools that work around macOS limitations. **Rectangle** has emerged as the de facto standard, providing keyboard shortcuts, snap areas, and multi-display support through open-source Swift code that serves as a reference implementation. **yabai** offers true tiling window management through binary space partitioning but requires SIP disabling for full functionality. **AeroSpace** takes a novel approach by completely reimplementing spaces as "workspaces" that hide inactive windows outside the visible screen area, acknowledging that Apple's native spaces cannot be properly controlled.

For developers building window management features, **Swindler** provides a type-safe Swift abstraction over accessibility APIs with proper event ordering and race condition handling. The library addresses common issues like phantom windows and provides cached window state for instantaneous reads. Commercial tools like Moom excel at multi-monitor scenarios with automatic layout restoration when display configurations change, while BetterSnapTool and Mosaic provide grid-based positioning systems that complement programmatic approaches.

Real-world implementations show that successful apps combine multiple strategies. Development teams standardize on tools like Rectangle with shared JSON configuration files for consistent layouts. Video editing workflows use Moom for layout restoration combined with BetterSnapTool for quick adjustments during different editing phases. **The pattern emerging is that native Spaces work better for app category organization while third-party window managers handle positioning within spaces**.

## Navigating Apple's documentation void

The developer community has identified systematic documentation gaps that force reliance on trial and error. **Collection behavior edge cases remain undocumented**, with many flag combinations producing unexpected results. The interaction between `NSWindowCollectionBehaviorFullScreenAuxiliary` and spaces lacks clear documentation, leading to inconsistent behavior across different macOS versions. Animation control for space transitions has no documented API, forcing developers to use third-party tools or accept jarring transitions.

Community resources have become essential references, with GitHub issues for projects like yabai, Amethyst, and Rectangle serving as de facto bug tracking systems for macOS window management issues. **Apple Developer Forums show limited activity due to lack of Apple engagement**, pushing discussions to Reddit communities and individual developer blogs that document undocumented behaviors through reverse engineering.

The sentiment across developer communities is one of frustration with Apple's neglect. Despite window management being fundamental to productivity workflows, Apple has maintained radio silence on public API requests spanning over a decade. **The breaking changes in macOS 15 that disabled core functionality in tools like Amethyst suggest Apple is actively hostile to third-party window management** rather than merely neglectful.

## Conclusion

Window management on macOS 14 and 15 represents a critical failure point for developer productivity. The combination of WindowServer focus bugs, space switching API breakages, and complete absence of public APIs creates an environment where building reliable multi-window applications requires extensive workarounds, private API usage, and acceptance of fundamental limitations. Until Apple addresses these core issues, developers must rely on fragile third-party solutions and defensive programming practices that compromise both security and user experience.