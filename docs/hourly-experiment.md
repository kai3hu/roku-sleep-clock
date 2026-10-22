# Hourly keep-running experiment (2.0.2)

Update for 2.1.0: playback timing and bounds are unchanged. The owner reported
more than three hours without an exit; console checks confirmed repeated
completed pulses. This is an initial result on one TV, not universal proof.
No additional long-running monitoring was requested. The new settings UI uses
**Keep running**, **Save & close**, and a save/enable confirmation before a
manual test when necessary; see [the current app guide](app-guide.md).

## Evidence and limits

The target TCL 55R635 on Roku OS 15.3.4 build 2303 reported
`EXIT_IDLE_AUTO_EXIT` after `TimeBase(7200860 ms)`, approximately two hours.
This is evidence of a system idle exit, not a BrightScript crash or a claim
that the TV hardware is faulty. Version 2.0.1's app black screen only hides
content; it does not reset Roku's system activity policy.

There is no documented general-purpose keep-awake switch in the current
`ifAppManager` interface. `UpdateLastKeypressTime` and in-app ECP are
prohibited by Roku's static-analysis rules. The experiment does not use them.

- Exit reasons: https://developer.roku.com/dev/docs/dev-environment
- Current app interface: https://developer.roku.com/dev/docs/ifappmanager
- Playback/loop/screensaver fields: https://developer.roku.com/dev/docs/video
- Restrictions: https://developer.roku.com/dev/docs/static-analysis-tool
- Screensaver policy: https://developer.roku.com/dev/docs/certification

**Hypothesis, not a verified fix:** a short media playback every hour might
reset the system's idle assessment. The Video API's documented screensaver
suppression is not a documented exemption from `EXIT_IDLE_AUTO_EXIT`.
Bundled-file playback must also be verified on the actual firmware.

## Build, install and opt in

1. Run `./package-dashboard.ps1 -Experimental`.
2. Upload `dist/sleep-dashboard-experimental-roku.zip` in the developer
   installer and choose **Replace with zip**. This replaces the one developer
   app slot; it does not create a second installed app. The local stable
   `dist/sleep-dashboard-roku.zip` is not overwritten by this build command.
3. Open Sleep Dashboard, press `*`, then **Settings > Display**.
4. Turn **Keep running (Experimental; 10 s every hour)** On.
5. Return to Settings and choose **Save and return**. Preview/Cancel does not
   enable playback. The first automatic pulse is one hour after enabling or
   reopening the app, not immediately on launch.
6. Optionally open **Settings > Status > Test keep-running pulse now** to
   check basic playback. Do not repeatedly press keys during the test: real
   remote input immediately stops the pulse. The status footer updates on
   playback state changes. Consult console port 8085 for `[KeepRunning]` logs.

The local ZIP can contain a private bundled Outlook link. Do not upload it
to a public repository, release, cloud scan or other person. Git excludes it.

## Behavior and safeguards

- Fixed cadence: 3600 seconds, one ten-second clip, `loop=false`.
- Playback lives under the permanently opaque black background. Existing UI,
  dim colors, menus, overlays, black screen and clock standby stay unchanged.
- No audio track; mute is additionally set. No remote media fallback.
- The player never receives focus; controls are disabled. Real input cancels
  playback before the app handles wake/navigation, and Home/Power still exit
  or change the system state normally. The app never relaunches itself.
- Twenty-second startup timeout; ten-second watchdog from the first playing
  event. Natural completion releases content. An error or interruption does
  not rapidly retry; the next automatic attempt is still an hour later.
- Page/agenda timers can sleep while the media schedule continues. Media
  callbacks never change the user-idle clock, reader position, rotation,
  wake-key handling or brightness. Only committed settings enable playback.
- Saving Off cancels any active pulse. No change to TV power/network settings.
- A manual test is explicit user activity in the menu, but the playback itself
  is not treated as a remote key and does not reset the app idle timer.

Potential drawbacks include decoder resource use, extra power consumption,
firmware-specific flash or Options-key behavior, and store policy issues.
Neither zero flicker nor store approval is promised by desktop tests.

## Device acceptance checklist (not yet performed)

1. Manual test: observe `Playing` then `Completed` after about ten seconds;
   verify no visible flash, player controls, sound, focus loss or page jump.
   If local playback errors, disable the experiment and retain the log code.
2. Real input during a pulse: first key from app black screen only wakes;
   a new key navigates. Settings, keyboard, Play/Pause, Back and Home remain
   usable. Check both normal black screen and clock standby.
3. Fresh launch with On saved: leave all remote controls untouched for more
   than three hours. Confirm playback near each hourly boundary, no
   `EXIT_IDLE_AUTO_EXIT`, intact live data and successful wake afterward.
   Read-only ECP queries/log connections do not simulate keys.
4. If the three-hour test passes, repeat for eight hours, crossing the
   separate four-hour system bandwidth/power boundaries. Record those
   settings instead of silently changing them. Verify background remains
   black, no playback sound/flash and no growing memory use.
5. Saving Off during playback stops it; canceling an unsaved toggle does not
   change committed behavior. Reopen to check saved settings.

Desktop checks cover scheduling, timeouts, opt-in normalization, save/cancel,
black-screen isolation, key cancellation and clip completion/error. They do
**not** validate Roku's decoder, system screensaver or idle-exit policy.

To roll back, reinstall the retained 2.0.1 ZIP. The experimental switch is
ignored by older code; other saved settings retain their existing schema.
