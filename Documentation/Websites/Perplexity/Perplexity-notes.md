# Perplexity Automation Notes

This document contains notes on the automation of Perplexity.ai within Hyperchat, including CSS selectors and specific interaction logic.

## Current Working Selectors (as of late 2024)

### Input Field Selectors

We use a prioritized list of CSS selectors to reliably find the main prompt input field on Perplexity. These selectors are designed to handle UI variations and updates, especially the distinction between a standard `<textarea>` and a more complex `div[contenteditable="true"]`.

The selectors are tried in the following order:
1.  `textarea[placeholder*="Ask anything"]` - The primary input on the main page.
2.  `textarea[placeholder*="Ask follow-up"]` - The input for follow-up questions.
3.  `textarea[placeholder*="Ask"]` - A more generic placeholder.
4.  `textarea[aria-label*="Ask"]` - Accessibility label selector.
5.  `div[contenteditable="true"][aria-label*="Ask"]` - For content-editable div inputs, which Perplexity often uses.
6.  `textarea` - A general fallback.
7.  `div[contenteditable="true"]` - A general fallback for rich text editors.

### Submit Button Selectors

To submit the prompt, we look for a submit button using these selectors:
1.  `button[aria-label="Submit"]` - The primary submit button.
2.  `button[aria-label="Submit Search"]` - An alternative label.
3.  `button[type="submit"]` - Standard form submit button.
4.  `button.bg-super` - A class-based selector that has been observed.
5.  `button:has(svg[data-icon="arrow-right"])` - Targets the button containing the right-arrow icon.

## Automation Logic: Simulating a Paste Event

Our interaction with Perplexity requires a specific approach because its input field is a complex, React-controlled component. Simply setting the `value` or `textContent` of the input does not work, as React's internal state is not updated, and the submission fails.

### The Problem: Bypassing React's State

Perplexity uses a `div[contenteditable="true"]` for its prompt input. Programmatically inserting text into this `div` is ignored by the site's JavaScript because it doesn't fire the events that React is listening for to update its component state. This means the submit button often remains disabled, and the app doesn't "know" there's text to send.

### The Solution: Simulated Paste

To solve this, we simulate a genuine `paste` event, which is a much more reliable way to trigger the necessary state updates in a React application.

The process is as follows:
1.  **Check Input Type**: The script first determines if the found input is a standard `<textarea>` or a `div[contenteditable="true"]`.
2.  **Simulate Paste for Divs**: If it's a `div`, we create a `DataTransfer` object, add the prompt text to it, and then dispatch a `ClipboardEvent` of type `paste` on the element.
3.  **Fallback to `execCommand`**: In the rare case that creating a `ClipboardEvent` fails, we fall back to using `document.execCommand('insertText', ...)` for broader compatibility.
4.  **Standard Set for Textarea**: If the input is a simple `<textarea>`, we set its `.value` directly.

This paste-simulation approach ensures that Perplexity's front-end logic correctly registers the new input, enables the submit button, and allows for a successful submission.

```javascript
// For contenteditable divs, simulate a paste event
const dataTransfer = new DataTransfer();
dataTransfer.setData('text/plain', promptText);
const pasteEvent = new ClipboardEvent('paste', {
    clipboardData: dataTransfer,
    bubbles: true,
    cancelable: true
});
input.dispatchEvent(pasteEvent);
``` 