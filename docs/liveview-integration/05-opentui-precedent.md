# OpenTUI Precedent Analysis

## How OpenTUI Solved the Same Problem

OpenTUI (TypeScript) solved this exact problem with their React and SolidJS integrations. Their architecture provides the blueprint for ElixirOpentui's LiveView integration.

## Side-by-Side Comparison

| OpenTUI (TypeScript) | ElixirOpentui (Elixir) |
|---|---|
| `@opentui/core` (no framework deps) | `elixir_opentui` (no Phoenix deps) |
| `@opentui/react` (React reconciler) | `elixir_opentui_live` (LiveView adapter) |
| `componentCatalogue` (tag -> constructor) | Element type -> HTML mapping |
| `react-reconciler` host config | LiveView lifecycle -> Runtime bridge |
| `Renderable` class hierarchy | `Element` struct + `Component` behaviour |
| Yoga layout engine | Flexbox Lite layout engine |
| Zig native buffer/diff | Zig NIF buffer/diff |
| `useRenderer()` hook | LiveView assigns + PubSub |

## Key Patterns from OpenTUI

### 1. Framework-Agnostic Core

OpenTUI's core has zero knowledge of React or SolidJS. The rendering pipeline operates on its own `Renderable` tree. Framework adapters translate between their native component model and OpenTUI's core.

**ElixirOpentui equivalent**: The `Element` struct, `Layout` engine, `Buffer`, and `Painter` have zero knowledge of LiveView. The adapter in `elixir_opentui_live` translates between LiveView's lifecycle and ElixirOpentui's core.

### 2. Thin Adapter Layer

OpenTUI's React adapter implements the `react-reconciler` host config — a ~200 line interface that maps React tree operations (appendChild, removeChild, commitUpdate) to OpenTUI operations.

**ElixirOpentui equivalent**: The HTML adapter is ~300 lines mapping Element types to HEEx templates. The event adapter maps `phx-click`/`phx-keyup` to ElixirOpentui `Input.event()` structs.

### 3. Component Catalogue

OpenTUI uses a `componentCatalogue` that maps string tags to component constructors. This decouples the framework adapter from specific component implementations.

**ElixirOpentui equivalent**: The `Element.element_type()` typespec already defines the catalogue. The HTML adapter pattern-matches on these types to produce corresponding HTML elements.

### 4. Layout Independence

OpenTUI uses Yoga (C++ via WASM) for layout. The layout engine is independent of both the framework adapter and the rendering backend.

**ElixirOpentui equivalent**: `Layout` (pure Elixir Flexbox Lite) is already independent. For web rendering, we can skip our layout engine entirely and let CSS flexbox handle it — the Style struct maps 1:1 to CSS properties.

## What OpenTUI Validates

1. **Separation works**: A TUI framework CAN support multiple frontend frameworks via thin adapters
2. **The core needn't change**: Adding React support to OpenTUI required zero changes to the core rendering pipeline
3. **Multiple adapters coexist**: React and SolidJS adapters ship independently without conflicting
4. **Layout can be delegated**: When rendering to web, native CSS layout is more appropriate than the TUI layout engine

## What OpenTUI Doesn't Address

1. **State sync across clients**: OpenTUI is single-user. H4's PubSub approach extends beyond OpenTUI's model
2. **Server-side rendering**: LiveView renders on the server; OpenTUI's adapters render client-side. This is a fundamental difference that affects the adapter design
3. **Terminal-in-browser**: OpenTUI doesn't stream ANSI to the browser (H1). This is unique to ElixirOpentui's architecture
