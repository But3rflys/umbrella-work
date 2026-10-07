---
icon: list-ol
---

# Draft Helper

Draft hints and item builds: a window with heroes for every turn, the draft win chance and a build for your role against their picks.

<!-- versions:start -->
**Download:** [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.9/draft_helper.lua) — `draft-helper-v2.0.0-beta.9`, 2026-10-07

<details>

<summary>All versions</summary>

| Version | Date | File | Downloads |
| --- | --- | --- | --- |
| [`draft-helper-v2.0.0-beta.9`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.9) | 2026-10-07 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.9/draft_helper.lua) | 26 |
| [`draft-helper-v2.0.0-beta.8`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.8) | 2026-10-07 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.8/draft_helper.lua) | 0 |
| [`draft-helper-v2.0.0-beta.7`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.7) | 2026-10-06 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.7/draft_helper.lua) | 2 |
| [`draft-helper-v2.0.0-beta.6`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.6) | 2026-10-06 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.6/draft_helper.lua) | 2 |
| [`draft-helper-v2.0.0-beta.5`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.5) | 2026-10-06 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.5/draft_helper.lua) | 5 |
| [`draft-helper-v2.0.0-beta.4`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.4) | 2026-10-06 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.4/draft_helper.lua) | 7 |
| [`draft-helper-v2.0.0-beta.3`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.3) | 2026-10-06 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.3/draft_helper.lua) | 6 |
| [`draft-helper-v2.0.0-beta.2`](https://github.com/But3rflys/umbrella-work/releases/tag/draft-helper-v2.0.0-beta.2) | 2026-10-06 | [draft_helper.lua](https://github.com/But3rflys/umbrella-work/releases/download/draft-helper-v2.0.0-beta.2/draft_helper.lua) | 0 |

</details>
<!-- versions:end -->

## How it works

**Draft.** The window opens at hero selection in Captains Mode and All Pick. For every turn the script lists heroes: what to pick, what to ban, what the enemy may take. Under each hero you see who he is good against and with. The draft win chance sits on top. The list can be narrowed to one position, and in settings you choose whether heroes are picked for the game or for the lane against your lane opponents.

**Stats.** The data comes from OpenDota and refreshes once a day: 200 thousand ranked matches per rank (all, Legend+, Ancient+, Divine+) and Captains Mode matches from the last 90 days. The script downloads it from GitHub by itself.

**Build.** After the draft every hero of our team has a build for his role from 7000+ MMR games: starting items, then early, mid and late game. Below come answers to their draft: Skadi against healing, Nullifier against saves, Dust against invisibility. The Who beats who table shows how much each of our heroes moves the win chance against each enemy hero.

**In-game panel.** A small build panel opens next to the shop. Left click pins an item to quick buy, Shift + left click replaces quick buy, right click buys. Switch the role in the panel header and drag the panel by it.

**Training.** Outside a match you can run a training draft in Captains Mode or All Pick: the enemy turns are played by the script using its own hints, or by you.

{% hint style="info" %}
Mark your heroes in My hero pool: they go higher in the hints, or only they stay in the list.
{% endhint %}

## Install

1. Download `draft_helper.lua` from the latest release.
2. Put the file into the `scripts` folder next to your cheat.
3. Open **Scripts > Draft Helper** and turn on **Enable**.
4. Bind a key to **Open window**: without it the window can't be opened.
