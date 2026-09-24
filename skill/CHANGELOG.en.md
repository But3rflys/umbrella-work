**update v1.0.2**

- **game data.** new `luatool data` command: abilities, items, heroes and units straight from the game files. the agent takes names, cast times, cooldowns and special values from there, not from memory
- **names.** check matches ability, item and hero names and special value keys against the game data and suggests the right one on a typo
- **log.** `check --log` shows the script's own lines and images that failed to load, not only errors
