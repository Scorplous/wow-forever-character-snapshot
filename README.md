# WoW Character Snapshot

AtlasSnapshot is a local character snapshot addon for the **World of Warcraft:
Forever beta**. It gathers information exposed by the game's addon APIs for
later inspection and gameplay guidance.

**Version:** 0.3.0. **Declared client interface:** 16001.

The addon refreshes its data in game after relevant events. **It does not provide
a live external file feed or connect automatically to an AI/chat service.** WoW
writes its SavedVariables file when the interface reloads, the character logs
out, or the client exits normally. A crash may lose unsaved changes.

## What it captures

- Character identity, level, XP, money, resources, combat state, and location.
- Equipped items and durability, carried bags, active quests and objectives.
- Completed quest IDs exposed by the client, independently of the active log.
- Spellbook descriptions, cooldowns, talents, skills, and professions.
- Combat stats, player auras, target information, action references, and basic
  group/PvP context.

Bank contents, chat messages, passwords, and guild recruitment records are not
collected. The addon does not move the character, fight, send messages, or
automate gameplay. No game assets or third-party binaries are included here.

## Compatibility and validation

This is experimental code developed and used with the Forever beta client.
The addon source in this package matches the existing version 0.3.0
implementation; the TOC author label is generalized for public distribution.
The Python regression harness uses simulated WoW APIs, not a running client.
Those tests do not establish compatibility with every beta build or character.

Forever-specific trait and skill APIs are handled where available. APIs can be
missing or restricted, including resource values outside combat. Retail,
Classic Era, other Classic variants, and future Forever releases are not
certified. Do not assume changing the TOC interface number makes a client
compatible. Check the captured client build and each section's diagnostics.

Completed-history capture has offline regression coverage; a complete lifetime
quest history has not been established by live testing.

## Install

1. Download this repository's ZIP using **Code > Download ZIP**, then extract it.
2. Find the WoW installation used by your Forever beta client.
3. Copy the inner `AtlasSnapshot` folder into:

   ```text
   <WoW installation>/_classic_beta_/Interface/AddOns/AtlasSnapshot/
   ```

   That folder must contain `AtlasSnapshot.toc` and `AtlasSnapshot.lua` directly.
   Do not copy the whole repository into the AddOns folder.
4. Enable **Atlas Snapshot** in the game's AddOns list and log in.

Python and the test dependencies are not needed to run the addon in WoW.

## Capture and read an export

After login, wait a few seconds, then use `/reload` **while safely out of combat**
to save the current snapshot. If you installed or updated the addon while WoW
was already running, first reload safely to load the new code, wait a few
seconds, then reload again to save data collected by that version.

The saved file is:

```text
<WoW installation>/_classic_beta_/WTF/Account/<account>/SavedVariables/AtlasSnapshot.lua
```

Read or privately share that file only after the save has finished. It contains
`AtlasSnapshotDB.latest`, representing the most recently captured character;
it is not a multi-character history. No external reader or network service is
bundled with this addon.

The optional `/atlassnapshot` command refreshes **in-memory** data and reports
unavailable sections. It does not itself write a file. A safe reload or normal
logout is still needed before an external reader can see the new data.

### Automatic refresh versus file freshness

Login and logout capture immediately. Relevant gear, bag, quest, talent, skill,
zone, target, money, level, spellbook, durability, and combat-end events schedule
a capture about two seconds later. Events received while one capture is pending
are coalesced. Quest turn-ins and quest-data loads also trigger this path.

This version has **no periodic five-second timer and no visible snapshot panel**.
It does not automatically reload the UI. Adding a timer alone would not make
WoW flush SavedVariables during play.

Check `latest.capturedAt`, the section timestamps, the character identity, and
the recorded client build before using a snapshot. Reading a file now does not
make its contents current. `lastOutOfCombat` is a separately dated baseline;
never substitute it for current data without labeling its age. Coordinates use
a 0-to-1 scale. Cooldowns use the game's `clockSeconds`, not wall-clock time.

## Incomplete or restricted data

Check both a section's `status` and its diagnostics. A section marked `captured`
can contain unavailable fields. Missing values are unknown, not zero. Item names
and quest titles may be absent while the client's cache is incomplete. Collapsed
quest headers may limit active entries exposed by some client builds.

Completed quests are stored in `latest.sections.completedQuests.data`:

- `ids`: valid client-reported completed IDs, sorted and deduplicated.
- `titlesByID`: available cached names; missing names do not invalidate IDs.
- `queriedAt`, source API, counts, and `captureStatus`: evidence and quality.
- `absenceMeansNeverCompleted = false`.
- `lifetimeHistoryGuaranteed = false`.

The inner `captureStatus` can be `captured`, `partial`, `error`, `restricted`,
`unavailable`, or `empty_unconfirmed`. An empty or partial response never proves
that no quests were completed. An absent ID never proves that a quest was never
completed. Hidden, alternate, repeatable/resettable, and account-wide flags may
differ from a lifetime character record.

## Update, roll back, or uninstall

Before updating, close WoW normally and back up the existing addon folder and
your SavedVariables file somewhere private. Replace only the addon folder with
the newer source. Do not replace SavedVariables with another player's data.
Log in and follow the safe capture instructions above.

To roll back the code, close WoW and restore your previous addon folder. Keep
the current saved data unless you deliberately want to restore an older backup;
restoring old data can discard newer observations.

To uninstall, close WoW and remove the `AtlasSnapshot` addon folder. Saved data
is retained separately. If you also want to remove that data, remove this
addon's `AtlasSnapshot.lua` and `.lua.bak` from the account's SavedVariables
folder. Do not delete the entire WTF or SavedVariables folder.

## Privacy

Runtime snapshots contain character/realm names, location, inventory, quests,
and other gameplay details. Keep them private. This public source repository
contains synthetic test fixtures only. The ignore file helps exclude exports,
screenshots, backups, and credentials; review any files before sharing them.
Do not post a complete snapshot in a public issue. Report the addon version,
client build, and a redacted error description instead.

## Run the offline tests

Use Python 3 with a compatible [Lupa](https://pypi.org/project/lupa/) installation.
From the repository root on Windows:

```powershell
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements-dev.txt
.venv/Scripts/python tests/test_snapshot.py
```

On macOS/Linux, use `.venv/bin/python` for the last two commands. The test script
resolves the addon relative to its own location and does not read your game
installation or SavedVariables. It covers collection, event coalescing, failure
isolation, unavailable/restricted APIs, talent/skill data, timestamped baselines,
and incomplete completed-quest history.

## License

No license has been selected; this repository does not currently include a
license file. Lupa is a separately installed test dependency and is not bundled.
World of Warcraft and its associated names belong to their respective owners.
