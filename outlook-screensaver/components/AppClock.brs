' Native SceneGraph animation only. No font metrics, timers or I/O on RENDER.
sub appInitClock()
    m.clockPrevious = m.top.FindNode("clockPrevious")
    m.clockPeriod = m.top.FindNode("clockPeriod")
    m.clockFx = m.top.FindNode("clockTransition")
    m.clockIn = m.top.FindNode("clockIn")
    m.clockOut = m.top.FindNode("clockOut")
    m.clockLift = m.top.FindNode("clockLift")
    m.clockDrop = m.top.FindNode("clockDrop")
    m.appClockBase = [0,0]
    m.appClockSleepAt = 0
    m.appClockSleepSlot = -1
    m.appClockSleepSeed = 0
    m.clockFx.ObserveField("state", "onAppClockTransition")
end sub

function appClockFonts() as object
    return ["System","Roboto Mono","Rajdhani","Digital","Lora"]
end function

function appClockFontName(id as string) as string
    names = {System:"System (original)","Roboto Mono":"Roboto Mono Light",Rajdhani:"Rajdhani Light",Digital:"DSEG7 Classic Light",Lora:"Lora Regular"}
    if names[id] <> invalid then return names[id]
    return "System (original)"
end function

function appClockFontUri(id as string) as string
    files = {"Roboto Mono":"RobotoMono-Light.ttf",Rajdhani:"Rajdhani-Light.ttf",Digital:"DSEG7Classic-Light.ttf",Lora:"SleepClockSerif-Regular.ttf"}
    if files[id] <> invalid then return "pkg:/fonts/" + files[id]
    return "font:SystemFontFile"
end function

function appClockTime(hour as integer, minute as integer, format as string) as object
    if format = "12h"
        period = "AM"
        if hour >= 12 then period = "PM"
        value = hour mod 12
        if value = 0 then value = 12
        return {digits:value.ToStr() + ":" + twoDigits(minute),period:period}
    end if
    return {digits:twoDigits(hour) + ":" + twoDigits(minute),period:""}
end function

' Offline font advance widths in thousandths of an em. No native font queries.
function appClockTextWidth(text as string, face as string, size as integer) as integer
    advances = [600,600,600,600,600,600,600,600,600,600,300]
    if face = "Roboto Mono" then advances = [600,600,600,600,600,600,600,600,600,600,600]
    if face = "Rajdhani" then advances = [508,312,474,493,515,476,490,367,513,490,187]
    if face = "Digital" then advances = [816,816,816,816,816,816,816,816,816,816,200]
    if face = "Lora" then advances = [621,364,537,557,542,545,578,461,562,578,250]
    total = 0
    for i = 1 to len(text)
        char = mid(text,i,1)
        index = 10
        if char <> ":" then index = val(char)
        total = total + advances[index]
    end for
    return int(total * size / 1000.0 + 0.5)
end function

sub appStopClockTransition()
    m.clockFx.control = "stop"
    m.clock.opacity = 1
    m.clockPrevious.opacity = 0
    m.clock.translation = m.appClockBase
end sub

sub onAppClockTransition()
    if m.clockFx.state = "stopped"
        m.clock.opacity = 1
        m.clockPrevious.opacity = 0
        m.clock.translation = m.appClockBase
    end if
end sub

sub appSetClockText(text as string)
    if m.clock.text = text then return
    old = m.clock.text
    appStopClockTransition()
    m.clock.text = text
    if not isText(old) then return
    if old = "" or m.appSettings.clockAnimation = "Off" or m.appMenu <> "" then return
    if not m.content.visible then return
    if m.appSleeping and not m.appSettings.clockStandby then return
    m.clockPrevious.text = old
    m.clockPrevious.font.uri = m.clock.font.uri
    m.clockPrevious.font.size = m.clock.font.size
    m.clockPrevious.width = m.clock.width
    m.clockPrevious.height = m.clock.height
    m.clockPrevious.color = m.clock.color
    x = m.appClockBase[0]
    y = m.appClockBase[1]
    offset = 0
    if m.appSettings.clockAnimation = "Slide" then offset = 8
    m.clockIn.keyValue = [0,1]
    m.clockOut.keyValue = [1,0]
    m.clockLift.keyValue = [[x,y + offset],[x,y]]
    m.clockDrop.keyValue = [[x,y],[x,y - offset]]
    m.clock.translation = [x,y + offset]
    m.clockPrevious.translation = [x,y]
    m.clock.opacity = 0
    m.clockPrevious.opacity = 1
    m.clockFx.control = "start"
end sub

sub appClockStyle()
    requested = [m.clock.translation[0],m.clock.translation[1]]
    appStopClockTransition()
    m.clock.font.uri = appClockFontUri(m.appSettings.clockFont)
    m.clockPrevious.font.uri = m.clock.font.uri
    m.clockPrevious.font.size = m.clock.font.size
    m.appClockBase = requested
    m.clock.translation = requested
    appClockPeriodPosition()
end sub

sub appClockPeriodPosition()
    m.clockPeriod.font.size = int(m.clock.font.size * 0.27)
    m.clockPeriod.translation = [m.appClockBase[0] + appClockTextWidth(m.clock.text,m.appSettings.clockFont,m.clock.font.size) + 14,m.appClockBase[1] + int(m.clock.font.size * 0.6)]
    m.clockPeriod.color = m.clock.color
    m.clockPeriod.visible = m.clockPeriod.text <> ""
end sub

function appStandbyClockPosition(slot as integer) as object
    order = [0,8,2,6,1,7,3,5,4]
    point = order[slot mod 9]
    xs = [120,580,1040]
    ys = [100,435,770]
    return [xs[point mod 3],ys[int(point / 3)]]
end function

sub appEnterClockStandby()
    appStopClockTransition()
    m.appClockSleepAt = int(m.appUptime.TotalMilliseconds() / 1000)
    m.appClockSleepSeed = int(m.appClockSleepAt / 600) mod 9
    m.appClockSleepSlot = -1
    appStandbyClockTick()
end sub

sub appStandbyClockTick()
    if not m.appSleeping or not m.appSettings.clockStandby then return
    now = int(m.appUptime.TotalMilliseconds() / 1000)
    slot = int((now - m.appClockSleepAt) / 600)
    if slot = m.appClockSleepSlot then return
    m.appClockSleepSlot = slot
    appStopClockTransition()
    m.content.scale = [1,1]
    m.content.translation = [0,0]
    m.clock.font.size = m.appSettings.clockSize
    m.clock.font.uri = appClockFontUri(m.appSettings.clockFont)
    m.clock.width = 760
    m.clock.height = 185
    m.appClockBase = appStandbyClockPosition(slot + m.appClockSleepSeed)
    m.clock.translation = m.appClockBase
    appClockPeriodPosition()
end sub
