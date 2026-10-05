# Monetization provider integration

Skyport Online keeps gameplay rewards separate from platform billing and rewarded-ad SDKs. No UI button grants paid currency or Premium entitlement directly.

## Google Play product catalog

The current internal products map to these store product IDs:

| Internal ID | Google Play product ID | Price target | Grant |
| --- | --- | ---: | --- |
| `aero_small` | `skyport_aero_small` | €1.99 | 120 Aero Tokens |
| `aero_medium` | `skyport_aero_medium` | €4.99 | 350 Aero Tokens |
| `aero_large` | `skyport_aero_large` | €9.99 | 800 Aero Tokens |
| `airport_pass` | `skyport_airport_pass` | €4.99 | Current-month Premium Airport Pass |

All four are configured as repeatable/consumable products in the game catalog. The billing adapter is responsible for the platform-specific purchase acknowledgement/consumption flow after verification.

## Game-side billing contract

`MissionProductBillingBridge` is the only purchase-request bridge used by the Airport Pass/Aero Token UI.

When the Android billing adapter is ready it should:

1. Call `ProgressionMain.set_mission_billing_provider_connected(true)`.
2. Listen to `MissionProductBillingBridge.purchase_requested(product_id, store_product_id)`.
3. Launch the Google Play purchase flow for `store_product_id`.
4. Verify/acknowledge the purchase according to the billing SDK and backend policy.
5. Pass the verified store product ID and unique purchase token to:
   `ProgressionMain.complete_mission_purchase_from_provider(store_product_id, purchase_token)`.

Restored verified purchases can use `complete_mission_restore_from_provider(...)`.

The game does not accept an empty purchase token. `MissionPassRules.purchase_receipts` records accepted tokens, so replaying the same provider callback cannot grant Aero Tokens twice.

## Rewarded ads

`RewardedPassengerAdBridge` remains the provider boundary for rewarded actions. The ad SDK should set the provider connected state, request/show the ad when the bridge asks for an action, and call `complete_reward_from_provider()` only after the SDK confirms the earned reward.

Mission rerolls therefore remain:

- one free reroll per UTC day;
- one additional rewarded-ad reroll per UTC day;
- no reward for merely opening or closing an ad.

## Important release requirement

The repository intentionally does not contain production Google Play credentials, service-account secrets, ad-unit IDs, or private verification keys. Those belong in the release/provider configuration, not source control.
