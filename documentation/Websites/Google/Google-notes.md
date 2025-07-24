# Google Search Automation Notes

This document contains technical notes, learnings, and solutions for automating interactions with Google Search (google.com) in the browser.

## 1. Current Status ✅

**Working as of 2024/2025:**
- URL parameter injection: `https://www.google.com/search?q=prompt&hl=en&safe=off`
- Text insertion and form submission automation
- Service loading and favicon extraction
- Multi-service sequential execution
- iPad user agent for optimal compatibility

## 2. Technical Architecture

### URL Parameter Method
- **Activation Method**: URL parameters (`?q=encoded_prompt`)
- **Home URL**: `https://www.google.com`
- **Base URL**: `https://www.google.com/search`
- **Query Parameter**: `q`
- **Additional Parameters**: 
  - `hl=en` (forces English interface)
  - `safe=off` (disables SafeSearch filtering)
- **User Agent**: iPad Safari (better compatibility than desktop)

### Current Selectors (2024/2025)
Selectors in order of reliability:

```javascript
const selectors = [
    // Google Search - all variations
    'input[name="q"]',              // Primary search input
    'textarea[name="q"]',           // Alternative textarea format
    'input[title="Search"]',        // Title-based fallback
    'input[aria-label*="Search"]',  // Accessibility label
    'input[role="combobox"]',       // ARIA role-based
    'input[type="search"]',         // HTML5 search type
    'textarea',                     // Generic textarea
    'input[type="text"]'            // Last resort text input
];
```

## 3. Implementation Details

### iPad User Agent Benefits
```swift
static let google = ServiceURLConfig(
    homeURL: "https://www.google.com",
    baseURL: "https://www.google.com/search",
    queryParam: "q",
    additionalParams: [
        "hl": "en",        // Language
        "safe": "off"      // Safe search
    ],
    userAgent: iPadUserAgent  // iPad for better compatibility
)
```

**Why iPad User Agent:**
- Google serves simpler HTML to mobile/tablet browsers
- Reduced JavaScript complexity improves automation reliability
- Fewer dynamic UI elements that can interfere with automation
- Better performance on limited resources

### URL Parameter Encoding
```swift
// Proper encoding for Google Search parameters
let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
let url = "\(baseURL)?q=\(encodedPrompt)&hl=en&safe=off"
```

### Text Injection Method
```javascript
// Direct value assignment for Google's standard input elements
if (inputType === 'div') {
    // For contenteditable divs (rare on Google)
    input.textContent = promptText;
    input.innerHTML = promptText;
} else {
    // Standard for Google search inputs
    input.value = promptText;
}
```

### Event Firing Sequence
```javascript
// Standard event sequence for Google's form handling
const events = [
    new Event('input', { bubbles: true, cancelable: true }),
    new Event('change', { bubbles: true, cancelable: true }),
    new Event('keyup', { bubbles: true, cancelable: true }),
    new Event('blur', { bubbles: true, cancelable: true }),
    new Event('focus', { bubbles: true, cancelable: true })
];

events.forEach(event => input.dispatchEvent(event));
```

## 4. Key Features & Benefits

### Multi-Language Support
- `hl=en` parameter ensures consistent English interface
- Predictable selector behavior across regions
- Consistent search result formatting

### SafeSearch Disabled
- `safe=off` parameter provides unrestricted search results
- Important for technical/development queries
- Avoids content filtering that might affect AI prompts

### Stable DOM Structure
- Google Search has one of the most stable DOM structures
- `input[name="q"]` selector rarely changes
- Minimal dynamic content that affects automation

### Fast Execution
- URL parameters allow immediate navigation
- No clipboard conflicts (parallel execution safe)
- Minimal JavaScript execution required

## 5. Configuration Details

**Service Definition** (`ServiceConfiguration.swift:152-162`):
```swift
static let google = ServiceURLConfig(
    homeURL: "https://www.google.com",
    baseURL: "https://www.google.com/search", 
    queryParam: "q",
    additionalParams: [
        "hl": "en",        // Language
        "safe": "off"      // Safe search
    ],
    userAgent: iPadUserAgent
)
```

**User Agent String**:
- Uses iPad Safari user agent for maximum compatibility
- Generated dynamically to match current Safari version
- Format: `Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) WebKit/...`

## 6. Automation Reliability

### Why Google Works Well
1. **Stable Selectors**: `input[name="q"]` has been consistent for years
2. **Simple DOM**: Minimal dynamic content or complex JavaScript
3. **URL Parameter Support**: Direct URL navigation without complex interaction
4. **Mobile-Optimized**: iPad user agent gets simpler, more reliable HTML
5. **No Authentication**: No login requirements or session management

### Performance Characteristics
- **Load Time**: Fast (~1-2 seconds for search results)
- **Memory Usage**: Low (simple HTML structure)
- **CPU Usage**: Minimal (basic form interaction)
- **Network**: Efficient (direct URL navigation)

## 7. Related Files
- `JavaScriptProvider.swift:105-118` - Google selector definitions
- `ServiceConfiguration.swift:152-162` - URL configuration and parameters
- `ServiceManager.swift` - Execution logic
- `URLParameterService.swift` - URL parameter handling
- `UserAgentGenerator.swift` - iPad user agent generation

## 8. Testing & Debugging

### Success Indicators
- Console log: `PASTE: Starting with prompt:`
- Console log: `DIRECT SET: Set text to`
- Search results appear with query in address bar
- No "Invalid diagnostic response" errors

### Common Issues (Rare)
- **Network blocking**: Corporate firewalls blocking Google
- **Region restrictions**: Some Google domains blocked in certain countries
- **User agent issues**: Desktop user agent causing complex UI

### Debug Commands
```bash
# Test Google automation specifically
grep -E "\[Google\]|Google:" /path/to/logs

# Monitor URL parameter services
tail -f /path/to/logs | grep "URLParameterService"

# Check user agent application
grep "iPad" /path/to/logs
```

## 9. Future Considerations

### Potential Issues to Monitor
- Google UI updates (rare but possible)
- Changes to search result page structure
- New authentication requirements
- Mobile/tablet UI changes

### Optimization Opportunities
- Pre-load Google homepage for faster execution
- Cache search preferences
- Implement result parsing for enhanced features 