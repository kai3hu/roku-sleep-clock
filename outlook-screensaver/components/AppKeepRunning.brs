' Experimental media pulse. Never treats playback as user input or wakes the UI.
sub appInitKeepRunning()
    appResetKeepRunningState()
    m.appKeepContent = CreateObject("roSGNode", "ContentNode")
    m.appKeepContent.url = "pkg:/media/hourly-black.mp4"
    m.appKeepContent.streamFormat = "mp4"
    m.appKeepVideo = CreateObject("roSGNode", "Video")
    m.appKeepVideo.id = "hourlyMediaPulse"
    m.appKeepVideo.width = 320
    m.appKeepVideo.height = 180
    m.appKeepVideo.enableUI = false
    m.appKeepVideo.mute = true
    m.appKeepVideo.loop = false
    m.appKeepVideo.enableScreenSaverWhilePlaying = false
    m.appKeepVideo.disableScreenSaver = true
    ' A visible video under the opaque background, not an invisible decoder.
    ' The background, text, keyboard and menus stay above it at all times.
    m.top.insertChild(m.appKeepVideo, 0)
    m.appKeepVideo.ObserveField("state", "onAppKeepRunningState")
end sub

sub appResetKeepRunningState()
    m.appKeepEnabled = false
    m.appKeepActive = false
    m.appKeepNextAt = 0
    m.appKeepStartedAt = 0
    m.appKeepPlayingAt = -1
    m.appKeepCount = 0
    m.appKeepCompleted = 0
    m.appKeepStatus = "Off (experimental)"
end sub

sub appApplyKeepRunning()
    enabled = m.appCommitted.keepRunning = true
    if enabled = m.appKeepEnabled then return
    m.appKeepEnabled = enabled
    if enabled
        m.appKeepNextAt = int(m.appUptime.TotalMilliseconds() / 1000) + 3600
        appSetKeepRunningStatus("Scheduled: 10 s every 60 min (unverified)")
        print "[KeepRunning] Enabled; first pulse in 3600 s; not yet device-verified."
    else
        appStopKeepRunning("Off (experimental)")
        print "[KeepRunning] Disabled."
    end if
end sub

sub appKeepRunningTick()
    appApplyKeepRunning()
    if not m.appKeepEnabled then return
    now = int(m.appUptime.TotalMilliseconds() / 1000)
    if m.appKeepActive
        if m.appKeepPlayingAt >= 0
            if now - m.appKeepPlayingAt >= 10 then appCompleteKeepRunning("10 s limit")
        else if now - m.appKeepStartedAt >= 20
            appStopKeepRunning("Failed to start; retry in 60 min")
            print "[KeepRunning] Start timeout; no rapid retry."
        end if
    else if now >= m.appKeepNextAt
        appStartKeepRunning()
    end if
end sub

sub appStartKeepRunning()
    if not m.appKeepEnabled or m.appKeepActive then return
    now = int(m.appUptime.TotalMilliseconds() / 1000)
    m.appKeepActive = true
    m.appKeepStartedAt = now
    m.appKeepPlayingAt = -1
    m.appKeepNextAt = now + 3600
    m.appKeepCount = m.appKeepCount + 1
    appSetKeepRunningStatus("Starting pulse " + m.appKeepCount.ToStr() + " (unverified)")
    m.appKeepVideo.content = m.appKeepContent
    m.appKeepVideo.control = "play"
    print "[KeepRunning] Pulse "; m.appKeepCount; " requested at uptime "; now; " s."
end sub

sub onAppKeepRunningState()
    if not m.appKeepActive then return
    state = m.appKeepVideo.state
    if state = "playing"
        if m.appKeepPlayingAt < 0
            m.appKeepPlayingAt = int(m.appUptime.TotalMilliseconds() / 1000)
            appSetKeepRunningStatus("Playing pulse " + m.appKeepCount.ToStr() + " (max 10 s)")
            print "[KeepRunning] Playing at uptime "; m.appKeepPlayingAt; " s."
        end if
    else if state = "finished"
        if m.appKeepPlayingAt >= 0
            appCompleteKeepRunning("end of clip")
        else
            appStopKeepRunning("Failed: no playback observed; retry in 60 min")
        end if
    else if state = "error"
        code = m.appKeepVideo.errorCode
        print "[KeepRunning] Playback error code: "; code
        appStopKeepRunning("Playback failed; retry in 60 min")
    else if state = "stopped" or state = "paused"
        appStopKeepRunning("Interrupted; next pulse in 60 min")
    end if
end sub

sub appCompleteKeepRunning(reason as string)
    m.appKeepCompleted = m.appKeepCompleted + 1
    appStopKeepRunning("Completed " + m.appKeepCompleted.ToStr() + " pulse(s); effect unverified")
    print "[KeepRunning] Completed: "; reason; ". Idle-exit prevention still requires a long device test."
end sub

sub appStopKeepRunning(status as string)
    active = m.appKeepActive
    m.appKeepActive = false
    appSetKeepRunningStatus(status)
    if active then m.appKeepVideo.control = "stop"
    m.appKeepVideo.content = invalid
end sub

sub appInterruptKeepRunning()
    if not m.appKeepActive then return
    appStopKeepRunning("Stopped for remote input; next pulse in 60 min")
    print "[KeepRunning] Stopped for real remote input."
end sub

sub appTestKeepRunning()
    if m.appCommitted.keepRunning <> true
        m.appMenuNote = "Enable Keep running in Display and Save first."
        return
    end if
    if m.appKeepActive
        m.appMenuNote = "A pulse is already active; no overlapping playback."
        return
    end if
    appApplyKeepRunning()
    appStartKeepRunning()
    m.appMenuNote = "Test requested. Check playback and long-run logs; success is not proven."
end sub

sub appSetKeepRunningStatus(status as string)
    m.appKeepStatus = status
    if m.appMenu = "Status" then appDrawMenu()
end sub
