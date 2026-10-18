sub init()
    m.top.functionName = "downloadWeather"
end sub

sub downloadWeather()
    ' Approximate centroid of Tuscaloosa ZIP 35406, not a street address.
    url = "https://api.open-meteo.com/v1/forecast?latitude=33.3388&longitude=-87.4676"
    url = url + "&current=temperature_2m,weather_code,is_day&temperature_unit=celsius&timezone=America%2FChicago"
    url = url + "&hourly=temperature_2m,weather_code,is_day&forecast_hours=25&timeformat=unixtime"
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnableEncodings(true)
    transfer.SetUrl(url)

    if not transfer.AsyncGetToString()
        m.top.result = { available: false }
        return
    end if
    response = wait(20000, port)
    if response = invalid
        transfer.AsyncCancel()
        m.top.result = { available: false }
        return
    end if
    if type(response) <> "roUrlEvent"
        m.top.result = { available: false }
        return
    end if
    if response.GetResponseCode() <> 200
        m.top.result = { available: false }
        return
    end if
    data = ParseJson(response.GetString())
    if type(data) <> "roAssociativeArray"
        m.top.result = { available: false }
        return
    end if
    current = data.current
    if type(current) <> "roAssociativeArray"
        m.top.result = { available: false }
        return
    end if
    if current.temperature_2m = invalid or current.weather_code = invalid or current.is_day = invalid
        m.top.result = { available: false }
        return
    end if

    hourly = data.hourly
    if type(hourly) <> "roAssociativeArray"
        m.top.result = { available: false }
        return
    end if
    now = CreateObject("roDateTime")
    forecast = buildWeatherForecast(hourly, now.AsSeconds())
    if forecast.Count() <> 24
        m.top.result = { available: false }
        return
    end if
    low = forecast[0].value
    high = low
    for each point in forecast
        if point.value < low then low = point.value
        if point.value > high then high = point.value
    end for
    condition = weatherCondition(current.weather_code, current.is_day)
    ' Round to the nearest degree, including negative temperatures.
    temperature = int(current.temperature_2m + 0.5)
    m.top.result = {
        available: true
        temperature: temperature.ToStr() + chr(176) + "C"
        description: condition.description
        icon: "pkg:/images/weather/" + condition.icon + ".png"
        forecast: forecast
        low: low
        high: high
    }
end sub

function buildWeatherForecast(hourly as object, nowSeconds as integer) as object
    result = []
    if type(hourly.time) <> "roArray" or type(hourly.temperature_2m) <> "roArray" or type(hourly.weather_code) <> "roArray" or type(hourly.is_day) <> "roArray" then return result
    for i = 0 to hourly.time.Count() - 1
        stamp = hourly.time[i]
        if stamp >= nowSeconds and stamp < nowSeconds + 86400 and result.Count() < 24
            if hourly.temperature_2m[i] <> invalid and hourly.weather_code[i] <> invalid and hourly.is_day[i] <> invalid
                date = CreateObject("roDateTime")
                date.FromSeconds(stamp)
                date.ToLocalTime()
                condition = weatherCondition(hourly.weather_code[i], hourly.is_day[i])
                hour = date.GetHours().ToStr()
                if date.GetHours() < 10 then hour = "0" + hour
                value = int(hourly.temperature_2m[i] + 0.5)
                result.Push({ timestamp: stamp, hour: hour + ":00", value: value, temperature: value.ToStr() + chr(176) + "C", icon: "pkg:/images/weather/" + condition.icon + ".png" })
            end if
        end if
    end for
    return result
end function

function weatherCondition(code as integer, isDay as integer) as object
    if code = 0
        if isDay = 0 then return { description: "Clear", icon: "moon" }
        return { description: "Clear", icon: "sun" }
    end if
    if code = 1 or code = 2
        if isDay = 0 then return { description: "Partly cloudy", icon: "partly-night" }
        return { description: "Partly cloudy", icon: "partly" }
    end if
    if code = 3 then return { description: "Overcast", icon: "cloud" }
    if code = 45 or code = 48 then return { description: "Fog", icon: "fog" }
    if code = 51 or code = 53 or code = 55 then return { description: "Drizzle", icon: "rain" }
    if code = 56 or code = 57 or code = 66 or code = 67 then return { description: "Freezing rain", icon: "rain" }
    if code = 61 or code = 63 or code = 65 then return { description: "Rain", icon: "rain" }
    if code = 80 or code = 81 or code = 82 then return { description: "Rain showers", icon: "rain" }
    if code = 71 or code = 73 or code = 75 or code = 77 or code = 85 or code = 86
        return { description: "Snow", icon: "snow" }
    end if
    if code = 95 or code = 96 or code = 99 then return { description: "Thunderstorm", icon: "storm" }
    return { description: "Weather", icon: "cloud" }
end function
