# Cursor Field Guide — macOS Window & Space Debugging (Sonoma 14 / Sequoia 15)


---

## 🔖 Ontology & Retrieval Keys

| Key Prefix | Theme                                                   |
| ---------- | ------------------------------------------------------- |
| `BUG_`     | Reproducible OS/WindowServer regression with workaround |
| `API_`     | Undocumented or private API signature / usage notes     |
| `PATTERN_` | Proven design or decision sequence                      |
| `TOOL_`    | Third‑party utility cheat‑sheet                         |
| `DBG_`     | Debug/diagnostic technique                              |

Chunk titles follow the pattern `PREFIX_NAME` (e.g. `BUG_FOCUS_STEAL`).

---

## BUG\_FOCUS\_STEAL

**Symptom:** Active window randomly greys‑out; keyboard input vanishes until user re‑clicks. Predominant on multi‑monitor Sonoma‑b1 → Sequoia‑dp2.
**Cause:** WindowServer thread races when updating `kCGWindowAlpha` after space switches.
**Fix Recipe:** Enable focus‑follows‑mouse via AutoRaise *and* force NSWindow to call `makeKeyWindow()` on `NSApplicationDidResignActive`. Eliminates \~90 % incidents.
**Gotchas:** Avoid `.worksWhenModal` panels; they escalate the race.

---

## BUG\_SPACE\_SWITCH\_FAIL\_CGError\_717863

**Symptom:** `CGError(rawValue:717863)` when script or tool issues space move; window flickers but stays put.
**Trigger API:** SkyLight’s `CGSMoveWindowsToManagedSpace` rejects IDs created before Sequoia.
**One‑liner Fix:** Re‑query fresh space IDs via `CGSCopySpaces(0)` immediately before the move; retry once.
**Known Gotchas:** Amethyst ≤0.16 cannot patch; Rectangle patched in 0.72+.

---

## BUG\_CHILD\_COLLECTION\_INHERIT

**Symptom:** Sheet or child panel lingers on prior space after parent moves.
**Fix Recipe:** After `addChildWindow:ordered:`, execute:

```swift
sheet.collectionBehavior = parent.collectionBehavior
DispatchQueue.main.async { parent.addChildWindow(sheet, ordered: .above) }
```

**Notes:** Needed only on macOS 15.0‑15.3 betas.

---

## BUG\_FRAME\_PERSISTENCE\_LOST

macOS 15 drops stored frame for external‑monitor windows after dock re‑plug.
**Fix:** Persist `window.frame` + `screen.localizedName`; on restore, pick best match via `screens.first(where:)` + constrain with `constrainFrameRect(_:to:)`.

---

## BUG\_STAGE\_MANAGER\_FREEZE\_HELP\_VIEWER

Minimising a Help‑viewer window under Stage Manager locks the stage.
**Mitigation:** Tag help window `.auxiliary` *and* `.canJoinAllApplications`.

---

## API\_SKYLIGHT\_CHEATSHEET

```c
// obtain connection
CGSConnectionID CGSMainConnectionID(void);
// list + create spaces
CFArrayRef CGSCopySpaces(CGSConnectionID);
OSStatus CGSSpaceCreate(CGSConnectionID, int opts, CGSSpaceID* outID);
// move windows
OSStatus CGSMoveWindowsToManagedSpace(CGSConnectionID, CFArrayRef windowIDs, CGSSpaceID dest);
```

**Risk:** signature changes each major macOS; wrap via dlsym & version check.

**Stage Manager Note:** Stage Manager respects specific collection behaviors. Windows with `.auxiliary`, `.moveToActiveSpace`, `.stationary`, or `.transient` flags will avoid being displaced as part of a Stage Manager app group. This interaction is not officially documented.

---

## PATTERN\_DISPLAY\_AWARE\_RESTORE

1. Observe `NSApplication.didChangeScreenParametersNotification`.
2. For each open window:

   * If saved `screenID` no longer present → choose new primary.
   * Call `window.setFrame(constrainFrameRect…)` on main queue.
3. Defer restore until first `windowDidChangeScreen`.

---

## PATTERN\_SPACE\_SWITCH\_HANDLE

> Public‑API tiling without CGS.

Create 1×1 transparent NSWindow per discovered space on first entry → keep reference. Activate handle window to jump spaces. Combine with `CGWindowListCopyWindowInfo` for inventory.

---

## PATTERN_FLOATING_PANEL

**Use‑Case:** A non‑activating panel that can appear on all spaces, including over full‑screen apps. Ideal for tool palettes or status windows.
**Fix Recipe:** Subclass `NSPanel` and configure `collectionBehavior` and other properties.

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

---

## PATTERN\_COLLECTION\_FLAGS

| Use‑case                         | collectionBehavior flags                    |
| -------------------------------- | ------------------------------------------- |
| App‑wide floating palette        | `[.canJoinAllSpaces, .fullScreenAuxiliary]` |
| Utility panel that follows focus | `[.moveToActiveSpace, .transient]`          |
| Stage Manager primary win        | `[.primary]`                                |
| Stage Manager auxiliary          | `[.auxiliary]`                              |

**Stage Manager Note:** Stage Manager respects specific collection behaviors. Windows with `.auxiliary`, `.moveToActiveSpace`, `.stationary`, or `.transient` flags will avoid being displaced as part of a Stage Manager app group. This interaction is not officially documented.

---

## TOOL\_ECOSYSTEM\_MAP

| Tool            | Strength                           | SIP?              |
| --------------- | ---------------------------------- | ----------------- |
| Rectangle 0.72+ | Keyboard snap, patched 717863      | No                |
| yabai 5.x       | Tiling & spaces via SkyLight       | **Yes** (partial) |
| AeroSpace       | Re‑implements workspaces w/out CGS | No                |
| DisplayMaid     | Auto‑restore on display change     | No                |

---

## DBG\_XCODE\_VIEW\_DEBUGGER

Shortcut: ⌘‑shift‑I while paused. Look for zero‑size SwiftUI views; inspect auto‑layout on AppKit side.

## DBG\_SYMBOLIC\_BREAKPOINTS

Set at `-[NSWindow windowWillResize:]`, `windowWillEnterFullScreen:` to trap unwanted events.

## DBG\_MAIN\_THREAD\_CHECKER

Crashes with `NSWindow drag regions…` mean off‑main‑thread UI; fix by `DispatchQueue.main.async`.

---

## MODERN\_TILING\_NOTES\_SEQUOIA

* Drag‑to‑edge overlay → margins default on; toggle via Settings > Desktop & Dock.
* Green‑button + Option reveals center‑tile.
* Known Bugs: corner snap misfires; accidental space swipe when hold near edge >400 ms.

---

