# Logging System Documentation

## Overview

Hyperchat now includes a comprehensive flag-based logging system that can be controlled through the UI. This allows developers to easily toggle different types of logging on/off for debugging purposes.

## Accessing the Logs Menu

The logging configuration is accessible through the **Logs** menu in the macOS menu bar when Hyperchat is running.

## Menu Options

### Preset Configurations

1. **Minimal Logging** - Enables only essential logging (navigation events, errors, and prompt debugging)
2. **Debug Reply-to-All** - Minimal logging plus detailed prompt execution debugging
3. **Verbose Logging** - Enables all logging types for comprehensive debugging

### Individual Logging Flags

After the preset options, you'll find individual checkable items for fine-tuned control:

- **Network Requests** ✓/✗ - HTTP requests and responses (filtered by analytics filter)
- **User Interactions** ✓/✗ - Clicks, form submissions, input changes, focus events
- **Console Messages** ✓/✗ - JavaScript console logs (errors are always logged)
- **DOM Changes** ✓/✗ - DOM mutations and changes
- **Navigation Events** ✓/✗ - WebView navigation and page loads
- **Prompt Debugging** ✓/✗ - Detailed prompt execution flow and state changes
- **Filter Analytics** ✓/✗ - When enabled, filters out analytics/tracking requests

## Implementation Details

### LoggingConfiguration Structure

Located in `WebViewLogger.swift`, the `LoggingConfiguration` struct contains static flags for each logging type:

```swift
struct LoggingConfiguration {
    static var networkRequests = false      // Network request/response logging
    static var userInteractions = false     // Click, focus, input events  
    static var consoleMessages = true       // JS console logs (always log errors)
    static var domChanges = false          // DOM mutation logging
    static var navigation = true           // WebView navigation events
    static var debugPrompts = true         // Prompt execution debugging
    static var analyticsFilter = true      // Filter out analytics/tracking requests
}
```

### Analytics Filtering

When `analyticsFilter` is enabled, the following domains are automatically filtered from network logs:
- googletagmanager.com
- google-analytics.com
- datadoghq.com
- browser-intake-datadoghq.com
- amazon-adsystem.com
- doubleclick.net
- facebook.com
- play.google.com/log
- accounts.google.com/gsi/log
- reddit.com
- redditstatic.com
- singular.net
- eppo.cloud
- ipv4.podscribe.com
- ab.chatgpt.com

### Usage Examples

**To debug reply-to-all issues:**
1. Click Logs → Debug Reply-to-All
2. Submit prompts and watch the console for detailed execution flow

**To reduce log noise:**
1. Click Logs → Minimal Logging
2. Only essential events will be logged

**To debug network issues:**
1. Click individual items to enable only what you need
2. Check "Network Requests" but leave others unchecked

## Benefits

1. **Reduced Log Noise** - No more overwhelming console output
2. **Targeted Debugging** - Enable only the logs relevant to your current issue
3. **Quick Presets** - One-click access to common logging configurations
4. **Real-time Toggle** - Changes take effect immediately without restarting
5. **Visual Feedback** - Check marks show current logging state

## Default Configuration

By default, Hyperchat starts with minimal logging enabled:
- Navigation events ✓
- Console messages ✓ (errors only)
- Prompt debugging ✓
- Analytics filter ✓
- All other logging disabled

This provides a good balance between useful debugging information and console clarity.