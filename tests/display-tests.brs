sub Main()
    m.detailsVisible = invalid
    m.heading = {visible:true}
    m.agenda = {visible:true}
    m.weatherGroup = {visible:true}
    m.pageTimer = {control:"start"}
    ' Running-task stubs avoid network calls during a morning transition.
    m.calendarTask = {state:"run"}
    m.weatherTask = {state:"run"}
    applyDisplaySchedule(0)
    if m.heading.visible or m.agenda.visible or m.weatherGroup.visible or m.pageTimer.control <> "stop"
        print "FAIL: Night details must be hidden"
        return
    end if
    applyDisplaySchedule(6)
    if m.detailsVisible
        print "FAIL: Details appeared before 07:00"
        return
    end if
    applyDisplaySchedule(7)
    if not m.heading.visible or not m.agenda.visible or not m.weatherGroup.visible or m.pageTimer.control <> "start"
        print "FAIL: Morning details must be visible"
        return
    end if
    applyDisplaySchedule(23)
    applyDisplaySchedule(0)
    if m.heading.visible or m.agenda.visible or m.weatherGroup.visible
        print "FAIL: Midnight rollover must hide all details"
        return
    end if
    print "PASS: Startup, morning and midnight visibility transitions"
end sub

function GetCalendarIcsUrl() as string
    return "https://example.invalid/calendar.ics"
end function
