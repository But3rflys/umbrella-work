---
icon: route
---

# Lane Pull

One key and your dominated creep grabs the enemy wave and drags it right to you.

<!-- versions:start -->
**Download:** [lane_pull.lua](https://github.com/But3rflys/umbrella-work/releases/download/lane-pull-v1.0.4/lane_pull.lua) — `lane-pull-v1.0.4`, 2026-09-20

<details>

<summary>All versions</summary>

| Version | Date | File | Downloads |
| --- | --- | --- | --- |
| [`lane-pull-v1.0.4`](https://github.com/But3rflys/umbrella-work/releases/tag/lane-pull-v1.0.4) | 2026-09-20 | [lane_pull.lua](https://github.com/But3rflys/umbrella-work/releases/download/lane-pull-v1.0.4/lane_pull.lua) | 110 |
| [`lane-pull-v1.0.3`](https://github.com/But3rflys/umbrella-work/releases/tag/lane-pull-v1.0.3) | 2026-09-20 | [lane_pull.lua](https://github.com/But3rflys/umbrella-work/releases/download/lane-pull-v1.0.3/lane_pull.lua) | 7 |

</details>
<!-- versions:end -->

## How it works

The first key press starts the pull, the second cancels it. The creep walks to the wave, hooks it and leads it back: it picks the meeting spot itself, walks around neutral camps and enemy heroes, and waits in the trees. If the wave sits in the fog, it waits by the spawn timer.

Creeps taken with Helm of the Dominator and similar items can pull; you tick who is allowed to in the menu. Between two candidates the healthy one goes and the hurt one stays home.

{% hint style="warning" %}
If an enemy hero gets right up close, or the creep drops below the HP threshold, the pull is called off and the creep runs back to you.
{% endhint %}

## Install

1. Download `lane_pull.lua` from the latest release.
2. Put the file into the `scripts` folder next to your cheat.
3. Open **Scripts** in the cheat menu and turn it on.

<!-- changelog:start -->
## Changelog

**update v1.0.4**

* **pull.** improved creep pull logic
<!-- changelog:end -->
