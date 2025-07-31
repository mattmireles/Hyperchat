/// Objective-C Bridging Header for Hyperchat
///
/// This file exposes C and C++ headers to Swift code in the Hyperchat target.
/// It bridges the llama.cpp C API to make it available in Swift.
///
/// Called by:
/// - Swift compiler when building any Swift file that uses C functions
/// - Configured via SWIFT_OBJC_BRIDGING_HEADER build setting
///
/// This enables:
/// - InferenceEngine.swift to call llama.cpp functions directly
/// - Swift code to use C types like OpaquePointer for llama models/contexts

#import "llama.h"