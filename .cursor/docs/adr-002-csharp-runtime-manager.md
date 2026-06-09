# ADR 002: Global C# Runtime Manager

## Status

Accepted.

## Context

The terrain renderer introduced C# for the map hot path, but a local
`TerrainRuntimeHost` made the GDScript/C# boundary implicit and tied the bridge
to one subsystem. Additional C# systems would repeat that pattern and make
service lifetime, task cancellation, and parser-safe GDScript access harder to
reason about.

## Decision

Use a global `CSharpRuntimeManager` Autoload as the only GDScript-facing C#
entry point. Keep the manager with other core services under
`assets/src/core/csharp-manager`, and keep domain-specific C# systems under
`assets/src/csharp`.

- GDScript calls `/root/CSharpRuntimeManager`; it does not preload `.cs` files
  or instantiate C# class names directly.
- The manager owns terrain visual job scheduling, cancellation, result draining,
  and C# canvas creation.
- Terrain workers return pure C# data objects; Godot dictionaries and nodes are
  created on the main thread.

## Alternatives

- Keep local host scenes per subsystem: lower immediate churn, but repeated
  bridge code and unclear task ownership.
- Let GDScript directly instantiate C# classes: fragile because this project's
  C# classes are not visible to the GDScript parser as global class names.

## Impact

The C# boundary is now explicit and reusable. Future C# hot paths should add a
small manager-facing API instead of exposing raw C# implementation classes to
GDScript. The tradeoff is one global service locator, kept narrow by limiting it
to cross-language runtime infrastructure rather than gameplay rules.
