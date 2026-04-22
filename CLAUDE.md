# SYNDICORE iOS — Claude Instructions

> **Verzija:** 2026-04-22 (Phase 4 Crystal Implosion done, feature status sync)
> **Pending:** rešavanje TBD stavki nakon reconcile-a sa `syndicore-BE/CLAUDE.md`

---

## 📋 CODE REVIEW TODO (round 2, 2026-04-18)

Posle merge-a HIGH/CRITICAL fixeva (commits `3f3148b` + `3d50270`) ostalo:

### 🔴 P0 — Regresija iz 3f3148b (fix odmah)

- [x] **Bootstrap retry double-configure crash** — `SupabaseManager.configure()` je sada idempotent (`if _shared != nil { return }`). Retry u `ConfigErrorView` bezbedan. ✅ (fixovano pre 2026-04-22, potvrđeno)

### 🟠 P1 — HIGH iz review-a (radi sledeće)

- [x] **`BuildCostResponse.buildingType: String` → `BuildingType` enum** (`Models/City.swift:~105`). ✅ 50f9db8
- [x] **URL query param encoding** (`Networking/Endpoint.swift`). Refaktor na `URLComponents` + `queryItems`. ✅ 50f9db8
- [x] **Timeout wrapper za async network pozive** — `withOptionalTimeout` helper u `APIClient`, 30s default na city/map/worlds. ✅ 50f9db8
- [x] **Silent unit dropping** — `os_log` warning za nepoznati `UnitType` u `ArmySnapshot` i `TroopMovement`. ✅ 50f9db8
- [x] **BuildSheet cost preview** — lokalni cost preview iz `game-constants.json` (credits/alloys/tech/duration). ✅ 50f9db8

### 🟡 P2 — MEDIUM (posle P0/P1)

- [ ] **`MapScene.swift:116` `group.name!`** — guaranteed safe u trenutnom loop-u, ali hygiene fix: `guard let name = group.name else { continue }` pre `tileGroupCache[name] = group`.
- [x] **`randomNonceString` charset** (`Services/SupabaseManager.swift`) — charset je ispravan: `"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._"`. ✅ (potvrđeno 2026-04-22, W postoji)
- [ ] **`MapView` hardkodovana 800×800 scene size** — koristiti `GeometryReader` da se prosledi actual size, ili garantovati `scaleMode = .resizeFill` pre `addChild`.
- [ ] **`GameConstantsManager.decode` koristi plain `JSONDecoder`** umesto `JSONDecoder.api`. Nije bitno ako GameData nema datume, ali konsistentnost.
- [ ] **`AnyCodableValue` bez `.array` / `.object` varijanti** (`Networking/APIError.swift:37`) — ako BE ikad pošalje nested JSON u `details`, decode će puknuti.
- [ ] **`MapView.setupCallbacks()` closure capture** — `scene.onTileTapped = { tile in selectedTile = tile }` hvata `self` implicitno. Dodati `[weak self]` eksplicitno.
- [x] **`RefreshErrorBanner` auto-dismiss** — 8s `.task` za fadeout sa animacijom. ✅ 55f3a25
- [x] **`WorldPickerView.loadWorlds()` bez timeout-a** — pokriveno P1 global timeout fix-om. ✅ 50f9db8
- [x] **`BuildingInfo` backward-compat throw** — explicit `DecodingError` sa jasnom porukom kad ni `currentLevel` ni `level` ne postoje. ✅ 55f3a25
- [ ] **`OnboardingView` error string match `err.error == "already_onboarded"`** — fragile. Definisati enum za BE error codes ili koristiti `.contains`.
- [ ] **`GameState.bootstrap` decode fail u `api.city(id:)`** — `activeCity` ostaje stale bez indikacije. Fallback na `pw.city` iz `/me` response-a.
- [ ] **`CountdownLabel` Timer cleanup** — `.autoconnect()` pokriva, ali dodati explicit `.onDisappear { cancellable?.cancel() }` za clarity.

### 🔵 P3 — LOW (kad bude vremena)

- [ ] **`Isometric.coord(forSlot:)` + `slot(forCoord:)`** — O(n²) iteracija 5×5 grida. Pre-compute static lookup dictionary.
- [ ] **Building `displayName` helper** — repetirana `.replacingOccurrences(of: "_", with: " ").capitalized` logika. Extract u `extension BuildingType { var displayName: String }`.
- [ ] **Apple Sign In simulator detection** preko `code == .unknown` je fragile. Zamena: `ProcessInfo.processInfo.environment["SIMULATOR_UDID"] != nil`.
- [ ] **`FactionPickerView` bez loading state-a** tokom `join()`. User može dvaput da klikne. Dodati `isJoining` flag + disable button.
- [ ] **`SettingsView` "Refresh Constants" button** bez loading feedback-a. Dodati `@State isRefreshing`.
- [ ] **`HQInfoSheet.targetLevel` fallback logic** — `hq.targetLevel ?? hq.currentLevel + 1` je konfuzno. Pojasniti invariantu.
- [x] **`CityView.buildableTypes` hardkodovana lista** — dodati resource buildings (DATA_BANK/FOUNDRY/TECH_LAB/POWER_GRID) sa flex slot provjerom. ✅ 55f3a25 (full allCases derivacija ostaje za later)
- [ ] **ContentView `@unknown default`** — Swift 5.10+ warning safety za exhaustive switch kad se doda nov `Screen` case.
- [ ] **APIClient `@unchecked Sendable`** — proveri da li može da bude `Sendable` direktno (URLSession, decoder, encoder su thread-safe).
- [ ] **Doc komentari na public API** — APIClient metodi, GameState metodi, CityScene callbacks.

### ❌ Pre-existing TODOs (poznato, čeka trigger)

- [ ] **5 building sprite-ova fali** (warehouse_v1, wall_building_v1, s_hologram_v1, corner_turret_v1, wall_v1). Ostalo dodato: data_bank, foundry, tech_lab, motor_pool, ops_center, watchtower, rally_point, trade_post, research_lab. ✅ partial (a4e3eb0, d0869c5, itd.)
- [ ] **Particle .sks fajlovi** (electric_arc, window_pulse, spark_shower). Čeka posle statickog renderovanja.
- [ ] **MapScene emoji occupants** (🏠💀💎🌀🏚️) — zamena sa custom sprite asset-ima za konsistentnost sa CityView stilom (map_ruins_v1 dodat za ruins).
- [x] **WebSocket servis** (`Services/SocketService.swift`) — Socket.IO implementiran. Events: `building_complete`, `training_complete`, `troops_arrived`. ✅ 498a0d9
- [x] **ArmyView** — kompletno implementiran: Troops tab (garrison + reinforcements), Movements tab (paginated, countdown, DEV skip, infinite scroll), Reports tab (paginated, detail view). ✅
- [ ] **SyndikatView** — placeholder, čeka implementaciju.
- [x] **TechTreeView** — Codex prikaz grana postoji, ali API upgrade (POST /research) još nije vezan.
- [x] **Crystal Implosion** — kompletno implementiran: HQInfoSheet implosion sekcija, CrystalSheet, TopHUD crystal badge, MapView ruins display, AppState.handleImplodeSuccess. ✅ 0936340

### ✅ Ne diraj (false positives iz review-a)

- `required init?(coder:) { fatalError() }` u SKNode subklasama — standardni SpriteKit pattern, ti objekti se nikad ne dekodiraju iz nib-a.
- `preconditionFailure` u `SupabaseManager.shared` getter-u — namerno, dev-only defensive crash path.
- `tileGroupCache[key]` lookup u `MapScene.loadTiles` — enum CaseIterable garantuje da ključ postoji.
- "O(n²) warp gate lines" — BE garantuje max ~20 gate-ova po worldu, ne 100+.

---

## ⚠️ OTVORENA PITANJA (TBD — čeka BE CLAUDE.md)

Sve niže u dokumentu markirano je `⚠️ TBD-BE`. Spisak za konsolidaciju:

1. ~~**SETTLER / SETTLE movement**~~ — **REŠENO.** SETTLER je za Crystal Implosion (HQ 20 + SETTLER → POST /implode → novi grad u sledećem ringu). SETTLE movement type se NE koristi na klijentu — BE interno handluje relokaciju. ✅
2. **War Factory** — TITAN se trenira tamo (linija u Units tabeli), ali building ne postoji ni u Fixed listi ni u `BuildingType` enum-u. War Factory je clan building u `game-constants.json`. Dodati ili pomeriti TITAN-a u postojeći building.
3. **Ring granice (Chebyshev distance → Ring)** — trebaju tačni range-ovi za FRINGE/GRID/CORE/NEXUS. Bez njih SpriteKit ne može da oboji tile-ove po ringu. (Klijent koristi `ring` polje sa servera, ali za minimap preview treba lokalno mapiranje.)
4. ~~**`crystals: [String]`** na `PlayerWorld`~~ — **REŠENO.** Niz ring naziva (npr. `["FRINGE", "GRID"]`), stiče se kroz Crystal Implosion mehaniku. Prikazano u CrystalSheet sa bonusima iz `game-constants.json`. ✅
5. **Watchtower / Wall / Rally Point / Trade Post** — nedostaje gameplay efekat (za UI labele i tooltips). `watchtower_alerts` config sada postoji u `game-constants.json`.
6. ~~**HQ → flex slots curve**~~ — **REŠENO.** Sada 5 tačaka u `game-constants.json`: `"1": 9, "5": 11, "10": 14, "15": 16, "20": 18`. ✅
7. **Mine `resourceType`** — može li biti `ENERGY`? Ili samo `CREDITS`/`ALLOYS`/`TECH`?
8. **Battle outcome** — postoji li inconclusive/retreat pored `attackerWon: Bool`?
9. ~~**Pagination**~~ — **REŠENO.** BE ima cursor-based pagination na `/movements` i `/reports`. iOS koristi `PaginatedResponse<T>` sa `items`, `nextCursor`, `hasMore`. Infinite scroll implementiran. ✅
10. ~~**Error response shape**~~ — **REŠENO.** Uniform `{ error: "code", details?: {} }`. iOS mapira u `APIError` enum sa `BEErrorCode`. ✅

---

## PRAVILA ZA CLAUDE-A

- **Predloži konkretnu implementaciju prvo, pa iteriraj na njoj.** Umesto 20 pitanja unapred — ponudi 2-3 varijante sa trade-off-ovima i pusti korisnika da izabere. Pita se samo ako je pitanje blokirajuće (destruktivna akcija, bezbednost, nepovratna arhitekturna odluka).
- **Objasni detaljno šta radiš i kako** — korisnik je SAP UI5 developer koji uči iOS/Swift. Koristi analogije sa web/frontend svetom.
- **Temeljno produkcijski kvalitet** — nema prečica, proper error handling, proper architecture, proper testing.
- **Solo projekat, nema roka, nema žurbe.**
- **Odgovaraj na srpskom, Latinica.** Tehnički termini OK na engleskom.
- **Vizuelni mockup pre velikih UI odluka** — prikazati izgled pre nego što se zalepi u produkcioni view.

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
- **SpriteKit** za MapView — tile grid sa 40k+ tile-ova (ceo svet), do ~10k u viewport-u (radius 50). Pan/zoom/pinch, ring boje, Warp Gate linije, occupant ikonice. Embeduje se u SwiftUI preko `SpriteView`. Vidi sekciju **SpriteKit Performance** za strategiju renderovanja.
- **Supabase Auth:** `supabase-swift` SDK (SPM: `https://github.com/supabase/supabase-swift`)
- **Networking:** URLSession + async/await + centralizovani `APIClient` sa auth interceptor-om i retry-em na 401
- **Cache:** SwiftData (za offline-first read model)
- **Real-time:** ⚠️ TBD-BE — potvrditi da li je BE Socket.IO ili native WebSocket. Ako Socket.IO → `socket.io-client-swift`; ako native → `URLSessionWebSocketTask` (nativno, nema dep).

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
  supabaseURL: URL(string: Config.supabaseURL)!,   // iz Config.plist
  supabaseKey: Config.supabaseAnonKey              // iz Config.plist
)

// Sign up
try await supabase.auth.signUp(email: email, password: password)

// Sign in
let session = try await supabase.auth.signIn(email: email, password: password)

// Get token za BE pozive
let token = try await supabase.auth.session.accessToken
```

**Config.plist** sadrži:
- `SUPABASE_URL`: `<TBD — staging URL iz .env, ne commit-ovati u CLAUDE.md>`
- `SUPABASE_ANON_KEY`: `<TBD — pita korisnika pri setup-u>`

Config.plist **mora** ići u `.gitignore`. Template `Config.example.plist` se commit-uje sa praznim vrednostima. Supabase anon key je dizajniran da bude public (oslonac na RLS policies na DB nivou), ali držimo ga van repo-a zbog higijene.

Svaki BE request šalje header: `Authorization: Bearer <accessToken>`

### Session refresh strategija

Supabase access token default expire time je **1 sat**. Za long-running igračke sesije:

1. `SupabaseManager` registruje `onAuthStateChange` listener pri init-u.
2. `APIClient` na svakom request-u zove `supabase.auth.session.accessToken` (SDK interno radi refresh ako je refresh_token valid).
3. Na **401 Unauthorized** response iz BE-a: pokušaj jednom `refreshSession()`, replay request. Ako opet 401 → log out, vrati user na `AuthView`.
4. Retry interceptor ne sme da pravi loop — max 1 retry po request-u.

---

## KORISNIČKI FLOW (redosled ekrana)

```
SplashScreen
    │ fetch GET /api/v1/config (game constants, cache lokalno sa ETag)
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
    ├── SyndikatView   (SwiftUI — clan CRUD, members, diplomacy)
    └── ResearchView   (SwiftUI — 6 tech tree grana, upgrade, respec)
```

---

## KOMPLETNA API REFERENCA (27 ruta)

Staging URL: `https://syndicore-be-staging.onrender.com`

### Error response shape (unified — ⚠️ TBD-BE potvrditi)

Pretpostavka za iOS klijenta dok se ne potvrdi sa BE:

```json
{ "error": "error_code_snake_case", "message": "Optional human-readable description" }
```

Na iOS strani mapirano u:

```swift
enum APIError: Error {
    case unauthorized                    // 401
    case notFound(code: String)          // 404
    case conflict(code: String)          // 409 (npr. "username_taken")
    case validation(code: String, message: String?)  // 400
    case server(status: Int)             // 5xx
    case decoding(Error)
    case transport(URLError)
}
```

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
| POST | `/api/v1/worlds/:id/join` | JWT | `{ "faction": "REAPERS" }` | 201 `{ playerWorld, city, tile }`. **Starter: samo HQ level 1.** Igrač gradi sve ostale zgrade. |

### Research (Tech Tree)

| Method | Path | Auth | Body | Response |
|--------|------|------|------|----------|
| GET | `/api/v1/worlds/:worldId/research` | JWT | — | `{ research: { branches: [...], totalPoints, spentPoints, remainingPoints, researchLabLevel } }` |
| POST | `/api/v1/worlds/:worldId/research` | JWT | `{ "branch": "LOGISTICS" }` | `{ result: { branch, previousLevel, newLevel, cost, pointsUsed, pointsRemaining } }` |
| POST | `/api/v1/worlds/:worldId/research/respec` | JWT | — | `{ result: { penalty: { credits, alloys, tech } } }` |

**Branches:** `LOGISTICS`, `SIEGE_ENGINEERING`, `MOBILIZATION` (universal) + `AGGRESSION_PROTOCOL` (Reapers), `BASTION_PROTOCOL` (Hegemony), `OVERRIDE_PROTOCOL` (Netrunners). Igrač može da istraži samo svoju faction granu + sve universal.

**Points:** Research Lab level određuje ukupan budget. Konkretne vrednosti → `game-constants.json` (source of truth, ne duplirati ovde).

### Syndikats (Clans)

| Method | Path | Auth | Body | Response |
|--------|------|------|------|----------|
| GET | `/api/v1/worlds/:worldId/syndikats` | — | — | `{ syndikats: [{ id, name, tag, memberCount, createdAt }] }` |
| GET | `/api/v1/worlds/:worldId/syndikats/:id` | — | — | `{ syndikat: { id, name, tag, members: [{ playerWorldId, username, faction, role }] } }` |
| POST | `/api/v1/worlds/:worldId/syndikats` | JWT | `{ "name": "...", "tag": "ABC" }` | 201 `{ syndikat }`. Creator = OVERLORD. |
| POST | `.../syndikats/:id/join` | JWT | — | `{ joined: true }` |
| POST | `.../syndikats/leave` | JWT | — | `{ left: true }`. OVERLORD ne može da napusti (mora transfer). |
| POST | `.../syndikats/:id/role` | JWT | `{ "targetPlayerWorldId": "...", "role": "OFFICER" }` | `{ updated: true }` |
| POST | `.../syndikats/:id/kick` | JWT | `{ "targetPlayerWorldId": "..." }` | `{ kicked: true }` |
| POST | `.../syndikats/:id/diplomacy` | JWT | `{ "targetSyndikatId": "...", "status": "PACT" }` | `{ updated: true, status }` |

**Roles:** OVERLORD (1) → WARDEN (max 3) → OFFICER (max 6) → MEMBER. Max 30 members.
**Diplomacy:** PACT (allied), NEUTRAL (default), HOSTILE (war).

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
  "ruins": { "id": "...", "originalRing": "FRINGE", "decaysAt": "2026-05-01T00:00:00.000Z" } | null
}
```

Radius je cappiran na 50. Za pan/zoom: debounced refetch sa novim `cx`, `cy` kad se kamera pomeri dovoljno (vidi **SpriteKit Performance** sekciju za threshold).

### City

| Method | Path | Auth | Body / Query | Response |
|--------|------|------|-------------|----------|
| GET | `/api/v1/cities/:id` | JWT | — | `{ city: { id, name, resources, tile, buildings, troops, constructionQueue } }` |
| POST | `/api/v1/cities/:id/build` | JWT | vidi dole | 200 `{ building: { id, type, currentLevel, targetLevel, endsAt }, cost }` |
| GET | `/api/v1/cities/:id/build-cost` | JWT | `?buildingId=X` | `{ buildingType, currentLevel, targetLevel, cost: { credits, alloys, tech }, durationMinutes }` |
| POST | `/api/v1/cities/:id/train` | JWT | `{ "unitType": "GRUNT", "count": 10 }` | 200 `{ trainingJob: { id, unitType, count, endsAt }, cost }` |
| GET | `/api/v1/cities/:id/training` | JWT | — | `{ training: [{ id, unitType, count, endsAt }] }` |

**Build endpoint body varijante:**
- Upgrade postojeće: `{ "buildingId": "..." }`
- Nova fixed zgrada: `{ "buildingType": "BARRACKS" }`
- Nova resource zgrada (flex slot): `{ "buildingType": "DATA_BANK", "slotIndex": 4 }`

**Building data u city response-u:**
```json
{
  "id": "...",
  "type": "HQ",
  "currentLevel": 1,
  "targetLevel": null,
  "endsAt": null,
  "slotIndex": null
}
```

> **Patch note:** originalni doc je imao `level` + `isUpgrading` + `upgradeEnd`. BE response koristi `currentLevel` + `targetLevel` + `endsAt`. `isUpgrading` je **izvedeno** (`targetLevel != nil && endsAt != nil`), ne posebno polje.

**Starter building (kreira se pri join-u):** samo **HQ level 1**. Igrač gradi sve ostale zgrade.

**Resource buildings** idu u flex slotove (0..N-1), N zavisi od HQ level-a (⚠️ TBD-BE puna curve u `game-constants.json`).

**Resursi su on-demand:** svaki GET `/cities/:id` automatski osvežava resurse po elapsed time od zadnjeg pristupa. Nema periodic tick-a — lazy evaluation.

### Troops & Movement

| Method | Path | Auth | Body | Response |
|--------|------|------|------|----------|
| POST | `/api/v1/cities/:id/send` | JWT | `{ "targetX": 5, "targetY": -3, "units": { "GRUNT": 50 }, "movementType": "ATTACK" }` | 200 `{ movement, route: { direct, viaGates, travelMinutes, arrivesAt } }` |
| GET | `/api/v1/worlds/:worldId/movements` | JWT | — | `{ movements: [{ id, type, from, to, units, viaGates, departedAt, arrivesAt, isReturning }] }` |

> **Patch note:** originalni doc je imao `routeViaGates` na GET /movements i `viaGates` u send response-u. Ujednačeno na `viaGates` (⚠️ TBD-BE potvrditi da BE zaista vraća `viaGates` na oba mesta — ako ne, BE da se poravna).

**MovementType enum:** `ATTACK`, `RAID`, `SCOUT`, `REINFORCE`, `TRANSPORT`, `SETTLE` (⚠️ TBD-BE — vidi otvoreno pitanje #1), `RETURN`

**Pathfinding:** server automatski bira najkraću rutu. `route.viaGates` je lista gate ID-ova ako je gate ruta brža (prazan array ili null ako je direktna). `route.direct: Bool` označava da li je direktna ruta pobedila.

**Army speed:** najsporija jedinica u grupi (tiles per hour). Prikazano u `travelMinutes`.

**Pagination:** ⚠️ TBD-BE — `GET /movements` trenutno vraća sve. Pre produkcije treba cursor-based pagination (`?limit=50&before=<movementId>`).

### Battle Reports

| Method | Path | Auth | Response |
|--------|------|------|----------|
| GET | `/api/v1/worlds/:worldId/reports` | JWT | `{ reports: [{ id, attackerWon, targetX, targetY, ratio, totalAtk, totalDef, attackerUnits, defenderUnits, resourcesStolen, buildingsDamaged, occurredAt, isAttacker }] }` |

**attackerUnits / defenderUnits structure:**
```json
{
  "before": { "GRUNT": 50, "ENFORCER": 20 },
  "after":  { "GRUNT": 35, "ENFORCER": 14 },
  "lost":   { "GRUNT": 15, "ENFORCER": 6 }
}
```

**Pagination:** ⚠️ TBD-BE — isto kao movements.

### Real-Time Events (Socket.IO)

**Library:** `socket.io-client-swift` (SPM). Server koristi Socket.IO v4.

**SPM package:**
```swift
.package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.1.0")
```

**Connection flow:**
1. Posle login-a, konektuj se sa JWT token-om na staging: `https://syndicore-be-staging.onrender.com`
2. Uključi se u sobe posle `connect` event-a:
   - `socket.emit("join_city", cityId)` — city-specifični event-ovi
   - `socket.emit("join_syndikat", syndikatId)` — ako je igrač u klanu

**Connection template:**
```swift
import SocketIO

let manager = SocketManager(socketURL: URL(string: "https://syndicore-be-staging.onrender.com")!,
    config: [.log(false), .compress, .connectParams(["token": accessToken])])
let socket = manager.defaultSocket

socket.on(clientEvent: .connect) { _, _ in
    socket.emit("join_city", cityId)
}

socket.connect()
```

**Events on city room (`city:{cityId}`):**

| Event | Payload | UI Action |
|-------|---------|-----------|
| `building_complete` | `{ buildingId, type, newLevel }` | Toast "Barracks upgraded to level 3!" + refresh buildings list |
| `training_complete` | `{ unitType, count }` | Toast "10 Grunts ready!" + refresh troops |

**Events on world room (`world:{worldId}`):**

| Event | Payload | UI Action |
|-------|---------|-----------|
| `troops_arrived` | `{ movementId, type, targetX, targetY }` | ATTACK → "Battle at (34,17)!" + refresh reports. RETURN → "Troops returned home" + refresh city |

**Implementation rules:**
- **Koristi event-ove SAMO kao UI refresh triggere** — uvek fetch fresh state iz REST API-ja posle event-a. Ne mutiraj lokalni state direktno iz event payload-a (može biti stale).
- Auto-reconnect na disconnect (Socket.IO to handluje sam).
- Server podržava polling fallback za loše konekcije.

**Redosled implementacije:** `building_complete` prvo (najčešći, najlakše za testiranje) → `training_complete` → `troops_arrived`.

---

## MAPA (4 ringa, kvadratni grid)

Ring se određuje Chebyshev distance-om: `d = max(|x|, |y|)` od centra `(0,0)`.

| Ring | Chebyshev range | Boja za SpriteKit | Opis |
|------|-----------------|-------------------|------|
| **FRINGE** | ⚠️ TBD-BE | Siva / bela (#E0E0E0) | Starter zona, spoljni prsten |
| **GRID** | ⚠️ TBD-BE | Narandžasta (#FF8C00) | PvP zona, srednji prsten |
| **CORE** | ⚠️ TBD-BE | Crvena (#DC143C) | Elite zona, unutrašnji prsten |
| **NEXUS** | ⚠️ TBD-BE | Ljubičasta / zlatna (#9B30FF) | Endgame centar |

> **Napomena:** `ring` polje stiže sa servera u svakom tile-u, tako da iOS klijent **ne mora** da računa ring lokalno za bojenje — koristi server vrednost. Chebyshev mapiranje treba samo za minimap preview i "koji ring targetujem" labelu u UI-ju.

**Terrain boje (SpriteKit tile-ovi):**

| Terrain | Boja |
|---------|------|
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

**Warp Gate linije:** tanke ljubičaste linije između svih gate-ova na mapi (complete graph). `SKShapeNode` sa `path`, draw-uju se jednom po viewport fetch-u.

---

## FAKCIJE (3)

Sve koriste ISTI roster jedinica. Razlika je u tech tree branch-u.

| Faction | Boja za UI | Ikonica |
|---------|-----------|---------|
| REAPERS | Crvena (#FF4444) | ⚔️ ili custom sword icon |
| HEGEMONY | Plava (#4488FF) | 🛡️ ili custom shield icon |
| NETRUNNERS | Zelena (#44FF88) | 💻 ili custom circuit icon |

---

## JEDINICE — Universal Roster

| Unit | Role | Trains at | Unlock lvl |
|------|------|-----------|------------|
| GRUNT | Fodder | Barracks | 1 |
| ENFORCER | Core | Barracks | 5 |
| SENTINEL | Defense | Barracks | 10 |
| STRIKER | Vehicle | Motor Pool | 1 |
| HAULER | Transport | Motor Pool | 5 |
| PHANTOM | Scout | Ops Center | 5 |
| BUSTER | Siege | Ops Center | 10 |
| TITAN | Clan elite | ⚠️ TBD-BE (doc kaže "War Factory", ne postoji kao building) | 1 |
| SETTLER | Expansion (⚠️ TBD-BE — vidi otvoreno pitanje #1) | HQ | 20 |

> **Napomena:** konkretne stat vrednosti (ATK/DEF/SPD/CARRY/energy cost) **ne dupliraju se ovde** — source of truth je `game-constants.json`. Klijent uvek čita iz cache-ovanog config-a.

---

## BUILDINGS

**Resource buildings (flex slots):** `DATA_BANK`, `FOUNDRY`, `TECH_LAB`, `POWER_GRID`

**Fixed buildings (one each):** `HQ`, `BARRACKS`, `MOTOR_POOL`, `OPS_CENTER`, `WAREHOUSE`, `WALL`, `WATCHTOWER`, `RALLY_POINT`, `TRADE_POST`, `RESEARCH_LAB`

**⚠️ TBD-BE `WAR_FACTORY`** — ako TITAN zaista ima poseban building, treba ga dodati u fixed listu i u `BuildingType` enum. Ako ne, premestiti TITAN-a u postojeći (verovatno `BARRACKS` ili `MOTOR_POOL`).

**Cost i time formule** → source of truth je `game-constants.json` (npr. `baseCost × 1.5^(level-1)`, `baseTimeMinutes × 1.4^(level-1)`). **Ne hardcode-ovati u Swift kod** — uvek čitati iz `GameConfig`.

**ONE construction queue** — jedan build istovremeno po gradu.

**HQ → flex slots curve:** ⚠️ TBD-BE puna tabela. Trenutno poznate tačke: lvl 1=9, lvl 10=14, lvl 20=18.

**Gameplay efekti buildings-a** — ⚠️ TBD-BE:
- `WALL` — defense boost?
- `WATCHTOWER` — scout range, incoming attack preview?
- `RALLY_POINT` — army organization, multi-troop send?
- `TRADE_POST` — resource exchange?

---

## SWIFT MODELI (Codable structs)

**Centralni decoder** — svi API response-ovi prolaze kroz jedan `JSONDecoder`:

```swift
extension JSONDecoder {
    static let api: JSONDecoder = {
        let d = JSONDecoder()
        // ISO8601 sa fractional seconds (BE šalje: "2026-05-01T00:00:00.000Z")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatter.date(from: string) { return date }
            // fallback bez fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(string)"
            )
        }
        return d
    }()
}
```

Svaki `Date` polje u modelima ispod koristi ovaj decoder. **Ne koristi `String` za datume** — izbegavaj ad-hoc parsiranje po viewima.

```swift
// ─── Player / World ───

struct Player: Codable, Identifiable {
    let id: String
    let username: String
    let createdAt: Date
    let updatedAt: Date
    let worlds: [PlayerWorld]?
}

struct PlayerWorld: Codable, Identifiable {
    let id: String
    let playerId: String
    let worldId: String
    let faction: Faction
    let ring: Ring
    let crystals: [String]   // ⚠️ TBD-BE — schema undokumentovana
    let joinedAt: Date
    let city: City?
}

struct World: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let status: WorldStatus
    let speedMultiplier: Double
    let mapRadius: Int
    let maxPlayers: Int
    let playerCount: Int
}

enum WorldStatus: String, Codable {
    case OPEN, RUNNING, ENDED, ARCHIVED
}

// ─── City / Buildings ───

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
    let currentLevel: Int
    let targetLevel: Int?      // nil ako nije u upgrade-u
    let endsAt: Date?          // nil ako nije u upgrade-u
    let slotIndex: Int?        // nil za fixed buildings

    var isUpgrading: Bool { targetLevel != nil && endsAt != nil }
}

struct ConstructionQueue: Codable {
    let buildingId: String
    let type: BuildingType
    let endsAt: Date?
}

struct TrainingJob: Codable, Identifiable {
    let id: String
    let unitType: UnitType
    let count: Int
    let endsAt: Date
}

// ─── Troops / Movement ───

struct TroopInfo: Codable {
    let unitType: UnitType
    let count: Int
}

struct TroopMovement: Codable, Identifiable {
    let id: String
    let type: MovementType
    let from: Coordinate
    let to: Coordinate
    let units: [UnitType: Int]
    let viaGates: [String]       // prazan array ako je direktna ruta
    let departedAt: Date
    let arrivesAt: Date
    let isReturning: Bool
}

struct Coordinate: Codable {
    let x: Int
    let y: Int
}

struct SendTroopsResponse: Codable {
    let movement: TroopMovement
    let route: Route
}

struct Route: Codable {
    let direct: Bool
    let viaGates: [String]
    let travelMinutes: Double
    let arrivesAt: Date
}

// ─── Battle ───

struct BattleReport: Codable, Identifiable {
    let id: String
    let attackerWon: Bool       // ⚠️ TBD-BE — postoji li inconclusive?
    let targetX: Int
    let targetY: Int
    let ratio: Double
    let totalAtk: Double
    let totalDef: Double
    let attackerUnits: ArmySnapshot
    let defenderUnits: ArmySnapshot
    let resourcesStolen: Resources?
    let buildingsDamaged: [String]?   // ⚠️ TBD-BE — ID lista ili strukturisano?
    let occurredAt: Date
    let isAttacker: Bool
}

struct ArmySnapshot: Codable {
    let before: [UnitType: Int]
    let after: [UnitType: Int]
    let lost: [UnitType: Int]
}

// ─── Map ───

struct MapViewport: Codable {
    let viewport: ViewportBounds
    let tileCount: Int
    let tiles: [MapTile]
}

struct ViewportBounds: Codable {
    let cx: Int
    let cy: Int
    let radius: Int
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
    let resourceType: ResourceType   // ⚠️ TBD-BE — potvrditi da ENERGY nije validna vrednost
    let productionRate: Double
    let owned: Bool
}

struct TileWarpGate: Codable {
    let id: String
}

struct TileRuins: Codable {
    let id: String
    let originalRing: Ring
    let decaysAt: Date
}

// ─── Syndikat ───

struct Syndikat: Codable, Identifiable {
    let id: String
    let name: String
    let tag: String
    let memberCount: Int?
    let createdAt: Date?
    let members: [SyndikatMember]?
}

struct SyndikatMember: Codable, Identifiable {
    var id: String { playerWorldId }
    let playerWorldId: String
    let playerId: String
    let username: String
    let faction: Faction
    let role: SyndikatRole
}

enum SyndikatRole: String, Codable {
    case OVERLORD, WARDEN, OFFICER, MEMBER
}

enum DiplomacyStatus: String, Codable {
    case PACT, NEUTRAL, HOSTILE
}

// ─── Research ───

struct ResearchState: Codable {
    let branches: [ResearchBranchState]
    let totalPoints: Int
    let spentPoints: Int
    let remainingPoints: Int
    let researchLabLevel: Int
}

struct ResearchBranchState: Codable {
    let branch: ResearchBranch
    let level: Int
    let maxLevel: Int
    let type: ResearchType
    let available: Bool
}

enum ResearchType: String, Codable {
    case universal, faction
}

struct ResearchResult: Codable {
    let branch: ResearchBranch
    let previousLevel: Int
    let newLevel: Int
    let cost: ResourceCost
    let pointsUsed: Int
    let pointsRemaining: Int
}

struct ResourceCost: Codable {
    let credits: Int
    let alloys: Int
    let tech: Int
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

enum ResourceType: String, Codable, CaseIterable {
    case CREDITS, ALLOYS, TECH, ENERGY
}

enum BuildingType: String, Codable, CaseIterable {
    // Resource (flex slots)
    case DATA_BANK, FOUNDRY, TECH_LAB, POWER_GRID
    // Fixed
    case HQ, BARRACKS, MOTOR_POOL, OPS_CENTER, WAREHOUSE
    case WALL, WATCHTOWER, RALLY_POINT, TRADE_POST, RESEARCH_LAB
    // ⚠️ TBD-BE: WAR_FACTORY ako stvarno postoji
}

enum UnitType: String, Codable, CaseIterable {
    case GRUNT, ENFORCER, SENTINEL, STRIKER, PHANTOM, BUSTER, HAULER, TITAN, SETTLER
}

enum MovementType: String, Codable {
    case ATTACK, RAID, SCOUT, REINFORCE, TRANSPORT, SETTLE, RETURN
}

enum ResearchBranch: String, Codable, CaseIterable {
    // Universal
    case LOGISTICS, SIEGE_ENGINEERING, MOBILIZATION
    // Faction-specific
    case AGGRESSION_PROTOCOL   // Reapers
    case BASTION_PROTOCOL      // Hegemony
    case OVERRIDE_PROTOCOL     // Netrunners
}
```

> **Napomena za dict sa enum ključem (`[UnitType: Int]`):** Swift `Codable` ne serijalizuje dictionary sa enum ključem nativno u JSON object. Treba custom `init(from:)` i `encode(to:)` koji mapira na `[String: Int]` u JSON-u i konvertuje. Implementacija ide u `ArmySnapshot`, `TroopMovement`, i response za send. Šablon:
>
> ```swift
> extension ArmySnapshot {
>     init(from decoder: Decoder) throws {
>         let c = try decoder.container(keyedBy: CodingKeys.self)
>         self.before = try Self.decodeUnitDict(c.decode([String: Int].self, forKey: .before))
>         self.after  = try Self.decodeUnitDict(c.decode([String: Int].self, forKey: .after))
>         self.lost   = try Self.decodeUnitDict(c.decode([String: Int].self, forKey: .lost))
>     }
>     private static func decodeUnitDict(_ raw: [String: Int]) throws -> [UnitType: Int] {
>         try raw.reduce(into: [:]) { acc, kv in
>             guard let unit = UnitType(rawValue: kv.key) else {
>                 throw DecodingError.dataCorruptedError(
>                     forKey: DynamicKey(stringValue: kv.key)!,
>                     in: /* ... */,
>                     debugDescription: "Unknown unit: \(kv.key)"
>                 )
>             }
>             acc[unit] = kv.value
>         }
>     }
> }
> ```

---

## SpriteKit Performance (MapView)

**Problem:** do ~10k tile-ova u viewport-u (radius 50 = 101×101). 10k `SKSpriteNode` instanci je gorenji limit za smooth 60fps na starijim iPhone-ovima.

**Preporučena strategija (redom po ceni implementacije):**

1. **`SKTileMapNode` + `SKTileSet`** — napravljen tačno za tile grid. Jedan node umesto 10k. Background sloj (terrain + ring boja) kao jedan tile map, overlay sloj za occupant-e kao posebne `SKSpriteNode`-ove (samo tile-ovi koji imaju occupant, tipično << 10k).
2. **Texture atlas** za terrain i occupant ikonice — `SKTextureAtlas` učitan jednom, deljen među svim node-ovima. Izbegava GPU texture switch.
3. **Viewport culling** — `SKCameraNode` sa manually skrivanjem node-ova van ekrana + padding zone. SpriteKit ne radi auto-culling agresivno.
4. **Debounced refetch** na pan: fetch novi viewport samo kad se kamera pomeri preko 30% radiusa od zadnjeg fetch-a. Ne zovi API na svaki frame pan-a.
5. **Warp Gate linije** — `SKShapeNode` sa path-om generisan jednom po viewport-u. Kompletan graph sa 20 gate-ova = 190 linija; OK kao jedan shape node sa compound path-om.

**Anti-pattern:** ne praviti 10k individualnih `SKSpriteNode` sa `color` property — `SKTileMapNode` je 10-20× brži.

---

## CITYVIEW SCENA — KOMPLETNA SPECIFIKACIJA

CityView je centralni ekran igre — mesto gde igrač provodi 80% vremena. Komponovan od **SwiftUI HUD overlay-a** + **SpriteKit SKScene** za izometrijski grad. Arhitekturni pattern: `ZStack { CitySceneView; VStack { TopHUD; Spacer(); BottomHUD } }`.

### Art direkcija (zaključano)

Style anchor je `SyndicoreContracts/art-reference/hero_reference_v1.png` — hero shot generisan u Tripo3D + Nano Banana Pro koji fiksira:

- **Paleta:** dark metallic steel + brushed carbon fiber panels, cyan neon accent lighting (~#00E0FF), orange warning lights (~#FF8C00), purple/teal dusk sky (~#8030C0 do #40B0A0), orange glow (~#FF5520) na ruinama
- **Iso ugao:** standard 2:1 projekcija (~30° camera elevation)
- **Materijali:** mat carbon fiber sa subtle texture, kromatska steel ivica, emissive neon strips
- **Osvetljenje:** ambient dark + cyan rim light na ivicama + orange point lights na warning beacon-ima
- **Atmosferski efekti:** volumetric ground mist na dnu scene, distant fog u pozadini

Svi novi sprajtovi moraju održavati ovaj style. Kada se generiše nov sprajt u Tripo Studio-u, uvek upload `hero_reference_v1.png` kao style reference.

### Asset library manifest (v1, 2026-04-17)

Svi sprajtovi su @1× verzije iz Tripo3D (Nano Banana Pro), tipično 1024×1024 px. Sede u `SyndiCore/Assets.xcassets/City/` sa nazivom imageset-a identičnim file name-u (bez `.png` ekstenzije). Loaduju se preko `SKTexture(imageNamed: "<naziv>")`. Transparent background je već deo svakog asset-a.

| Sprite | Naziv u Assets.xcassets | Uloga u sceni | Spawn count |
|---|---|---|---|
| Hero skybox | `hero_skybox_v1` | Background za SKScene, najniži z | 1 |
| Tile empty | `tile_empty_v1` | Prazan buildable slot, reuse | 24 |
| Tile selected | `tile_selected_v1` | Tap state, zamenjuje empty tileu | 0-1 istovremeno |
| Tile pulse effect | `tile_pulse_effect_v1` | Resource generation / upgrade celebration animacija | On-demand |
| HQ pyramid | `hq_pyramid_v1` | Central command, fiksna pozicija na (2,2) | 1 |
| Wall segment | `wall_segment_v1` | Perimetar, reuse duž svih 4 stranice | 12-16 |
| Corner pylon | `corner_pylon_v1` | Uglovi, flip-uje se za 4 ugla | 4 |
| Construction scaffold | `construction_scaffold_v1` | Zamenjuje tile dok build traje | On-demand |
| Barracks | `barracks_v1` | Military zgrada, trenira GRUNT/ENFORCER/SENTINEL | 0-1 |
| Power Grid | `power_grid_v1` | Resource zgrada (ENERGY), flex slot | 0-N |

**Reference materijali (NE ide u Assets.xcassets, drže se u `SyndicoreContracts/art-reference/`):**
- `hero_reference_v1.png` — master style anchor za buduće generacije u Tripo3D

**Nedostaje (generiše se postupno nakon prvog working CityScene renderovanja):**
- `s_hologram_v1` (floating emblem iznad HQ-a)
- Preostale zgrade: `data_bank_v1`, `foundry_v1`, `tech_lab_v1`, `motor_pool_v1`, `ops_center_v1`, `warehouse_v1`, `wall_building_v1` (fixed slot, ne perimeter), `watchtower_v1`, `rally_point_v1`, `trade_post_v1`, `research_lab_v1`
- `corner_turret_v1` (decorative, sedí iznad pylon-a)

Kada se generiše svaka nova zgrada, prati konvenciju naziva `<buildingtype_snake_case>_v1.png` da se enum rawValue direktno mapira.

### Grid layout

Grad je **5×5 grid** sa HQ fiksno na centralnom (col=2, row=2). Ukupno **24 buildable slotova** (sve osim HQ). Slot indeksiranje ide 0-23 od top-left ka bottom-right, preskakajući HQ.

⚠️ TBD-BE: Kako BE mapira `building.slotIndex` (0-17 flex + fixed positions) na (col, row) iOS grid? Treba dogovor. Za sada iOS strana će imati lokalnu mapu.

### Izometrijska matematika

Svi iso helperi idu u `SyndiCore/Views/City/Scene/Isometric.swift`:

```swift
import CoreGraphics

enum Isometric {
    static let tileWidth:  CGFloat = 128   // game-space units, 2:1 ratio
    static let tileHeight: CGFloat = 64
    static let gridSize:   Int     = 5
    static let hqCoord: (col: Int, row: Int) = (2, 2)

    /// Grid coord → scene pozicija (relative to worldLayer center)
    static func scenePosition(col: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(col - row) * tileWidth  / 2,
            y: -CGFloat(col + row) * tileHeight / 2   // negativno jer SpriteKit je y-up, mi hoćemo depth ide dole
        )
    }

    /// Tap u scene space → grid coord (za tap detection)
    static func tileCoord(at point: CGPoint) -> (col: Int, row: Int)? {
        let fx =  point.x / (tileWidth  / 2)
        let fy = -point.y / (tileHeight / 2)   // flip y jer radimo u inverznom smeru
        let col = Int(((fx + fy) / 2).rounded())
        let row = Int(((fy - fx) / 2).rounded())
        guard col >= 0, col < gridSize, row >= 0, row < gridSize else { return nil }
        return (col, row)
    }

    /// Z-position za iso depth sort (veće = bliže kameri)
    static func zDepth(col: Int, row: Int) -> CGFloat {
        CGFloat(col + row)
    }

    /// Da li je ovaj slot HQ
    static func isHQ(col: Int, row: Int) -> Bool {
        col == hqCoord.col && row == hqCoord.row
    }
}
```

**Scene konfiguracija:**

```swift
scene.scaleMode = .aspectFit   // Scene stane u bilo koji viewport bez iskrivljenja
scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)   // (0, 0) je na centru
scene.backgroundColor = .clear   // Skybox sprite radi bg
```

Sa ovim setup-om, HQ pozicija na `(col=2, row=2)` natively dolazi blizu centra scene.

### Scene node hijerarhija

`CityScene : SKScene`:

```
CityScene
├── backgroundLayer (SKNode, z = -100)
│   └── skyboxNode (SKSpriteNode, texture: hero_skybox_v1, size: scene.size × 1.2)
├── worldLayer (SKNode, z = 0)  ← ovde ide "svet" grada
│   ├── tileGrid (SKNode)
│   │   └── TileNode × 25  (24 buildable + HQ spot)
│   ├── hqNode (HQNode, na (2, 2))
│   ├── buildingsLayer (SKNode)
│   │   └── BuildingNode × N (dinamički, GameState-driven)
│   ├── scaffoldLayer (SKNode)
│   │   └── ScaffoldNode × N (dinamički, za zgrade koje se grade)
│   └── perimeterLayer (SKNode)
│       ├── WallNode × 12-16 (segmenti duž 4 stranice grida)
│       └── CornerPylonNode × 4 (uglovi, flip-uju se po potrebi)
└── cameraNode (SKCameraNode, dodat u scene.camera, pozicija (0, 0))
```

### Z-order konvencije

SpriteKit renderuje child-ove po `zPosition` (low → high = back → front).

| Layer | Z-position | Sadržaj |
|---|---|---|
| Background | -100 | Skybox, distant fog |
| Tile grid | `Isometric.zDepth(col, row)` = 0 do 8 | Svaki tile `z = col + row` (iso depth sort) |
| Tile selected overlay | `zDepth + 0.05` | Selected tile malo iznad normalnih |
| Buildings | `zDepth + 0.5` | Zgrada iznad svog tile-a |
| HQ | `zDepth(2, 2) + 0.5 = 4.5` | U iso depth sort-u sa ostalim buildinzima |
| Perimeter walls | `zDepth + 1.0` | Iznad tile-ova, ali u iso sort-u |
| Corner pylons | `zDepth + 1.5` | Iznad wall segmenata |
| Corner turret (future) | `zDepth + 1.6` | Sedi iznad pylon-a |
| Construction scaffold | `zDepth + 0.5` | Na istom z kao building (zamenjuje ga) |
| Pulse effect overlay | `zDepth + 2.0` | Iznad svega u toj zoni |
| HUD floating elements | 1000+ | Tooltips, notifications |

Formula `col + row` garantuje da zgrade "iza" (manji col+row) renderuju pre onih "ispred" (veći col+row), pa iso preklop radi prirodno.

### Perimeter wall placement

Walls idu **oko grida**, ne na grid-u. Računanje pozicija:

- **Gornja strana** (col 0..4, row = -1): wall_segment na poziciji pomerenoj za pola tile-a iznad grida, ukupno ~5 segmenata
- **Desna strana** (col = 5, row 0..4): flip horizontalno, ~5 segmenata
- **Donja strana** (col 0..4, row = 5): opet flip
- **Leva strana** (col = -1, row 0..4): osnovna orijentacija
- **4 ugla:** corner_pylon na (-1, -1), (5, -1), (5, 5), (-1, 5)

Konkretan helper u `WallLayout.swift`:

```swift
enum WallLayout {
    static func wallPositions() -> [(position: CGPoint, rotation: CGFloat)] {
        // Vraća niz pozicija + rotacija za sve wall segmente i pylon-e
        // Implementacija ide pri pisanju CityScene.swift
    }
}
```

### State → Visual mapping

`CityScene` observira `GameState.city` (via `@Observable`) i update-uje node-ove kad se data promeni:

- `city.buildings` array → `BuildingNode` instance (create/remove diff)
- Svaki `building.slotIndex` → (col, row) preko lokalne mape slot→coord
- `building.type` → koji sprite se učita: `SKTexture(imageNamed: "\(building.type.rawValue.lowercased())_v1")` — npr. `"barracks_v1"` za `BuildingType.BARRACKS`
- `building.currentLevel` → koji tier sprite (posle prvog pass-a; za sad svi koriste `_v1`)
- `building.isUpgrading` → swap na `construction_scaffold_v1`, plus SwiftUI timer overlay vezan za `building.endsAt`

### Interaktivni flow (tap → build)

1. Igrač tapne scenu → `CityScene.touchesBegan(_:with:)` hvata
2. Konvertuje touch lokaciju u `worldLayer` coordinate space preko `touch.location(in: worldLayer)`
3. `Isometric.tileCoord(at:)` vraća `(col, row)?`
4. Ako `nil` → tap van grida, ignoriši
5. Proveri u `GameState.city.buildings` da li postoji building na tom slot-u:
   - **Empty tile:** swap `tile_empty_v1` → `tile_selected_v1`, emit `onTileSelected((col, row))` closure → SwiftUI otvara `BuildSheet` sa listom zgrada
   - **HQ tile (2,2):** swap selected, emit `onHQSelected` → SwiftUI otvara `HQInfoSheet` (read-only, bez demolish)
   - **Occupied tile:** swap selected, emit `onBuildingSelected(buildingId)` → SwiftUI otvara `BuildingDetailSheet` (Upgrade/Demolish akcije)

**Build flow:**

1. Iz `BuildSheet` igrač bira tip zgrade (npr. BARRACKS)
2. `APIClient.build(cityId:, slotIndex:, type:)` poziv
3. API odgovor → `GameState.city.buildings` update-uje (imutable replace)
4. CityScene detektuje change → swap tile sprite na `construction_scaffold_v1`
5. SwiftUI countdown overlay iznad te tile pozicije pokazuje `building.endsAt - now()` do 0
6. Server šalje WebSocket event `building_complete` ⚠️ TBD-BE protokol ILI timer fire lokalno
7. Scaffold fade-out → building sprite fade-in sa `SKAction`

**SpriteKit swap primer:**

```swift
let fadeOut = SKAction.fadeOut(withDuration: 0.3)
let swap = SKAction.setTexture(SKTexture(imageNamed: "barracks_v1"))
let fadeIn = SKAction.fadeIn(withDuration: 0.3)
tileNode.run(SKAction.sequence([fadeOut, swap, fadeIn]))
```

### Particle effects (runtime, SKEmitterNode)

Neki sprajtovi dobijaju **animirani particle layer** iznad statičkog sprite-a da bi zgrada izgledala "živa". Implementacija u `SyndiCore/Views/City/Scene/Effects/` folder-u sa `.sks` fajlovima editovanim u Xcode SpriteKit Particle Editor-u.

| Zgrada | Efekat | SpriteKit emitter preset | Kada je aktivan |
|---|---|---|---|
| HQ pyramid | S hologram pulse (rotacija + opacity oscillation) | Custom `SKSpriteNode` + `SKAction.sequence` | Uvek (idle glow) |
| Power Grid | Electric arc zig-zag između cooling towers | `SKEmitterNode` tipa "Fire" sa cyan tintom, path sa zig-zag segmentima | Uvek kad zgrada nije u upgrade-u; intenzitet skalira sa `building.currentLevel` |
| Foundry (kasnije) | Spark shower iz furnace | `SKEmitterNode` "Spark" preset | Tokom production tick-a |
| Tech Lab (kasnije) | Floating holographic data glyphs | Custom particle sistem | Uvek |
| Barracks | Svetleći prozori sa pulse | `SKAction.repeatForever(fadeAlpha)` na child sprite | Uvek kad je garrison > 0 |
| Construction scaffold | Welding sparks, cyan work lights flicker | `SKEmitterNode` "Spark" | Uvek dok je scaffold aktivan |

**Particle node lifecycle:**
- Attach kao child od `BuildingNode`-a, pozicioniran u SCN local coordinate (npr. iznad cooling towers za Power Grid)
- Kreira se u `BuildingNode.init` na osnovu `BuildingType`
- Destroy pri `removeFromParent()` kad se zgrada demolish-uje

**Power Grid electric arc setup (konkretan primer):**

```swift
// PowerGridNode.swift
private func addElectricArc() {
    guard let emitter = SKEmitterNode(fileNamed: "electric_arc") else { return }
    emitter.position = CGPoint(x: 0, y: 40)   // iznad cooling towers
    emitter.zPosition = 0.2                    // blago iznad sprite-a
    addChild(emitter)
}
```

`electric_arc.sks` se pravi ručno u Xcode (File → New → File → SpriteKit Particle File → Spark template, pa tweak-uje se: birthRate 30, lifetime 0.3, color cyan #00E0FF, scale 0.3, zig-zag path).

### SwiftUI HUD overlay

Izgled diktira hero shot. Konkretno layout (referenca `hero_reference_v1.png`):

**TopHUD (SyndiCore/Views/City/HUD/TopHUD.swift):**
- Levo: KILL counter (skull icon + broj), POP counter (people icon), Research/Lab icon, Faction badge
- Desno: Resources — CRD (credits, žuto), ALY (alloys, plavo/zeleno), TCH (tech, teal), plus Settings/gear dugme u gornjem-desnom uglu
- Layout: `HStack` sa `Spacer()` u sredini

**BottomHUD (SyndiCore/Views/City/HUD/BottomHUD.swift):**
- Levo: Army button, Settings button
- Desno: Reports, Build queue, Travel buttons
- Padding iznad safe area, `HStack { leftButtons; Spacer(); rightButtons }`

**SideHUD (SyndiCore/Views/City/HUD/SideHUD.swift):**
- Levo-gore: List/menu button, Star/favorites button
- Desno-sredina (ili desno-dole): Gear icon, Shield icon
- Koristi `VStack` sa custom offset-om od safe area

**Resources binding:**

```swift
struct TopHUD: View {
    let resources: Resources?  // iz GameState.city.resources

    var body: some View {
        HStack {
            // ... KILL / POP / etc
            Spacer()
            if let r = resources {
                ResourcePill(label: "CRD", value: Int(r.credits))
                ResourcePill(label: "ALY", value: Int(r.alloys))
                ResourcePill(label: "TCH", value: Int(r.tech))
                ResourcePill(label: "NRG", value: Int(r.energy))
            }
        }
    }
}
```

`Resources` je `Double` po polju u BE response-u (on-demand lazy calc), pa tek na display-u se round-uje u Int. `Int(r.credits)` truncate-uje — za display je OK, ali za cost checks (building upgrade cost preview) koristiti `Double` direktno.

### Performance cilj

- 60 FPS na iPhone 13 mini baseline (ako tamo radi, svuda radi)
- Scene setup < 500ms (splash → first frame renderovan)
- Tap response < 100ms (tap → selected tile swap vidljiv)
- Memory: < 80MB za CityScene aktivnu sa svim asset-ima učitanim

Profiling: Xcode Instruments → SpriteKit template → FPS + Memory. Testirati rano.

---

## TESTING STRATEGIJA

**Unit tests (XCTest) — Models/:**
- Decoding svih Codable model-a sa sample JSON-ovima (fixture fajlovi u `SyndiCoreTests/Fixtures/`).
- Centralni decoder test: datum fractional / bez fractional / invalid format.
- Enum decoding: validne vrednosti, unknown string → throws.

**Unit tests — Services/:**
- `APIClient` sa mocked URLSession: auth interceptor, 401 retry, decode failures.
- `SupabaseManager` sa mocked session: refresh logic.

**Integration tests — protiv staging-a (manualno pokretani, ne u CI):**
- Full onboarding flow (signup → onboarding → join world → check city).
- Build → training → send troops → battle report.
- Cleanup: delete test player nakon.

**UI tests (XCUITest) — smoke only:**
- Launch app → splash → auth screen renders.
- Ne testirati detaljne flows (flaky, brzo se menjaju).

**Test fixture generacija:**
- Koristi `curl` ka staging-u sa test accountom, sačuvaj response JSON-ove kao fixture. Skripta `scripts/refresh-fixtures.sh` re-generiše sve fixture kad se OpenAPI menja.

---

## PREDLOŽENA STRUKTURA iOS PROJEKTA

```
syndicore-iOS/
├── CLAUDE.md                          ← ovaj fajl
├── .gitignore                         ← Config.plist, .DS_Store, build/
├── Config.example.plist               ← template (commit-uje se)
├── SyndicoreContracts/                ← auto-synced iz BE
│   ├── openapi.json
│   ├── game-constants.json
│   ├── VERSION
│   └── art-reference/                 ← style anchor images (ne ide u Assets)
│       └── hero_reference_v1.png
├── scripts/
│   └── refresh-fixtures.sh
├── SyndiCore/
│   ├── SyndiCoreApp.swift             ← @main entry
│   ├── Config.plist                   ← gitignored, sadrži SUPABASE_URL + anon key
│   ├── Models/
│   │   ├── Player.swift
│   │   ├── World.swift
│   │   ├── City.swift
│   │   ├── MapTile.swift
│   │   ├── BattleReport.swift
│   │   ├── Enums.swift                ← Faction, Ring, Terrain, ResourceType, ...
│   │   └── GameConfig.swift           ← parsed game-constants.json
│   ├── Services/
│   │   ├── SupabaseManager.swift      ← supabase-swift wrapper + session refresh
│   │   ├── APIClient.swift            ← URLSession + auth interceptor + retry
│   │   ├── APIError.swift             ← unified error enum
│   │   ├── JSONDecoder+API.swift      ← centralni decoder
│   │   └── SocketService.swift        ← ⚠️ TBD protokol
│   ├── State/
│   │   └── GameState.swift            ← @Observable, @MainActor
│   ├── Views/
│   │   ├── SplashView.swift
│   │   ├── AuthView.swift
│   │   ├── OnboardingView.swift
│   │   ├── WorldPickerView.swift
│   │   ├── FactionPickerView.swift
│   │   ├── MainGameView.swift         ← TabView container
│   │   ├── City/                      ← ekran grada (Prioritet 2)
│   │   │   ├── CityView.swift         ← SwiftUI ZStack: scene + HUD overlay
│   │   │   ├── HUD/
│   │   │   │   ├── TopHUD.swift
│   │   │   │   ├── BottomHUD.swift
│   │   │   │   ├── SideHUD.swift
│   │   │   │   ├── HUDButton.swift    ← reusable styled button
│   │   │   │   └── ResourcePill.swift ← mali resource display
│   │   │   ├── Sheets/
│   │   │   │   ├── BuildSheet.swift           ← empty tile tap → choose building
│   │   │   │   ├── BuildingDetailSheet.swift  ← occupied tile → upgrade/demolish
│   │   │   │   └── HQInfoSheet.swift          ← HQ tile → info only
│   │   │   └── Scene/
│   │   │       ├── CitySceneView.swift        ← UIViewRepresentable za SKView
│   │   │       ├── CityScene.swift            ← SKScene, top-level orchestrator
│   │   │       ├── Isometric.swift            ← projection math + constants
│   │   │       ├── WallLayout.swift           ← perimeter placement helper
│   │   │       ├── TileNode.swift             ← empty/selected states
│   │   │       ├── HQNode.swift               ← HQ sprite + future hologram
│   │   │       ├── BuildingNode.swift         ← loads texture po building.type
│   │   │       ├── WallNode.swift             ← perimeter wall wrapper
│   │   │       ├── CornerPylonNode.swift      ← uglovi
│   │   │       ├── ScaffoldNode.swift         ← construction in-progress
│   │   │       └── Effects/                   ← SpriteKit particle .sks fajlovi
│   │   │           └── electric_arc.sks       ← za Power Grid
│   │   ├── BuildingDetailView.swift   ← deprecated, zameniće ga BuildingDetailSheet
│   │   ├── TrainingView.swift
│   │   ├── ArmyView.swift
│   │   ├── BattleReportView.swift
│   │   ├── SyndikatView.swift         ← placeholder
│   │   └── ResearchView.swift         ← placeholder
│   ├── Map/
│   │   ├── MapScene.swift             ← SKScene (svetska mapa, Prioritet 3)
│   │   ├── MapView.swift              ← SwiftUI wrapper (SpriteView)
│   │   ├── MapTileMapNode.swift       ← SKTileMapNode wrapper za terrain/ring
│   │   ├── OccupantNode.swift         ← per-occupant SKSpriteNode
│   │   ├── WarpGateOverlay.swift
│   │   └── MovementLineNode.swift     ← animated troop path
│   └── Assets.xcassets/
│       └── City/                      ← svi sprite-ovi za CityScene
│           ├── hero_skybox_v1.imageset/
│           ├── tile_empty_v1.imageset/
│           ├── tile_selected_v1.imageset/
│           ├── tile_pulse_effect_v1.imageset/
│           ├── hq_pyramid_v1.imageset/
│           ├── wall_segment_v1.imageset/
│           ├── corner_pylon_v1.imageset/
│           ├── construction_scaffold_v1.imageset/
│           ├── barracks_v1.imageset/
│           └── power_grid_v1.imageset/
├── SyndiCoreTests/
│   ├── Fixtures/                      ← JSON fajlovi za decode testove
│   ├── Models/
│   │   └── DecodingTests.swift
│   ├── Services/
│   │   ├── APIClientTests.swift
│   │   └── DateDecoderTests.swift
│   ├── Scene/
│   │   └── IsometricTests.swift       ← scenePosition ↔ tileCoord round-trip
│   └── Integration/
│       └── OnboardingFlowTests.swift  ← staging, manual run
├── SyndiCoreUITests/
│   └── SmokeTests.swift
└── SyndiCore.xcodeproj/
```

---

## ŠTA DA SE IMPLEMENTIRA SLEDEĆE

> **Ažurirano:** 2026-04-22. Prioriteti 0-4 i 7 su završeni. Preostaje P5, P6, i P2 hygiene.

**✅ Prioritet 0 — Temelji:** APIClient, JSONDecoder.api, APIError, SupabaseManager, fixture testovi. DONE.

**✅ Prioritet 1 — Auth + Onboarding flow:** Splash → Auth → Onboarding → WorldPicker → FactionPicker → MainGame. DONE.

**✅ Prioritet 2 — CityView scena:** SpriteKit iso grid, buildings, HUD, sheets, construction flow, scaffold animations. DONE.

**✅ Prioritet 3 — MapView:** SKTileMapNode, occupants, warp gates, pan/zoom, debounced refetch, tap info, send troops, movement lines. DONE.

**✅ Prioritet 4 — ArmyView + Send troops:** Troops tab (garrison + reinforcements), Movements tab (paginated, countdown, DEV skip, infinite scroll), Reports tab (paginated, detail view), SendTroopsSheet. DONE.

**✅ Phase 4 — Crystal Implosion:** HQInfoSheet implosion, CrystalSheet, TopHUD crystal badge, MapView ruins, AppState.handleImplodeSuccess. DONE (0936340).

**✅ Prioritet 7 — Socket.IO real-time:** building_complete, training_complete, troops_arrived events, incoming attack banner. DONE (498a0d9).

**Prioritet 5 — ResearchView (tech tree) — SLEDEĆE:**
- GET research state → 6 grana (3 universal + 1 faction, 2 locked)
- Svaka grana: level bar, upgrade dugme, cost preview (iz `game-constants.json`)
- Respec dugme (reset all, 10% resource penalty)
- Points budget indicator (total / spent / remaining)
- API: `GET/POST /worlds/:id/research`, `POST /worlds/:id/research/respec`

**Prioritet 6 — SyndikatView (clans):**
- Lista syndikats-a u world-u
- Create / Join / Leave
- Member list sa ranks
- Promote / Kick (OVERLORD/WARDEN only)
- Diplomacy panel (PACT/NEUTRAL/HOSTILE)

**P2 — Code review hygiene (kad bude vremena):**
- MapScene `group.name!` force unwrap
- MapView hardcoded 800×800 scene size
- GameConstantsManager plain decoder
- AnyCodableValue bez .array/.object
- MapView closure capture [weak self]
- OnboardingView fragile error string match
- GameState.bootstrap decode fail fallback
- CountdownLabel Timer cleanup

---

## IMPLEMENTIRANI VIEWS — FEATURE STATUS

> **Ažurirano:** 2026-04-22
> Ovaj deo dokumentuje šta je stvarno implementirano i funkcionalno u iOS klijentu.
> Služi kao referenca za BE tim (šta iOS klijent može da konzumira) i za praćenje iOS razvoja.
> Svaki view ima status: ✅ Implementirano | 🚧 Delimično | ❌ Placeholder

---

### ✅ CityView (`Views/CityView.swift`)

Centralni ekran igre. SwiftUI `ZStack`: SpriteKit scena + HUD overlay.

#### SpriteKit scena (`CityScene`)
- **Grid** — 6×6 isometrijski grid, octagonal cutouts (12 tile-ova), HQ 2×2 region u centru
- **Tile mapa** — `SKTileMapNode`, buildable slotovi prikazuju `tile_empty_v1`, selected state `tile_selected_v1`
- **HQ sprite** — `hq_pyramid_v1`, statičan, tap otvara HQInfoSheet
- **Building sprite-ovi** — učitavaju se po `BuildingType` (npr. `barracks_v1`), scaffold prikazan dok traje gradnja
- **Skybox** — `hero_skybox_v1`, aspect-fill, pokriva ceo ekran
- **Fixed camera** — zaključan zoom (1.76×) i pan, bez user interakcije (pinch/pan/double-tap uklonjeni)
- **Long-press na zgradu** — prikazuje `BuildingTooltipNode` (naziv + level) iznad zgrade
- **Tap na prazan tile** → selected pulse overlay → otvara BuildSheet
- **Tap na zgradu** → selected pulse + scale tap animacija → otvara BuildingDetailSheet
- **Tap na HQ** → selected state → otvara HQInfoSheet
- **Resource tick floaters** — `+X` animacija iznad HQ kad se resursi povećaju između refresh-a
- **Construction progress bar** — `ConstructionProgressNode` na scaffold-u sa countdown-om
- **Celebration burst + screen flash** — po završetku gradnje (particle efekat + haptic + refreshCity callback)
- **Queue indicator dot** — pulsing dot iznad HQ kad postoji aktivna gradnja
- **Debug grid overlay** — togglable cyan outline-ovi + magenta anchor točke (dev only)
- **Scaffold → building fade-in** — kad gradnja završi, novi sprite fade-in (0.5s) umesto instant swap-a
- **Haptic feedback** — light tap, medium HQ

#### Crystal Implosion (Phase 4)
- **HQInfoSheet** — implosion sekcija vidljiva kad HQ == 20 i ring != NEXUS; 5 FE preconditions (HQ level, not NEXUS, no movements, no construction, has SETTLER); crystal bonus preview; destructive confirmation dialog; full BE error code handling
- **CrystalSheet** — collected crystals grupisani po ringu sa counts; cumulative bonuses (production/ATK/DEF); ring progression stepper (FRINGE → GRID → CORE → NEXUS)
- **TopHUD** — crystal badge (diamond icon + count), tap otvara CrystalSheet
- **AppState.handleImplodeSuccess** — city switch, player refresh, socket reconnect, completion toast
- **CompletionNoticeBanner** — `.implosion` kind (purple bolt icon)

#### Fixed building pozicije (zakucane u `CityScene.fixedPositions`)
| Building | Col | Row | Pozicija |
|---|---|---|---|
| OPS_CENTER | 2 | 1 | N od HQ |
| RALLY_POINT | 3 | 1 | N od HQ |
| BARRACKS | 1 | 2 | W od HQ |
| MOTOR_POOL | 4 | 2 | E od HQ |
| WAREHOUSE | 1 | 3 | W od HQ |
| TRADE_POST | 4 | 3 | E od HQ |
| WATCHTOWER | 2 | 4 | S od HQ |
| RESEARCH_LAB | 3 | 4 | S od HQ |

#### Resource slot pozicije (`CityScene.resourceSlotPositions`, 10 slotova)
`(2,0)`, `(3,0)`, `(4,1)`, `(5,2)`, `(5,3)`, `(3,5)`, `(2,5)`, `(1,4)`, `(0,3)`, `(0,2)`

#### HUD
- **TopHUD** — resource pills (Credits/Alloys/Tech/Energy sa ikonama) + naziv grada (capsule) + crystal badge
- **BottomHUD** — aktivna gradnja sa countdown timerom + trening queue (jedinice u treningu sa countdown-om) + "Train" dugme
- **RefreshErrorBanner** — pojavljuje se kad refresh ne uspe, sa Retry dugmetom, auto-dismiss nakon 8s, transition animacija

#### Sheets
- **BuildSheet** — lista zgrada koje igrač može da izgradi (fixed + resource buildings sa flex slot proverom); cost preview iz game-constants.json (credits/alloys/tech/trajanje); Build dugme po svakoj; disabled ako postoji queue; API: `POST /cities/:id/build` sa `buildingType` + `slotIndex` za resource zgrade; refresh + dismiss po uspehu
- **BuildingDetailSheet** — tip + current level; upgrade cost preview (`GET /cities/:id/build-cost`): Credits/Alloys/Tech + trajanje; Upgrade dugme → `POST /cities/:id/build` sa `buildingId`; countdown ako je već u upgrade-u
- **HQInfoSheet** — HQ level + countdown ako u upgrade; naziv grada, lokacija (x,y), ring, terrain; Crystal Implosion sekcija (kad HQ 20 + not NEXUS)
- **TrainingSheet** — lista jedinica iz `game-constants.json` po frakciji; sortovano po energy cost; stepper za količinu (1-100); cost preview po resursu × count + trainMin × count; API: `POST /cities/:id/train`; refresh + dismiss po uspehu
- **CrystalSheet** — collected crystals, bonuses, ring progression

#### Data / State management
- **Auto-refresh loop** — svakih 30s dok je view aktivan (`.task` sa cancellation)
- **Initial load** — `refreshCity()` na pojavi
- **Parallel fetch** — `refreshCity()` paralelno fetch-uje city + training jobs (`async let`)
- **Training jobs** — `activeTrainingJobs` u GameState, prikazuju se u BottomHUD
- **Post-action refresh** — odmah po Build / Upgrade / Train API pozivima
- **Post-construction-timer refresh** — `onConstructionComplete` callback iz scene → `refreshCity()`
- **Request timeouts** — 30s timeout na city, map viewport, worlds API pozive

---

### ✅ Auth flow (multi-screen)

| View | Status | Opis |
|---|---|---|
| `SplashView` | ✅ | Fetch `GET /api/v1/config`, ETag caching, error state sa retry |
| `AuthView` | ✅ | Supabase email/password sign in + sign up + Apple Sign In, error display |
| `OnboardingView` | ✅ | `GET /me` → 404 → username input → `POST /me/onboarding` |
| `WorldListView` | ✅ | `GET /worlds`, lista servera, join navigacija (auto-select prvi svet) |
| `FactionPickerView` | ✅ | Izbor REAPERS/HEGEMONY/NETRUNNERS → `POST /worlds/:id/join` |
| `MainGameView` | ✅ | `TabView` kontejner (City, Map, Army, Syndikat, Codex, Settings) |

---

### ✅ ArmyView (`Views/ArmyView.swift`)

Kompletno funkcionalan military screen sa 3 tab-a.

- **TroopsTab** — garrison prikaz (unit icon + name + count), reinforcements grupisano po saveznicima (username + faction), total defense summary (own + allied)
- **MovementsTab** — paginirani movements sa infinite scroll, countdown tajmer (CountdownLabel + onArrival callback), movement type icon/color, from→to coordinates, via gate indikator, DEV skip dugme (⚡), auto-refresh svakih 30s, pull-to-refresh
- **ReportsTab** — paginirani battle reports sa infinite scroll, tap za detail sheet, outcome headline (Attack Successful/Failed, Defense Held/Lost), target coordinates + ratio, stolen resources badge, date/time
- **BattleReportDetailView** — outcome (winner, target, ATK/DEF totals, ratio), attacker/defender army snapshot (before/after/lost tabela), resources stolen, buildings damaged
- **SendTroopsSheet** — movement type picker (segmented), unit stepper (per-type, Max/0 shortcuts), summary, error/success display, haptic feedback, post-send refresh

#### API integracija
- `GET /worlds/:id/movements?limit=50&before=<cursor>` — paginirano
- `GET /worlds/:id/reports?limit=50&before=<cursor>` — paginirano
- `POST /cities/:id/send` — send troops
- `POST /worlds/:id/movements/:id/skip` — DEV skip (instant complete)

---

### ✅ MapView (`Map/MapView.swift` + `Map/MapScene.swift`)

- ✅ `SKTileMapNode` terrain grid sa ring bojama
- ✅ Occupant overlay (`SKSpriteNode` za gradove, outposts, mines, warp gates, ruins)
- ✅ Ruins display: original ring, decay countdown (CountdownLabel), loot multiplier badge
- ✅ Warp Gate linije (`SKShapeNode` compound path)
- ✅ Camera pan/zoom sa `SKCameraNode`
- ✅ Tap na tile → `MapInfoView` popup (tip, ring, terrain, occupant info)
- ✅ Send troops akcija iz tile info (Attack/Raid/Scout/Reinforce/Transport per tile type)
- ✅ Debounced viewport refetch kad se kamera pomeri >30% radiusa
- ✅ Movement lines na mapi (`MovementLineNode`) — animirane putanje aktivnih pokreta
- ✅ Ruins: Raid action (primary), Scout action

---

### ✅ Real-time (`Services/SocketService.swift`)

- ✅ Socket.IO v4 konekcija sa JWT token auth
- ✅ Room join: `join_city` (city-specific), `join_syndikat` (ako je u klanu)
- ✅ Events: `building_complete` → refresh city + toast, `training_complete` → refresh city + toast, `troops_arrived` → refresh movements/reports/city + toast
- ✅ `IncomingAttackBanner` — prikazuje se kad neprijatelj šalje napad (iz movements)
- ✅ `CompletionNoticeBanner` — toast za building/training/implosion complete

---

### 🚧 Codex tab (`Views/CodexView.swift`)

- ✅ `UnitsView` — lista svih jedinica iz `game-constants.json` sa stats (ATK/DEF/SPD/CARRY)
- ✅ `UnitDetailView` — detalji po jedinici
- ✅ `BuildingsView` — lista svih zgrada sa opisima
- 🚧 `TechTreeView` — prikazuje grane vizuelno, ali upgrade API nije vezan
- ❌ Research API nije vezan (`GET/POST /worlds/:id/research`, `POST /worlds/:id/research/respec`)

---

### ❌ SyndikatView — placeholder

- Nije implementirano. API endpointi postoje u Endpoint.swift ali UI čeka.

---

### ❌ ResearchView — čeka implementaciju (P5)

- TechTreeView u Codex-u prikazuje grane read-only
- Treba: upgrade dugme, cost preview, points budget, respec

---

### 🛠 Dev Tools

- **SpriteAlignmentTestView** — 4 tab-a: HQ (anchor/scale/rotation tuning), 1×1 (building tuning), Grid (interaktivni tile editor), Zoom (camera defaults tuning)
- **TileGridEditorView** — isometrijski grid editor: drag-to-rearrange tile-ovi, tap-to-delete/restore, generiše Swift kod za kopiranje u `CityScene` i `Isometric`
- **DebugGridOverlayNode** — toggleable iz Settings-a; cyan tile outlines + magenta anchor točke

---

## GAME DESIGN REFERENCE

Kompletan GDD je u BE repo-u: `github.com/LukovicNikola/syndicore-BE/blob/main/CLAUDE.md`

Ključni koncepti za iOS:
- **Jedan grad po igraču** — progresira kroz ringove via Crystal Implosion (SETTLER + HQ 20 → implode → relocate)
- **4 ringa** (Fringe → Grid → Core → Nexus) — progresija kroz Crystal Implosion, svaki crystal daje permanentni bonus
- **Univerzalne jedinice** — svi igrači imaju isti roster od 8 jedinica + Settler
- **Frakcije** se razlikuju po tech tree branch-u, ne po jedinicama
- **Warp Gates** — fast-travel mreža, server računa najkraću rutu
- **Combat** je instant (3 faze), nema animacija borbe — samo izveštaj
- **Resursi** se kalkulišu on-demand (lazy), ne periodic tick
- **Ruins** — ostaju nakon Crystal Implosion, mogu se raidovati za 2× loot, decay nakon 14 dana

---

## CHANGELOG

**2026-04-22 (Phase 4 Crystal Implosion + feature status sync):**

- **Crystal Implosion** (commit `0936340`):
  - `GameData.swift`: crystal bonuses, implosion config, watchtower alerts models
  - `City.swift`: ImplodeResponse + related structs
  - `Endpoint.swift` + `APIClient.swift`: POST /cities/:id/implode + 5 new BE error codes
  - `HQInfoSheet.swift`: implosion section (HQ 20 + SETTLER required, movement/queue blockers, confirmation dialog)
  - `AppState.swift`: handleImplodeSuccess (city switch, player refresh, socket reconnect, toast)
  - `CrystalSheet.swift` (NEW): collected crystals by ring, cumulative bonuses, ring progression stepper
  - `TopHUD.swift`: crystal badge (diamond icon + count, tap to open CrystalSheet)
  - `MapView.swift`: ruins display with decay countdown + loot multiplier, RAID/SCOUT actions for ruins
  - `CompletionNoticeBanner.swift`: .implosion kind (purple bolt icon)
- **Contracts sync** (PR #22, merge `660cbf3`): openapi.json paginated movements/reports schemas, game-constants watchtower_alerts/crystals/implosion
- **CLAUDE.md sync**: P0 marked done (idempotent configure), ArmyView/Socket.IO/Crystal Implosion marked done, 4/10 TBD pitanja rešena, feature status fully updated to match actual implementation
- Closed stale PRs #18-21, merged #22

**2026-04-21 (city features round 2 + API hardening):**

- **P1 code review fixevi** (commit `50f9db8`):
  - `BuildCostResponse.buildingType` → `BuildingType` enum (type-safe)
  - URL query params refaktor na `URLComponents` + `queryItems` (Endpoint.swift)
  - Per-request timeout: `withOptionalTimeout` helper, 30s default na city/map/worlds
  - `os_log` warning za nepoznati `UnitType` u ArmySnapshot/TroopMovement decode
  - BuildSheet cost preview iz `game-constants.json` (credits/alloys/tech/trajanje)
- **City features** (commit `55f3a25`):
  - Resource buildings (DATA_BANK/FOUNDRY/TECH_LAB/POWER_GRID) dodati u BuildSheet sa `slotIndex` support
  - Scaffold → building fade-in animacija (0.5s) kad gradnja završi
  - RefreshErrorBanner auto-dismiss nakon 8s
  - Training queue prikaz u BottomHUD sa countdown tajmerima
  - `refreshCity()` paralelno fetch-uje city + training jobs
  - `BuildingInfo` explicit throw kad ni `currentLevel` ni `level` ne postoje
  - Fixed camera (pinch/pan/double-tap uklonjeni), zaključan zoom 1.76× i pan
  - Scaffold alignment: `SpriteCatalog.scaffold` spec kao single source of truth
  - Fix: ops_center prikazivao scaffold umesto sprite-a (uklonjen `currentLevel==0` check)
  - Uklonjen recenter button iz CityView
- Sprite spec-ovi tunirani za: data_bank, tech_lab, ops_center, foundry, motor_pool, trade_post

**2026-04-17 (CityView assets v1 + scena spec):**

- Dodata sekcija **CITYVIEW SCENA — KOMPLETNA SPECIFIKACIJA** sa art direction lock-om, asset library manifest-om, iso math helper-ima, node hijerarhijom, z-order konvencijama, state→visual mapping-om, i interactive flow-om.
- Generisan i dokumentovan prvi talas sprite-ova (v1, Tripo3D + Nano Banana Pro):
  - `hero_reference_v1.png` (art anchor, ne ide u Assets)
  - `hero_skybox_v1.png` (background)
  - `tile_empty_v1.png` (24 reuse)
  - `tile_selected_v1.png` (tap state)
  - `tile_pulse_effect_v1.png` (animacioni bonus)
  - `hq_pyramid_v1.png` (centralna komanda)
  - `wall_segment_v1.png` (perimeter, tile-able)
  - `corner_pylon_v1.png` (uglovi)
  - `construction_scaffold_v1.png` (build-in-progress state)
  - `barracks_v1.png` (prva military zgrada — trenira GRUNT/ENFORCER/SENTINEL)
  - `power_grid_v1.png` (prva resource zgrada — ENERGY, flex slot)
- Dodata pod-sekcija **Particle effects (runtime, SKEmitterNode)** — svi živi animirani efekti (Power Grid electric arc, Barracks prozor pulse, Foundry spark shower za kasnije) idu kao SpriteKit emitteri iznad statičkog sprite-a, ne pečeni u teksturu. Konkretan primer setup-a za `electric_arc.sks` particle emitter uključen.
- Prioritet 2 razbijen na pod-taskove (2a-2i) sa konkretnim asset referencama. Dodat Prioritet 2.5 (buildings nakon što scena radi) i 2.6 (HUD binding na GameState).
- `Isometric.swift` konstante fiksirane: `tileWidth = 128`, `tileHeight = 64`, `gridSize = 5`, `hqCoord = (2, 2)`.
- Ažurirana project struktura sa `Views/City/` subfolder-om (HUD/, Sheets/, Scene/, Scene/Effects/), dodata `SyndicoreContracts/art-reference/`, dodata `Assets.xcassets/City/` sa 10 imageset-a, dodat `SyndiCoreTests/Scene/` za iso math testove.
- Z-order konvencije fiksirane: skybox -100, tile/building iso sort po `col + row`, perimeter iznad, HUD 1000+.
- Performance cilj definisan: 60 FPS na iPhone 13 mini, scene setup < 500ms, tap response < 100ms, memory < 80MB.

**2025-04-17 (iOS-side patch):**

- Dodat TBD registar na vrhu dokumenta (10 stavki za BE reconcile).
- Pravilo #1 prepisano: "konkretna implementacija prvo, pa iteriraj" umesto "20 pitanja pre koda".
- `BuildingInfo` model ispravljen na `currentLevel` / `targetLevel` / `endsAt` (poklapa se sa server response-om). `isUpgrading` je sada computed property.
- String polja konvertovana u enum-e gde je server šalje kao string literal: `TroopInfo.unitType`, `TrainingJob.unitType`, `TroopMovement.type`, `TroopMovement.units`, `ConstructionQueue.type`, `TileMine.resourceType`, `BattleReport.attackerUnits/defenderUnits.before/after/lost`, `ResearchBranchState.branch`, `ResearchResult.branch`, `World.status`.
- Dodat `ResourceType` enum (CREDITS / ALLOYS / TECH / ENERGY).
- Dodat `WorldStatus` enum.
- Svi datumi konvertovani `String → Date`. Centralni `JSONDecoder.api` sa ISO8601 + fractional seconds strategijom.
- Dodat `[UnitType: Int]` codable helper šablon u napomeni.
- `viaGates` naming ujednačen između send i movements response-a (ranije `routeViaGates` vs `viaGates`).
- Dodat unified `APIError` enum i error response shape expectation.
- Dodat sekcija **Session refresh strategija** (Supabase 401 retry, token expire, logout flow).
- Dodat sekcija **SpriteKit Performance** sa `SKTileMapNode` preporukom umesto 10k individualnih `SKSpriteNode`.
- Dodat sekcija **Testing strategija** (unit + integration + UI + fixture skripta).
- Dodat **Prioritet 0 — Temelji** pre Priority 1 (APIClient, decoder, error mapping, testovi).
- Building/unit stat tabele skraćene — source of truth je `game-constants.json`, uklonjena duplikacija formula.
- `Config.plist` dodat u `.gitignore`, dodat `Config.example.plist` template.
- Supabase URL zamenjen placeholder-om (nije commit-ovan u doc).
- Ring table: Chebyshev range kolona dodata sa TBD markerima.
- WebSocket protokol markiran kao TBD (Socket.IO vs native).
- Pagination markirana kao TBD za `/movements` i `/reports`.
- `buildingsDamaged` polje na BattleReport dokumentovano kao TBD (shape nepoznat).
- Ažurirana project struktura sa `Tests/`, `scripts/`, `Config.example.plist`.