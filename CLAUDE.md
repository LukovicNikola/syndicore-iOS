# Syndicore iOS

Cyberpunk real-time strategy MMO — Swift/SwiftUI iOS client.

## Architecture

- **Target**: iOS 17+, Swift 5.9+, SwiftUI
- **Auth**: Supabase (ES256 JWT via JWKS) — tokens managed via `supabase-swift` SDK
- **Networking**: Native `URLSession` async/await, no third-party deps
- **State**: `@Observable` macro (Observation framework)

## Project Structure

```
Syndicore/
├── App/              # SwiftUI app entry point, app-level state
├── Models/           # Codable data models (generated from OpenAPI spec)
├── Networking/       # APIClient, endpoints, auth token provider
├── Views/            # SwiftUI views grouped by feature
└── Resources/        # Info.plist, asset catalogs
SyndicoreContracts/   # Auto-synced from syndicore-BE (DO NOT EDIT)
```

## Contracts

`SyndicoreContracts/` is auto-synced from `syndicore-BE` on every merge to `main`.
Do **not** edit files in that folder — push contract changes to the BE repo.

Key contract files:
- `openapi.json` — API schema (endpoints, request/response types)
- `game-constants.json` — All balance numbers, unit stats, building formulas
- `VERSION` — BE commit hash that produced these contracts

## API Base URLs

| Environment | URL |
|-------------|-----|
| Local       | `http://localhost:3000` |

All endpoints under `/api/v1/`. Auth endpoints require `Authorization: Bearer <supabase_token>`.

## Key Conventions

- Models use `camelCase` property names matching the API JSON keys
- Enums (`Faction`, `Ring`) use `UPPER_CASE` raw values matching Prisma enums
- Dates are ISO 8601 (`date-time` format)
- IDs are UUID strings
- Game constants are cached client-side using `ETag` / `If-None-Match`

## Commands

```bash
# Build (requires Xcode 15+)
xcodebuild -scheme Syndicore -destination 'platform=iOS Simulator,name=iPhone 15'

# Tests
xcodebuild test -scheme Syndicore -destination 'platform=iOS Simulator,name=iPhone 15'

# SwiftLint (if installed)
swiftlint
```
