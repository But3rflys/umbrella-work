---
icon: music
---

# MusicUI

A player overlay in game: track, cover art, equalizer and lyrics. It comes in two parts — the Lua overlay and the `MusicUI.exe` app.

<!-- versions:start -->
**Download:** [MusicUI.rar](https://github.com/But3rflys/umbrella-work/releases/download/musicui-v1.0.7/MusicUI.rar) — `musicui-v1.0.7`, 2026-09-20

<details>

<summary>All versions</summary>

| Version | Date | File | Downloads |
| --- | --- | --- | --- |
| [`musicui-v1.0.7`](https://github.com/But3rflys/umbrella-work/releases/tag/musicui-v1.0.7) | 2026-09-20 | [MusicUI.rar](https://github.com/But3rflys/umbrella-work/releases/download/musicui-v1.0.7/MusicUI.rar) | 70 |

</details>
<!-- versions:end -->

## How it works

The app reads what is playing in Spotify or the Windows system player and feeds the overlay. The overlay draws the track card with cover art and progress, an equalizer driven by the real audio, and lyrics that scroll along. Playback can be controlled straight from the overlay.

{% hint style="warning" %}
Without `MusicUI.exe` running the overlay stays empty: the track data comes from the app.
{% endhint %}

## Install

1. Download the archive from the latest release and unzip it anywhere.
2. Put `MusicUI.lua` into the `scripts` folder next to your cheat.
3. Run `MusicUI.exe` and follow the prompts in the console.
4. Open **Scripts** in the cheat menu and turn the overlay on.

The console language follows your Windows language. Force it with `MusicUI.exe --lang en` or `--lang ru`.

## Audio sources

<table><thead><tr><th width="230">Source</th><th>What you get</th></tr></thead><tbody><tr><td>Spotify</td><td>Track, artist, cover art, progress, playback controls.</td></tr><tr><td>Windows system player</td><td>The same for any player that reports itself to Windows.</td></tr></tbody></table>
