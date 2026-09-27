---
icon: layer-group
---

# Auto Stack

Auto stacking for Kunkka: at the right second of every minute the script throws Torrent on a camp so the creeps are in the air when the camp spawns.

<!-- versions:start -->
**Download:** [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.0.0/auto_stack.lua) — `auto-stack-v1.0.0`, 2026-09-27

<details>

<summary>All versions</summary>

| Version | Date | File | Downloads |
| --- | --- | --- | --- |
| [`auto-stack-v1.0.0`](https://github.com/But3rflys/umbrella-work/releases/tag/auto-stack-v1.0.0) | 2026-09-27 | [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.0.0/auto_stack.lua) | 0 |

</details>
<!-- versions:end -->

## How it works

The cast second is tuned for every camp on the map; the script accounts for ping and picks the Torrent spot that hits every creep in the camp. It can stack on its own or on a key: the nearest camp or the camp under the cursor. Rings hang over the camps, click one to turn that camp on or off. The chosen camp shows a countdown to the cast, and after the minute whether it stacked and why not.

{% hint style="warning" %}
The stack fails if a hero or another unit stands in the camp, or if Torrent missed some of the creeps.
{% endhint %}

## Install

1. Download `auto_stack.lua` from the latest release.
2. Put the file into the `scripts` folder next to your cheat.
3. Open **Heroes > Kunkka** and turn on **Auto Stack**.
