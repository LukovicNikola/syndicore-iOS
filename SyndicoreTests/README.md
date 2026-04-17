# SyndicoreTests

Unit test suite za Syndicore iOS. Pokriva decode logiku, Isometric math, i APIClient retry/error handling.

## Setup (Xcode-only, ne može iz terminala)

Test target **još nije dodat** u `Syndicore.xcodeproj`. Dodaj ga ručno:

1. Xcode → File → New → Target
2. Izaberi **Unit Testing Bundle**
3. Product Name: `SyndicoreTests`
4. Language: Swift
5. Target to be Tested: `Syndicore`
6. Kad se target kreira, dodaj postojeci `SyndicoreTests/` folder u target:
   - Desni klik na `SyndicoreTests` target → Add Files → izaberi sve .swift + .json fajlove pod `SyndicoreTests/`
7. Za JSON fixture-e: u File Inspector (desni panel), proveri da su Fixtures/*.json dodati u **SyndicoreTests** target membership. Ovo garantuje da se bundle-uju u test bundle.

## Struktura

```
SyndicoreTests/
├── Fixtures/              # JSON response sample-ovi iz staging-a
│   ├── city.json
│   └── battle_report.json
├── Models/
│   └── DecodingTests.swift    # Codable decode + date parsing
├── Scene/
│   └── IsometricTests.swift   # iso projection round-trip, bounds
└── Services/
    └── APIClientTests.swift   # 401 retry, mock URLProtocol
```

## Pokretanje

- Xcode: `⌘U` (Product → Test)
- CLI (nakon target setup-a):
  ```bash
  xcodebuild test -scheme Syndicore -destination 'platform=iOS Simulator,name=iPhone 15'
  ```

## Regeneracija fixture-a iz staging-a

TODO: skripta `scripts/refresh-fixtures.sh` koja hit-uje staging sa test account-om i prepisuje JSON fajlove. Za sada su fixture-i ručno pisani na osnovu dokumentovanih BE response shape-ova.
