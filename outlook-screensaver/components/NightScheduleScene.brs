sub init()
    m.top.backgroundURI = ""
    m.top.backgroundColor = "0x000000FF"
    m.content = m.top.FindNode("content")
    m.clock = m.top.FindNode("clock")
    m.agenda = m.top.FindNode("agenda")
    m.heading = m.top.FindNode("heading")
    m.today = m.top.FindNode("today")
    m.todayBody = m.top.FindNode("todayBody")
    m.todayItems = []
    m.todayPage = 0
    m.weatherGroup = m.top.FindNode("weather")
    m.displayColor = ""
    m.iconTint = ""
    m.tick = m.top.FindNode("tick")
    m.refresh = m.top.FindNode("refresh")
    m.calendarTask = m.top.FindNode("calendarTask")
    m.weatherTask = m.top.FindNode("weatherTask")
    m.weatherIcon = m.top.FindNode("weatherIcon")
    m.temperature = m.top.FindNode("temperature")
    m.weatherDescription = m.top.FindNode("weatherDescription")
    m.hasWeather = false
    m.weatherChart = m.top.FindNode("weatherChart")
    m.weatherForecast = m.top.FindNode("weatherForecast")
    m.weatherRange = m.top.FindNode("weatherRange")
    m.agendaLines = []
    m.agendaPage = 0
    m.pageTimer = m.top.FindNode("agendaPageTimer")
    m.newsGroup = m.top.FindNode("news")
    m.newsTask = m.top.FindNode("newsTask")
    m.rotationTimer = m.top.FindNode("rotationTimer")
    m.newsStories = []
    m.pendingNewsStories = invalid
    m.nextNewsIndex = 0
    m.rotationPage = "agenda"
    m.newsDelayed = false
    m.telegramGroup = m.top.FindNode("telegram")
    m.telegramGrid = m.top.FindNode("telegramGrid")
    m.telegramTask = m.top.FindNode("telegramTask")
    m.telegramPosts = []
    m.telegramAvailablePages = []
    m.telegramPages = []
    m.telegramPageIndex = 0
    m.telegramPagesUpdated = ""
    m.telegramUpdated = ""
    m.telegramDelayed = false
    m.telegramReadingClock = invalid
    m.telegramReadingDuration = 60
    m.telegramStatusBase = ""
    m.interactive = m.top.interactive = true

    m.tick.ObserveField("fire", "onTick")
    m.refresh.ObserveField("fire", "refreshData")
    m.calendarTask.ObserveField("agenda", "onAgendaChanged")
    m.calendarTask.ObserveField("today", "onTodayChanged")
    m.calendarTask.ObserveField("todayItems", "onTodayItemsChanged")
    m.weatherTask.ObserveField("result", "onWeatherChanged")
    m.pageTimer.ObserveField("fire", "nextAgendaPage")
    m.rotationTimer.ObserveField("fire", "rotateContent")
    m.newsTask.ObserveField("result", "onNewsChanged")
    m.telegramTask.ObserveField("result", "onTelegramChanged")

    if m.interactive then initDashboardApp()
    updateClock()
    loadCalendar()
    loadWeather()
    loadTelegram()
    loadNews()
    m.tick.control = "start"
    m.refresh.control = "start"
    if not m.interactive
        m.pageTimer.control = "start"
        m.rotationTimer.control = "start"
    end if
end sub

sub onTick()
    updateClock()
    if m.interactive = true
        appTick()
    else
        updateTelegramCountdown()
    end if
end sub

sub updateClock()
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    hour = now.GetHours()
    minute = now.GetMinutes()
    applyDisplaySchedule(hour)
    if m.interactive = true
        appUpdateClock(now)
    else
        m.clock.text = twoDigits(hour) + ":" + twoDigits(minute)
    end if
end sub

sub applyDisplaySchedule(localHour as integer)
    color = scheduleTextColor(localHour)
    if m.interactive = true then color = appTextColor(m.appSettings, localHour, m.appManualPaused = true)
    if m.displayColor = color then return
    m.displayColor = color
    m.iconTint = scheduleIconTint(localHour)
    if m.interactive = true then m.iconTint = appIconTint(m.appSettings, localHour, m.appManualPaused = true)
    applyContentPalette(m.content, m.displayColor, m.iconTint)
end sub

sub applyContentPalette(node as object, color as string, iconTint as string)
    kind = node.subtype()
    if kind = "Label" or kind = "Rectangle" then node.color = color
    if kind = "Poster" then node.blendColor = iconTint
    for i = 0 to node.getChildCount() - 1
        applyContentPalette(node.getChild(i), color, iconTint)
    end for
end sub

sub loadCalendar()
    if m.interactive = true
        if not appCanFetch("calendar") then return
    end if
    url = GetCalendarIcsUrl()
    if m.interactive = true
        url = m.appCommitted.calendarUrl
        if m.appCommitted.useBundledCalendar then url = GetCalendarIcsUrl()
    end if
    if url = ""
        m.agenda.text = "Add your Outlook ICS link in source/config.brs"
        m.today.text = "TODAY  /  Calendar not configured"
        m.todayBody.text = "Add your Outlook calendar to see today's schedule."
        if m.interactive = true
            m.appStatus.calendar = "Not configured"
            m.appPendingRefresh.calendar = false
            m.agenda.text = "Configure Outlook in Settings > Content."
        end if
        return
    end if
    if m.calendarTask.state = "run" then return
    if m.interactive = true
        m.calendarTask.days = m.appCommitted.calendarDays
        m.calendarTask.showEnded = m.appCommitted.showEnded
        appRequestStarted("calendar")
    end if
    m.calendarTask.uri = url
    m.calendarTask.control = "run"
end sub

sub refreshData()
    loadCalendar()
    loadWeather()
    loadTelegram()
    loadNews()
end sub

sub loadTelegram()
    if m.interactive = true
        if not appCanFetch("telegram") then return
        if m.telegramTask.state = "run" then return
        m.telegramTask.channel = m.appCommitted.telegramChannel
        m.telegramTask.sourceArticles = m.appCommitted.sourceArticles
        m.telegramTask.fontSize = appTelegramFontSize(m.appCommitted)
        appRequestStarted("telegram")
    end if
    if m.telegramTask.state <> "run" then m.telegramTask.control = "run"
end sub

sub onTelegramChanged()
    if m.interactive = true
        if not appAcceptResult("telegram") then return
    end if
    result = m.telegramTask.result
    if result = invalid then return
    if result.available
        if type(result.pages) <> "roArray" then return
        if result.pages.Count() = 0 then return
        m.telegramPosts = result.posts
        m.telegramAvailablePages = result.pages
        m.telegramUpdated = telegramLocalTime(result.fetchedAt)
        m.telegramDelayed = result.delayed = true
    else
        m.telegramDelayed = true
    end if
    if m.interactive = true then appDataArrived("telegram", result.available)
    ' Render only at page entry so a refresh never interrupts reading.
end sub

function renderTelegramPage() as integer
    m.telegramGrid.removeChildrenIndex(m.telegramGrid.getChildCount(), 0)
    if m.telegramPageIndex >= m.telegramPages.Count()
        ' Only consume precomputed data. Never register fonts or paginate on RENDER.
        m.telegramPages = m.telegramAvailablePages
        m.telegramPageIndex = 0
        m.telegramPagesUpdated = m.telegramUpdated
    end if
    if m.telegramPages.Count() = 0 then return 60
    cards = m.telegramPages[m.telegramPageIndex]
    duration = 60
    for each card in cards
        post = card.post
        kind = "MESSAGE"
        if post.isArticle = true then kind = "ARTICLE"
        channel = telegramChannel()
        bodySize = 30
        if m.interactive = true
            channel = m.appSettings.telegramChannel
            bodySize = appTelegramFontSize(m.appSettings)
        end if
        m.top.FindNode("telegramHeading").text = "TELEGRAM  /  @" + channel + "  /  " + kind
        metaText = telegramLocalTime(post.timestamp) + "  /  Page " + card.part.ToStr() + " of " + card.parts.ToStr()
        if card.continued then metaText = metaText + "  /  Continued"
        meta = createWeatherLabel(m.telegramGrid, metaText, 20, card.width, 30)
        meta.translation = [0, 0]
        ' Render the worker's exact lines; SceneGraph must not wrap them again.
        for i = 0 to card.lineTexts.Count() - 1
            body = createWeatherLabel(m.telegramGrid, card.lineTexts[i], bodySize, card.width, card.lineHeight)
            body.translation = [0, 42 + i * card.lineHeight]
            body.wrap = false
            body.font.uri = "pkg:/fonts/NotoSansSC-Regular.otf"
            body.font.fallbackGlyph = "u0020"
        end for
        attribution = "t.me/" + channel + "/" + post.id.ToStr()
        if post.isArticle = true
            attribution = "Article: telegra.ph  /  " + attribution
            if post.author <> "" then attribution = attribution + "  /  " + post.author
        end if
        m.top.FindNode("telegramAttribution").text = attribution
        duration = card.duration
    end for
    status = "Full text  /  Checked " + m.telegramPagesUpdated
    if m.telegramDelayed then status = status + "  /  Update delayed"
    m.telegramStatusBase = status
    m.telegramReadingDuration = duration
    m.telegramReadingClock = CreateObject("roTimespan")
    m.telegramReadingClock.Mark()
    updateTelegramCountdown()
    m.telegramPageIndex = m.telegramPageIndex + 1
    return duration
end function

sub updateTelegramCountdown()
    if m.rotationPage <> "telegram" or m.telegramReadingClock = invalid then return
    remaining = m.telegramReadingDuration - int(m.telegramReadingClock.TotalMilliseconds() / 1000)
    if remaining < 0 then remaining = 0
    countdown = int(remaining / 60).ToStr() + ":" + twoDigits(remaining mod 60)
    m.top.FindNode("telegramStatus").text = m.telegramStatusBase + "  /  Next page in " + countdown
end sub

sub loadNews()
    if m.interactive = true
        if not appCanFetch("news") then return
        if m.newsTask.state = "run" then return
        categories = []
        if m.appCommitted.technology then categories.Push("Technology")
        if m.appCommitted.science then categories.Push("Science")
        if m.appCommitted.economy then categories.Push("Economy")
        m.newsTask.categories = categories
        appRequestStarted("news")
    end if
    if m.newsTask.state = "run" then return
    m.newsTask.control = "run"
end sub

sub onNewsChanged()
    if m.interactive = true
        if not appAcceptResult("news") then return
    end if
    result = m.newsTask.result
    if result = invalid then return
    m.newsDelayed = result.delayed
    if type(result.stories) <> "roArray" then return
    if result.stories.Count() = 0
        if m.interactive = true then appDataArrived("news", false)
        return
    end if
    if m.interactive = true
        m.appPendingNews = result.stories
        appDataArrived("news", not result.delayed)
        return
    end if
    if m.rotationPage = "news"
        ' Keep the current article stable until its full minute has elapsed.
        m.pendingNewsStories = result.stories
    else
        setNewsStories(result.stories)
    end if
end sub

sub setNewsStories(articles as object)
    ' Preserve the next article when the same cached collection is re-emitted.
    nextUrl = ""
    if m.newsStories.Count() > 0 then nextUrl = m.newsStories[m.nextNewsIndex mod m.newsStories.Count()].url
    m.newsStories = articles
    m.nextNewsIndex = 0
    for i = 0 to articles.Count() - 1
        if articles[i].url = nextUrl then m.nextNewsIndex = i
    end for
end sub

sub rotateContent()
    if m.interactive = true
        appRotate()
        return
    end if
    if m.rotationPage = "telegram"
        if telegramHasContinuation(m.telegramPages, m.telegramPageIndex)
            duration = renderTelegramPage()
            m.rotationTimer.control = "stop"
            m.rotationTimer.duration = duration
            m.rotationTimer.control = "start"
            return
        end if
    end if
    if m.pendingNewsStories <> invalid
        setNewsStories(m.pendingNewsStories)
        m.pendingNewsStories = invalid
    end if
    phase = screensaverNextPhase(m.rotationPage, m.nextNewsIndex, m.newsStories.Count(), m.telegramPosts.Count() > 0)
    m.rotationPage = phase.page
    m.nextNewsIndex = phase.nextIndex
    isAgenda = phase.page = "agenda"
    m.heading.visible = isAgenda
    m.today.visible = isAgenda
    m.todayBody.visible = isAgenda
    m.agenda.visible = isAgenda
    m.weatherGroup.visible = isAgenda
    m.newsGroup.visible = phase.page = "news"
    m.telegramGroup.visible = phase.page = "telegram"
    if isAgenda
        m.pageTimer.control = "start"
    else if phase.page = "news"
        m.pageTimer.control = "stop"
        article = m.newsStories[phase.index]
        heading = "KAGI NEWS  /  " + ucase(article.category) + "  /  " + (phase.index + 1).ToStr() + " OF " + m.newsStories.Count().ToStr() + "  /  " + article.edition
        if m.newsDelayed then heading = heading + "  /  Update delayed"
        m.top.FindNode("newsHeading").text = heading
        m.top.FindNode("newsTitle").text = article.title
        m.top.FindNode("newsSummary").text = article.summary
        m.top.FindNode("newsUrl").text = shortText(article.sourceUrl, 180)
    else
        m.pageTimer.control = "stop"
        phase.duration = renderTelegramPage()
    end if
    m.rotationTimer.control = "stop"
    m.rotationTimer.duration = phase.duration
    m.rotationTimer.control = "start"
end sub

sub loadWeather()
    if m.interactive = true
        if not appCanFetch("weather") then return
        if m.weatherTask.state = "run" then return
        m.weatherTask.location = m.appCommitted.weatherLocation
        appRequestStarted("weather")
    end if
    if m.weatherTask.state <> "run" then m.weatherTask.control = "run"
end sub

sub onWeatherChanged()
    if m.interactive = true
        if not appAcceptResult("weather") then return
    end if
    result = m.weatherTask.result
    if result = invalid then return
    if m.interactive = true
        appDataArrived("weather", result.available)
        if result.available
            m.appWeatherRaw = result
            result = appWeatherUnits(result, m.appSettings.units)
            m.top.FindNode("weatherLocation").text = ucase(appWeatherCity(m.appCommitted.weatherLocation, m.appWeatherRaw))
        end if
    end if
    if result.available
        m.temperature.text = result.temperature
        m.weatherIcon.uri = result.icon
        m.weatherIcon.visible = true
        m.weatherDescription.text = result.description
        m.hasWeather = true
        renderForecast(result)
    else if m.hasWeather
        m.weatherDescription.text = "Weather data delayed"
    else
        m.temperature.text = "--" + chr(176) + "C"
        m.weatherIcon.visible = false
        m.weatherDescription.text = "Weather unavailable"
    end if
end sub

sub onAgendaChanged()
    if m.interactive = true
        if not appAcceptResult("calendar") then return
        appDataArrived("calendar", m.calendarTask.success)
    end if
    if m.calendarTask.agenda = "" then return
    m.agendaLines = m.calendarTask.agenda.Split(chr(10))
    if m.interactive = true
        pageCount = int((m.agendaLines.Count() + 5) / 6)
        if pageCount > 0 then m.agendaPage = m.agendaPage mod pageCount
    else
        m.agendaPage = 0
    end if
    showAgendaPage()
end sub

sub onTodayChanged()
    if m.interactive = true
        if not appAcceptResult("calendar") then return
    end if
    if m.todayItems.Count() = 0
        m.today.text = m.calendarTask.today
        if m.calendarTask.today.Instr("unavailable") >= 0 then m.todayBody.text = "Calendar unavailable"
    end if
end sub

sub onTodayItemsChanged()
    if m.interactive = true
        if not appAcceptResult("calendar") then return
    end if
    m.todayItems = m.calendarTask.todayItems
    if m.interactive = true
        pageCount = int((m.todayItems.Count() + 2) / 3)
        if pageCount > 0 then m.todayPage = m.todayPage mod pageCount
    else
        m.todayPage = 0
    end if
    showTodayPage()
    if m.interactive = true then appApplyLayout()
end sub

sub showTodayPage()
    count = m.todayItems.Count()
    noun = " events"
    if count = 1 then noun = " event"
    m.today.text = "TODAY  /  " + count.ToStr() + noun
    if count = 0
        m.todayBody.text = "No events today"
        return
    end if
    pages = int((count + 2) / 3)
    if pages > 1 then m.today.text = m.today.text + "  /  " + (m.todayPage + 1).ToStr() + " OF " + pages.ToStr()
    first = m.todayPage * 3
    last = first + 2
    if last >= count then last = count - 1
    text = ""
    for i = first to last
        if text <> "" then text = text + chr(10)
        text = text + m.todayItems[i].timeLabel + "   " + shortText(m.todayItems[i].title, 48)
    end for
    m.todayBody.text = text
    m.todayBody.font.size = 34
    if count <= 2 then m.todayBody.font.size = 38
    if m.interactive = true then m.todayBody.font.size = appBodySize(m.appSettings)
end sub

sub nextAgendaPage()
    if m.interactive = true
        if m.appSleeping or m.appManualPaused or not m.appPlaying or m.appMenu <> "" then return
    end if
    todayPages = int((m.todayItems.Count() + 2) / 3)
    if todayPages > 1
        m.todayPage = (m.todayPage + 1) mod todayPages
        showTodayPage()
    end if
    pages = int((m.agendaLines.Count() + 5) / 6)
    if pages > 1
        m.agendaPage = (m.agendaPage + 1) mod pages
        showAgendaPage()
    end if
    if m.interactive = true then appApplyLayout()
end sub

sub showAgendaPage()
    text = ""
    first = m.agendaPage * 6
    last = first + 5
    if last >= m.agendaLines.Count() then last = m.agendaLines.Count() - 1
    for i = first to last
        if text <> "" then text = text + chr(10)
        text = text + m.agendaLines[i]
    end for
    pages = int((m.agendaLines.Count() + 5) / 6)
    if pages > 1 then text = text + chr(10) + "Page " + (m.agendaPage + 1).ToStr() + " / " + pages.ToStr()
    m.agenda.text = text
end sub

sub renderForecast(result as object)
    m.weatherChart.removeChildrenIndex(m.weatherChart.getChildCount(), 0)
    m.weatherForecast.removeChildrenIndex(m.weatherForecast.getChildCount(), 0)
    unit = "C"
    if m.interactive = true then unit = m.appSettings.units
    m.weatherRange.text = "Low " + result.low.ToStr() + chr(176) + unit + "   /   High " + result.high.ToStr() + chr(176) + unit
    span = result.high - result.low
    if span < 1 then span = 1
    for i = 0 to result.forecast.Count() - 1
        point = result.forecast[i]
        height = 12 + ((point.value - result.low) / span) * 110
        bar = m.weatherChart.createChild("Rectangle")
        bar.width = 14
        bar.height = height
        bar.color = m.displayColor
        bar.translation = [i * 25, 130 - height]
        if i mod 6 = 0 or i = 23
            label = createWeatherLabel(m.weatherChart, point.hour, 20, 80, 30)
            x = i * 25 - 8
            if i = 23 then x = 520
            label.translation = [x, 145]
        end if
        if i mod 3 = 0
            sample = int(i / 3)
            x = (sample mod 4) * 160
            y = int(sample / 4) * 115
            label = createWeatherLabel(m.weatherForecast, point.hour, 22, 150, 35)
            label.translation = [x, y]
            icon = m.weatherForecast.createChild("Poster")
            icon.uri = point.icon
            icon.blendColor = m.iconTint
            icon.width = 40
            icon.height = 40
            icon.translation = [x, y + 40]
            label = createWeatherLabel(m.weatherForecast, point.temperature, 26, 110, 40)
            label.translation = [x + 45, y + 40]
        end if
    end for
end sub

function createWeatherLabel(parent as object, text as string, size as integer, width as integer, height as integer) as object
    label = parent.createChild("Label")
    label.text = text
    color = m.displayColor
    if color = "" then color = "0x0C0C0CFF"
    label.color = color
    label.width = width
    label.height = height
    font = CreateObject("roSGNode", "Font")
    font.uri = "font:SystemFontFile"
    font.size = size
    label.font = font
    return label
end function

function twoDigits(value as integer) as string
    if value < 10 then return "0" + value.ToStr()
    return value.ToStr()
end function
