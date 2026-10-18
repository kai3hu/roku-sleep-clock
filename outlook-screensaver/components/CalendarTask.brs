sub init()
    m.top.functionName = "downloadCalendar"
end sub

sub downloadCalendar()
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.SetMessagePort(port)
    transfer.SetUrl(m.top.uri)
    transfer.EnableEncodings(true)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()

    if not transfer.AsyncGetToString()
        calendarFailure("Unable to start calendar request")
        return
    end if

    response = wait(20000, port)
    if response = invalid
        transfer.AsyncCancel()
        calendarFailure("Calendar request timed out")
        return
    end if
    if type(response) <> "roUrlEvent"
        calendarFailure("Unable to load Outlook calendar")
        return
    end if
    status = response.GetResponseCode()
    if status < 200 or status >= 300
        if status = 410
            calendarFailure("Calendar link expired (HTTP 410)")
        else if status > 0
            calendarFailure("Calendar unavailable (HTTP " + status.ToStr() + ")")
        else
            calendarFailure("Calendar connection failed")
        end if
        return
    end if

    body = response.GetString()
    if body.Instr("BEGIN:VCALENDAR") < 0 or body.Instr("END:VCALENDAR") < 0
        calendarFailure("The link did not return an ICS calendar")
        return
    end if

    now = CreateObject("roDateTime")
    m.top.todayItems = calTodayRows(body, now.AsSeconds())
    m.top.today = buildTodayAgenda(body, now.AsSeconds())
    m.top.agenda = buildWeekAgenda(body, now.AsSeconds())
end sub

sub calendarFailure(message as string)
    m.top.todayItems = []
    m.top.today = "TODAY  /  Calendar unavailable"
    m.top.agenda = message
end sub
