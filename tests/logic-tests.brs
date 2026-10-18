sub Main()
    m.failures = 0
    expect(not showScheduleDetails(0), "00:00 starts clock-only mode")
    expect(not showScheduleDetails(6), "06:59 remains clock-only")
    expect(showScheduleDetails(7), "07:00 restores agenda and weather")
    expect(showScheduleDetails(23), "23:59 still displays extra information")
    now = calWall("20261017T180000Z")
    body = "BEGIN:VCALENDAR" + chr(10)
    body = body + eventFixture("past", "Past event", "20261016T090000Z", "20261016T100000Z", "")
    body = body + eventFixture("later", "Later event", "20261020T090000Z", "20261020T100000Z", "")
    body = body + eventFixture("next", "Next event", "20261018T090000Z", "20261018T100000Z", "")
    body = body + eventFixture("outside", "Outside window", "20261025T090000Z", "20261025T100000Z", "")
    body = body + "END:VCALENDAR"
    output = buildWeekAgenda(body, now)
    expect(output.Instr("Past event") = -1, "Past events excluded")
    expect(output.Instr("Outside window") = -1, "Events beyond 7 days excluded")
    expect(output.Instr("Next event") >= 0 and output.Instr("Later event") > output.Instr("Next event"), "Events sorted")

    body = "BEGIN:VCALENDAR" + chr(10)
    body = body + eventFixture("weekly", "Weekly meeting", "20261005T090000Z", "20261005T100000Z", "RRULE:FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261030T000000Z" + chr(10))
    body = body + eventFixture("weekly", "Moved meeting", "20261020T110000Z", "20261020T120000Z", "RECURRENCE-ID:20261019T090000Z" + chr(10))
    body = body + eventFixture("weekly", "Cancelled instance", "20261021T090000Z", "20261021T100000Z", "RECURRENCE-ID:20261021T090000Z" + chr(10) + "STATUS:CANCELLED" + chr(10))
    body = body + "END:VCALENDAR"
    output = buildWeekAgenda(body, now)
    expect(output.Instr("Moved meeting") >= 0, "Moved recurrence included")
    expect(output.Instr("Weekly meeting") = -1 and output.Instr("Cancelled instance") = -1, "Overrides suppress original and cancelled occurrences")

    body = "BEGIN:VCALENDAR" + chr(10)
    body = body + eventFixture("daily", "Daily meeting", "20261016T090000Z", "20261016T100000Z", "RRULE:FREQ=DAILY;COUNT=4" + chr(10) + "EXDATE:20261018T090000Z" + chr(10))
    body = body + eventFixture("all", "All day", "20261017", "20261018", "")
    body = body + "END:VCALENDAR"
    output = buildWeekAgenda(body, now)
    expect(output.Split("Daily meeting").Count() = 2, "COUNT and EXDATE respected")
    expect(output.Instr("ALL DAY") >= 0, "Ongoing all-day event retained")
    expect(calUtc("20261019T090000", "Eastern Standard Time", {}) = calWall("20261019T130000Z"), "Eastern DST conversion")
    expect(calUtc("20261219T090000", "Central Standard Time", {}) = calWall("20261219T150000Z"), "Central winter conversion")
    expect(calUtc("20261019T090000", "China Standard Time", {}) = calWall("20261019T010000Z"), "China conversion")
    expect(calNthDay(2026, 11, "1SU") = 1 and calNthDay(2026, 3, "2SU") = 8, "DST recurrence dates")

    zones = {}
    zones["Test/Eastern"] = [{start:"16010101T020000",offset:-18000,rule:{FREQ:"YEARLY",BYMONTH:"11",BYDAY:"1SU"}},{start:"16010101T020000",offset:-14400,rule:{FREQ:"YEARLY",BYMONTH:"3",BYDAY:"2SU"}}]
    expect(calUtc("20261019T090000", "Test/Eastern", zones) = calWall("20261019T130000Z"), "VTIMEZONE daylight rules")

    base = calWall("20261017T230000Z")
    hourly = {time:[],temperature_2m:[],weather_code:[],is_day:[]}
    for i = 0 to 24
        hourly.time.Push(base + i * 3600)
        hourly.temperature_2m.Push(i - 10.3)
        hourly.weather_code.Push(0)
        hourly.is_day.Push(0)
    end for
    forecast = buildWeatherForecast(hourly, base + 1800)
    expect(forecast.Count() = 24, "24 future forecast hours")
    expect(forecast[0].timestamp = base + 3600 and forecast[23].timestamp = base + 24 * 3600, "Forecast spans midnight and the next day")
    expect(forecast[0].value = -9 and forecast[0].icon.Instr("moon.png") >= 0, "Celsius rounding and night icon")
    expect(m.failures = 0, "All assertions passed")
    print "TEST_FAILURES="; m.failures
end sub

function eventFixture(uid as string, summary as string, start as string, finish as string, extra as string) as string
    nl = chr(10)
    return "BEGIN:VEVENT" + nl + "UID:" + uid + nl + "SUMMARY:" + summary + nl + "DTSTART:" + start + nl + "DTEND:" + finish + nl + extra + "END:VEVENT" + nl
end function

sub expect(condition as boolean, label as string)
    if condition
        print "PASS: "; label
    else
        m.failures = m.failures + 1
        print "FAIL: "; label
    end if
end sub
