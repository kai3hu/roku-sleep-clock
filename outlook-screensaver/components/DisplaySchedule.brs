' Uses the hour returned by roDateTime.ToLocalTime() on the Roku device.
function showScheduleDetails(localHour as integer) as boolean
    return localHour >= 7 and localHour < 24
end function
