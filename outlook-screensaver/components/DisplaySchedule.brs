' Uses the hour returned by roDateTime.ToLocalTime() on the Roku device.
function isDayBrightness(localHour as integer) as boolean
    return localHour >= 7 and localHour < 23
end function

function scheduleTextColor(localHour as integer) as string
    if isDayBrightness(localHour) then return "0x242424FF"
    return "0x0C0C0CFF"
end function

function scheduleIconTint(localHour as integer) as string
    ' Icons are drawn at #242424; night tint produces approximately #0C0C0C.
    if isDayBrightness(localHour) then return "0xFFFFFFFF"
    return "0x555555FF"
end function
