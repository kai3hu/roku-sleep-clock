' Bounded seven-day iCalendar expansion, including Outlook recurrence overrides.
function buildWeekAgenda(body as string, nowSeconds as integer, days = 7 as integer) as string
    rows = calAgendaRows(body, nowSeconds, nowSeconds + days * 86400)
    if rows.Count() = 0 then return "No events in the next " + days.ToStr() + " days"
    output = ""
    for each row in rows
        if output <> "" then output = output + chr(10)
        output = output + row.text
    end for
    return output
end function

' Convert device-local wall time without assuming a 24-hour DST transition day.
function calDeviceUtc(wall as integer) as integer
    stamp = wall
    for i = 0 to 2
        date = calDate(stamp)
        date.ToLocalTime()
        stamp = wall - (date.AsSeconds() - stamp)
    end for
    return stamp
end function

function buildTodayAgenda(body as string, nowSeconds as integer) as string
    rows = calTodayRows(body, nowSeconds)
    if rows.Count() = 0 then return "TODAY  /  No events"
    first = rows[0]
    for each row in rows
        if row.finish > nowSeconds
            first = row
            exit for
        end if
    end for
    countLabel = " event"
    if rows.Count() <> 1 then countLabel = " events"
    title = first.title
    if len(title) > 28 then title = left(title, 25) + "..."
    return "TODAY  /  " + rows.Count().ToStr() + countLabel + "  /  " + first.timeLabel + " " + title
end function

function calTodayRows(body as string, nowSeconds as integer) as object
    local = calDate(nowSeconds)
    local.ToLocalTime()
    raw = local.GetYear().ToStr() + calTwo(local.GetMonth()) + calTwo(local.GetDayOfMonth())
    wall = calWall(raw)
    return calAgendaRows(body, calDeviceUtc(wall), calDeviceUtc(wall + 86400))
end function

function calAgendaRows(body as string, windowStart as integer, windowEnd as integer) as object
    parsed = calParse(body)
    rows = []
    overrides = {}
    for each event in parsed.events
        if event.rid <> ""
            key = event.uid + "|" + calUtc(event.rid, event.ridTz, parsed.zones).ToStr()
            overrides[key] = true
        end if
    end for

    for each event in parsed.events
        if not event.cancelled and event.start <> "" and event.summary <> ""
            startWall = calWall(event.start)
            startUtc = calUtc(event.start, event.tz, parsed.zones)
            duration = 3600
            if Len(event.start) = 8 then duration = 86400
            if event.finish <> "" then duration = calUtc(event.finish, event.endTz, parsed.zones) - startUtc
            if duration < 0 then duration = 0
            candidates = [startWall]
            if event.rule.DoesExist("FREQ") and event.rid = ""
                candidates = calExpand(event, startWall, windowStart - duration - 86400, windowEnd + 86400, parsed.zones)
            end if
            for each extra in event.rdates
                candidates.Push(calWall(extra))
            end for
            seen = {}
            for each candidate in candidates
                raw = calCompact(candidate, Len(event.start) = 8)
                if Right(event.start, 1) = "Z" then raw = raw + "Z"
                occurrence = calUtc(raw, event.tz, parsed.zones)
                key = event.uid + "|" + occurrence.ToStr()
                excluded = false
                for each exdate in event.exdates
                    if calUtc(exdate, event.tz, parsed.zones) = occurrence then excluded = true
                end for
                if event.rid = "" and overrides.DoesExist(key) then excluded = true
                if not excluded and not seen.DoesExist(key) and occurrence < windowEnd and occurrence + duration > windowStart
                    seen[key] = true
                    local = calDate(occurrence)
                    local.ToLocalTime()
                    timeLabel = calTwo(local.GetHours()) + ":" + calTwo(local.GetMinutes())
                    if Len(event.start) = 8 then timeLabel = "ALL DAY"
                    days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                    label = days[local.GetDayOfWeek()] + " " + calTwo(local.GetMonth()) + "/" + calTwo(local.GetDayOfMonth())
                    title = event.summary
                    if Len(title) > 40 then title = Left(title, 37) + "..."
                    rows.Push({ sort: occurrence, finish:occurrence + duration, title:event.summary, timeLabel:timeLabel, text: label + "   " + timeLabel + "   " + title })
                end if
            end for
        end if
    end for
    rows.SortBy("sort")
    return rows
end function

function calParse(body as string) as object
    lines = []
    for each line in body.Replace(chr(13), "").Split(chr(10))
        if (Left(line, 1) = " " or Left(line, 1) = chr(9)) and lines.Count() > 0
            index = lines.Count() - 1
            lines[index] = lines[index] + line.Mid(1)
        else
            lines.Push(line)
        end if
    end for
    result = { events: [], zones: {} }
    event = invalid
    zone = ""
    phase = invalid
    inAlarm = false
    for each line in lines
        prop = calProperty(line)
        if line = "BEGIN:VEVENT"
            event = { uid: "", summary: "", start: "", finish: "", tz: "", endTz: "", rid: "", ridTz: "", rule: {}, exdates: [], rdates: [], cancelled: false }
        else if line = "END:VEVENT"
            if event <> invalid then result.events.Push(event)
            event = invalid
        else if line = "BEGIN:VALARM"
            inAlarm = true
        else if line = "END:VALARM"
            inAlarm = false
        else if event <> invalid and not inAlarm
            if prop.name = "UID" then event.uid = prop.value
            if prop.name = "SUMMARY" then event.summary = calClean(prop.value)
            if prop.name = "DTSTART"
                event.start = prop.value
                event.tz = prop.tz
            end if
            if prop.name = "DTEND"
                event.finish = prop.value
                event.endTz = prop.tz
            end if
            if prop.name = "RECURRENCE-ID"
                event.rid = prop.value
                event.ridTz = prop.tz
            end if
            if prop.name = "RRULE" then event.rule = calRule(prop.value)
            if prop.name = "EXDATE"
                for each value in prop.value.Split(",")
                    event.exdates.Push(value)
                end for
            end if
            if prop.name = "RDATE"
                for each value in prop.value.Split(",")
                    event.rdates.Push(value)
                end for
            end if
            if prop.name = "STATUS" then event.cancelled = prop.value = "CANCELLED"
        else
            if prop.name = "TZID"
                zone = prop.value
                result.zones[zone] = []
            end if
            if line = "BEGIN:STANDARD" or line = "BEGIN:DAYLIGHT" then phase = { start: "", offset: 0, rule: {} }
            if phase <> invalid
                if prop.name = "DTSTART" then phase.start = prop.value
                if prop.name = "TZOFFSETTO" then phase.offset = calParseOffset(prop.value)
                if prop.name = "RRULE" then phase.rule = calRule(prop.value)
                if line = "END:STANDARD" or line = "END:DAYLIGHT"
                    if zone <> "" then result.zones[zone].Push(phase)
                    phase = invalid
                end if
            end if
            if line = "END:VTIMEZONE" then zone = ""
        end if
    end for
    return result
end function

function calProperty(line as string) as object
    result = { name: "", value: "", tz: "" }
    colon = line.Instr(":")
    if colon < 0 then return result
    parts = line.Left(colon).Split(";")
    result.name = UCase(parts[0])
    result.value = line.Mid(colon + 1)
    for each part in parts
        if Left(part, 5) = "TZID=" then result.tz = part.Mid(5).Replace(chr(34), "")
    end for
    return result
end function

function calRule(value as string) as object
    rule = {}
    for each part in value.Split(";")
        equal = part.Instr("=")
        if equal > 0 then rule[part.Left(equal)] = part.Mid(equal + 1)
    end for
    return rule
end function

function calDate(seconds as integer) as object
    dt = CreateObject("roDateTime")
    dt.FromSeconds(seconds)
    return dt
end function

function calWall(raw as string) as integer
    if Len(raw) < 8 then return 0
    iso = raw.Left(4) + "-" + raw.Mid(4, 2) + "-" + raw.Mid(6, 2) + "T00:00:00.000"
    if Len(raw) >= 15 then iso = iso.Left(11) + raw.Mid(9, 2) + ":" + raw.Mid(11, 2) + ":" + raw.Mid(13, 2) + ".000"
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(iso)
    return dt.AsSeconds()
end function

function calUtc(raw as string, tz as string, zones as object) as integer
    wall = calWall(raw)
    if Right(raw, 1) = "Z" then return wall
    return wall - calOffset(wall, tz, zones)
end function

function calParseOffset(raw as string) as integer
    sign = 1
    if Left(raw, 1) = "-" then sign = -1
    return sign * (Val(raw.Mid(1, 2)) * 3600 + Val(raw.Mid(3, 2)) * 60)
end function

function calOffset(wall as integer, tz as string, zones as object) as integer
    date = calDate(wall)
    year = date.GetYear()
    if tz <> "" and zones.DoesExist(tz)
        selected = -2147483647
        offset = 0
        for each phase in zones[tz]
            if not phase.rule.DoesExist("FREQ")
                offset = phase.offset
            else
                for y = year - 1 to year
                    month = Val(phase.rule.BYMONTH)
                    day = 1
                    if phase.rule.DoesExist("BYDAY") then day = calNthDay(y, month, phase.rule.BYDAY)
                    if phase.rule.DoesExist("BYMONTHDAY") then day = Val(phase.rule.BYMONTHDAY)
                    raw = y.ToStr() + calTwo(month) + calTwo(day) + phase.start.Mid(8)
                    transition = calWall(raw)
                    if transition <= wall and transition > selected
                        selected = transition
                        offset = phase.offset
                    end if
                end for
            end if
        end for
        return offset
    end if
    ' Floating event dates use Tuscaloosa local time. Common Windows TZIDs
    ' are also accepted when the feed omits VTIMEZONE definitions.
    if tz = "China Standard Time" or tz = "Asia/Shanghai" then return 28800
    base = -21600
    if tz = "Eastern Standard Time" or tz = "America/New_York" then base = -18000
    if tz = "Mountain Standard Time" or tz = "America/Denver" then base = -25200
    if tz = "Pacific Standard Time" or tz = "America/Los_Angeles" then base = -28800
    march = calWall(year.ToStr() + "03" + calTwo(calNthDay(year, 3, "2SU")) + "T020000")
    november = calWall(year.ToStr() + "11" + calTwo(calNthDay(year, 11, "1SU")) + "T020000")
    if wall >= march and wall < november then return base + 3600
    return base
end function

function calNthDay(year as integer, month as integer, token as string) as integer
    ordinal = Val(Left(token, Len(token) - 2))
    if ordinal = 0 then ordinal = 1
    weekdays = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 }
    weekday = weekdays[Right(token, 2)]
    first = calDate(calWall(year.ToStr() + calTwo(month) + "01"))
    if ordinal > 0 then return 1 + ((weekday - first.GetDayOfWeek() + 7) mod 7) + (ordinal - 1) * 7
    nextMonth = month + 1
    nextYear = year
    if nextMonth = 13
        nextMonth = 1
        nextYear = year + 1
    end if
    last = calDate(calWall(nextYear.ToStr() + calTwo(nextMonth) + "01") - 86400)
    return last.GetDayOfMonth() - ((last.GetDayOfWeek() - weekday + 7) mod 7) + (ordinal + 1) * 7
end function

function calExpand(event as object, first as integer, low as integer, high as integer, zones as object) as object
    output = []
    rule = event.rule
    untilUtc = 2147483647
    if rule.DoesExist("UNTIL") then untilUtc = calUtc(rule.UNTIL, event.tz, zones)
    countLimit = 2147483647
    if rule.DoesExist("COUNT") then countLimit = Val(rule.COUNT)
    ' Only the nearby dates need expansion unless COUNT requires a series count.
    cursor = first
    if not rule.DoesExist("COUNT") and cursor < low
        cursor = first + int((low - first) / 86400) * 86400
    end if
    matched = 0
    steps = 0
    while cursor < high and steps < 40000
        if calMatches(cursor, first, rule)
            matched = matched + 1
            raw = calCompact(cursor, Len(event.start) = 8)
            if Right(event.start, 1) = "Z" then raw = raw + "Z"
            utc = calUtc(raw, event.tz, zones)
            if utc > untilUtc or matched > countLimit then exit while
            if cursor >= low then output.Push(cursor)
        end if
        cursor = cursor + 86400
        steps = steps + 1
    end while
    return output
end function

function calMatches(candidate as integer, first as integer, rule as object) as boolean
    if candidate < first then return false
    date = calDate(candidate)
    start = calDate(first)
    interval = 1
    if rule.DoesExist("INTERVAL") then interval = Val(rule.INTERVAL)
    if interval < 1 then interval = 1
    delta = int((candidate - first) / 86400)
    frequency = rule.FREQ
    if frequency = "DAILY"
        if delta mod interval <> 0 then return false
    else if frequency = "WEEKLY"
        wkst = 1
        weekdays = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 }
        if rule.DoesExist("WKST") then wkst = weekdays[rule.WKST]
        week = int((delta + ((start.GetDayOfWeek() - wkst + 7) mod 7)) / 7)
        if week mod interval <> 0 then return false
        if not rule.DoesExist("BYDAY") and date.GetDayOfWeek() <> start.GetDayOfWeek() then return false
    else if frequency = "MONTHLY"
        months = (date.GetYear() - start.GetYear()) * 12 + date.GetMonth() - start.GetMonth()
        if months mod interval <> 0 then return false
        if not rule.DoesExist("BYDAY") and not rule.DoesExist("BYMONTHDAY") and date.GetDayOfMonth() <> start.GetDayOfMonth() then return false
    else if frequency = "YEARLY"
        if (date.GetYear() - start.GetYear()) mod interval <> 0 then return false
        if not rule.DoesExist("BYMONTH") and date.GetMonth() <> start.GetMonth() then return false
        if not rule.DoesExist("BYDAY") and not rule.DoesExist("BYMONTHDAY") and date.GetDayOfMonth() <> start.GetDayOfMonth() then return false
    else
        return candidate = first
    end if
    if rule.DoesExist("BYMONTH") and not calListHas(rule.BYMONTH, date.GetMonth().ToStr()) then return false
    if rule.DoesExist("BYMONTHDAY") and not calListHas(rule.BYMONTHDAY, date.GetDayOfMonth().ToStr()) then return false
    if rule.DoesExist("BYDAY")
        names = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
        found = false
        for each token in rule.BYDAY.Split(",")
            if Right(token, 2) = names[date.GetDayOfWeek()]
                if Len(token) = 2
                    found = true
                else if date.GetDayOfMonth() = calNthDay(date.GetYear(), date.GetMonth(), token)
                    found = true
                end if
            end if
        end for
        if not found then return false
    end if
    return true
end function

function calListHas(list as string, token as string) as boolean
    for each value in list.Split(",")
        if value = token then return true
    end for
    return false
end function

function calCompact(seconds as integer, allDay as boolean) as string
    dt = calDate(seconds)
    raw = dt.GetYear().ToStr() + calTwo(dt.GetMonth()) + calTwo(dt.GetDayOfMonth())
    if not allDay then raw = raw + "T" + calTwo(dt.GetHours()) + calTwo(dt.GetMinutes()) + calTwo(dt.GetSeconds())
    return raw
end function

function calTwo(value as integer) as string
    if value < 10 then return "0" + value.ToStr()
    return value.ToStr()
end function

function calClean(value as string) as string
    slash = chr(92)
    return value.Replace(slash + "n", " ").Replace(slash + "N", " ").Replace(slash + ",", ",").Replace(slash + ";", ";").Replace(slash + slash, slash)
end function
