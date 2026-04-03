# ScreenshotRouter

A lightweight macOS menu bar app that intercepts screenshots and lets you instantly route them to a folder of your choice.

## How it works

Trigger a screenshot with your configured shortcut (default: `⌃⌥⌘4`). Instead of the screenshot landing in your default location, a compact folder picker appears — press 1–9 to pick a destination, or click a folder. The file is moved there instantly and a small "Saved" confirmation fades in and dismisses itself.

## Features

- Global hotkey to trigger screenshot capture
- Quick folder picker HUD with keyboard shortcuts (1–9)
- Supports unlimited destination folders
- Success animation with auto-dismiss
- Configurable shortcut via Settings
- Adapts to light and dark menu bar

## Requirements

- macOS 12+
- Accessibility permission (for global hotkey)
- Screen Recording permission (for screenshot capture)

## Installation

1. Download the latest release and unzip
2. Move `ScreenshotRouter.app` to your Applications folder
3. Open it — right-click → Open if macOS warns about an unidentified developer
4. Grant Accessibility and Screen Recording permissions when prompted

## Usage

- **Menu bar icon** → Settings to add/remove destination folders and change the shortcut
- **Trigger shortcut** → activates screenshot capture; folder picker appears after you select a region
- **1–9 keys** → instantly move the screenshot to that folder
- **Re-trigger shortcut while "Saved" is showing** → dismisses it
