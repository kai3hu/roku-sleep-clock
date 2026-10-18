sub init()
    m.top.backgroundURI = ""
    m.top.backgroundColor = "0x000000FF"
    m.content = m.top.FindNode("content")
    m.clock = m.top.FindNode("clock")
    m.agenda = m.top.FindNode("agenda")
    m.heading = m.top.FindNode("heading")
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

    m.tick.ObserveField("fire", "onTick")
    m.refresh.ObserveField("fire", "refreshData")
    m.calendarTask.ObserveField("agenda", "onAgendaChanged")
    m.weatherTask.ObserveField("result", "onWeatherChanged")
    m.pageTimer.ObserveField("fire", "nextAgendaPage")

    updateClock()
    loadCalendar()
    loadWeather()
    m.tick.control = "start"
    m.refresh.control = "start"
    m.pageTimer.control = "start"
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
        return
    end if
    if m.calendarTask.state = "run" then return
    m.calendarTask.uri = url
    m.calendarTask.control = "run"
end sub

sub refreshData()
    loadCalendar()
    loadWeather()
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

sub nextAgendaPage()
    pages = int((m.agendaLines.Count() + 11) / 12)
    if pages > 1
        m.agendaPage = (m.agendaPage + 1) mod pages
        showAgendaPage()
    end if
end sub

sub showAgendaPage()
    text = ""
    first = m.agendaPage * 12
    last = first + 11
    if last >= m.agendaLines.Count() then last = m.agendaLines.Count() - 1
    for i = first to last
        if text <> "" then text = text + chr(10)
        text = text + m.agendaLines[i]
    end for
    pages = int((m.agendaLines.Count() + 11) / 12)
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
