# Ukishima — Personal Fork

A personal fork of [Ukishima](https://github.com/amanhex/ukishima), extended and maintained as a customized desktop shell for **Quickshell**, **Wayland**, and **Hyprland**.

This fork retains the original Ukishima architecture and visual philosophy while introducing additional components, integrations, configuration options, and desktop workflows developed for personal use.

## Overview

Ukishima is a modular desktop shell built with Quickshell and QML. It provides a unified interface for desktop navigation, system controls, application management, media, recording, and configuration.

This fork expands that functionality with a particular focus on:

* Hyprland integration
* application and workspace management
* media management
* screen recording
* configurable shell behavior
* consistent animation and visual design
* Wayland-native components

## Beats

**Beats** is an integrated music interface developed for this fork.

It provides separate workflows for local and online music, including:

* Local music library browsing
* Local music search
* Online music search
* Playback controls
* Music management
* Separate local and online views
* Support for music stored on mounted network storage
* Efficient browsing of large music collections

The local library implementation is designed to minimize unnecessary filesystem and metadata operations, making it suitable for libraries stored on network-mounted filesystems.

## Application Dock

This fork introduces a native application dock implemented directly within Ukishima.

The dock is designed to integrate with the shell rather than operating as a separate desktop application.

Features include:

* Bottom, left, right, top-left, and top-right positioning
* Hidden-by-default edge activation
* Optional always-visible mode
* Configurable size
* Configurable reveal duration
* Application pinning
* Application launching
* Active application indication
* Running application indication
* Workspace-aware application detection
* Workspace indicators for applications running elsewhere
* Switching to another workspace when activating an application located there
* Search integration with the existing Ukishima launcher
* Middle-click support for closing running application windows
* Fullscreen-aware visibility
* Optional screen-space reservation in always-visible mode
* Overlay behavior for top-corner configurations
* Subtle visual indicators for hidden dock states

The dock uses the same visual components, motion system, and theme definitions as the rest of Ukishima.

## Screen Recording

The fork includes an integrated screen-recording workflow designed for Wayland and Hyprland.

One of its primary use cases is instant replay recording, allowing the user to save the most recent **30 seconds** of desktop activity without having to manually begin recording in advance.

This is intended for:

* Quickly capturing unexpected events
* Demonstrating software behavior
* Recording short gameplay moments
* Capturing bugs or visual issues
* Creating short desktop demonstrations

The recording workflow is integrated into the shell and is intended to remain lightweight and unobtrusive.

## Hyprland Integration

The fork makes extensive use of Hyprland's desktop state to provide context-aware behavior.

The shell integrates with:

* Monitors
* Workspaces
* Toplevel windows
* Active window state
* Application identifiers
* Fullscreen state
* Wayland layer-shell surfaces

This allows components such as the application dock to reflect the current state of the desktop and react to workspace and window changes.

## Appearance and Configuration

The settings system has been extended to expose configuration for the additional functionality introduced by this fork.

Available configuration includes:

* Interface scaling
* Themes
* Fonts
* Reduced-motion behavior
* Auto-hide behavior
* Dock enable/disable state
* Dock position
* Dock size
* Dock visibility mode
* Dock reveal duration
* Application pinning
* Kanji/glyph display mode

The configuration is intended to allow behavioral and visual changes without directly editing the underlying QML components.

## Kanji and Glyph Mode

Ukishima provides an optional glyph/Kanji-oriented interface mode.

When enabled, supported interface elements can use dedicated Kanji labels instead of their standard textual labels.

The fork extends this system to additional components, including the application dock and its settings interface.

## Architecture

The project is primarily implemented using:

* Quickshell
* QML
* JavaScript
* Wayland
* Hyprland

The additional functionality is implemented as native Quickshell surfaces and components wherever possible.

Shared application resolution is handled through reusable JavaScript utilities, allowing desktop entries to be resolved consistently across different shell components.

## Design Principles

This fork follows several principles:

1. **Wayland-native integration**
   Functionality should integrate with the Wayland and Hyprland environment rather than relying on unnecessary external desktop components.

2. **Consistent visual language**
   New interfaces should use the existing Ukishima theme, typography, motion, and component system.

3. **Context-aware behavior**
   Components should respond to the current monitor, workspace, application, and window state where appropriate.

4. **Minimal persistent UI**
   Interfaces should remain unobtrusive and appear when needed rather than permanently occupying the desktop.

5. **Configurable behavior**
   User-facing behavior should preferably be exposed through the shell's settings system.

## Project Status

This repository is a **personal fork of the original Ukishima project**.

It contains substantial modifications and additional functionality that are not part of upstream Ukishima, including:

* Beats
* Native application Dock
* Workspace-aware application management
* Instant 30-second replay recording
* Extended Hyprland integration
* Additional configuration options
* Kanji/glyph extensions
* Additional UI and interaction improvements

The repository is primarily maintained for personal use, experimentation, and continued development.

## Credits

Original project:

**Ukishima** by `amanhex`

This repository is an independent personal fork and is not the official Ukishima project.

Original project authors and contributors retain credit for the upstream work. All additional modifications and components in this repository are maintained independently.

