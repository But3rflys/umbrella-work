---
icon: chess
---

# Draft Helper

A draft helper: who to pick and who to ban by counters and synergy, a ready item build against the enemy pick and an in-game build panel.

<!-- versions:start -->
**Download:** [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.5.0/draft_helper.lua) — `draft-helper-v1.5.0`, 2026-10-02

<details>

<summary>All versions</summary>

| Version | Date | File | Downloads |
| --- | --- | --- | --- |
| [`draft-helper-v1.5.0`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.5.0) | 2026-10-02 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.5.0/draft_helper.lua) | 118 |
| [`draft-helper-v1.4.2`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.4.2) | 2026-10-01 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.4.2/draft_helper.lua) | 4 |
| [`draft-helper-v1.4.1`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.4.1) | 2026-10-01 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.4.1/draft_helper.lua) | 1 |
| [`draft-helper-v1.4.0`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.4.0) | 2026-10-01 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.4.0/draft_helper.lua) | 65 |
| [`draft-helper-v1.2.8`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.8) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.8/draft_helper.lua) | 112 |
| [`draft-helper-v1.2.7`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.7) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.7/draft_helper.lua) | 57 |
| [`draft-helper-v1.2.6`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.6) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.6/draft_helper.lua) | 24 |
| [`draft-helper-v1.2.5`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.5) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.5/draft_helper.lua) | 1 |
| [`draft-helper-v1.2.4`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.4) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.4/draft_helper.lua) | 1 |
| [`draft-helper-v1.2.3`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.3) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.3/draft_helper.lua) | 1 |
| [`draft-helper-v1.2.2`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.2) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.2/draft_helper.lua) | 4 |
| [`draft-helper-v1.2.1`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.1) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.1/draft_helper.lua) | 1 |
| [`draft-helper-v1.2.0`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.2.0) | 2026-09-30 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.2.0/draft_helper.lua) | 2 |
| [`draft-helper-v1.1.1`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.1.1) | 2026-09-29 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.1.1/draft_helper.lua) | 2 |
| [`draft-helper-v1.1.0`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v1.1.0) | 2026-09-29 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v1.1.0/draft_helper.lua) | 1 |

</details>
<!-- versions:end -->

## Draft window

Opens on a key or by itself at hero selection. Shows picks and bans of both teams and suggests who to pick and who to ban. Advice comes from counters to the enemies and synergy with allies, based on OpenDota stats: ranked matches of the chosen rank or Captains Mode.

* **In turns** for Captains Mode: all 24 steps in order.
* **Free** for All Pick, Turbo and ranked: picks and bans fill in by themselves.
* Positions 1 to 5 for your team and a position filter.
* Draft win chance.

## Draft summary

Once every hero is picked, a matchup table shows up along with an item build for the chosen hero. The build comes from pro matches of the hero on its position and adapts to the enemy pick. Switch the position with the buttons under the build.

## In-game build panel

Shows the next item, how much gold is missing and the purchase queue. If an enemy buys Butterfly, Ghost Scepter and the like, the panel suggests an item that helps against it. Three looks: Strip, List, Pill. Click an item to add it to your quick buy.

{% hint style="info" %}
All settings live inside the window, behind the gear in its header. When a new version is out, an Update button shows up in the window header.
{% endhint %}

## Install

1. Download `draft_helper.lua` from the latest release.
2. Put the file into the `scripts` folder next to your cheat.
3. Open **Scripts > Draft Helper**, turn the script on and bind **Open window**.
