# PROJECT HOPLITE — V0.0.5 Combat Feel + Injury AI

## Changes
- Light attacks are ~25-30% faster with earlier combo chain points.
- Combat input is polled directly from Input instead of `_unhandled_input`, reducing dropped rapid clicks.
- Light combo buffer increased from 2 to 3 queued attacks.
- Camera vertical pitch is distributed over authored spine/chest attack bones; the physical sword sweep follows it.
- One severed leg caps AI to a slow limp/walk (~1.85 m/s).
- Two severed legs force a low crawl state (~0.72 m/s) with the visual body lowered.
- Severing the right arm/forearm drops the sword and permanently disables AI attacks.
- Dead enemies now visibly collapse to the floor and stop blocking the player.

## Test
1. Spam LMB/J: every click should buffer more consistently and the 3-hit sequence should be much faster.
2. Jump above a target, look down, attack: the sword swing/sweep should angle down with the camera.
3. On an AI enemy: sever one leg, then both legs, then the right arm. Watch BODY=limp/crawl/disarmed.
4. Kill an AI: it should fall sideways instead of staying upright.
