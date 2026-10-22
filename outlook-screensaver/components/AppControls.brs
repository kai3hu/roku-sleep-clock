' SceneGraph-only app controller. Network, registry and font metrics stay in Tasks.
sub initDashboardApp()
    m.appSettings = appDefaults()
    m.appCommitted = appDefaults()
    m.appReady = false
    m.appSleeping = false
    m.appManualPaused = false
    m.appPlaying = true
    m.appMenu = ""
    m.appMenuIndex = 0
    m.appMenuZone = "rows"
    m.appFooterIndex = 0
    m.appCategoryIndex = 0
    m.appPicker = invalid
    m.appConfirm = invalid
    m.appCurrent = "dashboard"
    m.appTelegramShown = false
    m.appNewsIndex = 0
    m.appNewsShown = false
    m.appPendingNews = invalid
    m.appReaderSeconds = 60
    m.appRemaining = 120
    m.appSettingsDirty = false
    m.appSaveRetryAt = 0
    m.appPendingRefresh = {}
    m.appRequests = {}
    m.appStatus = {calendar:"Not loaded",weather:"Not loaded",news:"Not loaded",telegram:"Not loaded"}
    m.appIdleClock = CreateObject("roTimespan")
    m.appIdleClock.Mark()
    m.appUptime = CreateObject("roTimespan")
    m.appUptime.Mark()
    appInitClock()
    appInitKeepRunning()
    m.appRotationClock = CreateObject("roTimespan")
    m.appRotationClock.Mark()
    m.appChrome = m.top.createChild("Group")
    m.appDate = createWeatherLabel(m.appChrome, "", 24, 1000, 40)
    m.appDate.translation = [780,125]
    m.appHint = createWeatherLabel(m.appChrome, "Loading settings...", 20, 1650, 32)
    m.appHint.translation = [120,1035]
    m.appOverlay = m.top.createChild("Group")
    m.appOverlay.visible = false
    m.appStorage = CreateObject("roSGNode", "AppSettingsTask")
    m.top.appendChild(m.appStorage)
    m.appStorage.ObserveField("result", "onAppSettingsStored")
    m.appStorage.operation = "load"
    m.appStorage.control = "run"
    m.top.setFocus(true)
end sub

sub onAppSettingsStored()
    result = m.appStorage.result
    if result = invalid then return
    if result.operation = "load"
        m.appSettings = appNormalizeSettings(result.settings)
        m.appCommitted = appNormalizeSettings(result.settings)
        m.appPlaying = m.appSettings.autoplay
        m.appReady = true
        appApplyKeepRunning()
        appShowPage(appStartupPage(m.appSettings), false)
        refreshData()
    else if result.success <> true
        m.appSettingsDirty = true
        m.appSaveRetryAt = int(m.appUptime.TotalMilliseconds() / 1000) + 30
        m.appHint.text = "Settings could not be saved; retrying."
    end if
end sub

function appCanFetch(source as string) as boolean
    if not m.appReady then return false
    if not appNeedsData(m.appCommitted, source)
        m.appStatus[source] = "Disabled (not requested)"
        m.appPendingRefresh[source] = false
        return false
    end if
    return true
end function

function appSourceKey(source as string, settings as object) as string
    if source = "calendar" then return appCalendarAccountKey(settings) + "|" + settings.calendarDays.ToStr() + "|" + settings.showEnded.ToStr()
    if source = "weather" then return settings.weatherLocation
    if source = "news" then return settings.technology.ToStr() + settings.science.ToStr() + settings.economy.ToStr()
    return settings.telegramChannel + settings.sourceArticles.ToStr() + settings.fontSize
end function

function appCalendarAccountKey(settings as object) as string
    return settings.calendarUrl + "|" + settings.useBundledCalendar.ToStr() + "|" + settings.calendarAllowed.ToStr()
end function

sub appRequestStarted(source as string)
    m.appRequests[source] = appSourceKey(source, m.appCommitted)
    m.appStatus[source] = "Updating..."
    m.appPendingRefresh[source] = false
end sub

function appAcceptResult(source as string) as boolean
    if not appCanFetch(source) then return false
    if m.appRequests[source] <> appSourceKey(source, m.appCommitted)
        m.appPendingRefresh[source] = true
        return false
    end if
    return true
end function

sub appDataArrived(source as string, success as boolean)
    date = CreateObject("roDateTime")
    date.ToLocalTime()
    text = "Updated " + twoDigits(date.GetHours()) + ":" + twoDigits(date.GetMinutes())
    if not success then text = "Unavailable or delayed"
    m.appStatus[source] = text
    if m.appMenu = "Status" then appDrawMenu()
    if m.appMenu <> "" then return
    if m.appCurrent = source or (source = "calendar" and m.appCurrent = "agenda") or m.appCurrent = "dashboard"
        if source = "news" and m.newsStories.Count() = 0
            m.newsStories = m.appPendingNews
            m.appPendingNews = invalid
            appRenderNews()
        else if source = "telegram" and not m.appTelegramShown and not m.appSleeping
            seconds = appRenderTelegram(false)
            appArmRotation(appDuration(m.appSettings, "telegram", seconds))
        end if
    end if
end sub

sub appTick()
    if not m.appReady then return
    appKeepRunningTick()
    appStandbyClockTick()
    idle = int(m.appIdleClock.TotalMilliseconds() / 1000)
    if appShouldSleep(m.appSettings, idle, m.appSleeping) then appSleep()
    if not m.appSleeping and m.appMenu = ""
        m.appHint.visible = idle < 8
        if m.appManualPaused and m.appPlaying and m.appSettings.resumeAfter > 0 and idle >= m.appSettings.resumeAfter
            m.appManualPaused = false
            appArmRotation(m.appRemaining)
        end if
        if not m.appManualPaused and m.appPlaying
            m.appRemaining = m.appArmedSeconds - int(m.appRotationClock.TotalMilliseconds() / 1000)
            if m.appRemaining < 0 then m.appRemaining = 0
        end if
        if m.appCurrent = "telegram"
            suffix = "Paused"
            if not m.appManualPaused and m.appPlaying then suffix = "Next in " + int(m.appRemaining / 60).ToStr() + ":" + twoDigits(m.appRemaining mod 60)
            m.top.FindNode("telegramStatus").text = m.telegramStatusBase + "  /  " + suffix
        end if
    end if
    for each source in ["calendar","weather","news","telegram"]
        if m.appPendingRefresh[source] = true
            if source = "calendar" then loadCalendar()
            if source = "weather" then loadWeather()
            if source = "news" then loadNews()
            if source = "telegram" then loadTelegram()
        end if
    end for
    if m.appSettingsDirty and m.appStorage.state <> "run" and int(m.appUptime.TotalMilliseconds() / 1000) >= m.appSaveRetryAt
        m.appStorage.operation = "save"
        m.appStorage.settings = appNormalizeSettings(m.appCommitted)
        m.appSettingsDirty = false
        m.appStorage.control = "run"
    end if
end sub

sub appUpdateClock(now as object)
    parts = appClockTime(now.GetHours(),now.GetMinutes(),m.appSettings.hourFormat)
    appSetClockText(parts.digits)
    m.clockPeriod.text = parts.period
    appClockPeriodPosition()
    if m.appMenuClockSample <> invalid then m.appMenuClockSample.text = parts.digits
    m.appDate.text = now.GetYear().ToStr() + "-" + twoDigits(now.GetMonth()) + "-" + twoDigits(now.GetDayOfMonth())
    m.appDate.color = m.displayColor
    m.appDate.visible = m.appSettings.showDate and not m.appSleeping and m.appMenu = ""
    m.appHint.color = m.displayColor
end sub

sub appPauseForInput()
    if not m.appManualPaused and m.appPlaying
        m.appRemaining = m.appArmedSeconds - int(m.appRotationClock.TotalMilliseconds() / 1000)
        if m.appRemaining < 1 then m.appRemaining = 1
    end if
    m.appManualPaused = true
    m.rotationTimer.control = "stop"
    m.pageTimer.control = "stop"
    m.appIdleClock.Mark()
end sub

sub appArmRotation(seconds as integer)
    if seconds < 1 then seconds = 1
    m.rotationTimer.control = "stop"
    m.appRemaining = seconds
    m.appArmedSeconds = seconds
    m.appRotationClock.Mark()
    m.rotationTimer.duration = seconds
    m.pageTimer.control = "stop"
    if m.appPlaying and not m.appManualPaused and not m.appSleeping and m.appMenu = ""
        m.rotationTimer.control = "start"
        if m.appCurrent = "dashboard" or m.appCurrent = "agenda" then m.pageTimer.control = "start"
    end if
end sub

sub appSleep()
    if m.appMenu <> "" then appCloseMenu(false)
    appPauseForInput()
    m.appSleeping = true
    appStopClockTransition()
    m.content.visible = false
    m.appChrome.visible = false
    if m.appSettings.clockStandby
        m.content.visible = true
        appSetVisibility("clock")
        appEnterClockStandby()
    end if
end sub

sub appWake()
    m.appSleeping = false
    m.content.visible = true
    m.appChrome.visible = true
    m.appIdleClock.Mark()
    appSetVisibility(m.appCurrent)
    appApplyLayout()
    ' Do not change the page, reader index or remaining reading time.
    m.appManualPaused = true
    appShowHint()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if m.interactive <> true then return false
    if not press
        if m.appWakeKey = key
            m.appWakeKey = ""
            return true
        end if
        return false
    end if
    if not m.appReady then return true
    appInterruptKeepRunning()
    if m.appWakeKey = key then return true
    m.appWakeKey = ""
    if m.appSleeping
        m.appWakeKey = key
        appWake()
        return true
    end if
    appPauseForInput()
    if m.appKeyboard <> invalid then return appKeyboardInput(key)
    if m.appMenu <> "" then return appMenuKey(key)
    if key = "left" or key = "right"
        direction = 1
        if key = "left" then direction = -1
        appShowPage(appNeighbor(m.appSettings, m.appCurrent, direction), true)
    else if key = "up" or key = "down"
        direction = 1
        if key = "up" then direction = -1
        appBrowseItem(direction)
    else if key = "OK"
        appOpenMenu("Navigate")
    else if key = "options"
        appOpenMenu("Settings")
    else if key = "play" or key = "pause" or key = "playonly"
        m.appPlaying = not m.appPlaying
        if key = "pause" then m.appPlaying = false
        if key = "playonly" then m.appPlaying = true
        m.appManualPaused = false
        appArmRotation(m.appRemaining)
    else if key = "back"
        if m.appCurrent = "dashboard" or not m.appSettings.enabled.dashboard then return false
        appShowPage("dashboard", true)
    else
        return false
    end if
    appShowHint()
    return true
end function

sub appShowHint()
    state = "Auto"
    if m.appManualPaused or not m.appPlaying then state = "Paused"
    m.appHint.text = appPageName(m.appCurrent) + "  /  " + state + "  /  Left-Right: pages   Up-Down: items   OK: navigate   *: settings   Play: auto"
    m.appHint.visible = true
end sub

sub appSetVisibility(page as string)
    agenda = page = "dashboard" or page = "agenda"
    m.today.visible = agenda
    m.todayBody.visible = agenda
    m.heading.visible = agenda
    m.agenda.visible = agenda
    m.weatherGroup.visible = page = "dashboard" or page = "weather"
    m.newsGroup.visible = page = "news"
    m.telegramGroup.visible = page = "telegram"
end sub

sub appShowPage(page as string, manual as boolean, advance = false as boolean)
    if not m.appSettings.enabled[page] then page = appEnabledPages(m.appSettings)[0]
    m.appCurrent = page
    m.rotationPage = page
    m.appCommitted.lastPage = page
    m.appSettings.lastPage = page
    m.appSettingsDirty = true
    appSetVisibility(page)
    seconds = 60
    if page = "telegram"
        seconds = appRenderTelegram(advance)
    else if page = "news"
        currentUrl = ""
        if m.newsStories.Count() > 0 then currentUrl = m.newsStories[m.appNewsIndex mod m.newsStories.Count()].url
        if m.appPendingNews <> invalid
            m.newsStories = m.appPendingNews
            m.appPendingNews = invalid
            m.appNewsIndex = 0
            for i = 0 to m.newsStories.Count() - 1
                if m.newsStories[i].url = currentUrl then m.appNewsIndex = i
            end for
        end if
        if advance and m.appNewsShown = true and m.newsStories.Count() > 0 then m.appNewsIndex = (m.appNewsIndex + 1) mod m.newsStories.Count()
        appRenderNews()
        m.appNewsShown = true
    end if
    appApplyLayout()
    if manual then m.appManualPaused = true
    appArmRotation(appDuration(m.appSettings, page, seconds))
    appShowHint()
end sub

function appRenderTelegram(advance as boolean) as integer
    if m.telegramPages.Count() = 0 and m.telegramAvailablePages.Count() = 0
        m.top.FindNode("telegramHeading").text = "TELEGRAM  /  @" + m.appSettings.telegramChannel
        m.top.FindNode("telegramStatus").text = "Loading messages, or public feed unavailable."
        return 60
    end if
    if m.appTelegramShown and not advance then m.telegramPageIndex = m.telegramPageIndex - 1
    if m.telegramPageIndex < 0 then m.telegramPageIndex = 0
    seconds = renderTelegramPage()
    m.appTelegramShown = true
    m.appReaderSeconds = seconds
    return seconds
end function

sub appRenderNews()
    if m.newsStories.Count() = 0
        m.top.FindNode("newsHeading").text = "KAGI NEWS"
        m.top.FindNode("newsTitle").text = "No stories available"
        m.top.FindNode("newsSummary").text = "Enable news categories in Settings, or try Refresh."
        m.top.FindNode("newsUrl").text = ""
        return
    end if
    m.appNewsIndex = m.appNewsIndex mod m.newsStories.Count()
    article = m.newsStories[m.appNewsIndex]
    m.top.FindNode("newsHeading").text = "KAGI NEWS  /  " + ucase(article.category) + "  /  " + (m.appNewsIndex + 1).ToStr() + " OF " + m.newsStories.Count().ToStr() + "  /  " + article.edition
    m.top.FindNode("newsTitle").text = article.title
    m.top.FindNode("newsSummary").text = article.summary
    m.top.FindNode("newsUrl").text = shortText(article.sourceUrl, 180)
end sub

sub appRotate()
    if m.appSleeping or m.appManualPaused or not m.appPlaying or m.appMenu <> "" then return
    if m.appCurrent = "telegram" and telegramHasContinuation(m.telegramPages, m.telegramPageIndex)
        seconds = appRenderTelegram(true)
        appArmRotation(appDuration(m.appSettings, "telegram", seconds))
        return
    end if
    nextPage = appNeighbor(m.appSettings, m.appCurrent, 1)
    if nextPage = "telegram" and nextPage = m.appCurrent
        appShowPage("telegram", false, true)
        return
    end if
    if nextPage = m.appCurrent then appBrowseItem(1)
    appShowPage(nextPage, false, nextPage <> m.appCurrent)
end sub

sub appBrowseItem(direction as integer)
    if m.appCurrent = "news" and m.newsStories.Count() > 0
        m.appNewsIndex = (m.appNewsIndex + direction + m.newsStories.Count()) mod m.newsStories.Count()
        appRenderNews()
    else if m.appCurrent = "telegram" and m.telegramPages.Count() > 0
        current = m.telegramPageIndex - 1
        if direction > 0 and m.telegramPageIndex >= m.telegramPages.Count()
            m.telegramPageIndex = m.telegramPages.Count()
        else
            m.telegramPageIndex = (current + direction + m.telegramPages.Count()) mod m.telegramPages.Count()
        end if
        m.appReaderSeconds = renderTelegramPage()
        appArmRotation(appDuration(m.appSettings, "telegram", m.appReaderSeconds))
    else if m.appCurrent = "agenda" or m.appCurrent = "dashboard"
        count = int((m.agendaLines.Count() + 5) / 6)
        if count > 0 then m.agendaPage = (m.agendaPage + direction + count) mod count
        count = int((m.todayItems.Count() + 2) / 3)
        if count > 0 then m.todayPage = (m.todayPage + direction + count) mod count
        showAgendaPage()
        showTodayPage()
        appApplyLayout()
    end if
end sub

sub appApplyLayout()
    appStopClockTransition()
    settings = m.appSettings
    m.top.FindNode("weatherLocation").text = ucase(appWeatherCity(m.appCommitted.weatherLocation, m.appWeatherRaw))
    if m.appCurrent = "dashboard" or m.appCurrent = "agenda" then showTodayPage()
    scale = settings.margin / 100.0
    m.content.scale = [scale,scale]
    m.content.translation = [120 + (1 - scale) * 840,80 + (1 - scale) * 470]
    if m.appMenu <> ""
        m.content.scale = [0.38,0.38]
        m.content.translation = [1100,420]
    end if
    m.clock.font.size = settings.clockSize
    m.clock.width = 760
    m.clock.height = 155
    m.clock.translation = [0,0]
    m.today.translation = [12,155]
    m.todayBody.translation = [12,215]
    m.todayBody.height = 330
    m.todayBody.width = 900
    m.todayBody.font.size = appBodySize(settings)
    m.agenda.translation = [12,610]
    m.agenda.width = 900
    m.agenda.font.size = appSmallSize(settings)
    m.heading.translation = [12,555]
    m.heading.text = "NEXT " + settings.calendarDays.ToStr() + " DAYS"
    if settings.clockSize = 140
        m.clock.height = 185
        m.today.translation = [12,185]
        m.todayBody.translation = [12,245]
        m.todayBody.height = 300
    end if
    ' Reader pages reserve their vertical space for article text.
    if m.appCurrent = "news" or m.appCurrent = "telegram"
        if settings.clockSize > 110 then m.clock.font.size = 110
    end if
    m.weatherGroup.translation = [1000,10]
    m.weatherGroup.scale = [1,1]
    m.top.FindNode("weatherChart").visible = true
    m.top.FindNode("weatherForecast").visible = true
    m.top.FindNode("weatherRange").visible = true
    m.top.FindNode("weatherForecastHeading").visible = true
    if m.appCurrent = "agenda"
        m.todayBody.width = 1630
        m.agenda.width = 1630
    else if m.appCurrent = "weather"
        m.weatherGroup.translation = [830,0]
        m.weatherGroup.scale = [1.1,1.1]
    else if m.appCurrent = "clock"
        m.clock.translation = [470,330]
    else if m.appCurrent = "dashboard" and settings.layout = "Agenda Focus"
        m.todayBody.width = 1090
        m.agenda.width = 1090
        m.weatherGroup.translation = [1160,30]
        m.weatherGroup.scale = [0.75,0.75]
    else if m.appCurrent = "dashboard" and settings.layout = "Minimal"
        m.clock.translation = [300,180]
        m.today.translation = [312,380]
        m.todayBody.translation = [312,445]
        m.todayBody.height = 150
        m.todayBody.width = 1000
        m.heading.visible = false
        m.agenda.visible = false
        m.weatherGroup.translation = [1150,215]
        m.weatherGroup.scale = [0.75,0.75]
        m.top.FindNode("weatherChart").visible = false
        m.top.FindNode("weatherForecast").visible = false
        m.top.FindNode("weatherRange").visible = false
        m.top.FindNode("weatherForecastHeading").visible = false
        if m.todayItems.Count() > 0 then m.todayBody.text = m.todayItems[0].timeLabel + "   " + shortText(m.todayItems[0].title, 100)
    end if
    m.top.FindNode("newsTitle").font.size = appBodySize(settings) + 14
    summarySize = appBodySize(settings) - 2
    if summarySize > 34 then summarySize = 34
    m.top.FindNode("newsSummary").font.size = summarySize
    m.top.FindNode("newsSummary").height = 380
    m.top.FindNode("newsSummary").numLines = 9
    m.top.FindNode("newsUrl").translation = [0,630]
    m.top.FindNode("newsAttribution").translation = [0,695]
    m.displayColor = ""
    appClockStyle()
    updateClock()
    if m.appSleeping and m.appSettings.clockStandby
        ' A five-minute data refresh must not reset the standby clock anchor.
        m.appClockSleepSlot = -1
        appStandbyClockTick()
    end if
end sub

sub appOpenMenu(group as string)
    appPauseForInput()
    if group = "Settings"
        m.appBeforeSettings = appNormalizeSettings(m.appCommitted)
        m.appSettings = appNormalizeSettings(m.appCommitted)
    end if
    m.appMenu = group
    m.appMenuIndex = 0
    m.appMenuZone = "rows"
    m.appFooterIndex = 0
    m.appPicker = invalid
    m.appConfirm = invalid
    m.appMenuNote = ""
    m.appOverlay.visible = true
    m.appDate.visible = false
    m.appHint.visible = false
    appApplyLayout()
    appDrawMenu()
end sub

function appMenuRows() as object
    if m.appMenu = "Navigate"
        rows = []
        for each id in appEnabledPages(m.appSettings)
            rows.Push({key:id,label:appPageName(id),kind:"navigate"})
        end for
        rows.Push({key:"sleepNow",label:"Black screen now",kind:"action"})
        rows.Push({key:"refreshAll",label:"Refresh enabled sources",kind:"action"})
        rows.Push({key:"settings",label:"Settings",kind:"action"})
        return rows
    end if
    if m.appMenu = "Settings"
        rows = []
        for each name in appSettingGroups()
            rows.Push({key:name,label:name,kind:"group"})
        end for
        return rows
    end if
    if m.appMenu = "Pages"
        rows = [{key:"startup",label:"Startup page",values:["last","dashboard","agenda","weather","news","telegram","clock"]}]
        for each id in m.appSettings.order
            rows.Push({key:id,label:appPageName(id),kind:"page"})
        end for
        return rows
    end if
    return appSettingRows(m.appMenu)
end function

sub appDrawNavigationMenu()
    if m.appKeyboard <> invalid
        appDrawKeyboard()
        return
    end if
    m.appOverlay.removeChildrenIndex(m.appOverlay.getChildCount(), 0)
    background = m.appOverlay.createChild("Rectangle")
    background.width = 940
    background.height = 1080
    background.color = "0x000000FF"
    title = createWeatherLabel(m.appOverlay, "SLEEP DASHBOARD / " + ucase(m.appMenu), 30, 850, 48)
    title.translation = [60,55]
    title.color = "0x686868FF"
    rows = appMenuRows()
    if m.appMenuIndex >= rows.Count() then m.appMenuIndex = rows.Count() - 1
    first = int(m.appMenuIndex / 8) * 8
    last = first + 7
    if last >= rows.Count() then last = rows.Count() - 1
    for i = first to last
        row = rows[i]
        y = 145 + (i - first) * 82
        if i = m.appMenuIndex
            highlight = m.appOverlay.createChild("Rectangle")
            highlight.width = 830
            highlight.height = 74
            highlight.translation = [50,y - 8]
            highlight.color = "0x161616FF"
        end if
        text = row.label
        value = ""
        if row.kind = "page"
            state = "Off"
            if m.appSettings.enabled[row.key] then state = "On"
            text = (i).ToStr() + ". " + text + "  [" + state + "]"
        else if row.values <> invalid
            item = m.appSettings[row.key]
            value = item.ToStr()
            if type(item) = "Boolean" or type(item) = "roBoolean"
                value = "Off"
                if item then value = "On"
            end if
            if row.key = "startup" then value = appPageName(item)
        else if row.kind = "text"
            value = m.appSettings[row.key]
            if row.key = "calendarUrl"
                value = "Hidden / not configured"
                if m.appSettings.useBundledCalendar or m.appSettings.calendarUrl <> "" then value = "Hidden / configured"
            end if
        end if
        label = createWeatherLabel(m.appOverlay, text, 23, 800, 34)
        label.translation = [70,y]
        label.color = "0x585858FF"
        if i = m.appMenuIndex then label.color = "0x888888FF"
        if value <> ""
            label = createWeatherLabel(m.appOverlay, shortText(value, 70), 21, 790, 32)
            label.translation = [70,y + 34]
            label.color = "0x484848FF"
        end if
    end for
    note = "Up/Down: select   Left/Right: change   OK: choose   Back: return"
    if m.appMenu = "Pages" then note = "OK: enable/disable   Left/Right: reorder page   Back: return"
    if m.appMenu = "Status"
        note = "Outlook: " + m.appStatus.calendar + chr(10) + "Weather: " + m.appStatus.weather + "  /  News: " + m.appStatus.news + chr(10) + "Telegram: " + m.appStatus.telegram
        note = note + chr(10) + "Keep running: " + m.appKeepStatus + chr(10) + "Previous exit: " + m.top.lastExitReason
    end if
    if m.appMenuNote <> "" then note = m.appMenuNote + chr(10) + note
    footer = createWeatherLabel(m.appOverlay, note, 20, 830, 170)
    footer.translation = [60,825]
    footer.wrap = true
    footer.numLines = 6
    if m.appMenu = "Status"
        footer.font.size = 18
        footer.height = 185
        footer.numLines = 8
    end if
    footer.color = "0x585858FF"
    page = createWeatherLabel(m.appOverlay, "Page " + (int(m.appMenuIndex / 8) + 1).ToStr() + " / " + int((rows.Count() + 7) / 8).ToStr() + "  |  Changes are saved only with Save.", 18, 830, 35)
    page.translation = [60,1015]
    page.color = "0x404040FF"
    preview = createWeatherLabel(m.appOverlay, "LIVE PREVIEW", 22, 800, 40)
    preview.translation = [1020,180]
    preview.color = "0x484848FF"
end sub

function appNavigationKey(key as string) as boolean
    rows = appMenuRows()
    row = rows[m.appMenuIndex]
    if key = "up" or key = "down"
        direction = 1
        if key = "up" then direction = -1
        m.appMenuIndex = (m.appMenuIndex + direction + rows.Count()) mod rows.Count()
    else if key = "back"
        if m.appMenu = "Settings" or m.appMenu = "Navigate"
            appCloseMenu(false)
            return true
        end if
        m.appMenu = "Settings"
        m.appMenuIndex = 0
    else if key = "left" or key = "right" or key = "OK"
        direction = 1
        if key = "left" then direction = -1
        if row.kind = "navigate" and key = "OK"
            page = row.key
            appCloseMenu(false)
            appShowPage(page, true)
            return true
        else if row.kind = "group" and key = "OK"
            m.appMenu = row.key
            m.appMenuIndex = 0
        else if row.kind = "page"
            if key = "OK"
                if m.appSettings.enabled[row.key] and appEnabledPages(m.appSettings).Count() = 1
                    m.appMenuNote = "Keep at least one page enabled."
                else
                    m.appSettings.enabled[row.key] = not m.appSettings.enabled[row.key]
                end if
            else
                m.appSettings = appMovePage(m.appSettings, row.key, direction)
                for i = 0 to m.appSettings.order.Count() - 1
                    if m.appSettings.order[i] = row.key then m.appMenuIndex = i + 1
                end for
            end if
        else if row.kind = "text" and key = "OK"
            appOpenKeyboard(row)
            return true
        else if row.kind = "action" and key = "OK"
            appMenuAction(row.key)
            if m.appMenu = "" then return true
        else if row.values <> invalid
            index = 0
            for i = 0 to row.values.Count() - 1
                if row.values[i] = m.appSettings[row.key] then index = i
            end for
            m.appSettings[row.key] = row.values[(index + direction + row.values.Count()) mod row.values.Count()]
        end if
    else
        return true
    end if
    appSetVisibility(m.appCurrent)
    appApplyLayout()
    appDrawMenu()
    return true
end function

sub appMenuAction(action as string)
    if action = "saveSettings"
        appCloseMenu(true)
    else if action = "cancelSettings"
        appCloseMenu(false)
    else if action = "settings"
        appOpenMenu("Settings")
    else if action = "sleepNow"
        appCloseMenu(false)
        appSleep()
    else if action = "resetLayout"
        defaults = appDefaults()
        for each key in ["layout","fontSize","clockSize","clockFont","clockAnimation","hourFormat","showDate","margin"]
            m.appSettings[key] = defaults[key]
        end for
        m.appMenuNote = "Layout defaults previewed; choose Save to keep."
    else if action = "clearCalendar"
        m.appSettings.calendarUrl = ""
        m.appSettings.useBundledCalendar = false
        m.appSettings.calendarAllowed = false
        m.appMenuNote = "Outlook will be forgotten when you Save."
    else if action = "refreshAll"
        refreshData()
        m.appMenuNote = "Refreshing sources used by enabled pages."
    else if action = "testKeepRunning"
        appMenuTestKeepRunning()
    else
        source = lcase(action.Replace("refresh", ""))
        m.appPendingRefresh[source] = true
        m.appMenuNote = "Refresh queued (enabled sources only)."
    end if
end sub

sub appCloseMenu(save as boolean)
    m.appKeyboard = invalid
    m.appPicker = invalid
    m.appConfirm = invalid
    m.appMenuZone = "rows"
    if m.appMenu <> "Navigate"
        if save
            appCommitSettings()
        else
            m.appSettings = appNormalizeSettings(m.appCommitted)
        end if
    end if
    m.appMenu = ""
    m.appOverlay.visible = false
    m.appIdleClock.Mark()
    oldPage = m.appCurrent
    if not m.appSettings.enabled[m.appCurrent] then m.appCurrent = appStartupPage(m.appSettings)
    if oldPage <> m.appCurrent
        appShowPage(m.appCurrent, true)
    end if
    appSetVisibility(m.appCurrent)
    appApplyLayout()
    if m.appCurrent = "news" then appRenderNews()
    if m.appCurrent = "telegram" and not m.appTelegramShown
        seconds = appRenderTelegram(false)
        appArmRotation(appDuration(m.appSettings, "telegram", seconds))
    end if
    appShowHint()
end sub

sub appSettingsApplied(oldSettings as object)
    appApplyKeepRunning()
    for each source in ["calendar","weather","news","telegram"]
        changed = appSourceKey(source, oldSettings) <> appSourceKey(source, m.appSettings)
        if changed
            if source = "calendar"
                ' Range/finished-task filters are not an account disconnection.
                ' Keep the last visible data until the new response is published.
                if appCalendarAccountKey(oldSettings) <> appCalendarAccountKey(m.appSettings)
                    m.todayItems = []
                    m.agendaLines = []
                    m.todayPage = 0
                    m.agendaPage = 0
                    m.todayBody.text = ""
                    m.agenda.text = ""
                    m.calendarTask.uri = ""
                    if not m.appSettings.calendarAllowed then m.today.text = "TODAY / Outlook disabled"
                end if
            else if source = "telegram"
                m.telegramPages = []
                m.telegramAvailablePages = []
                m.telegramPosts = []
                m.telegramPageIndex = 0
                m.appTelegramShown = false
                m.telegramGrid.removeChildrenIndex(m.telegramGrid.getChildCount(), 0)
                m.top.FindNode("telegramStatus").text = "Waiting for updated channel/layout data..."
                m.top.FindNode("telegramAttribution").text = ""
            else if source = "news"
                m.newsStories = []
                m.appPendingNews = invalid
                m.appNewsIndex = 0
                m.appNewsShown = false
            else if source = "weather"
                m.hasWeather = false
                m.appWeatherRaw = invalid
                m.temperature.text = "--"
                m.weatherDescription.text = "Updating location..."
                m.weatherChart.removeChildrenIndex(m.weatherChart.getChildCount(), 0)
                m.weatherForecast.removeChildrenIndex(m.weatherForecast.getChildCount(), 0)
            end if
        end if
        if appNeedsData(m.appSettings, source)
            if changed or not appNeedsData(oldSettings, source) then m.appPendingRefresh[source] = true
        else
            m.appPendingRefresh[source] = false
            m.appStatus[source] = "Disabled (not requested)"
        end if
    end for
    if oldSettings.units <> m.appSettings.units and m.appWeatherRaw <> invalid
        m.weatherTask.result = m.appWeatherRaw
        onWeatherChanged()
    end if
end sub

sub appOpenKeyboard(row as object)
    text = m.appSettings[row.key]
    if row.key = "calendarUrl"
        text = ""
    end if
    m.appKeyboard = {key:row.key,label:row.label,text:text,index:0,caps:false}
    appDrawKeyboard()
end sub

function appKeyboardKeys() as object
    keys = []
    chars = "abcdefghijklmnopqrstuvwxyz0123456789:/?&=._-%@+#"
    if m.appKeyboard.caps then chars = ucase(chars)
    for i = 1 to len(chars)
        keys.Push(mid(chars,i,1))
    end for
    for each key in ["SPACE","DEL","CAPS","SAVE","CANCEL"]
        keys.Push(key)
    end for
    return keys
end function

sub appDrawKeyboard()
    m.appOverlay.removeChildrenIndex(m.appOverlay.getChildCount(),0)
    background = m.appOverlay.createChild("Rectangle")
    background.width = 940
    background.height = 1080
    background.color = "0x000000FF"
    label = createWeatherLabel(m.appOverlay,m.appKeyboard.label,28,840,60)
    label.translation = [60,65]
    label.color = "0x686868FF"
    text = m.appKeyboard.text
    if m.appKeyboard.key = "calendarUrl" then text = string(len(text),"*")
    if len(text) > 90 then text = right(text,90)
    label = createWeatherLabel(m.appOverlay,text + "_",24,810,150)
    label.translation = [60,150]
    label.wrap = true
    label.numLines = 4
    label.color = "0x686868FF"
    keys = appKeyboardKeys()
    for i = 0 to keys.Count() - 1
        x = 60 + (i mod 8) * 106
        y = 345 + int(i / 8) * 65
        if i = m.appKeyboard.index
            rectangle = m.appOverlay.createChild("Rectangle")
            rectangle.width = 100
            rectangle.height = 56
            rectangle.translation = [x - 5,y - 5]
            rectangle.color = "0x242424FF"
        end if
        label = createWeatherLabel(m.appOverlay,keys[i],20,100,48)
        label.translation = [x,y]
        label.color = "0x686868FF"
    end for
    note = "Arrows: choose key   OK: type   Back: cancel" + chr(10) + "SAVE adds this text to the preview; PLAY/PAUSE saves settings." + chr(10) + "Calendar links stay masked. Idle black screen still applies."
    if m.appMenuNote <> "" then note = m.appMenuNote + chr(10) + note
    label = createWeatherLabel(m.appOverlay,note,20,840,130)
    label.translation = [60,900]
    label.wrap = true
    label.numLines = 5
    label.color = "0x585858FF"
end sub

function appKeyboardInput(key as string) as boolean
    keys = appKeyboardKeys()
    keyboard = m.appKeyboard
    if key = "back"
        m.appKeyboard = invalid
        appDrawMenu()
        return true
    else if key = "left" or key = "right" or key = "up" or key = "down"
        amount = 1
        if key = "left" then amount = -1
        if key = "up" then amount = -8
        if key = "down" then amount = 8
        keyboard.index = (keyboard.index + amount + keys.Count()) mod keys.Count()
    else if key = "OK"
        chosen = keys[keyboard.index]
        if chosen = "CANCEL" then return appKeyboardInput("back")
        if chosen = "SAVE"
            if appSaveKeyboardValue()
                m.appKeyboard = invalid
                appDrawMenu()
                return true
            end if
        else if chosen = "CAPS"
            keyboard.caps = not keyboard.caps
        else if chosen = "DEL"
            if len(keyboard.text) > 0 then keyboard.text = left(keyboard.text,len(keyboard.text) - 1)
        else if chosen = "SPACE"
            keyboard.text = keyboard.text + " "
        else
            keyboard.text = keyboard.text + chosen
        end if
    else if left(key,4) = "Lit_"
        keyboard.text = keyboard.text + mid(key,5)
    end if
    if len(keyboard.text) > 4096 then keyboard.text = left(keyboard.text,4096)
    appDrawKeyboard()
    return true
end function

function appSaveKeyboardValue() as boolean
    key = m.appKeyboard.key
    text = m.appKeyboard.text.Trim()
    candidate = appNormalizeSettings(m.appSettings)
    candidate[key] = text
    if key = "calendarUrl"
        if not appValidCalendarUrl(text)
            m.appMenuNote = "Enter a valid HTTPS calendar URL."
            return false
        end if
        candidate.useBundledCalendar = false
        candidate.calendarAllowed = true
    end if
    if key = "weatherLocation" and (len(text) < 2 or len(text) > 100) then return false
    normalized = appNormalizeSettings(candidate)
    if key = "telegramChannel" and normalized.telegramChannel <> text.Replace("@", "").Replace("https://t.me/", "") then return false
    m.appSettings = normalized
    m.appMenuNote = "Value previewed; choose Save settings to keep."
    return true
end function
