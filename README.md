# Sleep Clock for Roku

Two minimal, sleep-friendly Roku screensavers are included.

![Clock, weekly agenda and weather preview](docs/agenda-preview.png)

Preview uses sample data and brighter text for readability. The actual screensaver uses dim gray text on pure black.

## Build from source

On Windows, run `./package-all.ps1` in PowerShell. The script generates menu artwork, creates a blank ignored `outlook-screensaver/source/config.brs` from the example if needed, and builds both ZIP packages in `dist`.

To validate the BrightScript logic, install Node.js and run:

```sh
npm install
npm test
npm run check
```

For a local developer checkout using a different package manager, the same `test` and `check` scripts are available from `package.json`.

## Versions

### Sleep Clock

- Pure black background
- Large 24-hour local time
- Dim gray text (`#181818`) on an explicitly opaque black background (`#000000`)
- Moves every 10 minutes to reduce OLED image retention
- No network access, ads, or sound

Package: `dist/night-clock-roku.zip`

### Sleep Clock + Agenda

- Displays the same large clock
- Clock, agenda and weather remain visible at all hours
- From 23:00 through 06:59, all text, charts and weather icons use an extra-dim palette (approximately `#0C0C0C`)
- From 07:00 to 22:59, the palette increases to `#242424`
- Automatically adjusts at the time boundary using the Roku device's local timezone; data continues refreshing every 5 minutes
- Displays events overlapping the rolling next 7 days, sorted by start time and labeled with weekday, date and local time
- Automatically pages every 20 seconds when there are more than 12 events; the layout stays in a fixed position
- Refreshes the calendar every 5 minutes while the screensaver is running
- Keeps the clock and agenda in a fixed position
- Displays current temperature plus the next 24 hourly Celsius forecasts for Tuscaloosa, AL 35406
- Shows 24 hourly temperature bars, the forecast low/high and 8 three-hourly temperature/icon samples
- Requests calendar and weather updates every 5 minutes while running
- Uses a private, read-only Outlook ICS link

Package: `dist/night-clock-outlook-roku.zip`

Weather data comes from [Open-Meteo](https://open-meteo.com/) under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Weather uses an approximate ZIP-area centroid (33.3388, -87.4676). Current conditions are model estimates; polling every 5 minutes does not mean the provider issues new model data every 5 minutes. Weather and calendar load independently. If a weather update fails, the last successful temperature remains visible with a delayed-data message.

Calendar recurrence support includes common daily, weekly, monthly and yearly rules, intervals, COUNT/UNTIL, BYDAY/BYMONTH/BYMONTHDAY, EXDATE/RDATE and RECURRENCE-ID overrides/cancellations. Embedded Outlook VTIMEZONE rules are used for source event times; display times follow the Roku device timezone. Advanced rules such as BYSETPOS, negative BYMONTHDAY, sub-day recurrence and THISANDFUTURE overrides are not supported. Recurrence expansion is bounded at 40,000 days for COUNT series. All-day events use local midnight boundaries. Set the Roku timezone correctly before testing.

## Logic validation

Developer tools can be installed under the ignored `.tools` directory. Run `node .tools/node_modules/brs/bin/cli.js outlook-screensaver/components/DisplaySchedule.brs outlook-screensaver/components/CalendarParser.brs outlook-screensaver/components/WeatherTask.brs tests/logic-tests.brs` for day/night brightness boundaries, calendar-window, recurrence, exception, timezone and 24-hour forecast tests. A successful run ends with `TEST_FAILURES= 0`.

## Connect the Outlook calendar

1. Open Outlook on the web and select **Calendar**.
2. Open **Settings > Calendar > Shared calendars**.
3. Under **Publish a calendar**, select the calendar and the desired detail level.
4. Select **Publish**, then copy the **ICS** link rather than the HTML link.
5. Copy `outlook-screensaver/source/config.brs.example` to `outlook-screensaver/source/config.brs` if it does not exist, then paste the link:

```brightscript
function GetCalendarIcsUrl() as string
    return "PASTE_YOUR_PRIVATE_ICS_LINK_HERE"
end function
```

6. Run `./package-all.ps1` to rebuild both packages.

The ICS link acts like a read-only password for the calendar. Do not share the configured source file or ZIP package. Some work or school accounts disable public calendar publishing through an administrator policy.

## Install on Roku

1. Enable Developer Mode on the Roku and note its IP address.
2. On a computer, open `http://ROKU_IP` and sign in to the Development Application Installer.
3. Select one of the ZIP packages from `dist` and choose **Install**.
4. On the Roku, open **Settings > Theme > Screensavers** and select the installed screensaver.

Developer sideloading normally supports one application at a time, so installing one package may replace the other.

## Menu names and previews

The screensaver list uses the names **Sleep Clock** and **Sleep Clock + Agenda**. Both packages include black-background menu thumbnails at HD and FHD sizes. Look in **Settings > Theme > Screensavers**, rather than the Roku Home screen.

Use the system **Preview** option in the screensaver detail menu when available to run the actual screensaver. A static preview image does not replace this system function.

`dist/previews` contains layout previews with sample events. Files ending in `-readable.png` use brighter text for viewing on a tablet. The agenda daytime preview uses `#242424`, and `sleep-clock-agenda-night.png` uses `#0C0C0C`; both show all information. The standalone clock preview uses `#181818`. These are layout simulations using a Windows font, not captures from a Roku TV. Event titles are sample text, not private Outlook data.

## Brightness

Roku applications cannot directly change the television backlight. If the clock is still too bright, lower the TV's backlight or picture brightness. To adjust the text brightness in the project, edit the `color` value in the corresponding SceneGraph XML file; values closer to `0x000000FF` are darker.
