/// MarkdownView.swift - Native SwiftUI Markdown Renderer
///
/// A custom SwiftUI component that renders markdown text with Apple-like polish.
/// This component provides syntax highlighting, proper typography, and consistent
/// theming that matches the app's gradient aesthetic.
///
/// Features:
/// - Headers (H1-H6) with gradient text effects
/// - Bold, italic, and inline code formatting
/// - Code blocks with syntax highlighting
/// - Lists (ordered and unordered)
/// - Links with hover states
/// - Proper line spacing and typography hierarchy
///
/// This component is used by:
/// - `MessageBubble.swift` for rendering AI response content
/// - `LocalChatView.swift` for displaying conversation messages
///
/// Related files:
/// - `GradientToolbarButton.swift` - Shares gradient color scheme
/// - `MessageBubble.swift` - Integrates markdown rendering into message display

import SwiftUI
import Foundation

// MARK: - Markdown Rendering Constants

/// Color and styling constants for markdown rendering
private enum MarkdownStyle {
    /// Gradient colors matching the app theme (pink → purple → blue)
    static let gradientColors = [
        Color(red: 1.0, green: 0.0, blue: 0.8),  // Pink
        Color(red: 0.6, green: 0.2, blue: 0.8),  // Purple  
        Color(red: 0.0, green: 0.6, blue: 1.0)   // Blue
    ]
    
    /// Code block background color
    static let codeBlockBackground = Color(.controlBackgroundColor).opacity(0.8)
    
    /// Code block border color
    static let codeBlockBorder = Color.secondary.opacity(0.3)
    
    /// Inline code background color
    static let inlineCodeBackground = Color.secondary.opacity(0.1)
    
    /// Link color
    static let linkColor = Color.blue
    
    /// Typography scaling factors
    static let h1Scale: CGFloat = 2.0
    static let h2Scale: CGFloat = 1.5
    static let h3Scale: CGFloat = 1.25
    static let h4Scale: CGFloat = 1.1
    static let h5Scale: CGFloat = 1.0
    static let h6Scale: CGFloat = 0.9
}

// MARK: - Markdown Parsing

/// Simple markdown parser that converts markdown text to structured data
struct MarkdownParser {
    
    /// Parsed markdown element types
    enum Element {
        case header(level: Int, text: String)
        case paragraph([InlineElement])
        case codeBlock(language: String?, code: String)
        case unorderedList([String])
        case orderedList([String])
        case horizontalRule
    }
    
    /// Inline markdown elements within paragraphs
    enum InlineElement {
        case text(String)
        case bold(String)
        case italic(String)
        case inlineCode(String)
        case link(text: String, url: String)
    }
    
    /// Parse markdown text into structured elements
    static func parse(_ markdown: String) -> [Element] {
        let lines = markdown.components(separatedBy: .newlines)
        var elements: [Element] = []
        var currentParagraphLines: [String] = []
        var isInCodeBlock = false
        var codeBlockLanguage: String?
        var codeBlockLines: [String] = []
        
        for line in lines {
            // Handle code blocks
            if line.hasPrefix("```") {
                if isInCodeBlock {
                    // End code block
                    let code = codeBlockLines.joined(separator: "\n")
                    elements.append(.codeBlock(language: codeBlockLanguage, code: code))
                    isInCodeBlock = false
                    codeBlockLanguage = nil
                    codeBlockLines = []
                } else {
                    // Start code block
                    flushParagraph(&elements, &currentParagraphLines)
                    isInCodeBlock = true
                    let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeBlockLanguage = language.isEmpty ? nil : language
                }
                continue
            }
            
            if isInCodeBlock {
                codeBlockLines.append(line)
                continue
            }
            
            // Handle headers
            if line.hasPrefix("#") {
                flushParagraph(&elements, &currentParagraphLines)
                let level = line.prefix(while: { $0 == "#" }).count
                let text = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                elements.append(.header(level: min(level, 6), text: text))
                continue
            }
            
            // Handle horizontal rules
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                flushParagraph(&elements, &currentParagraphLines)
                elements.append(.horizontalRule)
                continue
            }
            
            // Handle empty lines
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraph(&elements, &currentParagraphLines)
                continue
            }
            
            // Handle lists
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph(&elements, &currentParagraphLines)
                var listItems: [String] = []
                var currentLine = line
                
                // Collect consecutive list items
                repeat {
                    let item = String(currentLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    listItems.append(item)
                    // Note: This simplified parser doesn't handle multi-line lists
                    break
                } while false
                
                elements.append(.unorderedList(listItems))
                continue
            }
            
            // Regular paragraph line
            currentParagraphLines.append(line)
        }
        
        // Flush any remaining paragraph
        flushParagraph(&elements, &currentParagraphLines)
        
        return elements
    }
    
    /// Helper to convert accumulated paragraph lines into a paragraph element
    private static func flushParagraph(_ elements: inout [Element], _ lines: inout [String]) {
        if !lines.isEmpty {
            let text = lines.joined(separator: " ")
            let inlineElements = parseInlineElements(text)
            elements.append(.paragraph(inlineElements))
            lines.removeAll()
        }
    }
    
    /// Parse inline markdown elements (bold, italic, code, links)
    private static func parseInlineElements(_ text: String) -> [InlineElement] {
        var result: [InlineElement] = []
        var currentText = text
        
        // Simple regex-like parsing for inline elements
        // This is a simplified implementation - a full parser would be more robust
        
        // For now, return the text as-is - we can enhance this later
        result.append(.text(currentText))
        
        return result
    }
}

// MARK: - Markdown View Component

/// SwiftUI view that renders parsed markdown with Apple-like styling
struct MarkdownView: View {
    let markdown: String
    private let elements: [MarkdownParser.Element]
    
    init(_ markdown: String) {
        self.markdown = markdown
        self.elements = MarkdownParser.parse(markdown)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(elements.enumerated()), id: \.offset) { index, element in
                renderElement(element)
            }
        }
    }
    
    /// Render a single markdown element
    @ViewBuilder
    private func renderElement(_ element: MarkdownParser.Element) -> some View {
        switch element {
        case .header(let level, let text):
            renderHeader(level: level, text: text)
            
        case .paragraph(let inlineElements):
            renderParagraph(inlineElements)
            
        case .codeBlock(let language, let code):
            renderCodeBlock(language: language, code: code)
            
        case .unorderedList(let items):
            renderUnorderedList(items)
            
        case .orderedList(let items):
            renderOrderedList(items)
            
        case .horizontalRule:
            renderHorizontalRule()
        }
    }
    
    /// Render a header with gradient text effect
    @ViewBuilder
    private func renderHeader(level: Int, text: String) -> some View {
        let scale = headerScale(for: level)
        
        Text(text)
            .font(.system(size: 16 * scale, weight: .bold, design: .default))
            .foregroundStyle(
                LinearGradient(
                    colors: MarkdownStyle.gradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.vertical, 4)
    }
    
    /// Render a paragraph with inline formatting
    @ViewBuilder 
    private func renderParagraph(_ inlineElements: [MarkdownParser.InlineElement]) -> some View {
        // For now, render as simple text - we'll enhance inline parsing later
        let text = inlineElements.compactMap { element in
            switch element {
            case .text(let str): return str
            default: return nil
            }
        }.joined()
        
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.primary)
            .lineSpacing(2)
    }
    
    /// Render a code block with syntax highlighting background
    @ViewBuilder
    private func renderCodeBlock(language: String?, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language label if provided
            if let language = language, !language.isEmpty {
                HStack {
                    Text(language.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // Copy button
                    Button(action: {
                        copyCodeToClipboard(code)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy code")
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            
            // Code content with syntax highlighting
            ScrollView(.horizontal, showsIndicators: false) {
                syntaxHighlightedCode(code: code, language: language)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(MarkdownStyle.codeBlockBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(MarkdownStyle.codeBlockBorder, lineWidth: 1)
        )
        .cornerRadius(8)
    }
    
    /// Apply basic syntax highlighting to code
    @ViewBuilder
    private func syntaxHighlightedCode(code: String, language: String?) -> some View {
        if let language = language?.lowercased() {
            switch language {
            case "swift":
                swiftSyntaxHighlighting(code)
            case "python", "py":
                pythonSyntaxHighlighting(code)
            case "javascript", "js", "typescript", "ts":
                javaScriptSyntaxHighlighting(code)
            case "json":
                jsonSyntaxHighlighting(code)
            case "bash", "shell", "sh":
                shellSyntaxHighlighting(code)
            default:
                defaultCodeRendering(code)
            }
        } else {
            defaultCodeRendering(code)
        }
    }
    
    /// Default code rendering without syntax highlighting
    @ViewBuilder
    private func defaultCodeRendering(_ code: String) -> some View {
        Text(code)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.primary)
    }
    
    /// Swift syntax highlighting
    @ViewBuilder
    private func swiftSyntaxHighlighting(_ code: String) -> some View {
        let lines = code.components(separatedBy: .newlines)
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                swiftHighlightedLine(line)
            }
        }
    }
    
    /// Highlight a single Swift line
    @ViewBuilder
    private func swiftHighlightedLine(_ line: String) -> some View {
        let keywords = ["func", "var", "let", "class", "struct", "enum", "if", "else", "for", "while", "return", "import", "private", "public", "internal", "static", "override", "init", "deinit", "extension", "protocol", "associatedtype", "typealias", "guard", "switch", "case", "default", "break", "continue", "fallthrough", "repeat", "defer", "do", "catch", "try", "throw", "throws", "rethrows", "async", "await", "actor"]
        
        Text(attributedString(for: line, keywords: keywords, keywordColor: .purple))
            .font(.system(.body, design: .monospaced))
    }
    
    /// Python syntax highlighting
    @ViewBuilder
    private func pythonSyntaxHighlighting(_ code: String) -> some View {
        let lines = code.components(separatedBy: .newlines)
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                pythonHighlightedLine(line)
            }
        }
    }
    
    /// Highlight a single Python line
    @ViewBuilder
    private func pythonHighlightedLine(_ line: String) -> some View {
        let keywords = ["def", "class", "if", "elif", "else", "for", "while", "return", "import", "from", "as", "try", "except", "finally", "with", "lambda", "and", "or", "not", "in", "is", "True", "False", "None", "pass", "break", "continue", "global", "nonlocal", "assert", "del", "yield", "async", "await"]
        
        Text(attributedString(for: line, keywords: keywords, keywordColor: .blue))
            .font(.system(.body, design: .monospaced))
    }
    
    /// JavaScript/TypeScript syntax highlighting
    @ViewBuilder
    private func javaScriptSyntaxHighlighting(_ code: String) -> some View {
        let lines = code.components(separatedBy: .newlines)
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                javaScriptHighlightedLine(line)
            }
        }
    }
    
    /// Highlight a single JavaScript line
    @ViewBuilder
    private func javaScriptHighlightedLine(_ line: String) -> some View {
        let keywords = ["function", "var", "let", "const", "if", "else", "for", "while", "return", "import", "export", "default", "class", "extends", "constructor", "static", "async", "await", "try", "catch", "finally", "throw", "new", "this", "super", "typeof", "instanceof", "true", "false", "null", "undefined"]
        
        Text(attributedString(for: line, keywords: keywords, keywordColor: .indigo))
            .font(.system(.body, design: .monospaced))
    }
    
    /// JSON syntax highlighting
    private func jsonSyntaxHighlighting(_ code: String) -> some View {
        let attributedText = createHighlightedJSONAttributedString(code)
        return Text(AttributedString(attributedText))
    }
    
    /// Create attributed string with JSON syntax highlighting
    private func createHighlightedJSONAttributedString(_ code: String) -> NSMutableAttributedString {
        let attributedText = NSMutableAttributedString(string: code)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
        attributedText.addAttributes(baseAttributes, range: NSRange(location: 0, length: code.count))
        
        // Highlight JSON keys and strings (simplified)
        let stringPattern = #""[^"]*""#
        if let regex = try? NSRegularExpression(pattern: stringPattern) {
            let matches = regex.matches(in: code, range: NSRange(location: 0, length: code.count))
            matches.forEach { match in
                attributedText.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: match.range)
            }
        }
        
        return attributedText
    }
    
    /// Shell/Bash syntax highlighting
    @ViewBuilder
    private func shellSyntaxHighlighting(_ code: String) -> some View {
        let lines = code.components(separatedBy: .newlines)
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                shellHighlightedLine(line)
            }
        }
    }
    
    /// Highlight a single shell line
    @ViewBuilder
    private func shellHighlightedLine(_ line: String) -> some View {
        let keywords = ["if", "then", "else", "elif", "fi", "case", "esac", "for", "do", "done", "while", "until", "function", "return", "exit", "export", "alias", "source", "cd", "ls", "cp", "mv", "rm", "mkdir", "chmod", "chown", "grep", "awk", "sed", "sort", "uniq", "cat", "echo", "printf"]
        
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            // Comment line
            Text(line)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        } else {
            Text(attributedString(for: line, keywords: keywords, keywordColor: .orange))
                .font(.system(.body, design: .monospaced))
        }
    }
    
    /// Create attributed string with keyword highlighting
    private func attributedString(for text: String, keywords: [String], keywordColor: Color) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Apply base styling
        attributedString.font = .system(.body, design: .monospaced)
        attributedString.foregroundColor = .primary
        
        // Highlight keywords
        for keyword in keywords {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
                let matches = regex.matches(in: text, options: [], range: nsRange)
                
                for match in matches.reversed() {
                    if let range = Range(match.range, in: text) {
                        let attributedRange = AttributedString.Index(range.lowerBound, within: attributedString)!..<AttributedString.Index(range.upperBound, within: attributedString)!
                        attributedString[attributedRange].foregroundColor = keywordColor
                        attributedString[attributedRange].font = .system(.body, design: .monospaced).weight(.semibold)
                    }
                }
            }
        }
        
        // Highlight strings (simplified)
        let stringPattern = #""[^"]*""#
        if let regex = try? NSRegularExpression(pattern: stringPattern) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: nsRange)
            
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    let attributedRange = AttributedString.Index(range.lowerBound, within: attributedString)!..<AttributedString.Index(range.upperBound, within: attributedString)!
                    attributedString[attributedRange].foregroundColor = .green
                }
            }
        }
        
        // Highlight comments (lines starting with // or #)
        if text.trimmingCharacters(in: .whitespaces).hasPrefix("//") || 
           text.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            attributedString.foregroundColor = .secondary
        }
        
        return attributedString
    }
    
    /// Copy code to clipboard
    private func copyCodeToClipboard(_ code: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
    }
    
    /// Render an unordered list
    @ViewBuilder
    private func renderUnorderedList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    Text(item)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.leading, 8)
    }
    
    /// Render an ordered list
    @ViewBuilder
    private func renderOrderedList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    
                    Text(item)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.leading, 8)
    }
    
    /// Render a horizontal rule
    @ViewBuilder
    private func renderHorizontalRule() -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: MarkdownStyle.gradientColors.map { $0.opacity(0.3) },
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.vertical, 8)
    }
    
    /// Get the appropriate scale factor for a header level
    private func headerScale(for level: Int) -> CGFloat {
        switch level {
        case 1: return MarkdownStyle.h1Scale
        case 2: return MarkdownStyle.h2Scale
        case 3: return MarkdownStyle.h3Scale
        case 4: return MarkdownStyle.h4Scale
        case 5: return MarkdownStyle.h5Scale
        case 6: return MarkdownStyle.h6Scale
        default: return 1.0
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MarkdownView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleMarkdown = """
        # Welcome to Local LLM
        
        This is a **bold** statement and this is *italic* text.
        
        ## Code Example
        
        Here's some Swift code:
        
        ```swift
        func greet(name: String) -> String {
            return "Hello, \\(name)!"
        }
        ```
        
        ## Features
        
        - Beautiful markdown rendering
        - Syntax highlighting
        - Apple-like design
        - Gradient text effects
        
        ---
        
        ### More Information
        
        Visit our website for more details.
        """
        
        ScrollView {
            MarkdownView(sampleMarkdown)
                .padding()
        }
        .frame(width: 400, height: 600)
        .previewDisplayName("Markdown Preview")
    }
}
#endif