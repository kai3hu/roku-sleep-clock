# Hourly media pulse asset

`hourly-black.mp4` is generated specifically for this project: 10 seconds,
320x180, 24 fps, H.264 Constrained Baseline / level 3.0, SDR BT.709,
8-bit YUV420 limited-range black. It has **no audio track** and contains
no network URL, personal information, image, watermark or third-party footage.

Regenerate it using an FFmpeg build with libx264:

```powershell
./scripts/generate-keep-running-media.ps1 -Ffmpeg C:/path/to/ffmpeg.exe
```

The clip is played once per hour, never looped. An independent app watchdog
stops it ten seconds after the first `playing` event. Startup is bounded to
20 seconds. Player errors wait until the next hourly attempt, not a retry loop.
It is layered below the scene's opaque black rectangle, outside the content
group hidden by app sleep. Playback cannot wake the app or reset its user-idle
clock. Actual remote input stops an active pulse immediately.

This is an **unverified experiment**, not an official keep-awake API. Playback
support for a bundled `pkg:/media/` URL and prevention of `EXIT_IDLE_AUTO_EXIT`
must both be checked on the target Roku. A successful ten-second playback
does not prove that the two-hour idle policy has been reset. Do not replace
the bundled clip with a remote stream as an automatic fallback.

The generated black clip is dedicated to the public domain under CC0 1.0:
https://creativecommons.org/publicdomain/zero/1.0/
FFmpeg itself is a local build tool and is not distributed in the Roku app.
