// Sources/Hyperchat/InspirationQuotes.swift

import Foundation

/// Manages inspirational quotes for the loading screen
struct InspirationQuotes {
    
    /// The collection of inspirational quotes
    static let quotes: [String] = [
        // Core Truth
        "There is no fate but what we make.",
        "Knowledge is stored intelligence.",
        "The barrier between thought and execution is dissolving.",
        "You are the architect of the next reality.",
        "The best way to predict the future is to invent it.",
        
        // The Moment
        "We are past the event horizon; the takeoff has started.",
        "You are a collaborator in the most important experiment of our time.",
        "In a decade, perhaps everyone on earth will be capable of accomplishing more than the most impactful person can today.",
        "The mutatant apes taught sand to think.",
        "This is the most important thing happening in the world.",
        "We are all gods now.",
        "There's no turning back.",
        
        // The Responsibility
        "What you create here may outlive you.",
        "An intelligence is forming in your image. Be mindful.",
        "Forge your will in silicon.",
        "We can only see a short distance ahead, but we can see plenty there that needs to be done.",
        
        // The Human Element
        "The most important things in my life didn't have to do with computers.",
        "Imagination is more important than knowledge.",
        "Stay hungry. Stay foolish.",
        "Think different.",
        "I am the master of my fate, I am the captain of my soul.",
        "Be who you really are.",
        
        // The Builders' Wisdom
        "Move fast and break things.",
        "First we build the tools, then they build us.",
        "Our technology is part of our humanity.",
        "Never before in human history have so few been able to do so much with so little.",
        "Genius is one percent inspiration and ninety-nine percent perspiration.",
        "AI is going to be extremely, unbelievably important.",
        "Computing is not about computers anymore. It is about living.",

        // Genesis
        "Now they have one language. Nothing they plan to do will be impossible for them.",
    ]
    
    /// Returns a random quote
    static func randomQuote() -> String {
        quotes.randomElement() ?? "Think it into existence."
    }
}