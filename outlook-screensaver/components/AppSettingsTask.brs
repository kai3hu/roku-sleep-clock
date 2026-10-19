sub init()
    m.top.functionName = "settingsStorage"
end sub

sub settingsStorage()
    section = CreateObject("roRegistrySection", "SleepDashboard")
    input = invalid
    if m.top.operation = "save"
        settings = appNormalizeSettings(m.top.settings)
        success = section.Write("settings", FormatJson(settings))
        if success then success = section.Flush()
        m.top.result = {operation:"save",success:success}
    else
        if section.Exists("settings")
            text = section.Read("settings")
            if text <> "" then input = ParseJson(text)
        end if
        m.top.result = {operation:"load",settings:appNormalizeSettings(input),success:true}
    end if
end sub
