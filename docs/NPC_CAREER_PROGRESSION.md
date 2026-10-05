# NPC traffic, airport career and friendship progression

## Scene integration

`Main.tscn` now runs `ProgressionMain.gd`, a narrow adapter extending the existing airport operations controller. Career rules, local persistence, the NPC scheduler and the career UI live in separate modules. Existing runway, taxi, stand, service-vehicle, event and layout systems are reused rather than simulated a second time.

A legacy terminal-management error was also corrected: a building-context summary return had been inserted into a void management handler with an undefined `summary` variable. The summary belongs in the building-context path, not the action handler. The new CI job rejects script/parse/compile errors even when Godot exits with code zero.

## Ambient NPCs

There is one fictional pilot per V1 aircraft family: Tess/Pico, Miles/Swift, Elise/Comet, Freja/Voyager, Nico/Nimbus, Sofia/Arrow, Mateo/Atlas, Keiko/Falcon and Amara/Horizon. Pilot entries explicitly use relationship `npc`; they are not fake online users.

The first arrival opportunity is after 90 seconds of foreground play. Following opportunities use a randomized 180–360 seconds. Congestion retries after 30 seconds. The scheduler never backfills offline visits, admits at most one ambient NPC at a time, and respects the shared three-visitor limit. Pausing NPC arrivals does not interrupt an aircraft already being handled.

An NPC requires its aircraft's unlock level and at least one free stand with a compatible runway/taxi connection plus service-road access to fuel, passenger, cargo, cleaning, catering and pushback capacity. Small-only airports never admit medium aircraft. The Nimbus unlocks in the catalog at level 8, but the current Regional Runway unlock remains level 12; medium traffic waits for real infrastructure.

NPCs use the actual arrival, taxi, unloading, ground servicing, loading, pushback and takeoff loop. They never consume the host's passenger stock. Successful departure grants a modest local handling fee (`50 + 2 × seats` coins) and `6 + ceil(seats / 8)` XP. NPCs do not roll country imports, generate remote-owner receipts, or earn friendship. This preserves a separate role for player-to-player country cooperation.

The scheduler prefers recently unlocked models but retains earlier pilots and avoids the immediately previous pilot when alternatives exist. Tests can seed its RNG.

## Guided career

There are 28 permanent, sequential missions covering the complete nine-model V1 fleet. They alternate plane-specific country returns, aircraft orders, passenger supply, NPC servicing, land, service buildings and medium-aircraft infrastructure. Only the active unlocked flight objective advances. A flight must return successfully: assigning or dispatching it does not count. NPC/friend visits cannot satisfy an owned-aircraft flight objective.

The path introduces Belgium/Pico, Germany and the UK/Swift, France/Swift, Germany/Comet, Denmark/Voyager, medium infrastructure, France/Nimbus, the UK/Arrow, Denmark/Atlas, Germany/Falcon and a five-country Horizon tour. The tour counts unique countries. All target routes are within the relevant aircraft's range and use existing destinations.

Building and aircraft ownership objectives recognize existing purchases. Building upgrades at or above the requested level count, so players never need to demolish and rebuy something for a quest. Stored buildings do not count as placed infrastructure.

Rewards contain only XP and occasional passengers: no career coin bundles, premium currency or materials. Claim IDs and completed flight tokens prevent duplicate local claims. Passenger rewards first enter a persistent reserve and transfer only as whole passenger capacity becomes available. There is no expiry, paid skip, login requirement or ad requirement. Normal flights continue to supply XP and coins between career level gates.

The old static airport objective panel is replaced by a career pin. The career screen contains the active mentor briefing, progress, rewards, three upcoming objectives and `Show me where` guidance. Guidance opens the appropriate route/aircraft, building placement, upgrade panel, land selection or NPC directory. Other tabs provide Aircraft Orders, NPC Visitors and Friendship.

## Aircraft acquisition and level progression

Aircraft Orders buys aircraft with ordinary coins and stores each with a durable ownership UID. Prices are initial tuning values in `AirportProgressionRules.AIRCRAFT_PRICES`, from 1,500 coins for an extra Pico to 120,000 for a Horizon. Ownership is capped at 16 aircraft for this version. Purchased aircraft stay in reserve until there is a compatible, fully serviced free stand. They are not lost merely because the airport is full.

New airports begin at level 1. Legacy airports without a progression sidecar retain their prior level-4 starting position. The cumulative XP curve is `50 × level × (level - 1)`, capped at level 30. This is a working progression curve, not a completed economy balance simulation.

Owned aircraft use the existing NE/SE/SW/NW PNG assets through `CareerAircraft`. The same rendering is used for NPCs, with a distinct green NPC badge. No new portrait pack is claimed or required for this implementation.

## Local persistence and limits

`AirportProgressionStore` uses an airport-ID-scoped ConfigFile sidecar, written through a temporary file and rename, with a backup. It stores career claims/progress, passenger reward reserve, local wallet/XP, purchased fleet, flight tokens/runtime checkpoints, NPC discovery and friendship. It is separate from the older `ProfileStore` so legacy saves cannot silently discard new fields. Claims and aircraft purchases are saved before their UI-visible reward/spend is published. Failed saves leave those actions uncommitted.

Owned flight checkpoints retain the plan, remaining flight time and paid-passenger marker; saved airborne time can elapse while away, but rewards still require landing. Ground service may restart after a reload. This is not a complete serialization of every vehicle's exact position or a cloud save protocol. The progression checkpoint and older resource/event profile are separate local files, not a server-side multi-file transaction.

The existing Social screen still uses explicitly labeled LOCAL TEST NETWORK contacts until a real online provider exists. Nothing in this pass activates real multiplayer delivery or server anti-cheat.

## Friendship

Five ranks use 0/10/30/75/150 credited successful visits. At most five points per contact per UTC day count; duplicate visits and backward day changes cannot refresh that allowance. NPCs are excluded. Local test contacts remain identified as test contacts. Host coin bonuses are 0%, 0.5%, 1%, 1.5% and 2%; no resource-chance or passenger-gift-cap boosts are added.

## Validation

The progression workflow checks strict Godot import logs, validates every mission/model/range reference, and runs a real main-scene integration test. The integration test steps actual aircraft and service vehicles rather than forcing service-completed callbacks. It covers a player flight return, an NPC departure, absence of NPC remote receipts/reputation, one-time claims, passenger overflow release, real aircraft purchases, all career tabs and save reload. Existing project validation continues to run separately.
