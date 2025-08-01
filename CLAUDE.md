# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JunoApp is an iOS SwiftUI application that provides an AI-powered voice assistant named "Juno Vox". The app features conversational AI with text-to-speech capabilities, persona-based interactions, memory functionality, and Spotify integration.

## Build Commands

### Xcode Project
- **Build**: Use Xcode to build the project (`Cmd+B`) or use `xcodebuild -scheme JunoApp build`
- **Run**: Use Xcode to run the app (`Cmd+R`) or use `xcodebuild -scheme JunoApp -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug`
- **Test**: No test targets are currently configured in the scheme
- **Archive**: Use Xcode Product → Archive or `xcodebuild -scheme JunoApp archive`

## Architecture

### Core Structure
- **App Entry Point**: `JunoApp/App/JunoApp.swift` - Main SwiftUI App with `AppState` environment object
- **App State**: `JunoApp/App/AppState.swift` - Global state management with `@MainActor` compliance for persona selection and audio playback state
- **API Client**: `JunoApp/API/JunoAPIClient.swift` - HTTP client for backend communication at `https://djpresence.com:5020`

### Key Components

#### API Integration
- **Base URL**: `https://djpresence.com:5020`
- **Endpoints**: 
  - `/api/chat` - Chat conversations with personality parameter
  - `/api/tts` - Text-to-speech synthesis
  - `/api/memory/summary` - Memory retrieval
- **Error Handling**: Custom `APIClientError` enum with localized descriptions

#### Audio System
- **Audio Session**: `JunoApp/Audio/AudioSession.swift` - Singleton `AudioSessionManager` with playback/recording configurations
- **Player Management**: Integrated into `ChatViewModel` with AVPlayer for TTS audio playback
- **Background Audio**: Configured for background audio playback (see Info.plist UIBackgroundModes)

#### View Models (All @MainActor)
- **ChatViewModel**: Handles chat flow, TTS integration, and audio playback state
- **MemoryViewModel**: Manages memory summary fetching and API interactions
- **ConversationViewModel**: Additional conversation management

#### Persona System
- **PersonaMode**: Enum with cases: base, sassy, empathy, hype
- **Integration**: Persona passed to chat API and managed in AppState

### Data Models
- **ChatMessage**: Core message structure with audio URL support
- **MemorySummaryDTO**: Data transfer object for memory API responses
- **PersonaMode**: Enum for AI personality modes

### Views Structure
- **ChatView**: Main chat interface with message bubbles and audio controls
- **MemoryView**: Memory/summary display interface  
- **ConversationView**: Additional conversation management UI
- **Components**: Reusable UI components in `Views/Components/`

## Development Guidelines

### Threading & Concurrency
- All ViewModels use `@MainActor` for UI thread safety
- API calls use async/await pattern
- Audio operations properly manage main thread updates

### Audio Permissions
- Microphone access required (NSMicrophoneUsageDescription in Info.plist)
- Apple Music access configured (NSAppleMusicUsageDescription)
- Background audio modes enabled for continuous playback

### API Client Usage
- Centralized HTTP client with error handling
- Automatic URL building for audio file paths (handles relative/absolute URLs)
- JSON serialization for request/response handling

### State Management
- Global state via `AppState` environment object
- Published properties for reactive UI updates
- Proper cleanup in deinit methods (especially audio resources)

## Common Development Patterns

### Adding New API Endpoints
1. Add method to `APIClient` class following existing async/throws pattern
2. Update error handling in ViewModels
3. Add corresponding UI state management

### Audio Integration
- Use `AudioSessionManager.shared.configureForPlayback()` before audio operations
- Implement proper cleanup with `stopAudio()` methods
- Monitor player state with NotificationCenter observers

### Persona Integration
- Access current persona via `AppState.selectedPersona`
- Pass persona.rawValue to API chat calls
- Update UI to reflect persona-specific behavior

## Project Configuration
- **Bundle ID**: Configured via PRODUCT_BUNDLE_IDENTIFIER
- **Display Name**: "Juno Vox"
- **iOS Deployment**: Requires iOS device capabilities (armv7)
- **Network Security**: NSAllowsArbitraryLoads enabled for development