import Foundation

/// Centralized provider for all JavaScript code generation
/// This isolates brittle JavaScript strings and makes them testable
struct JavaScriptProvider {
    
    // MARK: - Paste and Submit Scripts
    
    /// Generates JavaScript to paste prompt and submit for URL parameter services
    static func pasteAndSubmitScript(prompt: String, for service: AIService) -> String {
        let escapedPrompt = prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        
        // Service-specific selectors - comprehensive list from production code
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
            const promptText = `\(escapedPrompt)`;
            console.log('PASTE: Starting with prompt:', promptText.substring(0, 50));
            
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
                    // For Perplexity, be extra careful to avoid sidebar expansion
                    const isPerplexity = window.location.hostname.includes('perplexity');
                    
                    // For Perplexity, skip focus to avoid sidebar expansion
                    if (!isPerplexity) {
                        input.focus();
                    }
                    
                    // Wait for any focus effects to settle
                    setTimeout(() => {
                        try {
                            // Direct text insertion instead of clipboard paste
                            if (inputType === 'div') {
                                // For contenteditable divs
                                input.textContent = promptText;
                                input.innerHTML = promptText; // Fallback
                            } else {
                                // For input/textarea elements
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
                            
                            // Auto-submit after a short delay - PRIMARY METHOD: Click submit button
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
    
    /// Generates service-specific submit logic
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
    
    /// Generates JavaScript for Claude's clipboard paste method
    static func claudePasteScript(prompt: String) -> String {
        let escapedPrompt = prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        
        return """
        (function() {
            console.log('[Claude] Starting Claude paste operation...');
            
            // Function to find the input field
            function findClaudeInput() {
                // Claude uses a contenteditable div
                const selectors = [
                    'div[contenteditable="true"]',
                    'div.ProseMirror',
                    'div[data-placeholder]'
                ];
                
                for (const selector of selectors) {
                    const element = document.querySelector(selector);
                    if (element) {
                        console.log('[Claude] Found input with selector:', selector);
                        return element;
                    }
                }
                return null;
            }
            
            // Function to set text in contenteditable
            function setTextInContentEditable(element, text) {
                // Clear existing content
                element.innerHTML = '';
                
                // Create text node
                const textNode = document.createTextNode(text);
                element.appendChild(textNode);
                
                // Set cursor to end
                const range = document.createRange();
                const selection = window.getSelection();
                range.selectNodeContents(element);
                range.collapse(false);
                selection.removeAllRanges();
                selection.addRange(range);
                
                // Dispatch input event
                element.dispatchEvent(new Event('input', { bubbles: true, cancelable: true }));
                
                // Also dispatch a paste event for good measure
                const pasteEvent = new ClipboardEvent('paste', {
                    clipboardData: new DataTransfer(),
                    bubbles: true,
                    cancelable: true
                });
                element.dispatchEvent(pasteEvent);
            }
            
            const input = findClaudeInput();
            if (!input) {
                console.error('[Claude] No input field found');
                return false;
            }
            
            // Focus the input
            input.focus();
            
            // Use execCommand as fallback for Claude
            try {
                // First, try to clear any existing content
                document.execCommand('selectAll', false, null);
                document.execCommand('delete', false, null);
                
                // Insert the text
                document.execCommand('insertText', false, "\(escapedPrompt)");
                console.log('[Claude] Text inserted using execCommand');
                
                // Also try the modern approach
                setTextInContentEditable(input, "\(escapedPrompt)");
                
                // Try to submit after a delay
                setTimeout(() => {
                    console.log('[Claude] Attempting to submit...');
                    
                    // Look for submit button
                    const submitButton = document.querySelector('button[aria-label*="Send"], button:has(svg path[d*="M4"]), button:has(svg path[d*="m21"])');
                    if (submitButton && !submitButton.disabled) {
                        console.log('[Claude] Found submit button, clicking...');
                        submitButton.click();
                    } else {
                        console.log('[Claude] No submit button found, trying Enter key...');
                        const enterEvent = new KeyboardEvent('keydown', {
                            key: 'Enter',
                            code: 'Enter',
                            keyCode: 13,
                            which: 13,
                            bubbles: true,
                            cancelable: true
                        });
                        input.dispatchEvent(enterEvent);
                    }
                }, 1000);
                
                return true;
            } catch (e) {
                console.error('[Claude] execCommand failed:', e);
                // Try direct approach as last resort
                setTextInContentEditable(input, "\(escapedPrompt)");
                return true;
            }
        })();
        """
    }
    
    // MARK: - Hibernation Scripts
    
    /// JavaScript to pause timers and animations for hibernation
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
    
    /// JavaScript to resume timers and animations after hibernation
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
    
    /// JavaScript to check if query was processed (for debugging)
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
}