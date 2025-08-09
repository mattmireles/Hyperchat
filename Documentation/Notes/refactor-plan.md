## Hyperchat Refactor Plan (Source of Truth)

Owner: Matt / Team  
Status: Draft v1  
Scope: App-level architecture, WebKit lifecycle, window/menu management, local LLM UI, logging, tests

### Goals
- Simpler: reduce god-objects and cross-cutting complexity without removing functionality.
- More reliable: fewer race conditions and WebKit pitfalls; predictable activation policy.
- Maintain behavior: same features, URLs, automation, windows, tests still pass.

### Targets (by file/module)

1) Service orchestration
- Current: `ServiceManager.swift` (~2,035 LOC) combines:
  - WebView creation, sequential loading, prompt routing, crash recovery, per-service delegates, notifications, browser controller handoff, logging and favicon logic.
- Plan: split into focused components; public API remains same.

Refactors
- ServiceRegistry
  - Responsibility: holds `activeServices`, `webServices` map, lookups and lifecycle bookkeeping.
  - Move: web/local registry maps, `findServiceId(for:)`, `getAllServiceManagers()` (global registry).
- LoadingQueue
  - Responsibility: sequential webview loading, delays, timers, state queue.
  - Move: `serviceLoadingQueue`, `loadNextServiceFromQueue()`, timing constants (only the loading ones).
- PromptRouter
  - Responsibility: new chat (URL param) vs reply-to-all (paste) execution.
  - Move: `URLParameterService.executePrompt`, `ClaudeService.executePrompt` into router invocations; keep service-specific code in service classes.
- CrashRecovery
  - Responsibility: `webViewWebContentProcessDidTerminate(_:)` and forced reload.
  - Keep: same delay and reload behavior, extracted into its own type for reusability.
- WebViewFactory (keep)
  - Continue to be the only constructor for non-local `WKWebView`; retains shared `WKProcessPool` and logging scripts.

Citations
```1965:2011:Sources/Hyperchat/ServiceManager.swift
func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    ...
    self.loadDefaultPage(for: service, webView: webService.webView, forceReload: true)
}
```
```1547:1549:Sources/Hyperchat/ServiceManager.swift
extension WKProcessPool {
    static let shared = WKProcessPool()
}
```

2) Window and layout
- Current: `OverlayController.swift` (~1,782 LOC) manages windows, layout, loading overlays, hibernation, focus state, event observation, building browser views and local views.
- Plan: split by concern and make associations weak to avoid retain-cycles.

Refactors
- WindowRegistry
  - Responsibility: create/track windows, be delegate entry point, expose counts/queries.
  - Change mapping types to weak-key maps (`NSMapTable<NSWindow, T>`).
- LayoutManager
  - Responsibility: build stack view, constraints, spacing, equal heights; stable interface for re-layout.
- LoadingOverlay
  - Responsibility: typewriter and fade-out logic; timeouts and timers isolated from business logic.
- HibernationManager
  - Responsibility: snapshot capture/restore and calling `ServiceManager.pauseAllWebViews()` / `resumeAllWebViews()` safely.
- ViewProvider (new)
  - Responsibility: given `AIService` and the needed dependencies, return an `NSView` for local or web content, so `OverlayController` doesn’t branch on backend type.
  - Keep: local services use `LocalChatView` (SwiftUI in `NSHostingController`); web services use `BrowserViewController.view` created around an injected `WKWebView`.

Citations
```751:820:Sources/Hyperchat/OverlayController.swift
private func setupBrowserViews(...){
    // Builds local hosting views and BrowserViews, adds to NSStackView
}
```

3) Activation policy and menus
- Current: canonical dual-mode methods exist, but a legacy/deprecated method still called by `OverlayController`.
- Plan: remove deprecated path, use only canonical switching methods driven by window events.

Refactors
- Keep these methods and make them the only code path:
```651:666:Sources/Hyperchat/AppDelegate.swift
func switchToRegularMode() { ... NSApp.setActivationPolicy(.regular) ... setupMainMenu() }
```
```668:683:Sources/Hyperchat/AppDelegate.swift
func switchToAccessoryMode() { ... NSApp.setActivationPolicy(.accessory) ... NSApp.mainMenu = nil }
```
- Remove `updateActivationPolicy(...)` and replace any callers with the above.
```685:698:Sources/Hyperchat/AppDelegate.swift
public func updateActivationPolicy(source: String = "unknown") { /* delete this method */ }
```
- `MenuBuilder` remains in its own type; consider moving it out of `AppDelegate.swift` to `MenuBuilder.swift` for clarity.

4) Local LLM UI surface
- Current: `LocalChatView.swift` is a clean `WKWebView` hosted SwiftUI view with a JS bridge to `InferenceEngine`.
- Plan: keep as is; let `ViewProvider` construct it for local services to keep `OverlayController` lean.

Citation
```121:138:Sources/Hyperchat/LocalChatView.swift
func createWebView() -> WKWebView { ... userContentController.add(self, name: "localLLM") ... }
```

5) WebKit surface
- Current: non-local web views created by `WebViewFactory` with `WKProcessPool.shared`, logging scripts, and UA handling.
- Plan: enforce factory-only creation by removing ad-hoc initialization elsewhere; keep LocalChatView’s custom config for local-only HTML.

Citation
```146:179:Sources/Hyperchat/WebViewFactory.swift
func createWebView(for service: AIService) -> WKWebView { ... configuration.processPool = WKProcessPool.shared ... }
```

6) Logging
- Current: heavy `print` usage spread across modules; `WebViewLogger` exists for web logs.
- Plan: add `Logger` facade (OSLog-backed), categories: web, ui, service, window. Replace hot-path prints; keep debug gated logs.

7) Persistence
- Current: `SettingsManager` uses `UserDefaults.synchronize()` unnecessarily.
- Plan: remove `.synchronize()` to reduce I/O churn; keep everything else.

Citation
```51:57:Sources/Hyperchat/SettingsManager.swift
userDefaults.set(encoded, forKey: servicesKey) // remove synchronize
```

8) Notifications vs Combine
- Current: mixed `NotificationCenter` + Combine publishers.
- Plan: restrict global events to NotificationCenter; prefer typed subjects for internal modules (e.g., focus, loading, hibernation).

### Phased execution

Phase 0: No-op cleanup (1 day)
- Remove `synchronize()` calls.
- Delete `updateActivationPolicy(...)`; update callers in `OverlayController` to call `switchToRegularMode`/`switchToAccessoryMode` as appropriate.
- Move `MenuBuilder` into `Sources/Hyperchat/MenuBuilder.swift` (import-correct).

Phase 1: ViewProvider integration (1–2 days)
- Create `Sources/Hyperchat/ViewProvider.swift`.
- Have `OverlayController` call `ViewProvider` when assembling views.
- Keep injection points for web views coming from `ServiceManager` to avoid factory duplication.

Phase 2: Split ServiceManager (3–4 days)
- Extract `LoadingQueue`, `PromptRouter`, `CrashRecovery`, `ServiceRegistry` into new files under `Sources/Hyperchat/Services/`.
- Keep public interface on `ServiceManager` intact; delegate internally.

Phase 3: Split OverlayController (3–4 days)
- Extract `WindowRegistry`, `LayoutManager`, `LoadingOverlay`, `HibernationManager` into `Sources/Hyperchat/UI/Overlay/`.
- Convert window maps to `NSMapTable` weak-key stores.

Phase 4: Logging consolidation (1 day)
- Add `Logger.swift`. Replace high-churn `print` in `ServiceManager`, `OverlayController`, `AppDelegate`

## Progress (Keep Notes on Progress so far below)

- 2025-08-09 – Phase 0 completed:
  - Removed `UserDefaults.synchronize()` calls in `SettingsManager.swift` (saveServices, analytics, onboarding setters).
  - Deleted deprecated `updateActivationPolicy(...)` from `AppDelegate.swift` and updated all callers.
  - Replaced callers in `OverlayController.swift` to use `switchToRegularMode()`/`switchToAccessoryMode()` based on window count.
  - Extracted `MenuBuilder` into new file `Sources/Hyperchat/MenuBuilder.swift` and updated project to include it.
  - Verified a clean build in Debug configuration.

- 2025-08-09 – Phase 1 completed:
  - Added `Sources/Hyperchat/ViewProvider.swift` to centralize view creation for services (local vs web).
  - Updated `OverlayController.setupBrowserViews(...)` to use `ViewProvider` instead of branching on backend type.
  - Web services continue to use pre-created WebViews from `ServiceManager.webServices` (no factory duplication).
  - Preserved controller tracking: updates `windowServiceManager.browserViewControllers` and `localViewControllers`.
  - Project file updated; verified Debug build succeeds.

- 2025-08-09 – Phase 2 completed:
  - Extracted `ServiceRegistry.swift`, `LoadingQueue.swift`, `CrashRecovery.swift`, and `PromptRouter.swift` into `Sources/Hyperchat/Services/` and integrated into target.
  - Updated project to include `ViewProvider.swift` reference for OverlayController usage.
  - Verified Debug build succeeds for the app target. Test targets require team signing and were not run.