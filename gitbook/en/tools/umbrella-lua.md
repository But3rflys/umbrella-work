---
icon: code
---

# umbrella-lua

A Claude Code and Codex skill: the agent writes and fixes Lua scripts for Umbrella by one set of rules. Every script gets the same menu layout and built-in en/ru localization.

<!-- versions:start -->
**Download:** [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.1/umbrella-lua.zip) — `umbrella-lua-v1.0.1`, 2026-09-23

<details>

<summary>All versions</summary>

| Version | Date | File | Downloads |
| --- | --- | --- | --- |
| [`umbrella-lua-v1.0.1`](https://github.com/But3rflys/umbrella-work/releases/tag/umbrella-lua-v1.0.1) | 2026-09-23 | [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.1/umbrella-lua.zip) | 0 |
| [`umbrella-lua-v1.0.0`](https://github.com/But3rflys/umbrella-work/releases/tag/umbrella-lua-v1.0.0) | 2026-09-23 | [umbrella-lua.zip](https://github.com/But3rflys/umbrella-work/releases/download/umbrella-lua-v1.0.0/umbrella-lua.zip) | 7 |

</details>
<!-- versions:end -->

## What it does

* writes new scripts with the standard menu and qLocalizer built in;
* brings someone else's script to the rules: flat keys without dots, en and ru dictionaries, the menu wrapper;
* checks syntax exactly like Lua 5.4 and matches calls against the Umbrella API reference;
* shows the script's errors from `debug.log` after a scripts reload.

## Install

1. Download `umbrella-lua.zip` from the latest release and unzip it.
2. Put the `umbrella-lua` folder into `%USERPROFILE%\.claude\skills\` (Claude Code) or `%USERPROFILE%\.agents\skills\` (Codex).
3. Restart the agent.

{% hint style="info" %}
Windows 10 or 11 is required. No Python or Lua needed: `luatool.exe` runs on the built-in .NET Framework 4.
{% endhint %}

## How to use

Ask the agent to write or fix an Umbrella script and the skill kicks in by itself. To call it explicitly: `/umbrella-lua` in Claude Code, `$umbrella-lua` in Codex. It works best when the agent is opened in your cheat's `scripts` folder, so it sees your scripts right away.

## Updating

Once a day `luatool.exe` checks the releases on GitHub. When a new version is out, the agent tells you and gives the link. To update, replace the whole `umbrella-lua` folder. Set `UMBRELLA_LUA_NO_UPDATE=1` to turn the check off.

`luatool.exe` is built by GitHub Actions from its sources. The sources and build steps are [in the repository](https://github.com/But3rflys/umbrella-work/tree/main/skill).

<!-- changelog:start -->
## Changelog

**update v1.0.1**

* **check.** new checks
* **migrate.** safer
* **output.** shorter
* **drawing.** FontAwesome glyphs
<!-- changelog:end -->
