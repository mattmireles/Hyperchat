/// JavaScriptProvider.swift - JavaScript Code Generation for Service Automation
///
/// This file centralizes all JavaScript code generation for automating AI services.
/// It provides type-safe Swift functions that generate JavaScript for prompt injection,
/// form submission, and WebView state management.
///
/// Key responsibilities:
/// - Generates JavaScript for URL parameter services (ChatGPT, Perplexity, Google)
/// - Provides specialized scripts for Claude's clipboard paste method
/// - Creates hibernation scripts for pausing/resuming WebView timers
/// - Generates debug scripts for troubleshooting
/// - Handles proper string escaping and service-specific selectors
///
/// Related files:
/// - `ServiceManager.swift`: Uses these scripts for prompt execution
/// - `BrowserViewController.swift`: May use debug scripts
/// - `WebViewFactory.swift`: Injects some scripts during WebView creation
///
/// Architecture:
/// - Static struct with no state (pure functions)
/// - Service-specific selector arrays for robust element finding
/// - Comprehensive error handling and fallback strategies
/// - Console logging for debugging automation issues

import Foundation

/// Centralized provider for all JavaScript code generation.
///
/// Design principles:
/// - Isolates brittle JavaScript strings from Swift code
/// - Makes JavaScript testable through generated output
/// - Provides service-specific customizations
/// - Handles all string escaping in one place
struct JavaScriptProvider {
    
    // MARK: - Paste and Submit Scripts
    
    /// Generates JavaScript to paste prompt and submit for URL parameter services.
    ///
    /// Used by:
    /// - `ServiceManager.executePasteAndSubmit()` for ChatGPT, Perplexity, Google
    ///
    /// Process:
    /// 1. Escapes prompt text for JavaScript string literal
    /// 2. Selects appropriate CSS selectors for the service
    /// 3. Finds visible input field using multiple strategies
    /// 4. Sets text directly (avoids clipboard issues)
    /// 5. Fires events to notify frameworks (React, etc.)
    /// 6. Attempts auto-submit via button click or Enter key
    ///
    /// Service-specific selectors:
    /// - ChatGPT: textarea[data-testid="textbox"], contenteditable divs
    /// - Perplexity: textarea[placeholder*="Ask"], avoids sidebar
    /// - Google: input[name="q"], search boxes
    ///
    /// Error handling:
    /// - Logs all steps for debugging
    /// - Returns error messages for Swift side
    /// - Provides element details when no input found
    static func pasteAndSubmitScript(prompt: String, for service: AIService) -> String {
        let escapedPrompt = prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        
        // Service-specific selectors updated for 2024/2025 UI changes
        // These are ordered by likelihood of success
        let selectors: String
        switch service.id {
        case "chatgpt":
            selectors = """
                const selectors = [
                    // ChatGPT - latest selectors (2024/2025)
                    'textarea[data-testid="textbox"]',
                    'div[contenteditable="true"][data-testid="textbox"]',
                    'textarea[placeholder*="Message ChatGPT"]',
                    'textarea[placeholder*="Send a message"]',
                    'div[contenteditable="true"][data-id="root"]',
                    '#prompt-textarea',
                    'textarea[data-id="root"]',
                    'div[contenteditable="true"][role="textbox"]',
                    'textarea[placeholder*="Message"]',
                    'textarea[placeholder*="Type a message"]',
                    'div[contenteditable="true"]',
                    'textarea.form-control',
                    'textarea',
                    'input[type="text"]'
                ];
                """
        case "perplexity":
            selectors = """
                const selectors = [
                    // Perplexity - comprehensive selectors
                    'textarea[placeholder*="Ask anything"]',
                    'textarea[placeholder*="Ask follow-up"]',
                    'textarea[placeholder*="Ask"]',
                    'textarea[aria-label*="Ask"]',
                    'div[contenteditable="true"][aria-label*="Ask"]',
                    'textarea',
                    'div[contenteditable="true"]'
                ];
                """
        case "google":
            selectors = """
                const selectors = [
                    // Google Search - all variations
                    'input[name="q"]',
                    'textarea[name="q"]',
                    'input[title="Search"]',
                    'input[aria-label*="Search"]',
                    'input[role="combobox"]',
                    'input[type="search"]',
                    'textarea',
                    'input[type="text"]'
                ];
                """
        default:
            selectors = """
                const selectors = [
                    // General fallbacks with better filtering
                    'textarea:not([readonly]):not([disabled]):not([style*="display: none"]):not([style*="visibility: hidden"])',
                    'input[type="text"]:not([readonly]):not([disabled]):not([style*="display: none"]):not([style*="visibility: hidden"])',
                    'div[contenteditable="true"]:not([style*="display: none"]):not([style*="visibility: hidden"])'
                ];
                """
        }
        
        return """
        (function() {
            // Store prompt text in JavaScript variable
            const promptText = `\(escapedPrompt)`;
            console.log('PASTE: Starting with prompt:', promptText.substring(0, 50));
            
            // Service-specific selectors
            \(selectors)
            
            let input = null;
            let inputType = 'unknown';
            
            // Find the first visible and interactable input
            for (const selector of selectors) {
                const elements = document.querySelectorAll(selector);
                for (const el of elements) {
                    const rect = el.getBoundingClientRect();
                    const style = window.getComputedStyle(el);
                    
                    if (rect.width > 0 && rect.height > 0 && 
                        style.display !== 'none' && 
                        style.visibility !== 'hidden' &&
                        !el.disabled && !el.readOnly) {
                        input = el;
                        inputType = el.tagName.toLowerCase();
                        break;
                    }
                }
                if (input) break;
            }
            
            if (input) {
                try {
                    // CRITICAL: Perplexity sidebar bug workaround
                    // Focusing input can trigger unwanted sidebar expansion
                    const isPerplexity = window.location.hostname.includes('perplexity');
                    
                    // Skip focus for Perplexity to avoid UI disruption
                    if (!isPerplexity) {
                        input.focus();
                    }
                    
                    // Wait for any focus effects to settle
                    setTimeout(() => {
                        try {
                            // Direct text insertion instead of clipboard paste
                            if (inputType === 'div') {
                                // For contenteditable divs, simulate a paste event, which is more robust
                                // for frameworks like React that have controlled components.
                                console.log('PASTE SIM: Attempting simulated paste for contenteditable div.');
                                try {
                                    const dataTransfer = new DataTransfer();
                                    dataTransfer.setData('text/plain', promptText);
                                    const pasteEvent = new ClipboardEvent('paste', {
                                        clipboardData: dataTransfer,
                                        bubbles: true,
                                        cancelable: true
                                    });
                                    input.dispatchEvent(pasteEvent);
                                } catch (e) {
                                    console.log('PASTE SIM: Paste event failed, falling back to execCommand.', e);
                                    // Fallback for older browsers or different editors
                                    document.execCommand('insertText', false, promptText);
                                }
                            } else {
                                // For standard input/textarea elements, setting .value is usually sufficient.
                                input.value = promptText;
                            }
                            
                            console.log('DIRECT SET: Set text to', promptText.substring(0, 50));
                            
                            // Fire comprehensive events to notify frameworks
                            // For Perplexity, skip focus/blur events that might trigger UI changes
                            const events = isPerplexity ? [
                                new Event('input', { bubbles: true, cancelable: true }),
                                new Event('change', { bubbles: true, cancelable: true })
                            ] : [
                                new Event('input', { bubbles: true, cancelable: true }),
                                new Event('change', { bubbles: true, cancelable: true }),
                                new Event('keyup', { bubbles: true, cancelable: true }),
                                new Event('blur', { bubbles: true, cancelable: true }),
                                new Event('focus', { bubbles: true, cancelable: true })
                            ];
                            
                            events.forEach(event => {
                                try {
                                    input.dispatchEvent(event);
                                } catch (e) {
                                    console.log('Event error:', e);
                                }
                            });
                            
                            // React-specific events
                            if (input._valueTracker) {
                                input._valueTracker.setValue('');
                            }
                            
                            const reactInputEvent = new Event('input', { bubbles: true });
                            reactInputEvent.simulated = true;
                            input.dispatchEvent(reactInputEvent);
                            
                            // Auto-submit after ensuring DOM updates are complete
                            // 300ms delay allows React/Vue/Angular to process changes
                            setTimeout(() => {
                                try {
                                    \(submitScript(for: service))
                                } catch (e) {
                                    console.log('AUTO-SUBMIT ERROR:', e);
                                }
                            }, 300);
                            
                        } catch (e) {
                            console.log('DIRECT SET ERROR:', e);
                        }
                    }, 200);
                    
                    console.log('SUCCESS: Found input', inputType, input.placeholder || input.getAttribute('aria-label') || 'no-label');
                    return 'SUCCESS: Found ' + inputType;
                } catch (e) {
                    console.log('ERROR setting up paste:', e);
                    return 'ERROR: ' + e.message;
                }
            } else {
                console.log('ERROR: No suitable input found');
                // Enhanced debugging
                const allInputs = document.querySelectorAll('input, textarea, div[contenteditable]');
                console.log('DEBUG: Found', allInputs.length, 'total input elements');
                
                // Log details about each input element for debugging
                allInputs.forEach((el, i) => {
                    const rect = el.getBoundingClientRect();
                    const style = window.getComputedStyle(el);
                    console.log('INPUT', i, ':', {
                        tagName: el.tagName,
                        type: el.type || 'N/A',
                        placeholder: el.placeholder || 'N/A',
                        'aria-label': el.getAttribute('aria-label') || 'N/A',
                        'data-id': el.getAttribute('data-id') || 'N/A',
                        visible: rect.width > 0 && rect.height > 0,
                        display: style.display,
                        visibility: style.visibility,
                        disabled: el.disabled,
                        readonly: el.readOnly
                    });
                });
                
                return 'ERROR: No input found (' + allInputs.length + ' total inputs)';
            }
        })();
        """
    }
    
    /// Generates service-specific submit button clicking logic.
    ///
    /// Called by:
    /// - `pasteAndSubmitScript()` after text insertion
    ///
    /// Strategy:
    /// 1. Try service-specific submit button selectors
    /// 2. Check button visibility and enabled state
    /// 3. Click first matching button
    /// 4. Fall back to Enter key simulation if no button found
    ///
    /// Service patterns:
    /// - ChatGPT: data-testid="send-button", aria-label="Send message"
    /// - Perplexity: aria-label="Submit", button.bg-super
    /// - Google: aria-label="Search", type="submit"
    private static func submitScript(for service: AIService) -> String {
        return """
            // Service-specific submit button selectors
            const submitSelectors = {
                chatgpt: [
                    'button[data-testid="send-button"]',
                    'button[data-testid="fruitjuice-send-button"]', 
                    'button#composer-submit-button',
                    'button[aria-label="Send message"]',
                    'button[aria-label="Send prompt"]'
                ],
                perplexity: [
                    'button[aria-label="Submit"]',
                    'button[aria-label="Submit Search"]',
                    'button[type="submit"]',
                    'button.bg-super',
                    'button:has(svg[data-icon="arrow-right"])'
                ],
                google: [
                    'button[aria-label="Search"]',
                    'button[type="submit"]',
                    'input[type="submit"]'
                ],
                default: [
                    'button[type="submit"]',
                    'button[aria-label*="Send"]',
                    'button[aria-label*="Submit"]',
                    'button:has(svg)',
                    'input[type="submit"]'
                ]
            };
            
            // Determine which selectors to use based on the current site
            const hostname = window.location.hostname;
            let selectors = submitSelectors.default;
            
            if (hostname.includes('chatgpt.com') || hostname.includes('chat.openai.com')) {
                selectors = submitSelectors.chatgpt;
            } else if (hostname.includes('perplexity.ai')) {
                selectors = submitSelectors.perplexity;
            } else if (hostname.includes('google.com')) {
                selectors = submitSelectors.google;
            }
            
            // Try to find and click the submit button
            let buttonClicked = false;
            for (const selector of selectors) {
                const submitBtn = document.querySelector(selector);
                if (submitBtn && !submitBtn.disabled) {
                    // For some sites, we might need to ensure the button is visible
                    const rect = submitBtn.getBoundingClientRect();
                    if (rect.width > 0 && rect.height > 0) {
                        submitBtn.click();
                        console.log('AUTO-SUBMIT: Clicked submit button with selector:', selector);
                        buttonClicked = true;
                        break;
                    }
                }
            }
            
            // FALLBACK: If button click didn't work, try Enter key as backup
            if (!buttonClicked) {
                console.log('AUTO-SUBMIT: No submit button found, trying Enter key fallback');
                
                const keydownEvent = new KeyboardEvent('keydown', {
                    key: 'Enter',
                    code: 'Enter',
                    keyCode: 13,
                    which: 13,
                    bubbles: true,
                    cancelable: true,
                    composed: true
                });
                
                const keyupEvent = new KeyboardEvent('keyup', {
                    key: 'Enter',
                    code: 'Enter',
                    keyCode: 13,
                    which: 13,
                    bubbles: true,
                    cancelable: true,
                    composed: true
                });
                
                input.dispatchEvent(keydownEvent);
                setTimeout(() => {
                    input.dispatchEvent(keyupEvent);
                }, 10);
            }
            """
    }
    
    // MARK: - Claude Scripts
    
    /// Generates JavaScript for Claude's clipboard paste method.
    ///
    /// Used by:
    /// - `ServiceManager.executeClaudeScript()` for Claude only
    ///
    /// Claude-specific approach:
    /// - Cannot use URL parameters like other services
    /// - Must simulate paste operation into contenteditable div
    /// - Uses execCommand for compatibility
    /// - Falls back to direct DOM manipulation
    ///
    /// Process:
    /// 1. Find Claude's ProseMirror editor div
    /// 2. Clear existing content
    /// 3. Insert text via execCommand('insertText')
    /// 4. Fire input events for React
    /// 5. Look for submit button and click
    ///
    /// Timing: Requires 3-second delay before execution
    /// to allow Claude's React app to fully initialize
    static func claudePasteScript(prompt: String) -> String {
        let escapedPrompt = prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        
        return """
        (function() {
            console.log('[Claude] Starting Claude diagnostic paste operation...');
            
            // Initialize diagnostic report
            const report = {
                inputFound: false,
                inputSelector: null,
                textInserted: false,
                enterDispatched: false,
                submitButtonFound: false,
                submitButtonSelector: null,
                errorMessage: null,
                pageURL: window.location.href,
                timestamp: new Date().toISOString()
            };
            
            try {
                // Input field selectors for Claude - Updated for current Claude.ai HTML structure
                const selectors = [
                    'div[aria-label="Write your prompt to Claude"].ProseMirror',  // Most specific - current Claude structure
                    'div.ProseMirror[contenteditable="true"][role="textbox"]',    // Structural match with role
                    'div[contenteditable="true"].ProseMirror.break-words',        // Class combination match
                    'div[contenteditable="true"][aria-label*="Claude"]',          // Aria label fallback
                    'div[contenteditable="true"][role="textbox"]',                // Role-based fallback
                    'div[contenteditable="true"]'                                 // Last resort
                ];
                
                let input = null;
                for (const selector of selectors) {
                    const element = document.querySelector(selector);
                    if (element) {
                        console.log('[Claude] Found input with selector:', selector);
                        input = element;
                        report.inputFound = true;
                        report.inputSelector = selector;
                        break;
                    }
                }

                if (!input) {
                    report.errorMessage = 'No input field found';
                    console.error('[Claude] No input field found');
                    return false;
                }
                
                console.log('[Claude] Found input field:', input);
                
                // Focus the editor first
                input.focus();
                
                // Clear existing content using selection
                const selection = window.getSelection();
                const range = document.createRange();
                range.selectNodeContents(input);
                selection.removeAllRanges();
                selection.addRange(range);
                
                // ProseMirror/Tiptap-compatible text insertion
                try {
                    console.log('[Claude] Attempting ProseMirror-compatible text insertion...');
                    
                    // Method 1: Try to access Tiptap/ProseMirror instance
                    let tiptapSuccess = false;
                    try {
                        // Look for Tiptap editor instance on the element or its parent
                        let editorElement = input;
                        let tiptapEditor = null;
                        
                        // Search up the DOM tree for the editor instance
                        while (editorElement && !tiptapEditor) {
                            if (editorElement.__tiptapEditor) {
                                tiptapEditor = editorElement.__tiptapEditor;
                                break;
                            }
                            if (editorElement._editor) {
                                tiptapEditor = editorElement._editor;
                                break;
                            }
                            editorElement = editorElement.parentElement;
                        }
                        
                        // If we found a Tiptap editor, use its API
                        if (tiptapEditor && tiptapEditor.commands) {
                            tiptapEditor.commands.clearContent();
                            tiptapEditor.commands.insertContent(`\(escapedPrompt)`);
                            tiptapSuccess = true;
                            console.log('[Claude] Text inserted via Tiptap API');
                        }
                    } catch (tiptapError) {
                        console.log('[Claude] Tiptap API not accessible:', tiptapError);
                    }
                    
                    // Method 2: Simulate realistic typing for ProseMirror if Tiptap API not available
                    if (!tiptapSuccess) {
                        console.log('[Claude] Using simulated typing approach...');
                        
                        // Clear existing content first
                        input.focus();
                        
                        // Select all existing content
                        const selectAllEvent = new KeyboardEvent('keydown', {
                            key: 'a',
                            code: 'KeyA',
                            keyCode: 65,
                            ctrlKey: true,
                            metaKey: true, // For macOS
                            bubbles: true,
                            cancelable: true
                        });
                        input.dispatchEvent(selectAllEvent);
                        
                        // Use composition events to simulate natural typing
                        input.dispatchEvent(new CompositionEvent('compositionstart', { 
                            bubbles: true, 
                            cancelable: true 
                        }));
                        
                        // Insert all text at once using composition events
                        const text = `\(escapedPrompt)`;
                        
                        // Dispatch composition update with full text
                        input.dispatchEvent(new CompositionEvent('compositionupdate', { 
                            data: text, 
                            bubbles: true, 
                            cancelable: true 
                        }));
                        
                        // Insert text using execCommand (more compatible with editors)
                        document.execCommand('insertText', false, text);
                        
                        // End composition
                        input.dispatchEvent(new CompositionEvent('compositionend', { 
                            data: text, 
                            bubbles: true, 
                            cancelable: true 
                        }));
                        
                        console.log('[Claude] Text inserted via simulated typing');
                    }
                    
                    // Fire additional events that React/ProseMirror expects
                    input.dispatchEvent(new Event('input', { bubbles: true, cancelable: true }));
                    input.dispatchEvent(new Event('change', { bubbles: true, cancelable: true }));
                    
                    // Trigger React state updates
                    const reactEvent = new Event('input', { bubbles: true });
                    reactEvent.simulated = true;
                    input.dispatchEvent(reactEvent);
                    
                    // Blur and refocus to trigger validation
                    input.blur();
                    // Use synchronous delay instead of await
                    setTimeout(() => {
                        input.focus();
                    }, 50);
                    
                } catch (insertError) {
                    console.log('[Claude] Text insertion failed:', insertError);
                    report.errorMessage = `Text insertion failed: ${insertError.toString()}`;
                }
                
                // Verify text was inserted
                const insertedText = input.textContent || input.innerText;
                if (insertedText.includes(`\(escapedPrompt)`.substring(0, 10))) {
                    report.textInserted = true;
                    console.log('[Claude] Text successfully inserted');
                } else {
                    console.log('[Claude] Text may not have been inserted correctly');
                }

                // Allow time for React/ProseMirror state to update
                setTimeout(() => {
                    console.log('[Claude] Starting submission attempt after state update delay...');
                
                // Updated submit button selectors for modern Claude UI
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
                
                // Simulate Enter key
                const enterEvent = new KeyboardEvent('keydown', {
                    key: 'Enter',
                    code: 'Enter',
                    keyCode: 13,
                    which: 13,
                    bubbles: true,
                    cancelable: true,
                    composed: true,
                    view: window,
                    detail: 0
                });
                
                const dispatched = input.dispatchEvent(enterEvent);
                report.enterDispatched = dispatched;
                console.log('[Claude] Enter key event dispatched:', dispatched);
                
                // Look for submit button with proper element handling
                let submitButton = null;
                for (const selector of submitSelectors) {
                    let element = document.querySelector(selector);
                    if (element) {
                        // If we found an SVG, get its parent button
                        if (element.tagName === 'SVG' || element.tagName === 'svg') {
                            element = element.closest('button') || element.parentElement;
                        }
                        
                        // Ensure we have a clickable button element
                        if (element && (element.tagName === 'BUTTON' || element.getAttribute('role') === 'button')) {
                            const rect = element.getBoundingClientRect();
                            const inputRect = input.getBoundingClientRect();
                            
                            // Check if button is visible, enabled, and positioned near the input field
                            // This helps avoid sidebar buttons that might be far from the input
                            const isNearInput = Math.abs(rect.bottom - inputRect.bottom) < 100; // Within 100px vertically
                            const isRightOfInput = rect.left >= inputRect.right - 50; // At or to the right of input
                            
                            if (rect.width > 0 && rect.height > 0 && !element.disabled && (isNearInput || isRightOfInput)) {
                                report.submitButtonFound = true;
                                report.submitButtonSelector = selector;
                                submitButton = element;
                                console.log('[Claude] Found submit button with selector:', selector, 'element:', element.tagName, 'near input:', isNearInput, 'right of input:', isRightOfInput);
                                break;
                            } else {
                                console.log('[Claude] Skipping button - not positioned correctly relative to input:', selector);
                            }
                        }
                    }
                }
                
                // Try clicking submit button
                if (submitButton) {
                    console.log('[Claude] Attempting to click submit button...');
                    try {
                        // Try multiple click methods for reliability
                        submitButton.focus();
                        submitButton.click();
                        
                        // Fallback: dispatch click event manually
                        const clickEvent = new MouseEvent('click', {
                            bubbles: true,
                            cancelable: true,
                            view: window
                        });
                        submitButton.dispatchEvent(clickEvent);
                        
                        report.submitButtonClicked = true;
                        console.log('[Claude] Submit button clicked successfully');
                    } catch (clickError) {
                        console.error('[Claude] Submit button click failed:', clickError);
                        report.errorMessage = `Submit click failed: ${clickError.toString()}`;
                    }
                } else {
                    console.log('[Claude] No submit button found, relying on Enter key');
                }
                
                }, 200); // End setTimeout - wait 200ms for React state to update
                
            } catch (error) {
                report.errorMessage = error.toString();
                console.error('[Claude] Error during execution:', error);
            }
            
            console.log('[Claude] Diagnostic report:', report);
            // Return diagnostic report as JSON string for Swift parser
            return JSON.stringify(report);
        })();
        """
    }
    
    // MARK: - Hibernation Scripts
    
    /// JavaScript to pause all timers and animations for window hibernation.
    ///
    /// Used by:
    /// - `ServiceManager.pauseAllWebViews()` when window loses focus
    ///
    /// Hibernation strategy:
    /// 1. Save original timer functions
    /// 2. Replace with no-op functions
    /// 3. All new timers return 0 (do nothing)
    /// 4. Existing timers continue but new ones don't start
    ///
    /// This dramatically reduces CPU usage for hidden windows
    /// while maintaining visual state for screenshots
    static func hibernationPauseScript() -> String {
        return """
        // Pause all timers and animations
        if (typeof window._hibernateState === 'undefined') {
            window._hibernateState = {
                setInterval: window.setInterval,
                setTimeout: window.setTimeout,
                requestAnimationFrame: window.requestAnimationFrame
            };
            window.setInterval = function() { return 0; };
            window.setTimeout = function() { return 0; };
            window.requestAnimationFrame = function() { return 0; };
        }
        """
    }
    
    /// JavaScript to resume timers and animations after hibernation.
    ///
    /// Used by:
    /// - `ServiceManager.resumeAllWebViews()` when window gains focus
    ///
    /// Process:
    /// 1. Check if hibernation state exists
    /// 2. Restore original timer functions
    /// 3. Delete hibernation state marker
    /// 4. New timers work normally again
    ///
    /// Note: Existing timers that were created during
    /// hibernation remain as no-ops (returning 0)
    static func hibernationResumeScript() -> String {
        return """
        // Restore all timers and animations
        if (typeof window._hibernateState !== 'undefined') {
            window.setInterval = window._hibernateState.setInterval;
            window.setTimeout = window._hibernateState.setTimeout;
            window.requestAnimationFrame = window._hibernateState.requestAnimationFrame;
            delete window._hibernateState;
        }
        """
    }
    
    // MARK: - Debug Scripts
    
    /// Generates comprehensive Perplexity DOM diagnostic script.
    ///
    /// This script analyzes the current Perplexity page state to understand:
    /// - Available input field selectors (initial vs follow-up)
    /// - Submit button selectors and their current state
    /// - Page context (initial query, follow-up query, results page)
    /// - Element visibility and interaction states
    ///
    /// Used for debugging follow-up query automation issues.
    /// Run this script on Perplexity.ai to gather diagnostic information.
    ///
    /// - Returns: JavaScript string for comprehensive Perplexity DOM analysis
    static func perplexityDiagnosticScript() -> String {
        return """
        (function() {
            console.log('[Perplexity Diagnostic] Starting comprehensive DOM analysis...');
            
            const report = {
                pageURL: window.location.href,
                timestamp: new Date().toISOString(),
                pageContext: 'unknown',
                inputElements: [],
                submitElements: [],
                recommendedSelectors: {
                    input: [],
                    submit: []
                }
            };
            
            // Determine page context
            const url = window.location.href;
            const hasQuery = url.includes('?q=') || document.querySelector('[data-testid="search-result"]');
            const hasFollowUpArea = document.querySelector('[placeholder*="follow"]') || 
                                    document.querySelector('[aria-label*="follow"]') ||
                                    document.querySelector('.follow-up');
                                    
            if (url === 'https://www.perplexity.ai/' || url === 'https://perplexity.ai/') {
                report.pageContext = 'initial_landing';
            } else if (hasQuery && !hasFollowUpArea) {
                report.pageContext = 'results_no_followup';
            } else if (hasQuery && hasFollowUpArea) {
                report.pageContext = 'results_with_followup';
            } else {
                report.pageContext = 'unknown';
            }
            
            console.log('[Perplexity Diagnostic] Page context:', report.pageContext);
            
            // Analyze all input elements
            const allInputs = document.querySelectorAll('input, textarea, div[contenteditable], [role="textbox"]');
            console.log('[Perplexity Diagnostic] Found', allInputs.length, 'potential input elements');
            
            allInputs.forEach((element, index) => {
                const rect = element.getBoundingClientRect();
                const style = window.getComputedStyle(element);
                const isVisible = rect.width > 0 && rect.height > 0 && 
                                 style.display !== 'none' && 
                                 style.visibility !== 'hidden' &&
                                 style.opacity !== '0';
                
                const inputInfo = {
                    index: index,
                    tagName: element.tagName.toLowerCase(),
                    type: element.type || 'N/A',
                    placeholder: element.placeholder || 'N/A',
                    ariaLabel: element.getAttribute('aria-label') || 'N/A',
                    dataTestId: element.getAttribute('data-testid') || 'N/A',
                    className: element.className || 'N/A',
                    id: element.id || 'N/A',
                    isVisible: isVisible,
                    isEnabled: !element.disabled && !element.readOnly,
                    rect: {
                        width: rect.width,
                        height: rect.height,
                        top: rect.top,
                        left: rect.left
                    },
                    value: (element.value || element.textContent || '').substring(0, 50),
                    parent: element.parentElement ? element.parentElement.tagName.toLowerCase() : 'N/A',
                    parentClass: element.parentElement ? element.parentElement.className : 'N/A'
                };
                
                report.inputElements.push(inputInfo);
                
                // Generate recommended selectors for visible, enabled inputs
                if (isVisible && inputInfo.isEnabled) {
                    const selectors = [];
                    
                    if (inputInfo.placeholder !== 'N/A') {
                        selectors.push(`${inputInfo.tagName}[placeholder*="${inputInfo.placeholder.substring(0, 20)}"]`);
                    }
                    if (inputInfo.ariaLabel !== 'N/A') {
                        selectors.push(`${inputInfo.tagName}[aria-label*="${inputInfo.ariaLabel.substring(0, 20)}"]`);
                    }
                    if (inputInfo.dataTestId !== 'N/A') {
                        selectors.push(`${inputInfo.tagName}[data-testid="${inputInfo.dataTestId}"]`);
                    }
                    if (inputInfo.id !== 'N/A') {
                        selectors.push(`#${inputInfo.id}`);
                    }
                    
                    report.recommendedSelectors.input.push(...selectors);
                }
                
                console.log(`[Perplexity Diagnostic] Input ${index}:`, inputInfo);
            });
            
            // Analyze all potential submit buttons
            const allButtons = document.querySelectorAll('button, input[type="submit"], [role="button"]');
            console.log('[Perplexity Diagnostic] Found', allButtons.length, 'potential submit elements');
            
            allButtons.forEach((element, index) => {
                const rect = element.getBoundingClientRect();
                const style = window.getComputedStyle(element);
                const isVisible = rect.width > 0 && rect.height > 0 && 
                                 style.display !== 'none' && 
                                 style.visibility !== 'hidden' &&
                                 style.opacity !== '0';
                
                const buttonInfo = {
                    index: index,
                    tagName: element.tagName.toLowerCase(),
                    type: element.type || 'N/A',
                    ariaLabel: element.getAttribute('aria-label') || 'N/A',
                    dataTestId: element.getAttribute('data-testid') || 'N/A',
                    className: element.className || 'N/A',
                    id: element.id || 'N/A',
                    textContent: (element.textContent || '').trim().substring(0, 30),
                    isVisible: isVisible,
                    isEnabled: !element.disabled,
                    rect: {
                        width: rect.width,
                        height: rect.height,
                        top: rect.top,
                        left: rect.left
                    },
                    hasSVG: element.querySelector('svg') !== null,
                    svgContent: element.querySelector('svg') ? element.querySelector('svg').outerHTML.substring(0, 100) : 'N/A'
                };
                
                report.submitElements.push(buttonInfo);
                
                // Generate recommended selectors for visible, enabled buttons that might be submit buttons
                if (isVisible && buttonInfo.isEnabled) {
                    const selectors = [];
                    
                    // Look for submit-like characteristics
                    const isLikelySubmit = buttonInfo.ariaLabel.toLowerCase().includes('submit') ||
                                          buttonInfo.ariaLabel.toLowerCase().includes('send') ||
                                          buttonInfo.textContent.toLowerCase().includes('submit') ||
                                          buttonInfo.textContent.toLowerCase().includes('send') ||
                                          buttonInfo.hasSVG;
                    
                    if (isLikelySubmit) {
                        if (buttonInfo.ariaLabel !== 'N/A') {
                            selectors.push(`button[aria-label="${buttonInfo.ariaLabel}"]`);
                        }
                        if (buttonInfo.dataTestId !== 'N/A') {
                            selectors.push(`button[data-testid="${buttonInfo.dataTestId}"]`);
                        }
                        if (buttonInfo.className !== 'N/A') {
                            // Extract meaningful class names
                            const classes = buttonInfo.className.split(' ').filter(c => 
                                c.length > 2 && !c.startsWith('css-') && !c.match(/^[a-f0-9]{6,}$/)
                            );
                            classes.forEach(cls => {
                                selectors.push(`button.${cls}`);
                            });
                        }
                        if (buttonInfo.hasSVG) {
                            selectors.push('button:has(svg)');
                        }
                        
                        report.recommendedSelectors.submit.push(...selectors);
                    }
                }
                
                console.log(`[Perplexity Diagnostic] Button ${index}:`, buttonInfo);
            });
            
            // Summary and recommendations
            const visibleInputs = report.inputElements.filter(el => el.isVisible && el.isEnabled);
            const likelySubmitButtons = report.submitElements.filter(el => 
                el.isVisible && el.isEnabled && (
                    el.ariaLabel.toLowerCase().includes('submit') ||
                    el.ariaLabel.toLowerCase().includes('send') ||
                    el.textContent.toLowerCase().includes('submit') ||
                    el.textContent.toLowerCase().includes('send') ||
                    el.hasSVG
                )
            );
            
            console.log('[Perplexity Diagnostic] Summary:');
            console.log('- Page context:', report.pageContext);
            console.log('- Visible/enabled inputs:', visibleInputs.length);
            console.log('- Likely submit buttons:', likelySubmitButtons.length);
            console.log('- Recommended input selectors:', report.recommendedSelectors.input);
            console.log('- Recommended submit selectors:', report.recommendedSelectors.submit);
            
            // Return comprehensive report
            return JSON.stringify(report, null, 2);
        })();
        """
    }
    
    /// JavaScript to check if URL query parameter was processed.
    ///
    /// Used by:
    /// - `ServiceManager` for debugging URL parameter services
    ///
    /// Diagnostic process:
    /// 1. Extract 'q' parameter from current URL
    /// 2. Search all input fields for the query text
    /// 3. Log whether query was found in any input
    ///
    /// Helps diagnose:
    /// - Service loaded but didn't process URL parameter
    /// - Timing issues with page initialization
    /// - Selector mismatches
    static func debugCheckQueryScript() -> String {
        return """
        // Check if the query parameter was processed
        const urlParams = new URLSearchParams(window.location.search);
        const query = urlParams.get('q');
        if (query) {
            const inputs = document.querySelectorAll('textarea, input[type="text"], div[contenteditable="true"]');
            let found = false;
            inputs.forEach(input => {
                const value = input.value || input.textContent || '';
                if (value.includes(query)) {
                    console.log('[Debug] Query found in input:', input);
                    found = true;
                }
            });
            if (!found) {
                console.log('[Debug] Query not found in any input field');
            }
        }
        """
    }
    
    // MARK: - Favicon Extraction
    
    /// JavaScript to extract the favicon URL from the current page.
    ///
    /// Used by:
    /// - `BrowserViewController.webView(_:didFinish:)` after page loads
    ///
    /// Extraction strategy:
    /// 1. Look for <link rel="icon"> and <link rel="shortcut icon"> tags
    /// 2. If found, post the href URL to the faviconFound message handler
    /// 3. If not found, fall back to /favicon.ico at the origin
    ///
    /// This simple approach covers 80% of websites without complex caching.
    static func faviconExtractionScript() -> String {
        return """
        (function() {
            console.log('[Favicon] Starting favicon extraction...');
            
            // Look for favicon in link tags
            const iconLinks = document.querySelectorAll('link[rel~="icon"], link[rel~="shortcut icon"]');
            
            for (const link of iconLinks) {
                if (link.href) {
                    console.log('[Favicon] Found favicon link:', link.href);
                    window.webkit.messageHandlers.faviconFound.postMessage(link.href);
                    return;
                }
            }
            
            // Fallback to /favicon.ico
            const fallbackURL = window.location.origin + '/favicon.ico';
            console.log('[Favicon] No favicon link found, using fallback:', fallbackURL);
            window.webkit.messageHandlers.faviconFound.postMessage(fallbackURL);
        })();
        """
    }
    
    /// Generates JavaScript to detect if the user is logged into Claude.
    ///
    /// This script checks for various indicators that suggest the user is
    /// logged into Claude.ai:
    /// - Presence of user profile/avatar elements
    /// - Navigation elements that only appear when logged in
    /// - Absence of login/signup buttons
    /// - URL patterns that indicate authenticated state
    ///
    /// The result is sent back to Swift via the claudeLoginStatus message handler.
    ///
    /// - Returns: JavaScript string for Claude login detection
    static func claudeLoginDetectionScript() -> String {
        return """
        (function() {
            console.log('[Claude Login Detection] Starting login state check...');
            
            // Claude login detection selectors
            // These are elements that typically appear when user is logged in
            const loggedInSelectors = [
                '[data-testid="user-menu"]',           // User profile menu
                '[aria-label*="user menu"]',           // User menu button
                '.user-avatar',                        // User avatar image
                '[data-testid="chat-input"]',          // Chat input (only visible when logged in)
                '[data-testid="conversation-list"]',   // Conversation sidebar
                'button[aria-label*="New chat"]',      // New chat button
                '[data-testid="profile-button"]',      // Profile button
                '.claude-logo + nav',                  // Navigation after logo (logged in nav)
            ];
            
            // Claude logged out selectors
            // These elements typically appear when user is NOT logged in
            const loggedOutSelectors = [
                'button[data-testid="login-button"]',  // Login button
                'a[href*="login"]',                    // Login links
                'button:contains("Sign in")',          // Sign in buttons
                'button:contains("Log in")',           // Log in buttons
                '.login-form',                         // Login form
                '[data-testid="signup-button"]',       // Signup button
            ];
            
            // Check for logged in indicators
            let loggedInIndicators = 0;
            for (const selector of loggedInSelectors) {
                const elements = document.querySelectorAll(selector);
                if (elements.length > 0) {
                    console.log('[Claude Login Detection] Found logged-in indicator:', selector);
                    loggedInIndicators++;
                }
            }
            
            // Check for logged out indicators
            let loggedOutIndicators = 0;
            for (const selector of loggedOutSelectors) {
                const elements = document.querySelectorAll(selector);
                if (elements.length > 0) {
                    console.log('[Claude Login Detection] Found logged-out indicator:', selector);
                    loggedOutIndicators++;
                }
            }
            
            // Check URL patterns
            const url = window.location.href;
            const isLoginPage = url.includes('/login') || url.includes('/auth') || url.includes('/signin');
            const isMainApp = url.includes('claude.ai') && !isLoginPage;
            
            // Determine login status
            let isLoggedIn = false;
            let confidence = 'low';
            
            if (loggedInIndicators >= 2 && loggedOutIndicators === 0 && isMainApp) {
                isLoggedIn = true;
                confidence = 'high';
            } else if (loggedInIndicators >= 1 && loggedOutIndicators === 0 && isMainApp) {
                isLoggedIn = true;
                confidence = 'medium';
            } else if (loggedOutIndicators > 0 || isLoginPage) {
                isLoggedIn = false;
                confidence = 'high';
            }
            
            const result = {
                isLoggedIn: isLoggedIn,
                confidence: confidence,
                loggedInIndicators: loggedInIndicators,
                loggedOutIndicators: loggedOutIndicators,
                url: url,
                timestamp: Date.now()
            };
            
            console.log('[Claude Login Detection] Result:', result);
            
            // Send result back to Swift
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.claudeLoginStatus) {
                window.webkit.messageHandlers.claudeLoginStatus.postMessage(JSON.stringify(result));
            }
            
            return result;
        })();
        """
    }
}