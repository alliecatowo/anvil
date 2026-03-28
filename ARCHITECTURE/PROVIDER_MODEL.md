# Provider Model

Anvil is a multi-provider app.
That means the UI and workflows must describe capabilities, not brands, unless the user is inside a provider setup flow.

## Terms

- `Provider`: the concrete integration implementation.
- `Service`: the app-level orchestrator that selects and coordinates providers.
- `Workspace`: the user-facing area that consumes capabilities from one or more providers.
- `Capability`: a concrete action or query the provider can satisfy.

## Scope

This model applies to:

- AI providers
- database providers
- deployment providers
- messaging providers
- notification providers
- source control providers
- search and indexing providers

## Rules

- Shared UI may not hardcode a concrete provider name in labels, buttons, or empty states.
- Provider-specific branding belongs only in setup, configuration, or provider detail views.
- Every provider surface must expose an honest capability set.
- A provider integration is not complete until it supports configuration, connection, capability discovery, execution, error handling, empty/setup states, and persistence where applicable.
- UI should branch on capabilities, not on brand names.
- Shared shell labels should describe the capability, not the vendor.
- A provider may appear in the shell only as a configured source, not as a shortcut for the entire workspace model.

## Capability Set

Common capabilities include:

- `connect`
- `disconnect`
- `discover`
- `list`
- `browse`
- `execute`
- `stream`
- `inspect`
- `search`
- `history`
- `export`
- `sync`
- `install`
- `deploy`

If a provider cannot do one of these, the UI must not pretend it can.

## Provider States

Use honest provider states instead of implied support:

- `unconfigured`
- `connecting`
- `connected`
- `capability-degraded`
- `disconnected`
- `error`

The UI must say which state is active and what the next action is.

## Current Database Rule

- SQLite is one valid provider implementation, not the shape of the feature.
- The shared database UX must stay provider-aware so PostgreSQL, MySQL, and other backends can be added without changing the shell contract.
- The connection UI must show the selected provider only in setup and provider detail.
- Database browsing, query history, results, export, and empty states must all work as capability-driven surfaces.

## Current Hosting Rule

- Hosting UI must separate project identity, environment identity, deployment identity, and provider identity.
- Provider-specific terms such as Vercel may appear in setup or provider-scoped detail only.
- The deployment surface must still read correctly when multiple hosting providers coexist.

## Completion Checklist

- Provider selector exists where multiple providers are possible.
- Capability gaps are represented as disabled or absent actions, not fake ones.
- Empty states say what provider or capability is missing.
- Error states tell the user what failed and what to do next.
- The workspace can restore the last active provider and connection when that makes sense.
- The shared shell can add a second provider without renaming the workspace.
