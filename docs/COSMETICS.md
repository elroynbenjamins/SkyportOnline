# Event Cosmetics

Event cosmetics are permanent account unlocks. Event expiration removes access
to the event shop/currency, but never removes cosmetics already purchased or
earned.

## Permanent customization access

Open:

**MORE → CUSTOMIZE**

The Customize screen remains available even when no event is active.

## Cosmetic slots

Skyport Online currently supports one equipped cosmetic per slot:

| Slot | Current visual behavior |
| --- | --- |
| Airport Border | Adds a seasonal frame around the airport HUD |
| Terminal Skin | Applies the event tint/accent to terminal buildings |
| Aircraft Livery | Applies an aircraft-specific live livery overlay |
| Alliance Flag | Shows the equipped Alliance flag badge in the airport header |
| Alliance Emblem | Shows the equipped Alliance emblem badge in the airport header |

The player can always choose **DEFAULT** to clear a slot.

## Current event cosmetics

Autumn Airbridge:

- Autumn Airport Border
- Autumn Terminal Skin
- Harvest Pico Livery
- Autumn Alliance Flag
- Autumn Alliance Emblem

Sky Lantern template:

- Lantern Airport Border
- Lantern Terminal Skin
- Festival Pico Livery
- Lantern Flag
- Lantern Alliance Emblem

## Aircraft-specific liveries

Aircraft liveries declare compatible aircraft model IDs.

The current event liveries target:

`pico_p8`

Equipping the Harvest/Festival Pico livery therefore changes Pico P8 aircraft
but does not recolor Swift S14 or other models.

This same structure can later support:

- Comet liveries
- M-class regional liveries
- multi-aircraft universal liveries
- dedicated sprite replacement files

without changing profile persistence.

## Visual implementation

The first implementation uses code-driven visual treatments so earned cosmetics
are visible immediately even before every event receives dedicated art.

The persisted cosmetic ID remains the stable identifier. A future art pass can
replace the tint/overlay with dedicated event PNGs while preserving every
player's ownership and equipped state.

## Persistence

Profile data stores:

- `owned_cosmetics` — permanent unlock ownership.
- `equipped_cosmetics` — one active cosmetic ID per slot.

A cosmetic must be owned before it can be equipped.

## Event integration requirement

Every cosmetic ID referenced by EventCatalog must also exist in CosmeticCatalog.

`tests/cosmetic_loadout_test.gd` validates this mapping across all configured
events and Alliance cosmetic milestones.
