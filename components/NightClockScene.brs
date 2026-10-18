sub init()
    m.top.backgroundURI = ""
    m.top.backgroundColor = "0x000000FF"
    m.clock = m.top.FindNode("clock")
    m.tick = m.top.FindNode("tick")
    m.lastMinute = -1

    m.tick.ObserveField("fire", "onTick")
    updateClock()
    m.tick.control = "start"
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

    ' Move once every 10 minutes among safe positions to reduce OLED image retention.
    tenMinuteSlot = int((hour * 60 + minute) / 10)
    if tenMinuteSlot <> m.lastMinute
        m.lastMinute = tenMinuteSlot
        moveClock(hour, minute)
    end if
end sub

sub moveClock(hour as integer, minute as integer)
    positions = [
        [180, 150], [750, 150], [1320, 150],
        [180, 480], [750, 480], [1320, 480],
        [180, 810], [750, 810], [1320, 810]
    ]

    ' A stable minute-based index avoids random-number setup and visits all 9 spots.
    index = int((hour * 60 + minute) / 10) mod positions.Count()
    m.clock.translation = positions[index]
end sub

function twoDigits(value as integer) as string
    if value < 10 then return "0" + value.ToStr()
    return value.ToStr()
end function
