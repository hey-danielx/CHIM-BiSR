# CHIM-BiSR

CHIM server plugin plus a Skyrim patch for **Bathing in Skyrim - Renewed**.

Followers keep a sticky dirt marker. They can complain about their own hygiene, comment on the player's smell, and wash themselves with `Take_Bath` when they have soap or a wash rag and are at water or a wash basin.

## What players install

1. **Skyrim patch** (`BiSR-CHIM-Patch.zip`) — Papyrus override plus `CHIM/bisr_actions.csv` and a bundled server plugin under `CHIM/server-plugins/CHIM-BiSR/`.
2. **CHIM server plugin** (`CHIM-BiSR.tar.gz`) — for the CHIM plugin manager, or auto-installed from the Skyrim zip on game start.

Load the Skyrim patch **below** Bathing in Skyrim - Renewed and `AIAgent`.

Bathing in Skyrim must be **enabled** in its MCM. Dirt tracking on followers uses BiSR's normal follower dirt; CHIM reads that state, it does not replace bathing.

## What CHIM sees

| Piece | When | What happens |
| --- | --- | --- |
| **Sticky marker** | Player or follower dirt crosses a hygiene tier | Stored on the server until they bathe |
| **Own-dirt comment** | A follower gets dirtier | One short in-character line; worse dirt sounds more uncomfortable |
| **Player-dirt comment** | The player gets dirtier | A nearby follower notices some dirt, or a bad smell when the player is filthy |
| **Take_Bath** | Follower has soap/wash rag and is in water, under a waterfall, or next to a wash basin | They wash without using BiSR dialogue |
| **Clear** | They finish bathing | `{Name} is clean again.` |

The player is human. CHIM does not speak as the player; followers react to the player's dirt.

## Build release archives

```powershell
.\scripts\build-release.ps1
```

Pass `-Mo2PatchPath` when building locally if you also want the generated CSV and `.dwpkg` copied into an existing MO2 mod folder.

Output in `release/`:

- `CHIM-BiSR.tar.gz` / `CHIM-BiSR.tar`
- `BiSR-CHIM-Patch.zip`
- `CHIM-BiSR/<version>.dwpkg` (bundled inside the Skyrim zip)

## GitHub release

1. Update the version in `manifest.json` and `dwemer-package.json`, then push.
2. Create a GitHub release whose tag matches that version, such as `1.0.0`.
3. The package workflow attaches `CHIM-BiSR.tar.gz`, `CHIM-BiSR.tar`, and `BiSR-CHIM-Patch.zip`.

Asset names must match exactly. The installer looks for `CHIM-BiSR.tar.gz`.

## Requirements

Bathing in Skyrim - Renewed, SKSE, PapyrusUtil, PO3 Papyrus Extender, CHIM (`AIAgent.esp`).

## In-game smoke test

1. Bathing in Skyrim enabled, CHIM loaded, this patch below both.
2. Travel until a follower is at least a bit dirty. They should get a hygiene marker and may make one short complaint.
3. Let the player get filthy. A follower should comment on the smell and that a bath is overdue.
4. Give that follower soap or a wash rag, stand them in a river or next to a wash basin, and let them use `Take_Bath` without opening BiSR dialogue.
