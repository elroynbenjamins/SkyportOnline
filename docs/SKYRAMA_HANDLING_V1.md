# Skyrama-style owned aircraft handling (V1)

V1 intentionally does **not** require aircraft to physically taxi between handling buildings.

The interaction model is:

- real animation for **landing** and **takeoff**;
- instant transfer between ground-handling structures after the player taps the next bubble;
- progress/timer feedback while a service is running;
- a completion bubble when the next player action is available.

## Receiving an owned aircraft

1. Flight timer completes.
2. Aircraft becomes inbound and exposes **RECEIVE**.
3. Player taps RECEIVE.
4. The aircraft performs the approach + landing animation.
5. It stops at the **END** of the runway.
6. The runway remains occupied by that aircraft until the player taps **UNLOAD**.
7. UNLOAD instantly transfers the aircraft to the cargo unloading / Ground Ops structure.
8. Cargo unloading runs as a timed stage.
9. When complete, **HANGAR** appears.
10. HANGAR instantly stores the aircraft and returns it to the available fleet.

## Sending an owned aircraft

1. Player selects an available aircraft.
2. Player chooses a destination country.
3. The aircraft instantly appears at the compatible fuel structure.
4. Fueling runs as a timed stage.
5. When complete, **LOAD** appears.
6. LOAD instantly transfers the aircraft to the cargo loading / Ground Ops structure.
7. Cargo loading runs as a timed stage.
8. When complete, **SEND** appears.
9. SEND requests the runway.
10. When the runway is free, the aircraft instantly appears at the **START** of the runway.
11. The takeoff + climb-out animation plays.
12. The aircraft enters its flight timer.

## Runway slot rules

A runway has one operational aircraft slot for V1.

- Only **one aircraft total** may occupy a runway at a time.
- A landed aircraft waiting at runway **END** blocks another landing and another departure.
- The landed aircraft releases the runway only when **UNLOAD** is tapped and it transfers away.
- A departure cleared to runway **START** blocks another takeoff and another arrival.
- Additional departing aircraft remain at their previous handling structure / SEND-ready state until the runway becomes available.
- The dispatcher queue remains responsible for ordering arrivals and departures.

These rules are intentionally independent from Taxiway pathfinding.

Taxiways remain grid-buildable visual/infrastructure pieces and can support richer movement later, but owned-aircraft V1 handling must not fail because a continuous physical taxi route is unavailable.
