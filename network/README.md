# LAN multiplayer checkpoints

## Stage 1 — connect and orient

- Launch the game normally (F6 on the board bypasses the lobby; use F5).
- On the first PC choose **Host match**. Share its LAN IPv4 address and port.
- On the second PC enter that address, leave the same port, and choose **Join match**.
- Both boards open after the connection handshake. The joining board is rotated
  180 degrees, with its team at the bottom and characters/menus upright.
- Stage 1 originally locked combat input; stage 2 now enables it with turn ownership.
- **Leave match** returns to the lobby; the other player's board pauses.
- **Local play** keeps the existing playable local mode.

For two instances on one computer, join `127.0.0.1`. The default UDP port is
`27841`. If Windows asks, allow the game on private networks. Wi-Fi guest/client
isolation can prevent two devices from reaching each other. The address field
also accepts a Tailscale address; Tailscale configuration is outside this stage.

## Stage 2 — authoritative combat commands (ready to verify)

Host-only simulation; team ownership; turn, move, select, cast, cancel, and end-turn
commands; authoritative state updates and stale-command rejection.

Both players need this build (protocol version 4). The host controls the
original lower team; the joining player controls the other team. Only the active
unit's owner can operate its menu. Clicking another unit cannot change initiative.

Verify these steps with two instances, joining `127.0.0.1` on the same computer:

1. Move the active unit. Both boards should show the same logical destination.
2. Choose a skill, select its target, or cancel. Check energy and health updates.
3. End the turn. The next unit's owner should gain control; the observer cannot act.
4. Repeat from the joining window and check that aiming respects the rotated view.
5. Try a multi-step skill such as Retreating Shot; check its cooldown on both boards.

Stage 2 includes legal target tiles and basic pillars/pads/shields so skills can be
used. Guest health bars now follow combat visibility and damage/healing previews,
with local unit inspection available. The observer's radial menu is dimmed and
does not highlight under their pointer; skill tooltips remain local and readable.
Odin clouds, their covered tiles, and countdowns replicate to the guest. Character,
zone, cloud, and tooltip hover are private to each player's own pointer.

Replication is change-driven rather than continuous: the host sends authoritative
state after commands and turn-start resolution, while the active player sends aim
updates only when the targeting tile changes. Private hover never enters snapshots.
Dust, cutscenes, and skill animations are intentionally not synchronized.

## Stage 3 — shared presentation

Radial menus, selected actions, skill availability, movement and attack ranges,
hovered attack areas, damage previews, multi-stage targeting, and skill effects.
Tooltips stay local to each player's own pointer.

## Stage 4 — full skill and network verification

Exercise all skills, persistent zones, displacement and bouncing shots, delayed
turn effects, disconnects, and two-device LAN play.

## Automated tests

Start these two headless processes together (host first):

```text
godot --headless --path . --script res://tests/netplay_session.gd -- host
godot --headless --path . --script res://tests/netplay_session.gd -- client
```

They use UDP port `27951`, verify the ready handshake, perspective, coordinate
mapping, upright UI, turn ownership, disconnect pause, rehosting, and timeout cleanup.

The combat test uses port `27952` and exercises both players' commands, invalid and
duplicate requests, stale revisions, movement costs, damage, stun, turn advancement,
replicated zones and pads, cooldowns, and guest Retreating Shot with different
viewport sizes:

```text
godot --headless --path . --script res://tests/netplay_combat.gd -- host
godot --headless --path . --script res://tests/netplay_combat.gd -- client
```
