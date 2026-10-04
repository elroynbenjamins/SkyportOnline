# Winter Airbridge — Christmas & New Year Launch Event

This is the first seasonal event intended for the public release of Skyport Online.

The event uses a broader **Winter** presentation while retaining Christmas and
New Year identity in its missions, cosmetics, and Alliance rewards.

## Activation

The event remains disabled until the release date is firm:

```gdscript
"id": "christmas_new_year_airbridge_2026",
"enabled": false,
```

Provisional schedule:

**December 18, 2026 00:00 UTC → January 8, 2027 00:00 UTC**

If release timing moves, update `start_unix` before enabling it so new players
receive close to the complete 21-day event.

Autumn Airbridge remains disabled archive/test content.

## Weekly route progression

| Week | Featured route | Intended aircraft |
| --- | --- | --- |
| 1 | Brussels • 175 km | Pico P8 • Lv1 |
| 2 | London • 360 km | Swift S14 • Lv2 |
| 3 | Berlin • 575 km | Comet C22 • Lv4 |

Featured routes are quest targets but do **not** generate repeatable event
currency.

`featured_route_currency = 0`

This prevents players from endlessly farming the shortest event route.

## Earnable currency

Personal quests:

**620 Festive Vouchers**

Alliance currency milestones:

**300 Festive Vouchers**

Maximum normal event income:

**920 Festive Vouchers**

## Expanded Winter shop

The shop deliberately contains more stock than one player can buy.

Total stock value if every purchase limit is exhausted:

**1,310 Festive Vouchers**

This makes the store a choice rather than a completion checklist.

### Cosmetics

| Item | Price | Limit |
| --- | ---: | ---: |
| Winter Lights Airport Border | 145 | 1 |
| Snowy Terminal Skin | 180 | 1 |
| Candy Cane Pico Livery | 220 | 1 |
| New Year Alliance Flag | 130 | 1 |
| Snow Globe Garden | 110 | 1 |

Personal cosmetic total:

**785 vouchers**

The Alliance track also contains the separate **Winter Alliance Emblem**.

### Passenger bundles

| Item | Price | Limit | Total passengers |
| --- | ---: | ---: | ---: |
| +25 Passengers | 25 | 3 | 75 |
| +50 Passengers | 40 | 2 | 100 |
| +75 Passengers | 60 | 1 | 75 |

Maximum event-shop passengers:

**250 passengers**

The +50 pack is specifically limited to **2 purchases**.

Passenger rewards still require enough free airport passenger storage before
the purchase can complete.

### Coin bundles

| Item | Reward | Price | Limit |
| --- | ---: | ---: | ---: |
| Winter Coin Pouch | 2,500 coins | 35 | 2 |
| New Year Coin Case | 6,000 coins | 75 | 1 |

Maximum event-shop coins:

**11,000 coins**

This is intentionally useful to a young airport without replacing the normal
aircraft/infrastructure economy.

### Winter Supply Crates

**Winter Supply Crate**

- Price: **55 Festive Vouchers**
- Purchase limit: **3**
- Each crate grants exactly **1 chosen country resource**
- Maximum: **3 chosen resources per event**

The player chooses the resource before vouchers are spent.

Available resource countries:

- Netherlands
- Belgium
- Germany
- United Kingdom
- France
- Denmark

All three resources from each listed country are selectable.

The selector intentionally excludes later global countries such as the United
States, Japan, China, Australia, etc., so the event does not bypass future
long-range route progression.

## Winter visuals

The Winter theme currently provides:

- Winter terminal light strings during the event.
- Snowy Terminal cosmetic treatment.
- Blue/white/red/green Winter airport border.
- Candy Cane Pico event livery.
- WINTER featured-flight marker.
- Placeable Winter Event Flag.
- Placeable Snow Globe Garden.

These code-driven visuals can later be replaced with dedicated event pixel art
without changing the event IDs or shop economy.

## Alliance track

| Alliance points | Reward |
| ---: | --- |
| 150 | +50 Festive Vouchers |
| 400 | Winter Alliance Emblem |
| 800 | +100 Festive Vouchers |
| 1,400 | +150 Festive Vouchers |

Alliance participation is valuable but not mandatory for accessing the event
shop. Personal-only players still earn 620 vouchers and can choose a strong mix
of cosmetics and utility items.

## Reward ceilings

Across the whole 21-day event:

- **620** personal vouchers.
- **300** Alliance vouchers.
- **920** maximum vouchers.
- **1,310** vouchers of shop stock.
- **250** maximum purchased passengers.
- **11,000** maximum purchased coins.
- **3** maximum selected country resources.

## Resource-crate transaction safety

A Winter Supply Crate does not deduct vouchers when the player opens the
selection screen.

The transaction happens only after a valid resource is selected.

Invalid resources, resources from disallowed countries, insufficient vouchers,
or purchases beyond the three-crate limit do not consume event currency.

## Release checklist

Before enabling:

1. Confirm release date.
2. Update `start_unix` if necessary.
3. Run the full Godot CI suite.
4. Confirm `tests/winter_launch_event_test.gd` passes.
5. Confirm Autumn remains disabled.
6. Confirm Winter cosmetic/building IDs exist.
7. Test both +50 passenger purchases.
8. Test coin-pack wallet updates.
9. Test all six resource-country groups in the crate selector.
10. Set `enabled = true`.
11. Build the release candidate.
12. Verify EVENT appears only inside the 21-day event window.
