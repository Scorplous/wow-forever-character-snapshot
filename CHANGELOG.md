# Changelog

## 0.3.0 beta package

- Package the existing published 0.3.0 addon; no gameplay code changes.
- Includes character, gear, bags, stats, active quests, talents and skills where client APIs expose them.
- Completed-quest IDs remain separate from active quests, with explicit partial, restricted and unavailable states; absence is not proof of non-completion.
- Regression harness passed with simulated APIs. Full lifetime history and compatibility beyond the declared Forever beta interface 16001 are not established.
- Add a versioned ZIP, installation instructions and SHA-256 checksum.
