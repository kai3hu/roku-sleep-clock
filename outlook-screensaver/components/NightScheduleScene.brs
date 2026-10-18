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

    updateClock()
    loadCalendar()
    loadWeather()
    loadTelegram()
    loadNews()
    m.tick.control = "start"
    m.refresh.control = "start"
    m.pageTimer.control = "start"
    m.rotationTimer.control = "start"
end sub

sub onTick()
    updateClock()
end sub

sub updateClock()
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    hour = now.GetHours()
    minute = now.GetMinutes()
    m.clock.text = twoDigits(hour) + ":" + twoDigits(minute)
    applyDisplaySchedule(hour)
end sub

sub applyDisplaySchedule(localHour as integer)
    color = scheduleTextColor(localHour)
    if m.displayColor = color then return
    m.displayColor = color
    m.iconTint = scheduleIconTint(localHour)
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
    url = GetCalendarIcsUrl()
    if url = ""
        m.agenda.text = "Add your Outlook ICS link in source/config.brs"
        m.today.text = "TODAY  /  Calendar not configured"
        m.todayBody.text = "Add your Outlook calendar to see today's schedule."
        return
    end if
    if m.calendarTask.state = "run" then return
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
    if m.telegramTask.state <> "run" then m.telegramTask.control = "run"
end sub

sub onTelegramChanged()
    result = m.telegramTask.result
    if result = invalid then return
    if result.available
        if type(result.pages) <> "roArray" then return
        if result.pages.Count() = 0 then return
        m.telegramPosts = result.posts
        m.telegramAvailablePages = result.pages
        m.telegramUpdated = telegramLocalTime(result.fetchedAt)
        m.telegramDelayed = false
    else
        m.telegramDelayed = true
    end if
    ' Render only at page entry so a refresh never interrupts reading.
end sub

sub renderTelegramPage()
    m.telegramGrid.removeChildrenIndex(m.telegramGrid.getChildCount(), 0)
    if m.telegramPageIndex >= m.telegramPages.Count()
        ' Only consume precomputed data. Never register fonts or paginate on RENDER.
        m.telegramPages = m.telegramAvailablePages
        m.telegramPageIndex = 0
        m.telegramPagesUpdated = m.telegramUpdated
    end if
    if m.telegramPages.Count() = 0 then return
    cards = m.telegramPages[m.telegramPageIndex]
    for each card in cards
        post = card.post
        metaText = telegramLocalTime(post.timestamp) + "  /  t.me/" + telegramChannel() + "/" + post.id.ToStr()
        if card.continued then metaText = metaText + "  /  Continued"
        meta = createWeatherLabel(m.telegramGrid, metaText, 20, card.width, 30)
        meta.translation = [card.x, card.y]
        body = createWeatherLabel(m.telegramGrid, card.text, 26, card.width, card.height)
        body.translation = [card.x, card.y + 35]
        body.wrap = true
        body.numLines = card.lines
        body.font.uri = "pkg:/fonts/NotoSansSC-Regular.otf"
        body.font.fallbackGlyph = "u0020"
    end for
    status = "https://t.me/" + telegramChannel() + "  /  Page " + (m.telegramPageIndex + 1).ToStr() + " of " + m.telegramPages.Count().ToStr() + "  /  Checked " + m.telegramPagesUpdated + "  /  Full text"
    if m.telegramDelayed then status = status + "  /  Update delayed"
    m.top.FindNode("telegramStatus").text = status
    m.telegramPageIndex = m.telegramPageIndex + 1
end sub

sub loadNews()
    if m.newsTask.state = "run" then return
    m.newsTask.control = "run"
end sub

sub onNewsChanged()
    result = m.newsTask.result
    if result = invalid then return
    m.newsDelayed = result.delayed
    if type(result.stories) <> "roArray" then return
    if result.stories.Count() = 0 then return
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
        renderTelegramPage()
    end if
    m.rotationTimer.control = "stop"
    m.rotationTimer.duration = phase.duration
    m.rotationTimer.control = "start"
end sub

sub loadWeather()
    if m.weatherTask.state <> "run" then m.weatherTask.control = "run"
end sub

sub onWeatherChanged()
    result = m.weatherTask.result
    if result = invalid then return
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
    if m.calendarTask.agenda = "" then return
    m.agendaLines = m.calendarTask.agenda.Split(chr(10))
    m.agendaPage = 0
    showAgendaPage()
end sub

sub onTodayChanged()
    if m.todayItems.Count() = 0
        m.today.text = m.calendarTask.today
        if m.calendarTask.today.Instr("unavailable") >= 0 then m.todayBody.text = "Calendar unavailable"
    end if
end sub

sub onTodayItemsChanged()
    m.todayItems = m.calendarTask.todayItems
    m.todayPage = 0
    showTodayPage()
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
end sub

sub nextAgendaPage()
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
    m.weatherRange.text = "Low " + result.low.ToStr() + chr(176) + "C   /   High " + result.high.ToStr() + chr(176) + "C"
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
    label.color = m.displayColor
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
