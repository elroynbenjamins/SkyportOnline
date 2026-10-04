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

The current live configuration also includes **Autumn Airbridge**, which is an
enabled event using the same framework but slightly different quest tuning.

## Operator safety

The runtime validates the entire event catalog before selecting an active event.
If validation fails, Events stay disabled and a warning is shown rather than
silently choosing a broken configuration.

`EventCatalog.validate_catalog()` currently checks:

- Unique event IDs.
- Unique quest, shop-item and Alliance milestone IDs.
- Week 1 / 2 / 3 content exists.
- Quest weeks and targets are valid.
- Event passenger-shop total does not exceed **150 passengers**.
- Alliance milestone targets increase.
- Enabled 21-day event windows do not overlap.

Back-to-back events are valid when the next event starts exactly when the
previous 21-day window ends.

Operator summary helpers:

- `total_personal_currency(event)`
- `total_shop_passengers(event)`
- `total_alliance_currency(event)`

The disabled Sky Lantern template remains the baseline:

**600 personal currency • 150 event-shop passengers • 300 Alliance currency**

The live Autumn Airbridge intentionally uses featured-destination quests and
currently totals:

**620 personal quest currency • 150 event-shop passengers • 300 Alliance currency**


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

The sample event uses the first four. Future event templates can use any metric
already emitted to `EventManager.record_metric()`.

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
- Live event catalog validation and overlap detection.
- Standard-template and Autumn Airbridge economy totals.
