' Pure settings and navigation helpers shared by the app, worker and tests.
function appPageIds() as object
    return ["dashboard", "agenda", "weather", "news", "telegram", "clock"]
end function

function appPageName(id as string) as string
    names = {dashboard:"Dashboard", agenda:"Agenda", weather:"Weather", news:"News", telegram:"Telegram", clock:"Clock", last:"Last viewed"}
    if names[id] <> invalid then return names[id]
    return id
end function

function appDefaults() as object
    return {schema:1, order:appPageIds(), enabled:{dashboard:true,agenda:false,weather:false,news:true,telegram:true,clock:false}, startup:"dashboard", lastPage:"dashboard", layout:"Balanced", fontSize:"Medium", clockSize:110, hourFormat:"24h", showDate:false, margin:100, nightStart:23, nightEnd:7, dayLevel:"Low", nightLevel:"Extra dim", tone:"Gray", wakeBoost:false, displayTimeout:300, autoplay:true, resumeAfter:180, dashboardSeconds:120, agendaSeconds:120, weatherSeconds:60, newsSeconds:60, clockSeconds:120, readingSpeed:"Normal", calendarDays:7, showEnded:true, calendarAllowed:true, calendarUrl:"", useBundledCalendar:true, weatherLocation:"35406", units:"C", technology:true, science:true, economy:true, telegramChannel:"DNSPODT", sourceArticles:true, clockStandby:false, keepRunning:false}
end function

function appContains(values as object, value as dynamic) as boolean
    kind = appValueKind(value)
    if kind = "unsupported" then return false
    for each item in values
        if appValueKind(item) = kind
            if item = value then return true
        end if
    end for
    return false
end function

function appValueKind(value as dynamic) as string
    if isText(value) then return "text"
    kind = type(value)
    if kind = "Boolean" or kind = "roBoolean" then return "boolean"
    for each numeric in ["Integer","roInt","roInteger","Float","roFloat","Double","roDouble","LongInteger","roLongInteger"]
        if kind = numeric then return "number"
    end for
    return "unsupported"
end function

function appBodySize(settings as object) as integer
    if settings.fontSize = "Small" then return 30
    if settings.fontSize = "Large" then return 38
    return 34
end function

function appSmallSize(settings as object) as integer
    if settings.fontSize = "Small" then return 22
    if settings.fontSize = "Large" then return 28
    return 24
end function

function appTelegramFontSize(settings as object) as integer
    if settings.fontSize = "Small" then return 24
    if settings.fontSize = "Large" then return 36
    return 30
end function

function appWeatherUnits(raw as object, unit as string) as object
    if unit = "C" then return raw
    result = {available:raw.available,description:raw.description,icon:raw.icon,forecast:[],low:int(raw.low * 1.8 + 32.5),high:int(raw.high * 1.8 + 32.5)}
    if isText(raw.city) then result.city = raw.city
    celsius = val(raw.temperature)
    result.temperature = int(celsius * 1.8 + 32.5).ToStr() + chr(176) + "F"
    for each point in raw.forecast
        value = int(point.value * 1.8 + 32.5)
        result.forecast.Push({timestamp:point.timestamp,hour:point.hour,value:value,temperature:value.ToStr() + chr(176) + "F",icon:point.icon})
    end for
    return result
end function

' Display geography, never the postal code used to look it up.
function appWeatherCity(location as string, raw = invalid as dynamic) as string
    if type(raw) = "roAssociativeArray"
        if isText(raw.city)
            city = appStripPostalCode(raw.city)
            if city <> "" then return city
        end if
    end if
    if location.Trim() = "35406" then return "Tuscaloosa"
    city = appStripPostalCode(location.Split(",")[0])
    if city <> "" then return city
    return "Weather"
end function

function appStripPostalCode(text as string) as string
    text = CreateObject("roRegex", "\b[0-9]{5}(-[0-9]{4})?\b", "").ReplaceAll(text, " ")
    return CreateObject("roRegex", "[ ]+", "").ReplaceAll(text, " ").Trim()
end function

function appSettingRows(group as string) as object
    if group = "Pages"
        rows = [{key:"startup",label:"Startup page",values:["last","dashboard","agenda","weather","news","telegram","clock"]}]
        for each id in appPageIds()
            rows.Push({key:id,label:appPageName(id),kind:"page"})
        end for
        return rows
    end if
    if group = "Layout"
        return [{key:"layout",label:"Dashboard layout",values:["Balanced","Agenda Focus","Minimal"]},{key:"fontSize",label:"Text size",values:["Small","Medium","Large"]},{key:"clockSize",label:"Clock size",values:[90,110,140]},{key:"hourFormat",label:"Clock format",values:["24h","12h"]},{key:"showDate",label:"Show date",values:[false,true]},{key:"margin",label:"Safe margins (%)",values:[90,95,100]},{key:"resetLayout",label:"Restore layout defaults",kind:"action"}]
    end if
    if group = "Display"
        return [{key:"displayTimeout",label:"Black screen after idle (seconds; 0=Never)",values:[0,60,180,300,600,1800,3600]},{key:"clockStandby",label:"Show clock instead of black on idle",values:[false,true]},{key:"keepRunning",label:"Keep running (Experimental; 10 s every hour)",values:[false,true]},{key:"nightStart",label:"Night starts (local hour)",values:appHours()},{key:"nightEnd",label:"Night ends (local hour)",values:appHours()},{key:"dayLevel",label:"Day text brightness",values:["Extra dim","Low","Medium"]},{key:"nightLevel",label:"Night text brightness",values:["Extra dim","Low","Medium"]},{key:"tone",label:"Text tone",values:["Gray","Warm gray"]},{key:"wakeBoost",label:"Temporarily brighten while browsing",values:[false,true]}]
    end if
    if group = "Rotation"
        times = [30,60,90,120,180,300]
        return [{key:"autoplay",label:"Automatic rotation",values:[false,true]},{key:"resumeAfter",label:"Resume after manual browsing (0=Never)",values:[0,60,180,300]},{key:"dashboardSeconds",label:"Dashboard seconds",values:times},{key:"agendaSeconds",label:"Agenda seconds",values:times},{key:"weatherSeconds",label:"Weather seconds",values:times},{key:"newsSeconds",label:"News seconds",values:times},{key:"clockSeconds",label:"Clock seconds",values:times},{key:"readingSpeed",label:"Article reading speed",values:["Slow","Normal","Fast"]}]
    end if
    if group = "Content"
        return [{key:"calendarDays",label:"Agenda range (days)",values:[1,3,7]},{key:"showEnded",label:"Include finished tasks today",values:[false,true]},{key:"calendarAllowed",label:"Outlook enabled",values:[false,true]},{key:"calendarUrl",label:"Set Outlook ICS link (hidden)",kind:"text"},{key:"clearCalendar",label:"Forget Outlook link and cached tasks",kind:"action"},{key:"weatherLocation",label:"Weather city or postal code",kind:"text"},{key:"units",label:"Temperature unit",values:["C","F"]},{key:"technology",label:"Technology news",values:[false,true]},{key:"science",label:"Science news",values:[false,true]},{key:"economy",label:"Economy news",values:[false,true]},{key:"telegramChannel",label:"Public Telegram channel",kind:"text"},{key:"sourceArticles",label:"Read Source articles instead of captions",values:[false,true]}]
    end if
    return [{key:"refreshAll",label:"Refresh enabled data sources now",kind:"action"},{key:"refreshCalendar",label:"Refresh Outlook",kind:"action"},{key:"refreshWeather",label:"Refresh weather",kind:"action"},{key:"refreshNews",label:"Refresh news",kind:"action"},{key:"refreshTelegram",label:"Refresh Telegram",kind:"action"},{key:"testKeepRunning",label:"Test keep-running pulse now",kind:"action"},{key:"cancelSettings",label:"Cancel changes",kind:"action"},{key:"saveSettings",label:"Save settings",kind:"action"}]
end function

function appHours() as object
    values = []
    for i = 0 to 23
        values.Push(i)
    end for
    return values
end function

function appNormalizeSettings(input as dynamic) as object
    settings = appDefaults()
    if type(input) <> "roAssociativeArray" then return settings
    for each group in ["Pages","Layout","Display","Rotation","Content"]
        for each row in appSettingRows(group)
            if row.values <> invalid
                if appContains(row.values, input[row.key]) then settings[row.key] = input[row.key]
            end if
        end for
    end for
    if type(input.enabled) = "roAssociativeArray"
        for each id in appPageIds()
            if type(input.enabled[id]) = "Boolean" or type(input.enabled[id]) = "roBoolean" then settings.enabled[id] = input.enabled[id]
        end for
    end if
    if type(input.order) = "roArray"
        settings.order = []
        for each id in input.order
            if appContains(appPageIds(), id) and not appContains(settings.order, id) then settings.order.Push(id)
        end for
        for each id in appPageIds()
            if not appContains(settings.order, id) then settings.order.Push(id)
        end for
    end if
    if isText(input.lastPage) and appContains(appPageIds(), input.lastPage) then settings.lastPage = input.lastPage
    if appEnabledPages(settings).Count() = 0 then settings.enabled.clock = true
    if isText(input.weatherLocation)
        if len(input.weatherLocation.Trim()) >= 2 and len(input.weatherLocation) <= 100 then settings.weatherLocation = input.weatherLocation.Trim()
    end if
    if isText(input.telegramChannel)
        channel = input.telegramChannel.Replace("https://t.me/", "").Replace("@", "").Trim()
        if CreateObject("roRegex", "^[A-Za-z][A-Za-z0-9_]{3,31}$", "").IsMatch(channel) then settings.telegramChannel = channel
    end if
    if isText(input.calendarUrl)
        if input.calendarUrl = "" or appValidCalendarUrl(input.calendarUrl) then settings.calendarUrl = input.calendarUrl
    end if
    if input.useBundledCalendar = false then settings.useBundledCalendar = false
    return settings
end function

function appValidCalendarUrl(url as string) as boolean
    if len(url) > 4096 then return false
    return CreateObject("roRegex", "^https://[^/ @]+/[^ " + chr(10) + chr(13) + "]+$", "i").IsMatch(url)
end function

function appEnabledPages(settings as object) as object
    result = []
    for each id in settings.order
        if settings.enabled[id] = true then result.Push(id)
    end for
    return result
end function

function appStartupPage(settings as object) as string
    page = settings.startup
    if page = "last" then page = settings.lastPage
    pages = appEnabledPages(settings)
    if appContains(pages, page) then return page
    return pages[0]
end function

function appNeighbor(settings as object, current as string, direction as integer) as string
    pages = appEnabledPages(settings)
    for i = 0 to pages.Count() - 1
        if pages[i] = current then return pages[(i + direction + pages.Count()) mod pages.Count()]
    end for
    return pages[0]
end function

function appNeedsData(settings as object, source as string) as boolean
    if source = "calendar" then return settings.calendarAllowed and (settings.enabled.dashboard or settings.enabled.agenda)
    if source = "weather" then return settings.enabled.dashboard or settings.enabled.weather
    if source = "news" then return settings.enabled.news and (settings.technology or settings.science or settings.economy)
    if source = "telegram" then return settings.enabled.telegram
    return false
end function

function appNight(settings as object, hour as integer) as boolean
    if settings.nightStart = settings.nightEnd then return false
    if settings.nightStart < settings.nightEnd then return hour >= settings.nightStart and hour < settings.nightEnd
    return hour >= settings.nightStart or hour < settings.nightEnd
end function

function appTextColor(settings as object, hour as integer, browsing = false as boolean) as string
    level = settings.dayLevel
    if appNight(settings, hour) then level = settings.nightLevel
    if browsing and settings.wakeBoost then level = "Medium"
    gray = {"Extra dim":"0x0C0C0CFF",Low:"0x242424FF",Medium:"0x484848FF"}
    warm = {"Extra dim":"0x0E0C0AFF",Low:"0x282420FF",Medium:"0x50483FFF"}
    if settings.tone = "Warm gray" then return warm[level]
    return gray[level]
end function

function appDuration(settings as object, page as string, readerSeconds = 60 as integer) as integer
    if page = "telegram"
        factor = 1.0
        if settings.readingSpeed = "Slow" then factor = 1.5
        if settings.readingSpeed = "Fast" then factor = 0.75
        return int(readerSeconds * factor)
    end if
    return settings[page + "Seconds"]
end function

function appIconTint(settings as object, hour as integer, browsing = false as boolean) as string
    level = settings.dayLevel
    if appNight(settings, hour) then level = settings.nightLevel
    if browsing and settings.wakeBoost then level = "Medium"
    if level = "Extra dim" then return "0x555555FF"
    return "0xFFFFFFFF"
end function

function appShouldSleep(settings as object, idleSeconds as integer, alreadySleeping as boolean) as boolean
    return not alreadySleeping and settings.displayTimeout > 0 and idleSeconds >= settings.displayTimeout
end function

function appMovePage(settings as object, id as string, direction as integer) as object
    order = settings.order
    for i = 0 to order.Count() - 1
        if order[i] = id
            other = i + direction
            if other >= 0 and other < order.Count()
                value = order[other]
                order[other] = id
                order[i] = value
            end if
            exit for
        end if
    end for
    return settings
end function
