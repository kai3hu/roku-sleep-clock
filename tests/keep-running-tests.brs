sub testKeepRunning()
    check(not appDefaults().keepRunning, "Hourly media pulse is opt-in")
    check(appNormalizeSettings({keepRunning:true}).keepRunning, "Keep-running opt-in survives registry normalization")
    check(not appNormalizeSettings({keepRunning:"true"}).keepRunning, "Malformed keep-running settings cannot opt in")
    initMockApp()
    m.appUptime.value = 7200000
    appKeepRunningTick()
    check(not m.appKeepActive and m.appKeepCount = 0, "No media plays while disabled, even after hours")

    initMockApp()
    m.appSettings.keepRunning = true
    appKeepRunningTick()
    check(not m.appKeepEnabled, "Unsaved preview cannot enable media playback")
    appCloseMenu(false)
    check(not m.appSettings.keepRunning, "Cancel discards an unsaved keep-running toggle")
    m.appCommitted.keepRunning = true
    m.appSettings.keepRunning = true
    appKeepRunningTick()
    check(m.appKeepNextAt = 3600 and not m.appKeepActive, "Enabling waits one hour instead of playing immediately")
    m.appUptime.value = 3599000
    appKeepRunningTick()
    check(not m.appKeepActive, "No playback before the exact hourly boundary")
    appSleep()
    m.appIdleClock.value = 100000
    m.telegramPageIndex = 3
    m.appUptime.value = 3600000
    appTick()
    check(m.appKeepActive and m.appKeepVideo.control = "play" and m.appKeepCount = 1, "Hourly boundary starts one short local playback")
    check(m.appSleeping and not m.content.visible and not m.appChrome.visible, "Pulse never wakes the black screen or chrome")
    check(m.appIdleClock.value = 100000 and m.telegramPageIndex = 3 and m.appCurrent = "dashboard", "Pulse cannot reset user-idle time or change the reading position")
    appKeepRunningTick()
    check(m.appKeepCount = 1, "An active pulse cannot overlap or restart each tick")
    m.appUptime.value = 3602000
    m.appKeepVideo.state = "playing"
    onAppKeepRunningState()
    m.appUptime.value = 3611000
    appKeepRunningTick()
    check(m.appKeepActive, "Playback duration is measured from playing, not from startup")
    m.appUptime.value = 3612000
    appKeepRunningTick()
    check(not m.appKeepActive and m.appKeepCompleted = 1 and m.appKeepVideo.control = "stop", "Playback is forcibly stopped after ten seconds")
    check(m.appKeepVideo.content = invalid and m.appKeepNextAt = 7200, "Playback releases its content and retains an hourly cadence")
    m.appUptime.value = 7199000
    appKeepRunningTick()
    check(not m.appKeepActive, "No continuous or rapid media loop between hourly pulses")
    m.appUptime.value = 7200000
    appKeepRunningTick()
    check(m.appKeepActive and m.appKeepCount = 2, "The second hourly pulse is scheduled independently of display sleep")
    onKeyEvent("right",true)
    check(not m.appKeepActive and not m.appSleeping and m.appCurrent = "dashboard", "Real input stops playback and only wakes the same page")
    onKeyEvent("right",false)

    m.appUptime.value = 10800000
    appKeepRunningTick()
    m.appKeepVideo.state = "error"
    m.appKeepVideo.errorCode = -3
    onAppKeepRunningState()
    check(not m.appKeepActive and m.appKeepStatus.Instr("failed") >= 0, "Media errors stop cleanly without hiding the app")
    m.appUptime.value = 10801000
    appKeepRunningTick()
    check(not m.appKeepActive and m.appKeepCount = 3, "Media failure does not trigger a rapid retry")
    m.appUptime.value = 14400000
    appKeepRunningTick()
    m.appUptime.value = 14420000
    appKeepRunningTick()
    check(not m.appKeepActive and m.appKeepStatus.Instr("Failed to start") >= 0, "Buffering without a playing event has a bounded startup timeout")

    appTestKeepRunning()
    m.appKeepVideo.state = "playing"
    onAppKeepRunningState()
    m.appKeepVideo.state = "finished"
    onAppKeepRunningState()
    check(not m.appKeepActive and m.appKeepCompleted = 2, "Natural clip completion releases the player without looping")
    appTestKeepRunning()
    m.appSettings.keepRunning = false
    appKeepRunningTick()
    check(m.appKeepActive, "Unsaved disabled preview cannot change the committed experiment")
    m.appCommitted.keepRunning = false
    appApplyKeepRunning()
    check(not m.appKeepActive and not m.appKeepEnabled and m.appKeepVideo.control = "stop", "Saving Off stops an active pulse immediately")
    count = m.appKeepCount
    appTestKeepRunning()
    check(m.appKeepCount = count and m.appMenuNote.Instr("Save first") >= 0, "Manual test cannot bypass explicit saved opt-in")
    check(not onKeyEvent("back",true), "Back on Dashboard still exits normally after a pulse")

    initMockApp()
    m.appCommitted.keepRunning = true
    m.appSettings.keepRunning = true
    m.appSettings.clockStandby = true
    appApplyKeepRunning()
    appSleep()
    for hour = 1 to 8
        m.appUptime.value = hour * 3600000
        appTick()
        check(m.appKeepActive and m.appKeepCount = hour, "Simulated overnight cadence has exactly one start per hour")
        check(m.appSleeping and m.content.visible and not m.appChrome.visible and not m.today.visible, "Hourly pulse preserves clock standby without restoring agenda or chrome")
        m.appKeepVideo.state = "playing"
        onAppKeepRunningState()
        m.appUptime.value = hour * 3600000 + 10000
        appTick()
        onAppKeepRunningState()
        check(not m.appKeepActive and m.appKeepCompleted = hour, "Completed pulse cannot be counted twice by a late callback")
    end for
end sub
