# Claude.ai Integration Notes

## 1. Technical Architecture Overview

Based on analysis of the production website, Claude.ai is built on a modern web stack. Understanding this stack is key to diagnosing issues and developing reliable automation scripts.

*   **Core Framework:** **Next.js**, a server-rendering React framework. This is evident from `/_next/static/...` asset paths.
*   **UI Library:** **React**. The entire front-end is component-based.
*   **Styling:** **Tailwind CSS**, identified by the heavy use of utility classes (`flex`, `items-center`, etc.).
*   **UI Components:** **Radix UI**, an unstyled, accessible component library for React. This is indicated by `radix-:` prefixed element IDs and `data-state` attributes.
*   **Text Editor:** **Tiptap/ProseMirror**, a rich-text editor toolkit that powers the `contenteditable` `div` used for chat input, not a standard `<textarea>`.
*   **Third-Party Services:**
    *   **Stripe:** For payment processing.
    *   **Intercom:** For customer support chat.
    *   **Google reCAPTCHA:** For bot detection.
    *   **Amplitude:** For product analytics.

## 2. Key Automation Challenges

The modern tech stack presents significant challenges for browser automation:

*   **Dynamic & Obfuscated Class Names:** CSS classes like `__variable_dcab32` are dynamically generated and change between builds, making them unusable for stable selectors.
*   **Complex DOM Structure:** The UI is a deeply nested tree of `div` elements, making robust XPath or CSS selectors difficult to write and maintain.
*   **Rich-Text Editor Input:** The chat input is a `contenteditable` `div` managed by Tiptap/ProseMirror. Automating text entry requires dispatching a sequence of keyboard and composition events to correctly update the editor's state, as simply setting an element's `value` is not possible.
*   **Dynamic Content & State:** Many UI elements are rendered conditionally based on application state (e.g., `data-state` attributes from Radix). Automation scripts must include explicit waits to ensure elements are present and interactable.
*   **Iframes:** Third-party services like Stripe and Intercom are embedded in `iframes`, which requires switching the automation driver's context to interact with them.

## 3. Historical Implementation Notes & Solutions

The following sections document specific problems encountered during development and the solutions that were implemented.

### 3.1. Service Activation Method
- **Other services** (ChatGPT, Perplexity, Google): Use URL parameters (`?q=prompt`)
- **Claude**: Uses clipboard paste automation due to lack of URL parameter support

### 3.2. Sequential Execution Implementation
**Problem**: Clipboard race conditions when multiple services executed in parallel
- Multiple services writing to `NSPasteboard` simultaneously
- Claude receiving "invalid UUID" errors
- Text injection failing sporadically

**Solution**: Service categorization in `ServiceManager.swift:1078-1174`
```swift
// Categorize services by execution method to prevent clipboard conflicts
let urlParameterServices = activeServices.filter { service in
    switch service.activationMethod {
    case .urlParameter: return true
    case .clipboardPaste: return false
    }
}

let clipboardServices = activeServices.filter { service in
    switch service.activationMethod {
    case .urlParameter: return false
    case .clipboardPaste: return true
    }
}

// Execute clipboard services sequentially to prevent race conditions
executeClipboardServicesSequentially(clipboardServices, prompt: prompt, replyToAll: replyToAll, currentIndex: 0)
```

### 3.3. JavaScript Return Type Issues
**Problem**: WebKit JavaScript execution errors
- Error: "JavaScript execution returned a result of an unsupported type"
- Occurred when JavaScript tried to return complex objects or Promises

**Initial Solution**: Changed from `JSON.stringify(report)` to simple boolean returns
```javascript
// Fixed return type for WebKit compatibility  
return report.textInserted && (report.enterDispatched || report.submitButtonFound);
```

**Final Solution**: Fixed async/await return type AND diagnostic response issues
- **Phase 1**: Removed `async` from function declaration: `(function() {` instead of `(async function() {`
- **Phase 1**: Replaced `await navigator.clipboard.writeText()` with synchronous `document.execCommand('insertText')`
- **Phase 2**: Fixed diagnostic response format: Changed `return boolean` to `return JSON.stringify(report)` for Swift parser compatibility
- **Result**: Eliminated WebKit "unsupported type" errors and "Invalid diagnostic response" issues

### 3.4. Claude's ProseMirror Editor
**Technical Requirements**:
- Uses ProseMirror contenteditable div, not standard textarea
- Requires specific event sequence for React state updates
- Needs composition events for proper text insertion

**Selectors** (updated for current Claude.ai structure):
```javascript
const selectors = [
    'div[aria-label="Write your prompt to Claude"].ProseMirror',  // Most specific
    'div.ProseMirror[contenteditable="true"][role="textbox"]',    // Structural match
    'div[contenteditable="true"].ProseMirror.break-words',        // Class combination
    'div[contenteditable="true"][aria-label*="Claude"]',          // Aria label fallback
    'div[contenteditable="true"][role="textbox"]',                // Role-based fallback
    'div[contenteditable="true"]'                                 // Last resort
];
```

### 3.5. Submit Button Targeting
**Problem**: Sidebar expansion instead of submission
- Broad selectors were matching sidebar buttons
- Buttons far from input field were being clicked

**Solution**: Spatial validation to target buttons near input field
```javascript
// Check if button is positioned near the input field
const isNearInput = Math.abs(rect.bottom - inputRect.bottom) < 100; // Within 100px vertically
const isRightOfInput = rect.left >= inputRect.right - 50; // At or to the right of input

if (rect.width > 0 && rect.height > 0 && !element.disabled && (isNearInput || isRightOfInput)) {
    // This is likely the correct submit button
}
```

**Updated Submit Selectors** (for modern Radix UI):
```javascript
const submitSelectors = [
    // Modern Radix UI button patterns (based on analysis)
    'button[data-state]:has(svg)',  // Radix buttons have data-state attributes
    'button[aria-label]:has(svg):not([aria-label*="menu"]):not([aria-label*="sidebar"])',  // Avoid menu buttons
    
    // Traditional Claude patterns  
    'button[aria-label*="Send message"]',
    'button[aria-label*="Send"]',
    'button[data-testid="send-button"]',
    
    // Icon-based targeting (more reliable than text)
    'button:has(svg[viewBox*="24"]):has(path[d*="M"])',  // SVG with path (send icon)
    'button:has(svg):not([disabled])',  // Any enabled button with SVG
    
    // Form and structural selectors
    'button[type="submit"]',
    'form button:last-child:not([disabled])',
    
    // Radix role-based fallbacks
    '[role="button"][data-state]:has(svg)',
    '[role="button"]:not([aria-label*="menu"]):not([aria-label*="sidebar"]):has(svg)',
    
    // Generic fallbacks (last resort)
    'button:not([disabled]):has(svg)',
    'button:not([disabled])[aria-label*="Send"]'
];
```

### 3.6. Timing Requirements
**Claude-specific delays**:
- `claudePasteDelay: 1.5` seconds - Wait for Claude's React app to initialize
- Additional delays for page load detection and script execution

### 3.7. Text Insertion Methods (Evolution)

**Original method (deprecated)**: Clipboard paste via `navigator.clipboard.writeText()`
```javascript
if (navigator.clipboard && navigator.clipboard.writeText) {
    await navigator.clipboard.writeText(escapedPrompt);
    document.execCommand('paste');
}
```

**Previous fallback (insufficient)**: Direct DOM manipulation with composition events
```javascript
input.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true }));
input.dispatchEvent(new CompositionEvent('compositionupdate', { data: escapedPrompt, bubbles: true }));
document.execCommand('insertText', false, escapedPrompt);
input.dispatchEvent(new CompositionEvent('compositionend', { data: escapedPrompt, bubbles: true }));
```

**Current solution**: ProseMirror/Tiptap-aware insertion with React state synchronization
```javascript
// Method 1: Try Tiptap API if available
if (tiptapEditor && tiptapEditor.commands) {
    tiptapEditor.commands.clearContent();
    tiptapEditor.commands.insertContent(escapedPrompt);
}

// Method 2: Simulate realistic typing with proper event sequence
input.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true }));
input.dispatchEvent(new CompositionEvent('compositionupdate', { data: text, bubbles: true }));
document.execCommand('insertText', false, text);
input.dispatchEvent(new CompositionEvent('compositionend', { data: text, bubbles: true }));

// Trigger React state updates
const reactEvent = new Event('input', { bubbles: true });
reactEvent.simulated = true;
input.dispatchEvent(reactEvent);

// Allow React state to update before submission attempt
setTimeout(() => { /* submission logic */ }, 200);
```

## 4. Current Status ✅ (2024/2025)

**Fully Operational:**
- ✅ **Text injection**: Synchronous `document.execCommand('insertText')` method working
- ✅ **Sequential execution**: Clipboard race conditions eliminated 
- ✅ **Submit automation**: Spatial validation prevents wrong button clicks
- ✅ **Multi-service support**: Works alongside ChatGPT, Perplexity, Google
- ✅ **WebKit compatibility**: All async operation issues resolved
- ✅ **Diagnostic reporting**: JSON format parsing working correctly
- ✅ **Service loading**: Proper initialization and favicon extraction
- ✅ **Build success**: No compilation or runtime errors

### Recent Improvements (2024/2025)

#### Sequential Service Loading (`ServiceManager.swift`)
- **Problem**: Multiple WebViews starting simultaneously caused GPU process conflicts
- **Solution**: Services load one at a time via sequential queue
- **Implementation**: 
  ```swift
  /// Services are loaded sequentially to prevent:
  /// - GPU process conflicts (multiple WebViews starting simultaneously)
  /// - Memory spikes from parallel loading  
  /// - Race conditions in WebKit initialization
  private func loadNextServiceFromQueue() {
      // Load one service at a time with 0.5s delay
  }
  ```

#### Enhanced Clipboard Service Execution
- **Problem**: Multiple clipboard services conflicting when executed in parallel
- **Solution**: Sequential execution with completion handlers
- **Implementation**:
  ```swift
  /// Execute clipboard services sequentially to prevent race conditions
  executeClipboardServicesSequentially(clipboardServices, prompt: prompt, replyToAll: replyToAll, currentIndex: 0)
  ```

#### Improved JavaScript Diagnostics  
- **Problem**: "Invalid diagnostic response" errors from Swift parser
- **Solution**: Return JSON string format instead of boolean
- **Before**: `return report.textInserted && (report.enterDispatched || report.submitButtonFound);`
- **After**: `return JSON.stringify(report);`
- **Location**: `JavaScriptProvider.swift:605`

## 5. Testing Commands
```bash
# Build and test
xcodebuild -scheme Hyperchat -configuration Debug build

# Monitor logs for Claude-specific issues
grep -E "\[Claude\]|Claude:" /path/to/logs
```

## 6. Related Files
- `ServiceManager.swift` - Sequential execution and service loading logic
  - Lines 1078-1174: Sequential clipboard execution 
  - Lines 200-300: Sequential service loading queue
- `JavaScriptProvider.swift:397-631` - Claude-specific JavaScript automation
- `ServiceConfiguration.swift` - Service URL configurations and activation methods
- `WebViewFactory.swift` - WebView creation and initialization
- `BrowserViewController.swift` - WebView delegate handoff after loading

## 7. WebKit Gotchas & Lessons Learned

### JavaScript Execution Constraints
- **Cannot return complex objects**: WebKit only accepts primitive values from JS
- **Promise handling**: Async functions automatically return Promises (unsupported)
- **Return type consistency**: Must return same type (string, number, boolean) consistently
- **Solution**: Use synchronous operations or convert complex objects to JSON strings

### Multi-Service Architecture Lessons
- **Clipboard conflicts**: Multiple services accessing clipboard simultaneously causes failures
- **Sequential execution**: Clipboard-based services must execute one at a time
- **GPU process limits**: Multiple WebViews starting simultaneously causes crashes
- **Solution**: Service categorization with sequential queues

### Timing and Race Conditions
- **JavaScript state sync**: React/modern frameworks need event firing for state updates
- **WebView initialization**: Services need proper loading delays before automation
- **Focus management**: Input focus must be handled carefully to avoid UI disruption
- **Solution**: Comprehensive event sequences and appropriate delays

### Debugging Best Practices
- **Diagnostic reporting**: Return structured JSON for detailed error analysis
- **Console logging**: Extensive logging for tracing automation steps
- **Selector validation**: Test element visibility and interactability before use
- **Error handling**: Graceful fallbacks when primary methods fail 