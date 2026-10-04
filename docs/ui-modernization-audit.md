# Skyport Online — UI Modernization Audit

## Direction

The airport and World Map are the game.

UI should support those surfaces instead of making the player feel like they are moving between admin dashboards.

Skyrama is useful inspiration for keeping the airport visually dominant, using chunky build/fleet trays instead of nested settings menus, and making planes, destinations, buildings and friends feel like collectible game objects.

Skyport Online should modernize those ideas with:
- landscape-first hierarchy;
- fewer simultaneous text blocks;
- rounded layered cards;
- stronger primary/secondary actions;
- consistent status colors;
- contextual overlays instead of unnecessary full-screen menus;
- large mobile touch targets;
- pixel-art imagery inside modern UI chrome.

## Shared visual language

Implemented foundation:
- GameUIStyle.gd shared styling layer;
- common background, panel and border palette;
- raised and dark cards;
- selected-state cards;
- primary, secondary, event, gold and danger actions;
- common progress bars;
- common input styling;
- consistent headings and muted copy.

### Status colors

- Cyan: navigation / selection / normal active state.
- Gold: rewards, premium-feeling progression, Mastery, major unlocks.
- Green: ready / connected / completed.
- Amber: waiting / warning / constrained.
- Red: blocked / invalid / dangerous.
- Autumn orange: active seasonal event content.

Color should reinforce text/icons, never replace them.

## 1. Airport HUD

### Problems found
- Too many equally weighted top cards.
- Resource information did not feel tactile.
- Build catalog read as a long developer inventory.
- Navigation had six visually identical controls.
- Operational cards competed with the airport itself.

### Implemented
- Modern shared top-card styling.
- Stronger level/coin/passenger/gem hierarchy.
- Distinct ATC / airside / ground-ops cards.
- Primary build/placement action styling.
- Tactile bottom navigation.
- Event attention state.
- Selected build-item styling.
- Filtered Build Tray: ALL / INFRA / PAX / SERV / OPS / DECOR.

### Next refinement
- Convert airside / ground ops / ATC cards into compact status chips that expand only when tapped.
- Reduce permanent top-screen height.
- Add proper pixel icons for passengers, coins, gems and ATC instead of relying on emoji long term.
- Add a contextual aircraft card when tapping a plane.
- Keep normal airport camera framing unobstructed.

## 2. World Map

### Problems found
- Strong system depth but too much information had equal visual weight.
- Destination buttons did not distinguish contract/surge/selection strongly enough.
- Right details panel behaved like a text report.
- Aircraft list and route details competed with the map.

### Implemented
- Raised aircraft/details cards.
- Dark map frame.
- Selected aircraft card state.
- Selected destination state.
- Gold Priority Contract destination treatment.
- Event/surge destination treatment.
- Strong primary ASSIGN action.
- Muted secondary/status copy.

### Next refinement
Replace the long details text with four compact blocks:
1. Route: distance, time, demand.
2. Reward: coins, XP, event/contract multiplier.
3. Resources: three item icons + drop chance.
4. Aircraft fit: seats, range, Mastery.

Keep the map visually larger than the information columns.

## 3. Fleet Control

### Problems found
- Three-column structure was functional but spreadsheet-like.
- Selected aircraft did not feel like a collectible owned object.
- Catalog entries had weak progression hierarchy.

### Implemented
- Shared raised/dark card hierarchy.
- Selected owned-aircraft card.
- Gold Mastery bar.
- Stronger locked / owned catalog treatment.
- Consistent heading and status typography.

### Next refinement
- Add aircraft sprite/portrait to each owned card.
- Turn Seats / Range / Speed / Size / Resource Modifier into stat chips.
- Make five-star Mastery its own visual reward track.
- Show next Mastery reward as a reward tile rather than prose.
- Fleet can eventually become a large side drawer over a dimmed airport instead of a separate app-like page.

## 4. Seasonal Event

### Problems found
- Quest, Shop and Alliance columns looked like generic button lists.
- Claimable rewards did not feel rewarding.
- Event identity mostly came from text.

### Implemented
- Event-colored outer panel.
- Claimable quest/milestone = gold.
- Purchasable shop item = event orange.
- Completed/owned = selected state.
- Locked/unaffordable = subdued.
- Modern column cards.
- Physical Autumn airport decorations and featured-flight markers.

### Next refinement
- Event hero/banner art.
- Quest progress bars.
- Cosmetic thumbnails in shop cards.
- Large Alliance shared progress bar.
- Visual weekly unlock transition.

## 5. Resource / Economy screen

### Problems found
- Functionally useful but read like a diagnostic page.
- Lifetime metrics were one sentence instead of game KPIs.
- Resource rows lacked collectible identity.

### Implemented
- Shared raised panel.
- Primary passenger boost action.
- Resource cards.
- Clearer passenger and lifetime-flow hierarchy.

### Next refinement
Use KPI tiles for Flights, Passengers Generated, Passengers Boarded, Coins, XP and Resources.
Add resource icons and country framing.
Add country / upgrade-needed filters.
Rename MORE later to a clearer inventory/economy entry point.

## 6. Passenger / Service upgrade panels

### Problems found
- Utility-dialog appearance.
- Current vs next stats primarily prose.
- Upgrade action lacked hierarchy.

### Implemented
- Raised contextual cards.
- Strong heading.
- Muted explanation.
- Primary upgrade action.
- Secondary close action.

### Next refinement
- Side-by-side Current → Next rows.
- Green stat deltas.
- Resource requirement chips with owned/needed counts.
- Building sprite/icon at top.
- Success pulse after upgrading.

## 7. Flight Return Summary

### Problems found
- Important reward moment looked like a generic modal.
- Rewards were mostly text.

### Implemented
- Gold reward card.
- Gold COLLECT action.
- Strong reward title hierarchy.

### Next refinement
- Coin / XP / resource reward tiles.
- Mastery star progress animation.
- Separate contract/event bonus block.
- Short celebratory reveal before collect.

## 8. Airport creation / home-country choice

### Problems found
- Strong system design but too much onboarding prose.
- Country markers felt like debug squares.
- Form and map competed equally.

### Implemented
- Shared game panels.
- Styled text inputs.
- Shorter guest explanation.
- Strong CREATE AIRPORT action.
- Circular country markers with selection rings.
- Stronger country/resource cards.

### Next refinement
Use a two-step guided flow:
1. Airport identity.
2. Choose home country.

Let the country map own most of step 2.
Show selected flag/name plus three resource icons.
Move probability math behind an info control.

## 9. ATC / Airport Operations

Operational depth should primarily be visible in-world:
- hold-short lights;
- stop bars;
- tug movement;
- service vehicles;
- aircraft state markers;
- queues.

HUD should summarize exceptions/bottlenecks rather than narrate every operation.

### Next refinement
Use compact expandable chips such as RWY CLEAR, RWY BUSY, 2 WAITING, GROUND OPS OK.

## Responsive mobile rules

Primary target: landscape.

- Important touch targets: at least ~44 px.
- Main actions: 52–60 px.
- Body text: generally 14–16 px.
- Small metadata: 12–13 px.
- Avoid more than three simultaneous major panels over the airport.
- Scroll inside cards/drawers, not whole screens.
- Never require hover for important information.

## Implementation order

### Modernization Pass A — implemented
- Shared UI style system.
- Airport HUD.
- World Map.
- Fleet.
- Event.
- Resources/economy.
- Upgrade panels.
- Flight return.
- Airport creation / country map.
- Build category tray.

### Modernization Pass B — recommended next
- Compact airport status chips.
- World Map detail cards.
- Fleet sprite cards + stat chips.
- Quest progress bars.
- Upgrade before/after rows.
- Reward tiles.

### Modernization Pass C
- Dedicated pixel-art UI icon pack.
- Aircraft thumbnails.
- Resource icons.
- Event/shop thumbnails.
- Micro-animations and transition polish.

## Core rule

Whenever a new system is added, first ask:

Can this information be shown directly on the airport or map?

If yes, prefer the world representation.

If not, use a compact contextual card.

Only use a full-screen management surface when that surface itself is a core game space, such as the World Map.
