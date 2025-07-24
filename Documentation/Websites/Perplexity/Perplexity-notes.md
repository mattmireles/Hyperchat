# Perplexity Automation Notes

This document contains notes on the automation of Perplexity.ai within Hyperchat, including CSS selectors and specific interaction logic.

## Current Working Selectors (as of late 2024)

### Input Field Selectors

We use a prioritized list of CSS selectors to reliably find the main prompt input field on Perplexity. These selectors are designed to handle UI variations and updates.

The selectors are tried in the following order:
1.  `textarea[placeholder*="Ask anything"]` - The primary input on the main page.
2.  `textarea[placeholder*="Ask follow-up"]` - The input for follow-up questions.
3.  `textarea[placeholder*="Ask"]` - A more generic placeholder.
4.  `textarea[aria-label*="Ask"]` - Accessibility label selector.
5.  `div[contenteditable="true"][aria-label*="Ask"]` - For content-editable div inputs.
6.  `textarea` - A general fallback.
7.  `div[contenteditable="true"]` - A general fallback for rich text editors.

### Submit Button Selectors

To submit the prompt, we look for a submit button using these selectors:
1.  `button[aria-label="Submit"]` - The primary submit button.
2.  `button[aria-label="Submit Search"]` - An alternative label.
3.  `button[type="submit"]` - Standard form submit button.
4.  `button.bg-super` - A class-based selector that has been observed.
5.  `button:has(svg[data-icon="arrow-right"])` - Targets the button containing the right-arrow icon.

## Automation Logic

Our interaction with Perplexity involves special handling to avoid disrupting the user experience and to work around its specific UI behavior.

### Bypassing Sidebar Expansion

A key challenge with Perplexity is that focusing the input field can trigger an unwanted sidebar expansion. To prevent this, our automation script **deliberately avoids calling `.focus()`** on the input field before injecting the prompt.

### Event Simulation

After setting the input field's value directly, we fire a limited set of JavaScript events to ensure the site's framework (likely React) recognizes the new input. For Perplexity, we only fire `input` and `change` events. This is different from other services where we might also fire `keyup`, `blur`, and `focus`.

```javascript
// For Perplexity, skip focus/blur events that might trigger UI changes
const events = isPerplexity ? [
    new Event('input', { bubbles: true, cancelable: true }),
    new Event('change', { bubbles: true, cancelable: true })
] : [
    // ... more events for other services
];
```

This tailored approach ensures that prompts are submitted reliably without causing unintended UI side effects. 