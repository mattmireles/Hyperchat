# ChatGPT Automation Notes

This document contains technical notes, learnings, and solutions for automating interactions with ChatGPT (chat.openai.com) in the browser.

## 1. Current Status ✅

**Working as of 2024/2025:**
- URL parameter injection: `https://chatgpt.com/?q=prompt`
- Text insertion and form submission automation
- Service loading and favicon extraction
- Multi-service sequential execution

## 2. Technical Architecture

### URL Parameter Method
- **Activation Method**: URL parameters (`?q=encoded_prompt`)
- **Base URL**: `https://chatgpt.com`
- **Home URL**: `https://chatgpt.com` 
- **Query Parameter**: `q`
- **User Agent**: Desktop Safari (generated dynamically)

### Current Selectors (2024/2025)
Updated selectors in order of reliability:

```javascript
const selectors = [
    // ChatGPT - latest selectors (2024/2025)
    'textarea[data-testid="textbox"]',                    // Primary selector
    'div[contenteditable="true"][data-testid="textbox"]', // Alternative content-editable
    'textarea[placeholder*="Message ChatGPT"]',           // Placeholder-based
    'textarea[placeholder*="Send a message"]',            // Alternative placeholder
    'div[contenteditable="true"][data-id="root"]',        // Root content div
    '#prompt-textarea',                                   // ID-based fallback
    'textarea[data-id="root"]',                           // Data ID fallback
    'div[contenteditable="true"][role="textbox"]',        // Role-based
    'textarea[placeholder*="Message"]',                   // Generic message
    'textarea[placeholder*="Type a message"]',            // Typing prompt
    'div[contenteditable="true"]',                        // Generic contenteditable
    'textarea.form-control',                              // Bootstrap class
    'textarea',                                           // Generic textarea
    'input[type="text"]'                                  // Last resort
];
```

## 3. Implementation Details

### Text Injection Method
```javascript
// Direct text insertion instead of clipboard
if (inputType === 'div') {
    // For contenteditable divs
    input.textContent = promptText;
    input.innerHTML = promptText; // Fallback
} else {
    // For input/textarea elements
    input.value = promptText;
}
```

### Event Firing for React State Updates
```javascript
// Comprehensive event sequence for React framework
const events = [
    new Event('input', { bubbles: true, cancelable: true }),
    new Event('change', { bubbles: true, cancelable: true }),
    new Event('keyup', { bubbles: true, cancelable: true }),
    new Event('blur', { bubbles: true, cancelable: true }),
    new Event('focus', { bubbles: true, cancelable: true })
];

events.forEach(event => input.dispatchEvent(event));
```

### Submit Button Detection
```javascript
const submitSelectors = [
    'button[data-testid*="send"]',
    'button[aria-label*="Send message"]',
    'button[aria-label*="Send"]',
    'button:has(svg)',  // Icon-based detection
    'button[type="submit"]',
    'input[type="submit"]'
];
```

## 4. Key Learnings & Solutions

### Element Visibility Validation
```javascript
// Ensure elements are actually visible and interactable
const rect = el.getBoundingClientRect();
const style = window.getComputedStyle(el);

if (rect.width > 0 && rect.height > 0 && 
    style.display !== 'none' && 
    style.visibility !== 'hidden' &&
    !el.disabled && !el.readOnly) {
    // Element is valid for interaction
}
```

### Focus Management
- Focus input before text insertion for proper state initialization
- Brief delay after focus to allow UI effects to settle
- Event firing sequence matches user interaction patterns

### Multi-Service Compatibility
- Executes via URL parameters (parallel execution safe)
- No clipboard conflicts with Claude's clipboard method
- Sequential execution only needed for clipboard-based services

## 5. Configuration Details

**Service Definition** (`ServiceConfiguration.swift`):
```swift
static let chatgpt = ServiceURLConfig(
    homeURL: "https://chatgpt.com",
    baseURL: "https://chatgpt.com",
    queryParam: "q",
    additionalParams: [:],  // No additional parameters needed
    userAgent: .desktop     // Uses generated Safari desktop user agent
)
```

## 6. Related Files
- `JavaScriptProvider.swift:72-91` - ChatGPT selector definitions
- `ServiceConfiguration.swift` - URL configuration
- `ServiceManager.swift` - Execution logic
- `URLParameterService.swift` - URL parameter handling

## 7. Testing & Debugging

### Success Indicators
- Console log: `PASTE: Starting with prompt:`
- Console log: `DIRECT SET: Set text to`
- Console log: `SUBMIT: Attempting auto-submit`
- No "Invalid diagnostic response" errors

### Common Issues
- **Selector mismatch**: UI updates change data-testid values
- **React state sync**: Events not properly firing
- **Focus issues**: Input not properly focused before text insertion

### Debug Commands
```bash
# Test ChatGPT automation specifically
grep -E "\[ChatGPT\]|ChatGPT:" /path/to/logs

# Monitor all service execution
tail -f /path/to/logs | grep "executePrompt"
``` 