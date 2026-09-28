---
icon: layer-group
---

# Auto Stack

Auto stacking for Kunkka and Invoker: at the right second of every minute the script throws Torrent or Tornado on a camp so the creeps are above the camp when it spawns.

<!-- versions:start -->
**Download:** [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.1.0/auto_stack.lua) — `auto-stack-v1.1.0`, 2026-09-28

<details>

<summary>All versions</summary>

| Version | Date | File | Downloads |
| --- | --- | --- | --- |
| [`auto-stack-v1.1.0`](https://github.com/But3rflys/umbrella-work/releases/tag/auto-stack-v1.1.0) | 2026-09-28 | [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.1.0/auto_stack.lua) | 13 |
| [`auto-stack-v1.0.0`](https://github.com/But3rflys/umbrella-work/releases/tag/auto-stack-v1.0.0) | 2026-09-27 | [auto_stack.lua](https://github.com/But3rflys/umbrella-work/releases/download/auto-stack-v1.0.0/auto_stack.lua) | 14 |

</details>
<!-- versions:end -->

## How it works

**Kunkka.** The cast second is tuned for every camp on the map; the script accounts for ping and places Torrent to hit every creep in the camp.

**Invoker.** Tornado bobs the creeps up and down, so the script works out the moment when every hit creep is above the camp. Range and air time come from the Quas and Wex levels. Turn on **Invoke Tornado** and the script invokes it right before the throw.

It can stack on its own or on a key: the nearest camp or the camp under the cursor. Rings hang over the camps, click one to turn that camp on or off. The chosen camp shows a countdown to the cast, and after the minute whether it stacked and why not.

{% hint style="warning" %}
The stack fails if a hero or another unit stands in the camp, or if not every creep was hit.
{% endhint %}

## Install

1. Download `auto_stack.lua` from the latest release.
2. Put the file into the `scripts` folder next to your cheat.
3. Open **Heroes > Kunkka** or **Heroes > Invoker** and turn on **Auto Stack**.

<!-- changelog:start -->
## Changelog

**update v1.1.0**

* **invoker.** stacks camps with tornado, can invoke it right before the throw
* **startup.** the script didn't start for some users, fixed
<!-- changelog:end -->
