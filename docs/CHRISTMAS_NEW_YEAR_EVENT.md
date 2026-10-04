# Christmas & New Year Airbridge — Release Checklist

This is the first event intended for the public release of Skyport Online.

## Current status

The event is fully configured but intentionally disabled.

```gdscript
"id": "christmas_new_year_airbridge_2026",
"enabled": false,
```

Do not enable it until the actual release timing is known.

## Provisional schedule

Start:

**December 18, 2026 00:00 UTC**

End:

**January 8, 2027 00:00 UTC**

Duration remains the standard **21 days**.

If launch slips, move `start_unix` so players receive close to the full three-week event. Do not launch a heavily expired event just because the original provisional date has passed.

## New-player route progression

Week 1: **Brussels** — 175 km — Lv1 — Pico P8 can reach it.

Week 2: **London** — 360 km — Lv1 — Swift S14 can reach it from Lv2.

Week 3: **Berlin** — 575 km — Lv4 — Comet C22 can reach it from Lv4.

Copenhagen is intentionally not used for Week 3 because its 620 km distance would force the Lv6 Voyager and is too aggressive for a launch population.

## Currency economy

Personal quests: **620 Festive Vouchers**

Alliance milestone currency: **300 Festive Vouchers**

Maximum completion currency: **920 Festive Vouchers**

Featured-route repeat bonus: **0**

Event currency therefore comes from quest and Alliance milestone claims, not from endlessly farming the same seasonal route.

## Shop

Personal cosmetics:

- Christmas Lights Airport Border — 145.
- Snowy Terminal Skin — 180.
- Candy Cane Pico Livery — 220.
- New Year Alliance Flag — 130.
- Snow Globe Garden — 110.

Passenger packs:

- +25 passengers — 25 each — max 3.
- +75 passengers — 60 — max 1.

Total shop cost: **920 Festive Vouchers**

A complete personal + Alliance clear can buy the whole shop exactly.

Maximum event-shop passenger gain: **150 passengers**

## Alliance track

- 150 points → +50 Festive Vouchers.
- 400 points → North Star Alliance Emblem.
- 800 points → +100 Festive Vouchers.
- 1,400 points → +150 Festive Vouchers.

The Alliance backend can later push the real shared total into the existing EventManager hook without changing this event definition.

## Cosmetics / visuals

Configured cosmetic IDs:

- `event_xmas_airport_border`
- `event_xmas_terminal_skin`
- `event_xmas_pico_livery`
- `event_xmas_alliance_flag`
- `event_xmas_snow_globe_garden`
- `event_xmas_alliance_emblem`

Current code-driven visuals include:

- Christmas terminal lights.
- Snowy terminal treatment.
- Christmas airport border.
- Candy Cane Pico styling.
- Placeable New Year Event Flag.
- Placeable Snow Globe Garden.
- Christmas event aircraft badge.

Dedicated pixel-art variants can replace these later while preserving the same cosmetic IDs.

## Final activation steps

Before public release:

1. Confirm intended launch day.
2. Update `start_unix` if needed.
3. Verify the game release leaves close to three weeks of event availability.
4. Run full CI.
5. Confirm `tests/christmas_new_year_event_test.gd` passes.
6. Confirm all five personal cosmetic rewards and the Alliance emblem exist.
7. Confirm passenger storage can accept purchased packs.
8. Set `"enabled": true`.
9. Build the release candidate.
10. Verify EVENT appears only inside the active 21-day window.

Autumn Airbridge should remain disabled for the first public release.
