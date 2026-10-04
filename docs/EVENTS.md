# Skyport Online Events

Skyport Online events use one reusable 21-day structure. New events should be
content/config changes, not new gameplay systems.

## Turning an event on or off

Events live in:

`src/events/EventCatalog.gd`

Each event has one authoritative switch:

```gdscript
"enabled": false,
```

Change it to `true` to allow the event to run. Change it back to `false`
to hide and stop the event immediately.

A scheduled event also has a `start_unix`. Every event automatically lasts:

**21 days / 3 weeks**

The duration is controlled by `EventCatalog.EVENT_DURATION_DAYS` and should
normally remain 21 so all events share the same structure.

The included **Sky Lantern Festival** is a disabled example/template.

The first release-facing event is **Christmas & New Year Airbridge**.

It ships with `enabled = false` until the release date is firm.

Provisional schedule:

**December 18, 2026 00:00 UTC → January 8, 2027 00:00 UTC**

If release timing changes, update `start_unix` before enabling the event.
Autumn Airbridge remains disabled archive/test content because the game is not
expected to release during the Autumn event window.


## Fixed event structure

Every event follows the same loop:

**Play normal airport gameplay → complete event quests → claim event currency
→ buy cosmetics / limited passengers → contribute Alliance points**

The Event button only appears in the bottom navigation while an event is
active.

### Week 1

Four starter quests:

- Flights completed.
- Passengers boarded.
- Country resources earned.
- Flight coins earned.

Each quest awards **40 event currency + 10 Alliance points**.

Maximum week-1 currency: **160**.

### Week 2

The same four gameplay categories return with higher targets.

Each awards **50 event currency + 15 Alliance points**.

Maximum week-2 currency: **200**.

### Week 3

The final four quests use the highest targets.

Each awards **60 event currency + 20 Alliance points**.

Maximum week-3 currency: **240**.

A complete personal event therefore awards:

**600 event currency + 180 personal Alliance contribution**

Old unfinished quests remain available after the next week opens, but a future
week does not gain progress before it unlocks.

## Event currency

Currency is stored per event ID.

Example:

`sky_lantern_festival_2026` → `Lantern Tickets`

Currency cannot carry into another event because every event has a separate
persistent state. After an event is disabled or expires, its old currency
remains archived in the profile but is inaccessible to other events.

## Event shop

The sample shop establishes the standard V1 structure:

| Item | Cost | Limit |
| --- | ---: | ---: |
| Airport border cosmetic | 150 | 1 |
| Terminal skin cosmetic | 220 | 1 |
| Pico livery cosmetic | 260 | 1 |
| Event flag cosmetic | 180 | 1 |
| +25 passengers | 25 | 3 |
| +75 passengers | 60 | 1 |

Event passenger purchases are deliberately limited to:

**150 passengers maximum per full event**

Passenger purchases also require enough free passenger storage for the entire
pack. Event currency is not consumed when storage is too full.

Cosmetic ownership persists permanently through `owned_cosmetics`. The first
event framework stores cosmetic unlock IDs now; actual skin/equip visuals can
be connected later without changing the event economy.

## Alliance event

Every event may enable the standard Alliance section.

Personal quest claims add Alliance contribution points. The current sample has
four shared milestones:

| Alliance points | Reward |
| ---: | --- |
| 150 | +50 event currency |
| 400 | Alliance event cosmetic |
| 800 | +100 event currency |
| 1,400 | +150 event currency |

Total possible Alliance currency bonus: **300**.

The local profile stores:

- Personal event contribution.
- Last known Alliance total.
- Claimed Alliance milestones.

The current game does not yet have live Alliance networking. The event manager
therefore exposes:

`set_alliance_total_from_server(total)`

When the Alliance backend is implemented, it can push the real shared total
into the exact same event UI and milestone system.

## Event economy target

A full personal clear gives **600** currency.

A fully completed Alliance track can add **300** currency.

Maximum event currency from quests/milestones is therefore **900** before any
future special grants.

The example shop costs slightly more than that if a player tries to buy every
cosmetic and every passenger pack, so the player must make at least a small
choice. Events should remain optional side progression rather than mandatory
airport power.

## Gameplay metrics

The framework currently understands these metrics:

- `flights_completed`
- `passengers_boarded`
- `resources_earned`
- `flight_coins`
- `buildings_placed`
- `destination_flights`

The sample event uses the first four. Future event templates can use any metric
already emitted to `EventManager.record_metric()`.


## First release event

**Christmas & New Year Airbridge** is tuned for a brand-new airport population.

Featured quest-route progression:

| Week | Route | Intended aircraft |
| --- | --- | --- |
| 1 | Brussels • 175 km • Lv1 | Pico P8 • Lv1 • 320 km range |
| 2 | London • 360 km • Lv1 | Swift S14 • Lv2 • 430 km range |
| 3 | Berlin • 575 km • Lv4 | Comet C22 • Lv4 • 600 km range |

This keeps all three weekly route quests reachable without requiring the Lv6
Voyager.

The event has:

- 12 quests total, 4 per week.
- **620 Festive Vouchers** from all personal quests.
- Up to **300 Festive Vouchers** from Alliance milestones.
- **920 total completion currency**.
- 5 personal cosmetics.
- 1 Alliance-exclusive cosmetic.
- +25 passengers ×3.
- +75 passengers ×1.
- **150 event-shop passengers maximum**.

The complete shop also costs **920 Festive Vouchers exactly**. A player who
fully clears both the personal and Alliance tracks can therefore buy every
event-shop item once. Players who only complete the personal track must
prioritize.

Featured routes deliberately use `featured_route_currency = 0`, so repeat
flying does not create unlimited event currency. Their purpose is quest
progression and seasonal identity.

## Adding a new event

Copy the sample dictionary in `EventCatalog.all()` and change:

1. Event ID.
2. Display name and currency name.
3. `enabled`.
4. `start_unix`.
5. Quest titles/targets/rewards.
6. Cosmetic IDs/names.
7. Shop prices and limits.
8. Alliance milestone names/targets/rewards.

Do not create a new Event screen, currency system, quest class or shop system
for each event.

## Persistence

Profile persistence now includes:

- `event_states`
- `owned_cosmetics`

Each event state contains:

- Event currency.
- Quest progress.
- Claimed quests.
- Shop purchase counts.
- Personal Alliance contribution.
- Cached Alliance total.
- Claimed Alliance milestones.

## Validation

`tests/event_framework_test.gd` validates:

- 21-day duration.
- Three weekly unlock windows.
- 600 personal quest currency.
- Alliance contribution.
- Event currency persistence.
- Passenger shop rewards and storage blocking.
- Cosmetic persistence.
- Alliance milestone rewards.
- The sample event shipping disabled by default.
