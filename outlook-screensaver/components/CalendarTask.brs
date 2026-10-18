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
        m.top.agenda = "Unable to start calendar request"
        return
    end if

    response = wait(20000, port)
    if response = invalid
        transfer.AsyncCancel()
        m.top.agenda = "Calendar request timed out"
        return
    end if
    if type(response) <> "roUrlEvent"
        m.top.agenda = "Unable to load Outlook calendar"
        return
    end if
    status = response.GetResponseCode()
    if status < 200 or status >= 300
        if status = 410
            m.top.agenda = "Calendar link expired (HTTP 410)"
        else if status > 0
            m.top.agenda = "Calendar unavailable (HTTP " + status.ToStr() + ")"
        else
            m.top.agenda = "Calendar connection failed"
        end if
        return
    end if

    body = response.GetString()
    if body.Instr("BEGIN:VCALENDAR") < 0 or body.Instr("END:VCALENDAR") < 0
        m.top.agenda = "The link did not return an ICS calendar"
        return
    end if

    now = CreateObject("roDateTime")
    m.top.agenda = buildWeekAgenda(body, now.AsSeconds())
end sub
