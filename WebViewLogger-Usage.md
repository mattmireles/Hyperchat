# WebViewLogger Usage Guide

## Overview
The WebViewLogger provides comprehensive logging for all WebView activities in HyperChat. It captures:
- Navigation events (URLs, redirects, errors)
- JavaScript console logs (log, warn, error, debug)
- Network requests and responses
- DOM changes (element additions, removals, attribute changes)
- User interactions (clicks, form submissions, text input, copy/paste)

## Log File Locations
Logs are saved to:
```
~/Library/Logs/HyperChat/[ServiceName]/[YYYY-MM-DD].log
```

For example:
- `~/Library/Logs/HyperChat/ChatGPT/2025-06-20.log`
- `~/Library/Logs/HyperChat/Claude/2025-06-20.log`
- `~/Library/Logs/HyperChat/Perplexity/2025-06-20.log`
- `~/Library/Logs/HyperChat/Google/2025-06-20.log`

## Log Format
Each log entry is a JSON object with:
```json
{
  "timestamp": "2025-06-20 15:30:45.123",
  "type": "info",
  "service": "ChatGPT",
  "message": "Navigation Started: URL: https://chatgpt.com..."
}
```

## Viewing Logs

### Real-time monitoring
```bash
# Watch all services
tail -f ~/Library/Logs/HyperChat/*/*.log

# Watch specific service
tail -f ~/Library/Logs/HyperChat/ChatGPT/*.log
```

### Search logs
```bash
# Find all errors
grep '"type": "error"' ~/Library/Logs/HyperChat/*/*.log

# Find specific URL
grep "perplexity.ai" ~/Library/Logs/HyperChat/Perplexity/*.log
```

### Parse JSON logs
```bash
# Pretty print logs
cat ~/Library/Logs/HyperChat/Claude/2025-06-20.log | jq '.'

# Filter by type
cat ~/Library/Logs/HyperChat/ChatGPT/2025-06-20.log | jq 'select(.type == "error")'
```

## What's Logged

### Navigation Events
- Page load start/finish
- URL changes
- HTTP status codes
- Load errors

### JavaScript Console
- All console.log/warn/error calls
- Unhandled JavaScript errors
- Promise rejections

### Network Activity
- Fetch API requests
- XMLHttpRequest calls
- Request URLs and methods
- Response status codes

### DOM Changes
- Element additions/removals
- Attribute modifications
- Text content changes

### User Interactions
- Button/link clicks
- Form submissions
- Text input (debounced)
- Copy/paste events
- Focus events

## Privacy Note
The logger captures:
- URLs visited
- Console messages
- User interaction metadata (not actual text content)
- Network request URLs

Sensitive data like passwords or form values are NOT logged directly, only metadata about interactions.

## Integration Status
The WebViewLogger is fully integrated into ServiceManager and will automatically start logging when the app runs. No additional configuration is needed.