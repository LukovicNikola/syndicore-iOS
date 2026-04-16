# SYNDICORE iOS — Claude Instructions

## PRAVILA ZA CLAUDE-A

- **Uvek pitaj pre nego što pretpostaviš.** 20 pitanja bolje nego jedna pogrešna pretpostavka. Ponudi opcije i pusti korisnika da izabere.
- **Objasni detaljno šta radiš i kako** — korisnik je SAP UI5 developer koji uči iOS/Swift. Koristi analogije sa web/frontend svetom.
- **Temeljno produkcijski kvalitet** — nema prečica, proper error handling, proper architecture.
- **Solo projekat, nema roka, nema žurbe.**
- **Odgovaraj na srpskom, Latinica.** Tehnički termini OK na engleskom.
- **Predloži plan pre nego što pišeš kod.**

---

## PROJEKAT

Cyberpunk real-time strategy MMO (Travian stil). Jedan igrač ima JEDAN grad koji progresira kroz 4 ringa mape putem Crystal Implosion mehanike.

- **Backend repo:** github.com/LukovicNikola/syndicore-BE
- **iOS repo:** github.com/LukovicNikola/syndicore-iOS (ovaj)
- **Staging API:** https://syndicore-be-staging.onrender.com
- **Swagger UI:** https://syndicore-be-staging.onrender.com/docs
- **Contracts:** `SyndicoreContracts/openapi.json` + `game-constants.json` (auto-sync iz BE)

---

## TECH STACK (iOS)

- **Swift, iOS 17+**
- **SwiftUI** za SVE ekrane OSIM mape
- **SpriteKit** za MapView — tile grid sa 40k+ tile-ova, pan/zoom/pinch, ring boje, Warp Gate linije, occupant ikonice. Embeduje se u SwiftUI preko `SpriteView`.
- **Supabase Auth:** `supabase-swift` SDK (SPM: `https://github.com/supabase/supabase-swift`)
- **Networking:** URLSession + async/await
- **Cache:** SwiftData
- **Real-time:** Socket.IO Swift client (za kasniju fazu — za sada samo REST)

---

## BACKEND STATUS (šta je implementirano i radi)

Backend je **funkcionalan** sa sledećim sistemima:

| Sistem | Status | Opis |
|---|---|---|
| Auth | ✅ | Supabase Auth (ES256 JWT via JWKS) |
| Multi-world | ✅ | Više servera, igrač bira koji da igra |
| Map generation | ✅ | 4 ringa, Warp Gates, Outposts, Mines |
| City management | ✅ | Buildings + on-demand resource calc |
| Building construction | ✅ | BullMQ timer, cost formula, queue |
| Troop training | ✅ | Per-building queue, unlock levels |
| Troop movement | ✅ | Pathfinding sa Warp Gate network |
| Combat | ✅ | 3 faze (Siege→Battle→Aftermath), loot, return trips |
| Battle reports | ✅ | Detaljni izveštaji sa before/after/lost |
| Map viewport | ✅ | Tile grid sa svim occupant-ima |
| Game constants | ✅ | Public endpoint, ETag caching |
| Observability | ✅ | Sentry + Better Stack + Grafana Cloud |

---

## AUTH MEHANIZAM

Supabase izdaje JWT (ES256, asimetrično potpisan). Backend verifikuje preko JWKS.

```swift
import Supabase

let supabase = SupabaseClient(
  supabaseURL: URL(string: "SUPABASE_URL_IZ_CONFIG_PLIST")!,
  supabaseKey: "ANON_KEY_IZ_CONFIG_PLIST"
)

// Sign up
try await supabase.auth.signUp(email: email, password: password)

// Sign in
let session = try await supabase.auth.signIn(email: email, password: password)

// Get token za BE pozive
let token = try await supabase.auth.session.accessToken
```

Supabase URL i anon key stavi u `Config.plist` (ne hardcode). Vrednosti:
- URL: `https://zdtzsruzqjrtjkbtvsjo.supabase.co`
- Anon key: pita korisnika

Svaki BE request šalje header: `Authorization: Bearer <accessToken>`

---

## KORISNIČKI FLOW (redosled ekrana)

```
SplashScreen
    │ fetch GET /api/v1/config (game constants, cache lokalno)
    ▼
AuthScreen
    │ Supabase sign in / sign up
    ▼
OnboardingScreen
    │ GET /api/v1/me → ako 404 → prikaži username input
    │ POST /api/v1/me/onboarding { username }
    ▼
WorldPickerScreen
    │ GET /api/v1/worlds → lista servera
    ▼
FactionPickerScreen
    │ izaberi REAPERS / HEGEMONY / NETRUNNERS
    │ POST /api/v1/worlds/:id/join { faction }
    ▼
MainGameScreen (TabView)
    ├── CityView      (SwiftUI — buildings, resources, construction queue, training)
    ├── MapView        (SpriteKit — tile grid, gradovi, trupe, Warp Gates)
    ├── ArmyView       (SwiftUI — troops, send attack, movements)
    ├── SyndikatView   (SwiftUI — clan management) [placeholder za sada]
    └── ResearchView   (SwiftUI — tech tree) [placeholder za sada]
```

---

## KOMPLETNA API REFERENCA (16 ruta)

Staging URL: `https://syndicore-be-staging.onrender.com`

### Sistem

| Method | Path | Auth | Opis |
|--------|------|------|------|
| GET | `/health` | — | Health check, vraća `{ status, game, db, commit }` |
| GET | `/api/v1/config` | — | Game constants (ETag caching, public). Vraća ceo `game-constants.json`. Šalji `If-None-Match` za 304. |
| GET | `/openapi.json` | — | OpenAPI 3.1 spec |
| GET | `/docs` | — | Swagger UI (samo staging) |

### Player

| Method | Path | Auth | Body | Response |
|--------|------|------|------|----------|
| GET | `/api/v1/me` | JWT | — | `{ player: { id, username, createdAt, updatedAt, worlds: [...] } }` ili 404 `{ error: "onboarding_required" }` |
| POST | `/api/v1/me/onboarding` | JWT | `{ "username": "ime" }` | 201 `{ player }` ili 409 `already_onboarded` / `username_taken` |

### Worlds

| Method | Path | Auth | Body | Response |
|--------|------|------|------|----------|
| GET | `/api/v1/worlds` | — | — | `{ worlds: [{ id, name, slug, status, speedMultiplier, mapRadius, maxPlayers, playerCount }] }` |
| GET | `/api/v1/worlds/:id` | — | — | Isto kao gore ali za jedan svet |
| POST | `/api/v1/worlds/:id/join` | JWT | `{ "faction": "REAPERS" }` | 201 `{ playerWorld: { id, faction, ring, crystals }, city: { id, name }, tile: { x, y } }` |

### Map

| Method | Path | Auth | Query | Response |
|--------|------|------|-------|----------|
| GET | `/api/v1/worlds/:worldId/map` | JWT | `cx=0&cy=0&r=20` | `{ viewport: { cx, cy, radius }, tileCount, tiles: [{ x, y, ring, terrain, rarity, city, outpost, mine, warpGate, ruins }] }` |

**Tile structure u map response-u:**
```json
{
  "x": 5, "y": -3,
  "ring": "FRINGE",
  "terrain": "FLATLAND",
  "rarity": "COMMON",
  "city": { "id": "...", "name": "Player's Base", "owner": "username", "ownerId": "uuid", "faction": "REAPERS" } | null,
  "outpost": { "id": "...", "level": 3, "defeated": false } | null,
  "mine": { "id": "...", "resourceType": "CREDITS", "productionRate": 100, "owned": false } | null,
  "warpGate": { "id": "..." } | null,
  "ruins": { "id": "...", "originalRing": "FRINGE", "decaysAt": "2026-05-01T..." } | null
}
```

Radius je cappiran na 50. Za pan/zoom: refetch sa novim `cx`, `cy` kad kamera se pomeri.

### City

| Method | Path | Auth | Body / Query | Response |
|--------|------|------|-------------|----------|
| GET | `/api/v1/cities/:id` | JWT | — | `{ city: { id, name, resources: { credits, alloys, tech, energy }, tile: { x, y, ring, terrain, rarity }, buildings: [...], troops: [...], constructionQueue } }` |
| POST | `/api/v1/cities/:id/build` | JWT | `{ "buildingId": "..." }` za upgrade ILI `{ "buildingType": "DATA_BANK", "slotIndex": 4 }` za novo | 200 `{ building: { id, type, targetLevel, endsAt }, cost }` |
| GET | `/api/v1/cities/:id/build-cost` | JWT | `?buildingId=X` | `{ buildingType, currentLevel, targetLevel, cost: { credits, alloys, tech }, durationMinutes }` |
| POST | `/api/v1/cities/:id/train` | JWT | `{ "unitType": "GRUNT", "count": 10 }` | 200 `{ trainingJob: { id, unitType, count, endsAt }, cost }` |
| GET | `/api/v1/cities/:id/training` | JWT | — | `{ training: [{ id, unitType, count, endsAt }] }` |

**Building data u city response-u:**
```json
{ "id": "...", "type": "HQ", "level": 1, "isUpgrading": false, "upgradeEnd": null, "slotIndex": null }
```

**Starter buildings (kreiraju se pri join-u):** HQ:1, DATA_BANK:1, FOUNDRY:1, TECH_LAB:1, POWER_GRID:1

**Resursi su on-demand:** svaki GET `/cities/:id` automatski osvežava resurse po elapsed time od zadnjeg pristupa. Nema periodic tick-a — lazy evaluation.

### Troops & Movement

| Method | Path | Auth | Body | Response |
|--------|------|------|------|----------|
| POST | `/api/v1/cities/:id/send` | JWT | `{ "targetX": 5, "targetY": -3, "units": { "GRUNT": 50 }, "movementType": "ATTACK" }` | 200 `{ movement: { id, from, to, units }, route: { direct, viaGates, travelMinutes, arrivesAt } }` |
| GET | `/api/v1/worlds/:worldId/movements` | JWT | — | `{ movements: [{ id, type, from, to, units, routeViaGates, departedAt, arrivesAt, isReturning }] }` |

**MovementType enum:** `ATTACK`, `RAID`, `SCOUT`, `REINFORCE`, `TRANSPORT`, `SETTLE`, `RETURN`

**Pathfinding:** server automatski bira najkraću rutu (direktna ili kroz Warp Gate network). `route.viaGates` je lista gate ID-ova ako je gate ruta brža. `route.direct` je `true` ako je direktna ruta brža.

**Army speed:** najsporija jedinica u grupi (tiles per hour). Prikazano u `travelMinutes`.

### Battle Reports

| Method | Path | Auth | Response |
|--------|------|------|----------|
| GET | `/api/v1/worlds/:worldId/reports` | JWT | `{ reports: [{ id, attackerWon, targetX, targetY, ratio, totalAtk, totalDef, attackerUnits, defenderUnits, resourcesStolen, buildingsDamaged, occurredAt, isAttacker }] }` |

**attackerUnits / defenderUnits structure:**
```json
{
  "before": { "GRUNT": 50, "ENFORCER": 20 },
  "after": { "GRUNT": 35, "ENFORCER": 14 },
  "lost": { "GRUNT": 15, "ENFORCER": 6 }
}
```

### WebSocket Events (Socket.IO — za kasniju implementaciju)

Server emituje u `city:<cityId>` room:
- `building_complete { buildingId, newLevel }`
- `training_complete { unitType, count }`

Server emituje u `world:<worldId>` room:
- `troops_arrived { movementId, type, targetX, targetY }`

---

## MAPA (4 ringa, kvadratni grid)

Ring se određuje Chebyshev distance-om: `max(|x|, |y|)` od centra `(0,0)`.

| Ring | Boja za SpriteKit | Opis |
|------|-------------------|------|
| **FRINGE** | Siva / bela (#E0E0E0) | Starter zona, spoljni prsten |
| **GRID** | Narandžasta (#FF8C00) | PvP zona, srednji prsten |
| **CORE** | Crvena (#DC143C) | Elite zona, unutrašnji prsten |
| **NEXUS** | Ljubičasta / zlatna (#9B30FF) | Endgame centar |

**Terrain boje (SpriteKit tile-ovi):**

| Terrain | Ikonica / boja |
|---------|---------------|
| FLATLAND | Zelena |
| QUARRY | Smeđa |
| RUINS | Tamno siva |
| GEOTHERMAL | Narandžasto-crvena |
| HILLTOP | Svetlo smeđa |
| RIVERSIDE | Plava |
| CROSSROADS | Žuta |
| WASTELAND | Tamna siva |

**Rarity vizualni indikator:**
- COMMON: normalan tile
- UNCOMMON: blagi sjaj / plavi border
- RARE: zlatni sjaj / border

**Occupant ikonice na tile-ovima:**
- City: kućica ikonica sa username-om
- Outpost: crvena lobanja (NPC)
- Mine: kristal ikonica (boja po resourceType)
- Warp Gate: ljubičasti portal
- Ruins: razrušena kućica

**Warp Gate linije:** tanke ljubičaste linije između svih gate-ova na mapi (complete graph — svi su međusobno povezani). Koristiti `SKShapeNode` sa `path`.

---

## FAKCIJE (3)

Sve koriste ISTI roster jedinica. Razlika je u tech tree branch-u.

| Faction | Boja za UI | Ikonica |
|---------|-----------|---------|
| REAPERS | Crvena (#FF4444) | ⚔️ ili custom sword icon |
| HEGEMONY | Plava (#4488FF) | 🛡️ ili custom shield icon |
| NETRUNNERS | Zelena (#44FF88) | 💻 ili custom circuit icon |

---

## JEDINICE — Universal Roster (8 + Settler)

| Unit | Role | ATK | DEF | SPD | CARRY | ⚡/h | Trains at | Unlock lvl |
|------|------|-----|-----|-----|-------|------|-----------|------------|
| GRUNT | Fodder | 30 | 12 | 11 | 40 | 1 | Barracks | 1 |
| ENFORCER | Core | 65 | 35 | 8 | 20 | 2 | Barracks | 5 |
| SENTINEL | Defense | 20 | 70 | 6 | 10 | 3 | Barracks | 10 |
| STRIKER | Vehicle | 60 | 20 | 20 | 60 | 3 | Motor Pool | 1 |
| HAULER | Transport | 0 | 15 | 14 | 120 | 1 | Motor Pool | 5 |
| PHANTOM | Scout | 5 | 5 | 24 | 0 | 1 | Ops Center | 5 |
| BUSTER | Siege | 10 | 8 | 4 | 0 | 5 | Ops Center | 10 |
| TITAN | Clan elite | 200 | 200 | 4 | 0 | 15 | War Factory | 1 |
| SETTLER | Expansion | 0 | 0 | 5 | 0 | 0 | HQ | 20 |

---

## BUILDINGS

**Resource buildings (flex slots):** DATA_BANK, FOUNDRY, TECH_LAB, POWER_GRID
**Fixed buildings (one each):** HQ, BARRACKS, MOTOR_POOL, OPS_CENTER, WAREHOUSE, WALL, WATCHTOWER, RALLY_POINT, TRADE_POST, RESEARCH_LAB

**Building cost formula:** `baseCost × 1.5^(level-1)` per resource
**Construction time:** `baseTimeMinutes × 1.4^(level-1)`

HQ level → flex slots: 1=9, 10=14, 20=18.
ONE construction queue — jedan build istovremeno po gradu.

---

## SWIFT MODELI (Codable structs)

```swift
struct Player: Codable, Identifiable {
    let id: String
    let username: String
    let createdAt: String
    let updatedAt: String
    let worlds: [PlayerWorld]?
}

struct PlayerWorld: Codable, Identifiable {
    let id: String
    let playerId: String
    let worldId: String
    let faction: Faction
    let ring: Ring
    let crystals: [String]
    let joinedAt: String
    let city: City?
}

struct World: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let status: String  // OPEN, RUNNING, ENDED, ARCHIVED
    let speedMultiplier: Double
    let mapRadius: Int
    let maxPlayers: Int
    let playerCount: Int
}

struct City: Codable, Identifiable {
    let id: String
    let name: String
    let resources: Resources?
    let tile: TileInfo?
    let buildings: [BuildingInfo]?
    let troops: [TroopInfo]?
    let constructionQueue: ConstructionQueue?
}

struct Resources: Codable {
    let credits: Double
    let alloys: Double
    let tech: Double
    let energy: Double
}

struct TileInfo: Codable {
    let x: Int
    let y: Int
    let ring: Ring
    let terrain: Terrain
    let rarity: Rarity
}

struct BuildingInfo: Codable, Identifiable {
    let id: String
    let type: BuildingType
    let level: Int
    let isUpgrading: Bool
    let upgradeEnd: String?
    let slotIndex: Int?
}

struct TroopInfo: Codable {
    let unitType: String
    let count: Int
}

struct ConstructionQueue: Codable {
    let buildingId: String
    let type: String
    let endsAt: String?
}

struct TrainingJob: Codable, Identifiable {
    let id: String
    let unitType: String
    let count: Int
    let endsAt: String
}

struct TroopMovement: Codable, Identifiable {
    let id: String
    let type: String
    let from: Coordinate
    let to: Coordinate
    let units: [String: Int]
    let routeViaGates: [String]
    let departedAt: String
    let arrivesAt: String
    let isReturning: Bool
}

struct Coordinate: Codable {
    let x: Int
    let y: Int
}

struct BattleReport: Codable, Identifiable {
    let id: String
    let attackerWon: Bool
    let targetX: Int
    let targetY: Int
    let ratio: Double
    let totalAtk: Double
    let totalDef: Double
    let attackerUnits: ArmySnapshot
    let defenderUnits: ArmySnapshot
    let resourcesStolen: Resources?
    let occurredAt: String
    let isAttacker: Bool
}

struct ArmySnapshot: Codable {
    let before: [String: Int]
    let after: [String: Int]
    let lost: [String: Int]
}

struct MapTile: Codable {
    let x: Int
    let y: Int
    let ring: Ring
    let terrain: Terrain
    let rarity: Rarity
    let city: TileCity?
    let outpost: TileOutpost?
    let mine: TileMine?
    let warpGate: TileWarpGate?
    let ruins: TileRuins?
    
    var hasOccupant: Bool {
        city != nil || outpost != nil || mine != nil || warpGate != nil || ruins != nil
    }
}

struct TileCity: Codable {
    let id: String
    let name: String
    let owner: String
    let ownerId: String
    let faction: Faction
}

struct TileOutpost: Codable {
    let id: String
    let level: Int
    let defeated: Bool
}

struct TileMine: Codable {
    let id: String
    let resourceType: String
    let productionRate: Double
    let owned: Bool
}

struct TileWarpGate: Codable {
    let id: String
}

struct TileRuins: Codable {
    let id: String
    let originalRing: Ring
    let decaysAt: String
}

// ─── Enums ───

enum Faction: String, Codable, CaseIterable {
    case REAPERS, HEGEMONY, NETRUNNERS
}

enum Ring: String, Codable {
    case FRINGE, GRID, CORE, NEXUS
}

enum Terrain: String, Codable, CaseIterable {
    case WASTELAND, FLATLAND, QUARRY, RUINS, GEOTHERMAL, HILLTOP, RIVERSIDE, CROSSROADS
}

enum Rarity: String, Codable {
    case COMMON, UNCOMMON, RARE
}

enum BuildingType: String, Codable, CaseIterable {
    case DATA_BANK, FOUNDRY, TECH_LAB, POWER_GRID
    case HQ, BARRACKS, MOTOR_POOL, OPS_CENTER, WAREHOUSE
    case WALL, WATCHTOWER, RALLY_POINT, TRADE_POST, RESEARCH_LAB
}

enum UnitType: String, Codable, CaseIterable {
    case GRUNT, ENFORCER, SENTINEL, STRIKER, PHANTOM, BUSTER, HAULER, TITAN, SETTLER
}

enum MovementType: String, Codable {
    case ATTACK, RAID, SCOUT, REINFORCE, TRANSPORT, SETTLE, RETURN
}
```

---

## PREDLOŽENA STRUKTURA iOS PROJEKTA

```
syndicore-iOS/
├── CLAUDE.md                          ← ovaj fajl
├── SyndicoreContracts/                ← auto-synced iz BE
│   ├── openapi.json
│   ├── game-constants.json
│   └── VERSION
├── SyndiCore/
│   ├── SyndiCoreApp.swift             ← @main entry
│   ├── Config.plist                   ← Supabase URL + anon key
│   ├── Models/
│   │   ├── Player.swift
│   │   ├── World.swift
│   │   ├── City.swift
│   │   ├── MapTile.swift
│   │   ├── BattleReport.swift
│   │   ├── Enums.swift                ← Faction, Ring, Terrain, etc.
│   │   └── GameConfig.swift           ← parsed game-constants.json
│   ├── Services/
│   │   ├── SupabaseManager.swift      ← supabase-swift wrapper
│   │   ├── APIService.swift           ← URLSession REST calls
│   │   └── SocketService.swift        ← Socket.IO (later)
│   ├── State/
│   │   └── GameState.swift            ← @Observable, @MainActor
│   ├── Views/
│   │   ├── SplashView.swift
│   │   ├── AuthView.swift
│   │   ├── OnboardingView.swift
│   │   ├── WorldPickerView.swift
│   │   ├── FactionPickerView.swift
│   │   ├── MainGameView.swift         ← TabView container
│   │   ├── CityView.swift
│   │   ├── BuildingDetailView.swift
│   │   ├── TrainingView.swift
│   │   ├── ArmyView.swift
│   │   ├── BattleReportView.swift
│   │   ├── SyndikatView.swift         ← placeholder
│   │   └── ResearchView.swift         ← placeholder
│   ├── Map/
│   │   ├── MapScene.swift             ← SKScene (SpriteKit)
│   │   ├── MapView.swift              ← SwiftUI wrapper (SpriteView)
│   │   ├── TileNode.swift             ← SKSpriteNode per tile
│   │   ├── WarpGateNode.swift
│   │   └── MovementLineNode.swift     ← animated troop path
│   └── Assets.xcassets/
└── SyndiCore.xcodeproj/
```

---

## ŠTA DA SE IMPLEMENTIRA SADA

**Prioritet 1 — Auth + Onboarding flow (ekrani 1-6):**
- SplashView → AuthView → OnboardingView → WorldPickerView → FactionPickerView → MainGameView
- Svi sa pravim API pozivima ka staging URL-u
- Pravi Supabase Auth (sign up + sign in)

**Prioritet 2 — CityView (funkcionalan):**
- Prikaz resursa (credits, alloys, tech, energy) sa ikonicama
- Lista buildings sa level-om i upgrade dugmetom
- Construction queue (timer countdown do upgradeEnd)
- Training dugme → modal za izbor jedinice + količine
- Active training jobs lista

**Prioritet 3 — MapView (SpriteKit osnova):**
- Fetch viewport tile-ova (`GET /api/v1/worlds/:id/map?cx=&cy=&r=`)
- Renderuj grid: boja po ring-u, terrain tip
- Occupant ikonice (city, outpost, mine, warp gate, ruins)
- Warp Gate linije između svih gate-ova
- Camera pan/zoom sa SKCameraNode
- Tap na tile → info popup (šta je na tile-u)
- Refetch kad kamera se pomeri dovoljno

**Prioritet 4 — ArmyView + Send troops:**
- Lista trupa u gradu
- "Send" dugme → modal: izaberi target (x,y), izaberi trupe, izaberi tip (ATTACK)
- Active movements lista sa countdown tajmerima
- Battle reports lista

**Placeholder za kasnije:** SyndikatView, ResearchView

---

## GAME DESIGN REFERENCE

Kompletan GDD (game design document) je u BE repo-u: `github.com/LukovicNikola/syndicore-BE/blob/main/CLAUDE.md`

Ključni koncepti za iOS:
- **Jedan grad po igraču** — nema multi-city menadžmenta
- **4 ringa** (Fringe → Grid → Core → Nexus) — progresija kroz Crystal Implosion
- **Univerzalne jedinice** — svi igrači imaju isti roster od 8 jedinica
- **Frakcije** se razlikuju po tech tree branch-u, ne po jedinicama
- **Warp Gates** su fast-travel mreža — server računa najkraću rutu automatski
- **Combat** je instant (3 faze), nema animacija borbe — samo izveštaj
- **Resursi** se kalkulišu on-demand (lazy), ne periodic tick
