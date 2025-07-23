### Field Manual — Stabilizing Hybrid AppKit, SwiftUI, and WKWebView Layouts

---

\## 1  Known Failure Modes & Root Causes

| Symptom                                                      | Real Cause                                                                                                                         | Fix Anchor         |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| **Overlay shrinks to ≈15 × 15 px at lower‑left**             | NSStackView resolves ambiguous size **before** WKWebView reports one (out‑of‑process); `intrinsicContentSize == .zero ⇒ collapse`. | §3 Wrapper Pattern |
| **Border never tracks per‑view focus—only window key state** | No JS→native bridge; focus events lost; overlay hit‑test region desynced by `NSHostingView` bug.                                   | §4 Focus Pipeline  |
| **`convert(_:to:)` returns origin‑only rect**                | Flipped SwiftUI coords inside unflipped AppKit; `NSHostingView` draws OK but keeps stale (0,0) event frame.                        | §2 Diagnostics     |

Edge cases

* `.frame()` on the SwiftUI representable freezes resizing (esp. fullscreen).
* Multiple WKWebViews ⇒ process explosion; **share one `WKProcessPool`.**
* Child‑window overlays bypass all NSView layer bugs **but cost perf.**

---

\## 2  Rapid Diagnostics

* **Visual origin overlay** – draw red/green axes at (0,0) of suspect views.
* **Stepwise conversion** – `v.convert(r, to:nil)` → `window.convertToScreen` and log.
* **SwiftUI diff** – `po Self._printChanges()` at a breakpoint.
* **Layout timing** – break on `-[NSView layout]` / `layoutSubtreeIfNeeded`.

---

\## 3  Bullet‑proof Layout: *Wrapper View Pattern* (99 % of bugs vanish)

```swift
// 1. Container managed by NSStackView
let wrapper = NSView()
wrapper.translatesAutoresizingMaskIntoConstraints = false

// 2. Web view (no Auto Layout!)
let web = WKWebView(frame: .zero, configuration: cfg)
web.autoresizingMask = [.width, .height]      // old‑school fill
wrapper.addSubview(web)

// 3. Overlay
let border = NSHostingView(rootView: FocusIndicator(model))
wrapper.addSubview(border)

// 4. Pin overlay → wrapper (regular Auto Layout)
NSLayoutConstraint.activate([
    border.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
    border.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
    border.topAnchor.constraint(equalTo: wrapper.topAnchor),
    border.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
])

// 5. Add wrapper to stackView
stackView.addArrangedSubview(wrapper)
```

*Never* set `translatesAutoresizingMaskIntoConstraints = false` on the WKWebView. NSStackView sees only the wrapper → stable size; `autoresizingMask` keeps the web view in sync.

\### Flipped‑coordinate override (when needed)

```swift
class FlippedView: NSView {  // One‑liner fix
    override var isFlipped: Bool { true }
}
```

Attach overlay under a flipped ancestor when `NSHostingView` hits the coord‑sync bug.

\### Alternatives (use only if wrapper fails)

1. **Manual KVO frame sync** – works, but risks recursion + jank.
2. **Child‑window overlay** – heavyweight but bullet‑proof over all layers.

```swift
let borderWin = NSWindow(contentRect: .zero,
                         styleMask: .borderless,
                         backing: .buffered,
                         defer: false)
borderWin.isOpaque = false
borderWin.backgroundColor = .clear
borderWin.ignoresMouseEvents = true
parentWin.addChildWindow(borderWin, ordered: .above)
// Update borderWin.frame inside wrapper.layout()
```

---

\## 4  Focus Tracking Pipeline (leak‑free & SPA‑safe)

\### 4.1  Weak‑proxy handler (breaks retain cycle)

```swift
class ScriptProxy: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(_ d: WKScriptMessageHandler) { delegate = d }
    func userContentController(_ u: WKUserContentController,
                               didReceive m: WKScriptMessage) {
        delegate?.userContentController(u, didReceive: m)
    }
}

let ucc = WKUserContentController()
ucc.add(ScriptProxy(coordinator), name: "focus")
cfg.userContentController = ucc
```

*Fallback (legacy code)* – if you **can’t** use the proxy, call `removeScriptMessageHandler(forName:"focus")` in `viewWillDisappear` to break the cycle manually.

\### 4.2  ObservableObject + SwiftUI border

```swift
final class WebFocus: ObservableObject { @Published var isFocused = false }

struct FocusIndicator: View {
    @ObservedObject var model: WebFocus
    var body: some View {
        Rectangle()
            .stroke(model.isFocused ? Color.accentColor : .clear, lineWidth: 3)
            .animation(.easeInOut(duration: 0.2), value: model.isFocused)
    }
}
```

\### 4.3  JavaScript (bubbles, survives SPA **and** back/forward)

```javascript
(function () {
  const send = f => window.webkit?.messageHandlers.focus?.postMessage({ isFocused: f });
  const hook = (t, fn) => document.addEventListener(t, fn, true);

  hook('focusin',  () => send(true));
  hook('focusout', () => send(false));

  // SPA soft nav
  ['pushState', 'replaceState'].forEach(fn => {
    const orig = history[fn];
    history[fn] = function () {
      const r = orig.apply(this, arguments);
      send(document.hasFocus());
      return r;
    };
  });
  window.addEventListener('popstate', () => send(document.hasFocus()));

  // Initial check
  if (document.hasFocus() && document.activeElement !== document.body) send(true);
})();
```

Inject **once** at `documentEnd` via `WKUserScript` *and* re‑inject in `webView(_:didFinish:)` for belt‑and‑suspenders.

\### 4.4  Swift message handler

```swift
func userContentController(_ u: WKUserContentController,
                           didReceive m: WKScriptMessage) {
    guard let d = m.body as? [String: Any],
          let f = d["isFocused"] as? Bool else { return }
    DispatchQueue.main.async { model.isFocused = f }
}
```

---

\## 5  Performance & Hard‑Won Tips

| Tweak                                                                                                          | Why / When                                       |
| -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| **Shared `WKProcessPool`**                                                                                     | Prevent 2 × WKWebViews ⇒ 5 processes.            |
| `cfg.suppressesIncrementalRendering = true`                                                                    | Favor smooth final paint over progressive flash. |
| Avoid `.offset()` / `.position()` on hosted SwiftUI view inside `NSHostingView`                                | Triggers hit‑test desync (macOS 13‑14).          |
| If overlay misaligns during window resize, call `wrapper.layoutSubtreeIfNeeded()` in `windowDidEndLiveResize`. |                                                  |

---

\## 6  Release Checklist

* [ ] Wrapper pattern in place (no Auto Layout on `WKWebView`).
* [ ] Overlay pinned to wrapper, not web view.
* [ ] Weak proxy breaks `WKScriptMessageHandler` cycle *or* handler removed manually.
* [ ] `focusin` / `focusout` JS injected + re‑injected; `popstate` handled.
* [ ] Origins visualized; flipped mismatch resolved.
* [ ] Shared `WKProcessPool`; no runaway processes.

---

\## TL;DR
*Isolate the web view, pin the overlay to a stable wrapper, use a weak‑proxy message handler (or remove it), listen for bubbling focus events **plus** `popstate`, reinject after every nav, and share your `WKProcessPool`. Do that and the border stays flush, tint flips per‑tab, and your memory graph stays green.*
