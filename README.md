# Skyport Online

Mobile-first isometric airport management game.

## Current milestone: Pass 9 — Passenger bottleneck + regional-resource upgrade sinks

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

## Passenger bottleneck

Passenger aircraft now consume passengers before departure.

The aircraft flow is therefore:

**Fuel / service → destination ready → passenger boarding → runway request → departure**

If the airport does not have enough passengers for that aircraft's seat requirement, the aircraft remains at its stand in:

**WAITING PASSENGERS**

Passenger generation continues in the background. As soon as enough passengers are available, the waiting aircraft automatically boards them and enters the runway queue.

The current prototype aircraft use their passenger capacity as the boarding requirement:

- Aerolet 100 — 18 passengers.
- Aerolet 120 — 24 passengers.

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
| 2 | 2.2 | 55 | 2,500 | 2 Belgium Chocolate + 1 UK Specialty Goods |
| 3 | 3.2 | 75 | 6,000 | 2 France Cosmetics + 2 Germany Industrial Tools |
| 4 | 4.5 | 100 | 12,000 | 3 Denmark Design Goods + 2 UK Specialty Goods |
| 5 | 6.0 | 135 | 22,000 | 3 Germany Machinery + 3 France Luxury Goods + 2 Netherlands Horticulture |

The first upgrade deliberately uses resources from early World Map destinations so the system is reachable without late-game routes.

Building upgrade levels are persisted in the guest profile.

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

Passenger-generation buildings are directly selectable in the airport view.

Tapping the Travel Office opens an upgrade panel showing:

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

Current tested examples:

| Aircraft / route | Resource chance per item |
| --- | ---: |
| Aerolet 100 → London | 40.0% |
| Aerolet 120 → London | 30.4% |
| Regional 200 → London | 47.9% |
| Regional 200 → Copenhagen | 50.4% |

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

**Lv1: 1.5 passengers/min + 40 storage**  
**Lv2: 2.2 passengers/min + 55 storage**  
**Aircraft boarding deducts passenger stock**  
**An aircraft cannot board when stock is insufficient**

## Next pass

**Pass 10 — Passenger acquisition options + deeper airport economy**

Recommended next work:

- Add the agreed rewarded-ad passenger boost: +25 passengers, capped by available storage.
- Add daily friend / Alliance passenger gifting groundwork.
- Add a second physical passenger-building family with a different footprint / production profile.
- Begin requiring passenger counts by route / aircraft role rather than always filling every seat.
- Add passenger demand preview to the World Map before dispatch.
- Start an economy/history panel showing passenger generation, flight consumption, resource income, and bottlenecks.
