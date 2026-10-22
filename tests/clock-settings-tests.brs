sub testClockAndSettings()
    check(appClockFonts().Count() = 5, "Clock picker includes four new typefaces and the original System face")
    for each face in appClockFonts()
        check(appNormalizeSettings({clockFont:face}).clockFont = face, "Each font is validated and persists through normalization")
    end for
    check(appNormalizeSettings({clockFont:"bad",clockAnimation:"bad"}).clockFont = "System", "Old/corrupt settings keep a safe original-font fallback")
    check(appNormalizeSettings({clockAnimation:"Off",clockSize:140,hourFormat:"12h"}).clockSize = 140, "Clock fields survive migration from the Layout category")
    check(appClockTime(0,9,"12h").digits = "12:09" and appClockTime(0,9,"12h").period = "AM", "12-hour midnight uses a separate AM label")
    check(appClockTime(12,0,"12h").period = "PM" and appClockTime(23,5,"24h").digits = "23:05", "Noon and 24-hour formats stay correct")
    for each face in appClockFonts()
        width = appClockTextWidth("12:59",face,140)
        check(width + 124 < 760, "Largest font plus separate AM/PM fits the standby safe box")
    end for

    initMockApp()
    m.clock.text = "23:48"
    m.appClockBase = [50,70]
    appSetClockText("23:49")
    check(m.clockFx.control = "start" and m.clockPrevious.text = "23:48", "Minute changes start a native transition with the prior time")
    check(m.clockIn.keyValue[0] = 0 and m.clockIn.keyValue[1] = 1 and m.clockOut.keyValue[0] = 1, "Transition alpha stays bounded without a brightness boost")
    m.clockFx.control = "unchanged"
    appSetClockText("23:49")
    check(m.clockFx.control = "unchanged", "Second-by-second clock ticks cannot replay the minute transition")
    m.appSettings.clockAnimation = "Slide"
    appSetClockText("23:50")
    check(m.clockLift.keyValue[0][1] = 78 and m.clockDrop.keyValue[1][1] = 62, "Slide moves only eight pixels around the clock baseline")
    m.appSettings.clockAnimation = "Off"
    appSetClockText("23:51")
    check(m.clockFx.control = "stop" and m.clock.opacity = 1 and m.clockPrevious.opacity = 0, "Off restores a clean static clock")
    m.appSettings.clockAnimation = "Fade"
    m.content.visible = false
    appSetClockText("23:52")
    check(m.clockFx.control = "stop", "A fully black screen cannot start a visible clock transition")
    m.content.visible = true
    m.appMenu = "Clock"
    appSetClockText("23:53")
    check(m.clockFx.control = "stop", "Settings previews never animate the underlying page clock")
    m.appMenu = ""
    m.clock.translation = [470,330]
    m.appSettings.clockFont = "Digital"
    appClockStyle()
    check(m.appClockBase[0] = 470 and m.appClockBase[1] = 330, "Changing font preserves the chosen layout's clock anchor")
    check(m.clock.font.uri = "pkg:/fonts/DSEG7Classic-Light.ttf", "The digital clock uses the bundled static face")

    initMockApp()
    m.appSettings.clockStandby = true
    m.appSettings.clockSize = 140
    m.appSettings.margin = 90
    m.appSettings.layout = "Minimal"
    m.appCommitted = appNormalizeSettings(m.appSettings)
    m.clock.text = "12:59"
    m.clockPeriod.text = "PM"
    m.appUptime.value = 123000
    m.telegramPageIndex = 7
    appSleep()
    initial = clockPointKey(m.clock.translation)
    check(m.appSleeping and m.content.visible and not m.today.visible and not m.appChrome.visible, "Clock standby hides agenda and chrome while showing only the clock")
    m.appUptime.value = 722000
    appStandbyClockTick()
    check(clockPointKey(m.clock.translation) = initial, "Standby position stays fixed for the full first 599 seconds")
    appApplyLayout()
    check(clockPointKey(m.clock.translation) = initial and m.appClockSleepAt = 123, "Data-refresh layout passes cannot reset the standby position or its ten-minute deadline")
    m.appUptime.value = 723000
    appStandbyClockTick()
    check(clockPointKey(m.clock.translation) <> initial and m.appClockSleepSlot = 1, "Clock moves at exactly ten minutes after entering standby")
    seen = {}
    for slot = 0 to 8
        point = appStandbyClockPosition(slot)
        seen[clockPointKey(point)] = true
        check(point[0] >= 100 and point[0] + 760 <= 1820 and point[1] >= 80 and point[1] + 185 <= 1000, "Every standby position respects overscan margins at the largest clock size")
    end for
    check(seen.Count() = 9, "A full movement cycle uses nine distinct safe positions")
    idle = m.appIdleClock.value
    m.appUptime.value = 1923000
    appStandbyClockTick()
    check(m.appClockSleepSlot = 3 and m.appIdleClock.value = idle and m.telegramPageIndex = 7, "A delayed tick catches up without faking input or changing article position")
    onKeyEvent("right",true)
    check(not m.appSleeping and m.appCurrent = "dashboard" and m.telegramPageIndex = 7, "First wake key restores the same page without navigating")
    check(m.content.translation[0] <> 0 and m.clock.translation[0] = 300, "Wake restores normal Minimal layout instead of leaving the standby anchor")
    m.appSettings.clockSize = 90
    appApplyLayout()
    check(m.clock.font.size = 90, "Clock size choice also applies to Minimal layout")

    initMockApp()
    appSleep()
    initial = clockPointKey(m.clock.translation)
    m.appUptime.value = 1800000
    appStandbyClockTick()
    check(not m.content.visible and clockPointKey(m.clock.translation) = initial, "Full black idle stays black and does not move or reveal a clock")

    initMockApp()
    appOpenMenu("Settings")
    appMenuKey("OK")
    check(m.appMenu = "Clock", "Clock is one OK away from the settings home")
    appMenuKey("OK")
    check(m.appPicker <> invalid and m.appPicker.row.key = "clockFont", "OK opens the complete font picker instead of cycling blindly")
    appMenuKey("down")
    check(m.appSettings.clockFont = "Roboto Mono" and m.appCommitted.clockFont = "System", "Font choices preview immediately without modifying committed settings")
    appMenuKey("back")
    check(m.appPicker = invalid and m.appSettings.clockFont = "System", "Back cancels just the current font choice")
    appMenuKey("OK")
    appMenuKey("down")
    appMenuKey("OK")
    appMenuKey("back")
    appMenuKey("back")
    check(m.appConfirm <> invalid and m.appCommitted.clockFont = "System", "Exiting with changes asks instead of silently discarding the new font")
    appMenuKey("back")
    check(m.appConfirm = invalid and m.appMenu = "Settings", "Back from the save prompt keeps editing")
    appMenuKey("play")
    check(m.appMenu = "" and m.appCommitted.clockFont = "Roboto Mono" and m.appSettingsDirty, "One Play/Pause press explicitly saves and closes from any settings page")

    initMockApp()
    appOpenMenu("Settings")
    m.appSettings.keepRunning = true
    m.appMenu = "Status"
    appMenuAction("testKeepRunning")
    check(m.appConfirm <> invalid and not m.appKeepActive, "Test with an unsaved switch shows a prominent save-and-test confirmation")
    appMenuKey("OK")
    check(m.appCommitted.keepRunning and m.appKeepActive, "Save and test explicitly commits opt-in and starts a single pulse")
    onKeyEvent("back",true)
    check(not m.appKeepActive, "Real remote input still cancels a settings test pulse")
    m.appMenu = "Clock"
    m.appSettings.clockFont = "Lora"
    m.appMenuZone = "footer"
    m.appFooterIndex = 1
    appMenuKey("OK")
    check(m.appMenu = "" and m.appCommitted.clockFont = "System" and m.appCommitted.keepRunning, "Explicit Discard restores the saved font without disabling already-saved hourly playback")
end sub

function clockPointKey(point as object) as string
    return point[0].ToStr() + "," + point[1].ToStr()
end function
