# WoW Forever Character Snapshot

AtlasSnapshot is a local character snapshot addon for the **World of Warcraft:
Forever beta**, designed to give **ChatGPT** character data for gear comparisons,
quest planning, and explanations of your learned abilities. Instead of typing
out your equipment, stats, and quest log, you capture them in a local file and
choose how to share that file with ChatGPT.

**Atlas** is the nickname the project's creator uses for ChatGPT.
**AtlasSnapshot** is the addon/project brand, not a separate AI service or an
additional service you need to install or subscribe to.

**Version:** 0.3.0. **Declared client interface:** 16001.

The addon refreshes its data in game after relevant events. **It does not provide
a live external file feed or connect automatically to an AI/chat service.** WoW
writes its SavedVariables file when the interface reloads, the character logs
out, or the client exits normally. A crash may lose unsaved changes.

## Why this is useful

The project grew out of playing a paladin while talking with ChatGPT about what
to do next. Repeatedly reading equipment stats, learned abilities, and long quest
lists aloud interrupts play and makes it easy to miss a detail. A snapshot gives
the assistant a structured record to inspect before offering advice.

- **Less transcription:** share one saved snapshot instead of typing out every
  item, talent, and objective or narrating several menus.
- **More relevant advice:** ask about the gear actually equipped, abilities
  actually recorded, and objectives still in the captured quest log.
- **Smaller, clearer next steps:** give your play style and goal, then ask for
  one practical questing or gear decision at a time.
- **Visible limits:** timestamps and capture states help distinguish what the
  file establishes from stale, missing, or client-restricted information.

This reduces guessing; it does not make the assistant infallible or the data
live. The snapshot alone cannot establish the optimal route, current enemy
activity, auction prices, or undocumented server behavior. Those questions need
additional current evidence. Voice is an optional way to talk with ChatGPT;
the same workflow works through text, and voice is not an addon requirement.

## Do I need ChatGPT to run it?

No. A compatible WoW client and this addon are sufficient to collect and save
snapshots. ChatGPT is the intended analysis/advice workflow, but the saved data
can also be inspected manually or by another reader. The addon makes no OpenAI
API calls and requires no API key or ChatGPT subscription to operate.

To get advice from ChatGPT, use ChatGPT separately and provide the saved data.
Upload, analysis, and local-access features depend on the ChatGPT interface and
account you use; installing the addon does not enable or grant those features.
Python and Lupa are only dependencies for the optional offline tests.

## What it captures

The snapshot is a structured Lua SavedVariables file, not a screenshot or video.
It records the following information when the current client exposes it:

| Section | Snapshot contents | How it can help |
| --- | --- | --- |
| Character | Name, realm, class, race, faction, level, current/required/rested XP, money, health and mana, alive/dead and combat/resting states, and hearth location. | Establish which character the advice concerns and its progression or resource limits. |
| Location | Zone, subzone, map ID, map coordinates, and instance information. | Plan from the captured location; this is not continuous position tracking. |
| Equipment | Equipment slots, item links and cached names, quality, item/required levels, item stats, and current/maximum durability. | Compare equipped pieces and identify potential upgrade priorities. |
| Carried bags | Backpack and four bag slots, available slot counts, item links/names, quantities, and exposed cooldowns. | Check supplies, carried quest items, and available bag space. Bank storage is excluded. |
| Combat stats | Strength, Agility, Stamina, Intellect, Spirit, armor, attack power, weapon damage and speed, critical strike, dodge/parry/block chances, resistances, spell damage/healing bonuses, and mana regeneration. | Explain the captured build's strengths and tradeoffs; this is not a measured damage-per-second combat log. |
| Active quests | Quest IDs, titles, levels, log headers, objective text and progress, and completion flags where returned by the client. | Identify unfinished objectives and quests ready for turn-in without assuming they are still current after you continue playing. |
| Completed quests | Sorted, deduplicated completed quest IDs reported by the client, available cached titles, query time, counts, and capture quality. | Check evidence of earlier quest progress independently of the active log. This is not a guaranteed lifetime history. |
| Talents | Available trait configurations, trees, nodes, ranks, definitions and spell descriptions, committed talent currency, and staged-change indicators. | Discuss learned choices while distinguishing pending edits from committed talents. |
| Skills and professions | Exposed skill lines, ranks, maximum ranks, and profession information. | Understand weapon/profession training and crafting context where available. |
| Spellbook | Known spell names and ranks, client descriptions, cooldowns, power costs, and charges where available. | Ground ability advice in the captured spellbook and client version. |
| Auras, target, and actions | Player buffs/debuffs, basic current-target details, and action-bar slot references. | Provide context for a particular captured moment, not a live fight feed. |
| Group and PvP context | Group size, group/raid membership flags, PvP flags/zone type, movement speed, mounted/swimming state, and latency. | Explain surrounding conditions at capture time. |

Fields can be absent, restricted, uncached, or failed. Their inclusion in this
table describes what the addon attempts to collect, not a guarantee that every
field is available in every snapshot. See [Incomplete or restricted
data](#incomplete-or-restricted-data) before treating an absent value as evidence.

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

## Using a snapshot with ChatGPT

### Share a saved file or an excerpt

1. Follow [Capture and read an export](#capture-and-read-an-export), including a
   safe reload or normal logout to write the file.
2. Make a copy of the file from **SavedVariables** and review it for information
   you do not want to share. The addon code also has the name `AtlasSnapshot.lua`;
   the file inside `Interface/AddOns` is the program, not your character snapshot.
3. Attach the snapshot copy in a ChatGPT interface that supports the file type,
   or paste the relevant text into the chat. If the interface rejects `.lua`,
   you can make a plain-text `.txt` copy for sharing; leave WoW's original file
   and filename unchanged. File-upload availability and limits vary by surface.
4. Say you are playing **WoW Forever beta**, give your goal, and ask ChatGPT to
   check the captured character, build, timestamp, and section statuses first.

For example:

> Read this WoW Forever snapshot. Check its timestamp and unavailable sections,
> then recommend one next questing step based on the active objectives. Treat
> missing completed-quest IDs as unknown, not as proof I never did those quests.

The snapshot supplies character context, not a complete game database. Quest
locations, reward comparisons, and beta-specific mechanics may still need
verification. Later gear changes or quest progress require a newer saved file.

### Let an authorized local agent read it

If your setup includes an agent such as Codex with local file-reading tools, you
can grant it access to the saved snapshot and ask it to inspect that file. This
requires the relevant computer connection, tools, and filesystem permissions.
A regular ChatGPT chat does not gain access to your computer merely because
the addon is installed or because you mention a local file path.

Local access saves you the manual attachment step; it does **not** change when
WoW writes SavedVariables. The agent must still check the capture time and
report stale or partial data. There is no automatic upload, account linking,
background monitoring, or direct ChatGPT connection in this addon.

See the official OpenAI documentation for [working with
files](https://learn.chatgpt.com/docs/artifacts-viewer?surface=app) and [Codex
filesystem permissions](https://learn.chatgpt.com/docs/permissions). These are
separate application capabilities, not features supplied by AtlasSnapshot.

### Example workflow while playing

1. Play normally. The addon refreshes its in-game snapshot after relevant events
   such as gear changes or quest updates; that does not yet refresh the external
   saved file.
2. When you want advice, get somewhere safe and out of combat. Use `/reload`
   to save fresh data, or use a snapshot already written by a normal logout.
   Do not interrupt combat to refresh the file.
3. Share the saved snapshot with ChatGPT, or ask your authorized local agent to
   read it. Have it confirm the capture time, recorded level/location, and any
   unavailable sections before recommending a next step.
4. Give your goal and play style, through voice or text. For example, a melee
   paladin player might want damage while retaining useful healing and buffs.
   Ask one focused question, such as:
   - "Which equipped armor slot is the weakest fit for that play style?"
   - "Which active quest should I focus on next from the location in this save?"
   - "Is this new weapon better for me? Here is its tooltip."
5. For an item comparison, the snapshot supplies the **equipped** item baseline
   and items captured in your bags. A vendor item, auction listing, or unclaimed
   quest reward may not be in it. Provide the candidate's tooltip, relevant
   stats, or a screenshot separately, including the price if cost matters.
6. Continue playing and request the next step when needed. After meaningful gear
   or quest changes, repeat the safe save/read step so the advice uses updated
   evidence. Until then, the assistant should identify the file as an older save.

Ask for missing details to be identified rather than guessed. Completed quest
IDs can support a known completion; an absent ID cannot prove a quest was never
completed. Quest routing still needs verified locations and mechanics for the
correct game version.

Screenshots and any authorized screen-reading or computer-control tools are
separate capabilities. AtlasSnapshot does not capture your screen, listen to
voice chat, control the game, or provide a continuous live view to ChatGPT.

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
