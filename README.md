# Skyport Online

Mobile-first isometric airport management game.

## Current milestone: Pass 11 — Fleet Control + Mastery presentation

Skyport Online now connects the international country economy directly back into airport progression.

### Current foundation

- Godot 4 landscape project using a 1280×720 reference viewport.
- Guest-first airport creation with airport name, code, home-country selection, and persistent profile.
- Interactive country selection backed by the regional-resource catalog.
- Isometric airport grid with land expansion.
- Physical airport buildings, taxiways, service roads, stands, and runways.
- Ground-service and runway queues.
- Aircraft-specific flight timers and range.
- Interactive Europe World Map.
- Three independently rolled country resources per completed flight.
- Persistent regional-resource inventory.
- Passive passenger generation and passenger storage.
- Passenger stock now gates aircraft departures.
- Country resources now have their first real upgrade sink.
- Fleet tab now opens a live aircraft roster with Mastery and V1 catalog progression.

## V1 aircraft turnaround timings

The playable V1 aircraft catalog now uses the approved nine S/M aircraft:

**Pico P8 → Swift S14 → Comet C22 → Voyager V32 → Nimbus N40 → Arrow A52 → Atlas A64 → Falcon F72 → Horizon H88**

Ground handling uses four blocks:

1. **Unload** — passenger deboarding and cargo unloading run in parallel.
2. **Service** — fuel, cleaning and catering run in parallel.
3. **Load** — passenger boarding and cargo loading run in parallel.
4. **Pushback prep** — final checks before runway queue.

A faster fuel building modifies only the fuel timer. Future passenger, cargo, cleaning and catering buildings can therefore improve their own service category independently.

| Aircraft | Lv | Size | Pax | Taxi speed | Pax out | Cargo out | Fuel | Clean | Catering | Pax in | Cargo in | Push | Full return |
| --- | ---: | :---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Pico P8 | 1 | S | 8 | 122 | 6s | 6s | 12s | 7s | 6s | 10s | 8s | 3s | 31s |
| Swift S14 | 2 | S | 14 | 132 | 7s | 7s | 11s | 7s | 6s | 11s | 9s | 3s | 32s |
| Comet C22 | 4 | S | 22 | 118 | 8s | 9s | 15s | 9s | 8s | 13s | 11s | 3s | 40s |
| Voyager V32 | 6 | S | 32 | 112 | 9s | 11s | 19s | 10s | 9s | 15s | 14s | 4s | 49s |
| Nimbus N40 | 8 | M | 40 | 100 | 11s | 15s | 24s | 13s | 11s | 18s | 18s | 5s | 62s |
| Arrow A52 | 10 | M | 52 | 108 | 12s | 17s | 22s | 13s | 11s | 19s | 20s | 5s | 64s |
| Atlas A64 | 12 | M | 64 | 92 | 14s | 21s | 30s | 16s | 14s | 23s | 27s | 6s | 84s |
| Falcon F72 | 15 | M | 72 | 102 | 14s | 20s | 28s | 15s | 13s | 22s | 25s | 6s | 79s |
| Horizon H88 | 17 | M | 88 | 94 | 16s | 24s | 36s | 18s | 16s | 26s | 32s | 7s | 99s |

**Full return** is standard-fuel stand time before taxi. Taxi itself remains physical and route-dependent; every aircraft now applies its own taxi speed, so airport layout affects real turnaround efficiency.

The starter airport uses **2× Pico P8** aircraft. L and XL remain future-ready and are intentionally not implemented in the V1 aircraft catalog.

## Ground-service infrastructure

Aircraft turnaround is now constrained by real service fleets rather than invisible timers.

The starter airport includes a compact **Ground Operations Depot** connected to the service-road loop. It provides four independent one-vehicle fleets:

- Passenger handling.
- Baggage / cargo handling.
- Cabin cleaning.
- Catering.

Fuel remains a separate fuel-station fleet.

Each service has its own queue and capacity. Two aircraft can therefore be waiting for the same cleaning van while a baggage tractor or passenger vehicle remains available. Service vehicles physically travel along the existing service-road network to the aircraft stand.

The turnaround order is now:

**Deboard + unload → fuel + clean + cater → wait for passenger stock → board + load → pushback → runway queue**

Passenger stock is consumed **before** passenger boarding begins. If stock is insufficient, the aircraft remains at the stand in a visible waiting state instead of completing a fake boarding timer.

Specialized service buildings unlock later:

| Building | Unlock | Service | Speed | Vehicles |
| --- | ---: | --- | ---: | ---: |
| Ground Operations Depot | Lv 1 | Pax / Cargo / Clean / Cater | x1.00 | 1 each |
| Cleaning Center | Lv 3 | Cleaning | x1.35 | 2 |
| Passenger Service Hub | Lv 4 | Passenger | x1.25 | 2 |
| Baggage Depot | Lv 5 | Cargo | x1.35 | 2 |
| Catering Kitchen | Lv 6 | Catering | x1.30 | 2 |

The dispatcher always prefers the fastest compatible facility with free capacity and a valid service-road route. This makes airport layout and specialized infrastructure real throughput decisions.

## Reconciled V1 progression gates

The passenger, Fleet, service-upgrade, and aircraft systems now share the same S → M progression data:

- **Small Hangar** — S-only, 3 aircraft-capacity slots.
- **Medium Stand** — Lv8, 45,000 coins.
- **Regional Fuel Depot** — Lv8, 60,000 coins.
- **Regional Hangar** — Lv8, 105,000 coins, S/M, 5 slots.
- **Regional Runway** — Lv8, 150,000 coins.
- **Nimbus N40** — Lv8, 185,000 coins.

The first complete M-aircraft project therefore remains **545,000 coins**.

All nine V1 aircraft definitions now retain purchase price, hangar-space usage, and operating-cost metadata alongside their live taxi, turnaround, Mastery, range, and resource-drop fields.

Starter aircraft no longer receive a hidden default route. The lifecycle is:

**turnaround → choose destination in WORLD → passenger check/boarding → pushback/runway → flight → return/reward → clear completed route → next turnaround → choose destination again**

Bremen is now an Lv1, 280 km destination. Together with Brussels, this gives the Pico P8 two starter countries within its 320 km range and makes the first Travel Office resource upgrade reachable through Belgium + Germany.

## Passenger bottleneck

Passenger aircraft now consume passengers before departure.

The aircraft flow is therefore:

**Fuel / service → destination ready → passenger boarding → runway request → departure**

If the airport does not have enough passengers for that aircraft's seat requirement, the aircraft remains at its stand in:

**WAITING PASSENGERS**

Passenger generation continues in the background. As soon as enough passengers are available, the waiting aircraft automatically boards them and enters the runway queue.

The live starter fleet currently uses **2× Pico P8** aircraft, so each fresh Pico normally boards 8 passengers before Mastery. The requirement comes from the selected aircraft profile and is reduced by Mastery when applicable.

This makes passenger production a real operational bottleneck rather than a cosmetic counter.

The passenger balance is persisted in the guest profile.

## Travel Office

The first passenger-generation building is the **Travel Office**.

It is a distinct 2×2 physical building. Additional Travel Offices cost 6,500 coins and unlock at airport Lv2.

The starter airport currently includes one Travel Office.

Internal upgrades improve production and storage only. The building keeps the same visual, matching the intended Skyport Online rule that internal numerical upgrades do not need to visually transform the building.

### Travel Office progression

| Level | Passengers / min | Storage | Coin cost | Regional-resource cost |
| --- | ---: | ---: | ---: | --- |
| 1 | 1.5 | 40 | — | — |
| 2 | 2.2 | 55 | 2,500 | 2 Belgium Chocolate + 1 Germany Industrial Tools |
| 3 | 3.2 | 75 | 6,000 | 2 France Cosmetics + 2 Germany Industrial Tools |
| 4 | 4.5 | 100 | 12,000 | 3 Denmark Design Goods + 2 UK Specialty Goods |
| 5 | 6.0 | 135 | 22,000 | 3 Germany Machinery + 3 France Luxury Goods + 2 Netherlands Horticulture |

The first upgrade deliberately uses resources from early World Map destinations so the system is reachable without late-game routes.

Building upgrade levels are persisted in the guest profile.

## Terminal passenger capacity

The **Small Terminal** is now a passenger-capacity provider as well as a physical airport building. It does not generate passengers by itself.

| Level | Passenger capacity | Coin cost | Resource direction |
| --- | ---: | ---: | --- |
| 1 | 120 | — | Base |
| 2 | 250 | 18,000 | Belgium + UK |
| 3 | 450 | 60,000 | Germany + France + UK |
| 4 | 750 | 175,000 | Denmark + Germany + Belgium |
| 5 | 1,200 | 500,000 | UK + France + Netherlands |

Terminal upgrades are internal/statistical; the building does not need to visually transform.

The starter passenger economy therefore begins with **120 terminal capacity + 40 Travel Office storage = 160 total passengers**.

## Regional-resource inventory

The bottom **MORE** button currently opens the first regional-resource inventory screen.

It shows:

- Current passengers.
- Passenger storage.
- Passenger production per minute.
- Owned country resources grouped by country.
- Current quantity of each owned material.

Flight-return drops are persisted to the profile and immediately become available for upgrades.

## Passenger building interaction

Passenger-upgradable buildings are directly selectable in the airport view.

Tapping the Travel Office, Shuttle Station, or Small Terminal opens an upgrade panel showing:

- Current internal level.
- Current passenger generation rate.
- Current passenger storage.
- Next-level generation/storage.
- Coin requirement.
- Every required regional resource.
- Owned amount versus required amount.
- Whether the upgrade can currently be purchased.

A successful upgrade atomically consumes the regional resources from the persistent profile, deducts the coin cost, applies the new building level, and immediately recalculates airport passenger production/storage.

## Country-resource economy

Each configured country has exactly three regional resources.

Completed flights roll all three independently.

Base chance:

**40% per resource**

Adjusted by:

- Aircraft-specific modifier: −20% to +20%.
- Flight-duration modifier.
- Aircraft-size modifier.

The current result is clamped between 20% and 70%.

Current tested V1 examples:

| Aircraft / route | Resource chance per item |
| --- | ---: |
| Swift S14 → London | 28.8% |
| Comet C22 → London | 32.4% |
| Nimbus N40 → London | 41.6% |
| Nimbus N40 → Copenhagen | 43.9% |

Rewards are granted only after the aircraft physically lands, taxis back, and reaches its stand.

## Flight-return economy

Successful completed flights currently award:

- Coins.
- XP.
- Three country-resource rolls.

The return summary shows all resource successes/failures and the player's updated owned count.

The resulting loop is now:

**Fly internationally → return safely → collect regional resources → upgrade passenger infrastructure → generate/store more passengers → support a larger/faster flight schedule**

## Persistence

The local guest profile currently stores:

- Airport identity.
- Home country.
- Account / guest identifiers.
- Regional-resource inventory.
- Passenger balance.
- Passenger-building internal upgrade levels.

The profile structure remains ready for attaching a linked account later without replacing the airport.

## Automated validation

GitHub Actions currently validates:

- Godot project import / GDScript parsing.
- Landscape startup.
- Airport country selection and country-resource catalog.
- Airside taxiway / runway connectivity.
- Ground-service road routing.
- Fuel queues and vehicle capacity.
- Arrival and departure runway queues.
- Full aircraft lifecycle.
- Aircraft-specific flight timers and range.
- Country-resource drop modifiers.
- Passenger Travel Office production.
- Passenger storage.
- Passenger boarding consumption.
- Insufficient-passenger blocking.
- Resource-funded Travel Office upgrade.
- Upgrade resource consumption.
- Passenger balance persistence.
- Passenger building-level persistence.

Current passenger regression verifies:

**Starter Terminal + Travel Office: 160 total capacity**  
**Travel Office Lv2: 2.2 passengers/min and 175 combined capacity**  
**Small Terminal Lv2 + Travel Office Lv2: 305 combined capacity**  
**Aircraft boarding deducts passenger stock**  
**An aircraft cannot board when stock is insufficient**


## Aircraft Mastery

Aircraft Mastery is account-wide **per aircraft type**. Owning or flying multiple copies of the same model contributes to the same mastery track.

Mastery hours are only credited after a flight successfully returns, lands, taxis back, and parks. Dispatching or canceling does not grant mastery.

Flight-hours use the route's aviation time:

**distance ÷ aircraft cruise speed**

rather than the compressed gameplay countdown. This keeps the mastery milestones genuinely long-term.

### Five-star mastery track

| Stars | Hours flown | Cumulative benefit |
| --- | ---: | --- |
| ★☆☆☆☆ | 10 h | ~5% lower passenger requirement, with at least 1 passenger saved |
| ★★☆☆☆ | 50 h | Previous benefit +5% flight XP |
| ★★★☆☆ | 150 h | Previous benefits +5% flight coins |
| ★★★★☆ | 400 h | Passenger reduction improves to ~10% with at least 2 saved; XP improves to +10% |
| ★★★★★ | 1,000 h | Previous benefits; coin bonus improves to +10% |

The minimum absolute passenger reduction prevents a percentage bonus disappearing through rounding on tiny starter planes such as the Pico P8.

For example, the Pico P8 normally requires 8 passengers:

- Unmastered: 8.
- Star 1: 7.
- Star 4–5: 6.

Mastery reward bonuses apply to the **next** flight after a milestone is earned. The returning flight contributes the hours that unlock the new star.

The World Map now displays:

- Mastery stars.
- Total flight-hours.
- Progress toward the next star.
- Mastery-adjusted passenger demand.
- Mastery XP bonus.
- Mastery coin bonus.
- Mastery-adjusted reward preview.

The flight return summary shows current mastery hours and calls out a newly unlocked star.


## Fleet Control screen

The bottom **FLEET** button now opens a dedicated landscape fleet-management screen rather than a placeholder.

The screen has three live areas:

1. **Owned aircraft** — every current aircraft instance with flight number, model, Mastery stars, live state and assigned route.
2. **Selected aircraft details** — operational state, route, stand/runway assignment, seats, Mastery-adjusted passenger requirement, cruise speed, range, taxi speed, resource modifier, turnaround timing and Mastery progression.
3. **V1 aircraft catalog** — all approved S/M aircraft with level locks, ownership count, seats, range and shared model Mastery.

Current live V1 progression is:

**Pico P8 → Swift S14 → Comet C22 → Voyager V32 → Nimbus N40 → Arrow A52 → Atlas A64 → Falcon F72 → Horizon H88**

The Fleet header also summarizes the current airport fleet as:

**owned • airborne • ground operations • waiting**

### Fleet + Mastery integration

Mastery is shared per aircraft type, so all owned copies of the same model show the same star progression.

The selected-aircraft panel shows:

- Current Mastery stars.
- Total flight-hours.
- Progress bar to the next star.
- Current Mastery benefits.
- Next Mastery reward.
- Base seats → Mastery-adjusted passenger demand.
- Current destination and remaining en-route time when airborne.
- Per-model resource-drop modifier.
- Full ground turnaround profile.

When a returning flight adds Mastery hours, an open Fleet screen refreshes immediately. A new star therefore appears without closing/reopening the screen.

The V1 catalog remains visible even for locked aircraft, which makes long-term fleet progression explicit. For example, Horizon H88 remains visible as a **Lv17** target before it is unlocked.

## Passenger-support systems

### Rewarded passenger boost

The passenger economy now has the agreed reward:

**+25 passengers**

The reward respects available passenger storage. If only 10 spaces remain, only 10 passengers are added.

- Maximum 3 rewarded passenger claims per day.
- Maximum theoretical rewarded-ad contribution: 75 passengers/day before storage limits.

The UI and reward callback are implemented, but an external rewarded-ad provider is **not connected yet**. The ad bridge deliberately does not auto-grant a reward. A future ad SDK must call the completion callback after it confirms a completed rewarded ad.

This prevents the prototype from pretending an ad was watched or allowing a free unlimited +25 button.

### Friend / Alliance passenger gift groundwork

The persistent profile now contains a daily incoming passenger-gift ledger.

Current provisional social balance:

- +5 passengers per received friend / Alliance gift.
- Maximum 10 incoming gifts per day.
- Maximum 50 gifted passengers per day before storage limits.

The actual Friends / Alliance networking layer is not connected yet. These rules and persistence are ready for that later integration.

## Second passenger-building family

The **Airport Shuttle Station** is now a second distinct passenger building rather than another Travel Office upgrade.

- Unlock: airport Lv4.
- Cost: 15,000 coins.
- Footprint: 3×2.
- Role: higher passenger throughput with lower storage efficiency.

### Shuttle Station progression

| Level | Passengers / min | Storage | Upgrade direction |
| --- | ---: | ---: | --- |
| 1 | 2.8 | 30 | Base |
| 2 | 4.0 | 42 | Coins + German Automotive Parts + French Gourmet Food |
| 3 | 5.5 | 58 | Coins + Danish Renewable Parts + Belgian Precision Parts |
| 4 | 7.5 | 80 | Coins + UK Aerospace Parts + German Machinery + French Luxury Goods |

This gives a real airport-layout choice:

- **Travel Office:** slower generation, better storage.
- **Shuttle Station:** faster generation, less storage per footprint/progression role.

Both retain their physical building identity while internal upgrades improve production/storage without requiring a new sprite.

## Passenger demand before dispatch

The World Map now previews the aircraft's actual passenger requirement before assignment.

This preview includes Mastery reductions, so a highly mastered aircraft can visibly require fewer passengers than a fresh aircraft of the same type.

Passenger stock remains a real departure gate:

**Serviced aircraft → destination assigned → passenger requirement checked → board passengers → runway queue**

If passenger stock is insufficient, the aircraft remains at the stand in **WAITING PASSENGERS** until enough passengers regenerate or arrive from a future support source.

## Resource-drop reconciliation

The country resource model continues to use:

**40% base chance per resource, rolled independently**

but the final per-flight chance is adjusted by:

- Aircraft-specific modifier: −20% to +20%.
- Flight-duration modifier.
- Aircraft-size modifier.

The approved V1 plane catalog now carries those aircraft-specific resource identities as well.

Examples include:

- Swift S14: −20% aircraft modifier.
- Atlas A64: +20% aircraft modifier.
- Horizon H88: +15% aircraft modifier.

The airport-creation UI now describes 40% as a **base chance**, not a fixed chance.

## Automated validation

The validation suite now covers:

- Landscape startup.
- Guest airport creation and country catalog.
- Airside / service-road connectivity.
- Aircraft turnaround timing.
- Flight timers and range.
- Adjusted independent country-resource drops.
- Passenger production, storage, and boarding bottleneck.
- Passenger-building upgrades and persistence.
- Five Mastery star milestones.
- Mastery passenger reductions.
- Mastery XP and coin bonuses.
- Mastery hours persistence by aircraft type.
- Fleet screen owned-aircraft list, V1 catalog locks, live state and Mastery refresh.
- Rewarded +25 passenger capacity handling.
- Rewarded-ad callback safety.
- Shuttle Station production/storage profile.
- Daily friend passenger-gift cap/reset logic.
- Rewarded-ad daily passenger cap persistence.
- Terminal passenger-capacity progression.
- Reconciled V1 aircraft prices, starter-route reach, and 545k regional gate.


## Next pass

Two useful directions are now ready and can be worked independently:

**Pass 12 — Passenger demand + economy history**

- Replace “always fill every seat” with destination-specific demand/load factors.
- Show expected passengers before dispatch, then apply Mastery reductions to that demand.
- Add route demand differences by destination, contract/event conditions, and later time/season.
- Track passengers generated, passengers boarded, resources earned, coins/XP returned, and aircraft utilization.
- Add a compact economy/history screen for identifying bottlenecks.

**Parallel airport-operations pass**

- Add visible per-aircraft turnaround progress at the stand.
- Add internal service-facility capacity/speed upgrades using regional resources.
- Keep the physical building visually unchanged while its throughput improves.
