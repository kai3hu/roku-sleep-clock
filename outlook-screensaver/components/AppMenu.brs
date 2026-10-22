' Remote-first settings. Drafts stay separate from saved accounts and requests.
function appSettingGroups() as object
    return ["Clock","Pages","Layout","Display","Rotation","Content","Status"]
end function

function appSettingsChanged() as boolean
    return FormatJson(appNormalizeSettings(m.appSettings)) <> FormatJson(appNormalizeSettings(m.appCommitted))
end function

sub appCommitSettings()
    old = appNormalizeSettings(m.appCommitted)
    m.appSettings = appNormalizeSettings(m.appSettings)
    m.appCommitted = appNormalizeSettings(m.appSettings)
    m.appSettingsDirty = true
    m.appPlaying = m.appSettings.autoplay
    appSettingsApplied(old)
end sub

function appSettingValue(key as string, value as dynamic) as string
    if key = "clockFont" then return appClockFontName(value)
    if key = "clockStandby"
        if value = true then return "Clock only"
        return "Black screen"
    end if
    if key = "startup" then return appPageName(value)
    if key = "calendarUrl"
        if m.appSettings.useBundledCalendar or value <> "" then return "Configured / hidden"
        return "Not configured"
    end if
    if appValueKind(value) = "boolean"
        if value then return "On"
        return "Off"
    end if
    if key = "displayTimeout" or key = "resumeAfter"
        if value = 0 then return "Never"
        if value < 3600 then return int(value / 60).ToStr() + " min"
        return int(value / 3600).ToStr() + " hour"
    end if
    if key = "nightStart" or key = "nightEnd" then return twoDigits(value) + ":00"
    if right(key,7) = "Seconds" then return value.ToStr() + " s"
    if key = "calendarDays"
        if value = 1 then return "1 day"
        return value.ToStr() + " days"
    end if
    if key = "margin" then return value.ToStr() + "%"
    return value.ToStr()
end function

function appSettingHelp(key as string) as string
    notes = {
        clockFont:"OK opens all fonts with real clock samples. System keeps the original font.",
        clockAnimation:"A subtle transition when the minute changes. No blinking or brightness boost.",
        clockSize:"Reader pages cap large clocks to preserve article space.",
        hourFormat:"AM/PM uses a separate readable label, including with the digital font.",
        clockStandby:"Clock only moves to a different safe position every 10 minutes. Black screen stays fully black.",
        displayTimeout:"Only real remote input resets this timer. Data refresh and hourly playback do not wake the screen.",
        keepRunning:"Experimental: local silent playback for 10 seconds every hour. Save to apply; no continuous loop.",
        calendarUrl:"Your private Outlook link stays masked. Network changes apply only after Save.",
        clearCalendar:"Forgets the saved link and hides tasks after Save. It does not erase a link bundled in the installer.",
        startup:"Only enabled pages can be used at startup; Last viewed remembers your last page.",
        layout:"Preview the layout on the right before saving.",
        fontSize:"Changes content text, not the selected clock typeface.",
        wakeBoost:"Optional, temporary brightness while manually browsing. Off keeps the existing dim palette.",
        testKeepRunning:"Runs one short local playback. Unsaved changes require confirmation before this test.",
        Clock:"Fonts, minute transitions, time format and moving clock standby.",
        Pages:"Enable pages, reorder them and choose what opens first.",
        Layout:"Arrange agenda and weather; adjust content text and safe margins.",
        Display:"Idle timeout, night hours, dim colors and hourly playback.",
        Rotation:"Automatic page changes and reading time.",
        Content:"Outlook, weather, news and public Telegram settings.",
        Status:"Source update status and manual refresh / playback checks."
    }
    if notes[key] <> invalid then return notes[key]
    return "Left/Right changes the preview. OK opens choices. PLAY/PAUSE saves and closes."
end function

sub appMenuLabel(parent as object, text as string, x as integer, y as integer, width as integer, size as integer, color as string)
    label = createWeatherLabel(parent,text,size,width,44)
    label.translation = [x,y]
    label.color = color
end sub

sub appMenuRect(parent as object, x as integer, y as integer, width as integer, height as integer, color as string)
    rectangle = parent.createChild("Rectangle")
    rectangle.translation = [x,y]
    rectangle.width = width
    rectangle.height = height
    rectangle.color = color
end sub

sub appDrawMenu()
    m.appMenuClockSample = invalid
    if m.appKeyboard <> invalid
        appDrawKeyboard()
        return
    end if
    if m.appMenu = "Navigate"
        appDrawNavigationMenu()
        return
    end if
    if m.appPicker <> invalid
        appDrawChoicePicker()
    else
        appDrawSettingsPanel()
    end if
    if m.appConfirm <> invalid then appDrawConfirmation()
end sub

sub appDrawSettingsPanel()
    panel = m.appOverlay
    panel.removeChildrenIndex(panel.getChildCount(),0)
    appMenuRect(panel,0,0,1050,1080,"0x000000FF")
    appMenuLabel(panel,"SETTINGS",50,48,500,32,"0x888888FF")
    saved = "Saved"
    if appSettingsChanged() then saved = "Unsaved changes"
    appMenuLabel(panel,saved,720,60,300,21,"0x777777FF")
    groups = appSettingGroups()
    active = m.appMenu
    if active = "Settings" then active = groups[m.appMenuIndex mod groups.Count()]
    for i = 0 to groups.Count() - 1
        color = "0x484848FF"
        if groups[i] = active
            appMenuRect(panel,32,150 + i * 70,255,60,"0x161616FF")
            color = "0x888888FF"
        end if
        appMenuLabel(panel,groups[i],52,160 + i * 70,225,25,color)
    end for
    appMenuLabel(panel,active,330,140,600,30,"0x888888FF")
    rows = appMenuRows()
    selected = m.appMenuIndex
    if m.appMenu = "Settings"
        rows = appSettingRows(active)
        selected = -1
    end if
    if selected >= 0 then appMenuLabel(panel,(selected + 1).ToStr() + " / " + rows.Count().ToStr(),900,147,120,19,"0x585858FF")
    first = selected - 3
    if first > rows.Count() - 7 then first = rows.Count() - 7
    if first < 0 then first = 0
    last = first + 6
    if last >= rows.Count() then last = rows.Count() - 1
    for i = first to last
        row = rows[i]
        y = 215 + (i - first) * 86
        focused = i = selected and m.appMenuZone <> "footer"
        if focused then appMenuRect(panel,320,y - 7,700,80,"0x161616FF")
        color = "0x585858FF"
        if focused then color = "0x999999FF"
        appMenuLabel(panel,row.label,340,y,405,24,color)
        value = "OK"
        if row.kind = "page"
            value = "Off"
            if m.appSettings.enabled[row.key] then value = "On"
        else if row.values <> invalid or row.kind = "text"
            value = appSettingValue(row.key,m.appSettings[row.key])
        end if
        label = createWeatherLabel(panel,shortText(value,26),21,270,36)
        label.translation = [735,y + 2]
        label.horizAlign = "right"
        label.color = color
        if focused and row.values <> invalid and row.values.Count() <= 3
            for j = 0 to row.values.Count() - 1
                shade = "0x0B0B0BFF"
                ink = "0x585858FF"
                if row.values[j] = m.appSettings[row.key]
                    shade = "0x2A2A2AFF"
                    ink = "0x999999FF"
                end if
                appMenuRect(panel,340 + j * 188,y + 39,180,31,shade)
                appMenuLabel(panel,appSettingValue(row.key,row.values[j]),350 + j * 188,y + 39,166,18,ink)
            end for
        else
            detail = "Left/Right: move page   OK: On/Off"
            if row.kind <> "page" then detail = appSettingHelp(row.key)
            appMenuLabel(panel,shortText(detail,80),342,y + 40,655,17,"0x484848FF")
        end if
    end for
    note = "Up/Down: choose category   OK: open"
    if m.appMenu <> "Settings" then note = "Up/Down: select   Left/Right: change   OK: all choices   Back: categories"
    if m.appMenuNote <> "" then note = m.appMenuNote + chr(10) + note
    footer = createWeatherLabel(panel,note,19,680,105)
    footer.translation = [330,835]
    footer.wrap = true
    footer.numLines = 4
    footer.color = "0x686868FF"
    if m.appMenu = "Status" then appDrawSourceStatus(panel)
    appDrawSettingsFooter(panel)
    appDrawClockPreview(panel)
end sub

sub appDrawSettingsFooter(panel as object)
    for i = 0 to 1
        shade = "0x101010FF"
        ink = "0x686868FF"
        if m.appMenuZone = "footer" and m.appFooterIndex = i
            shade = "0x2A2A2AFF"
            ink = "0x999999FF"
        end if
        x = 330 + i * 370
        appMenuRect(panel,x,965,350,64,shade)
        title = "Save & close"
        if i = 1 then title = "Discard changes"
        appMenuLabel(panel,title,x + 18,978,320,24,ink)
    end for
    appMenuLabel(panel,"PLAY/PAUSE: save & close from any settings page",330,1035,700,18,"0x585858FF")
end sub

sub appDrawClockPreview(panel as object)
    appMenuLabel(panel,"CLOCK PREVIEW",1100,80,700,23,"0x585858FF")
    sample = createWeatherLabel(panel,m.clock.text,110,740,180)
    sample.translation = [1100,145]
    sample.font.uri = appClockFontUri(m.appSettings.clockFont)
    sample.color = "0x686868FF"
    m.appMenuClockSample = sample
    appMenuLabel(panel,appClockFontName(m.appSettings.clockFont),1100,320,740,22,"0x585858FF")
    appMenuLabel(panel,"LIVE LAYOUT PREVIEW",1100,375,740,21,"0x484848FF")
end sub

sub appDrawSourceStatus(panel as object)
    ' Status actions remain on the left; updates never expose account URLs.
    text = "Outlook: " + m.appStatus.calendar + chr(10) + "Weather: " + m.appStatus.weather + chr(10) + "News: " + m.appStatus.news + chr(10) + "Telegram: " + m.appStatus.telegram + chr(10) + "Keep running: " + m.appKeepStatus + chr(10) + "Previous exit: " + m.top.lastExitReason
    label = createWeatherLabel(panel,text,19,740,240)
    label.translation = [1100,790]
    label.wrap = true
    label.numLines = 9
    label.color = "0x585858FF"
end sub

sub appOpenChoicePicker(row as object)
    index = 0
    for i = 0 to row.values.Count() - 1
        if row.values[i] = m.appSettings[row.key] then index = i
    end for
    m.appPicker = {row:row,index:index,original:m.appSettings[row.key]}
    appDrawMenu()
end sub

sub appDrawChoicePicker()
    panel = m.appOverlay
    panel.removeChildrenIndex(panel.getChildCount(),0)
    appMenuRect(panel,0,0,1050,1080,"0x000000FF")
    picker = m.appPicker
    row = picker.row
    appMenuLabel(panel,"CHOOSE / " + ucase(row.label),50,55,950,30,"0x888888FF")
    appMenuLabel(panel,(picker.index + 1).ToStr() + " / " + row.values.Count().ToStr(),850,62,150,20,"0x686868FF")
    first = picker.index - 3
    if first > row.values.Count() - 7 then first = row.values.Count() - 7
    if first < 0 then first = 0
    last = first + 6
    if last >= row.values.Count() then last = row.values.Count() - 1
    for i = first to last
        y = 160 + (i - first) * 100
        ink = "0x585858FF"
        if i = picker.index
            appMenuRect(panel,40,y - 10,960,88,"0x202020FF")
            ink = "0x999999FF"
        end if
        appMenuLabel(panel,appSettingValue(row.key,row.values[i]),64,y + 12,490,25,ink)
        if row.key = "clockFont"
            sample = createWeatherLabel(panel,"23:48",68,410,90)
            sample.translation = [570,y - 3]
            sample.font.uri = appClockFontUri(row.values[i])
            sample.color = ink
        end if
    end for
    appMenuLabel(panel,"Up/Down: preview   OK: use choice   Back: cancel choice",55,910,940,22,"0x686868FF")
    appMenuLabel(panel,"PLAY/PAUSE saves this choice and closes settings",55,965,940,21,"0x686868FF")
    appDrawClockPreview(panel)
end sub

function appPickerKey(key as string) as boolean
    picker = m.appPicker
    if key = "back"
        m.appSettings[picker.row.key] = picker.original
        m.appPicker = invalid
    else if key = "OK"
        m.appPicker = invalid
    else if key = "up" or key = "down" or key = "left" or key = "right"
        direction = 1
        if key = "up" or key = "left" then direction = -1
        picker.index = (picker.index + direction + picker.row.values.Count()) mod picker.row.values.Count()
        m.appSettings[picker.row.key] = picker.row.values[picker.index]
    end if
    appApplyLayout()
    appDrawMenu()
    return true
end function

sub appRequestSettingsExit()
    if appSettingsChanged()
        m.appConfirm = {kind:"exit",index:0}
        appDrawMenu()
    else
        appCloseMenu(false)
    end if
end sub

sub appMenuTestKeepRunning()
    if m.appCommitted.keepRunning <> true or appSettingsChanged()
        m.appConfirm = {kind:"test",index:0}
        appDrawMenu()
    else
        appTestKeepRunning()
    end if
end sub

function appConfirmationChoices() as object
    if m.appConfirm.kind = "test"
        if m.appSettings.keepRunning then return ["Save changes and test","Keep editing"]
        return ["Enable, save and test","Keep editing"]
    end if
    return ["Save and close","Keep editing","Discard changes"]
end function

sub appDrawConfirmation()
    panel = m.appOverlay
    appMenuRect(panel,295,220,1330,650,"0x303030FF")
    appMenuRect(panel,299,224,1322,642,"0x000000FF")
    title = "Save your changes?"
    detail = "Your choices are previewed, not saved. Back keeps editing."
    if m.appConfirm.kind = "test"
        title = "Save settings before testing"
        detail = "Hourly playback must be saved as On. The test stays silent and black."
    end if
    appMenuLabel(panel,title,350,270,1200,36,"0x999999FF")
    appMenuLabel(panel,detail,350,340,1200,22,"0x777777FF")
    choices = appConfirmationChoices()
    for i = 0 to choices.Count() - 1
        ink = "0x686868FF"
        if i = m.appConfirm.index
            appMenuRect(panel,345,430 + i * 105,1230,88,"0x242424FF")
            ink = "0x999999FF"
        end if
        appMenuLabel(panel,choices[i],370,451 + i * 105,1160,27,ink)
    end for
end sub

function appConfirmationKey(key as string) as boolean
    if key = "back"
        m.appConfirm = invalid
    else if key = "up" or key = "down" or key = "left" or key = "right"
        direction = 1
        if key = "up" or key = "left" then direction = -1
        choices = appConfirmationChoices()
        m.appConfirm.index = (m.appConfirm.index + direction + choices.Count()) mod choices.Count()
    else if key = "OK"
        kind = m.appConfirm.kind
        choice = m.appConfirm.index
        m.appConfirm = invalid
        if choice = 0
            if kind = "test"
                m.appSettings.keepRunning = true
                appCommitSettings()
                appTestKeepRunning()
            else
                appCloseMenu(true)
                return true
            end if
        else if choice = 2
            appCloseMenu(false)
            return true
        end if
    end if
    appDrawMenu()
    return true
end function

function appMenuKey(key as string) as boolean
    if m.appMenu = "Navigate" then return appNavigationKey(key)
    if m.appConfirm <> invalid then return appConfirmationKey(key)
    if key = "play" or key = "pause" or key = "playonly"
        appCloseMenu(true)
        return true
    end if
    if m.appPicker <> invalid then return appPickerKey(key)
    if key = "options"
        appRequestSettingsExit()
        return true
    end if
    rows = appMenuRows()
    if m.appMenuZone = "footer"
        if key = "left" or key = "right" then m.appFooterIndex = 1 - m.appFooterIndex
        if key = "up"
            m.appMenuZone = "rows"
            m.appMenuIndex = rows.Count() - 1
        else if key = "down"
            m.appMenuZone = "rows"
            m.appMenuIndex = 0
        else if key = "OK"
            appCloseMenu(m.appFooterIndex = 0)
            return true
        else if key = "back"
            m.appMenuZone = "rows"
        end if
    else if key = "up" or key = "down"
        direction = 1
        if key = "up" then direction = -1
        index = m.appMenuIndex + direction
        if index < 0 or index >= rows.Count()
            m.appMenuZone = "footer"
            m.appFooterIndex = 0
        else
            m.appMenuIndex = index
        end if
    else if key = "back"
        if m.appMenu = "Settings"
            appRequestSettingsExit()
            return true
        end if
        m.appMenu = "Settings"
        m.appMenuIndex = m.appCategoryIndex
    else if key = "left" or key = "right" or key = "OK"
        row = rows[m.appMenuIndex]
        direction = 1
        if key = "left" then direction = -1
        if row.kind = "group" and key = "OK"
            m.appCategoryIndex = m.appMenuIndex
            m.appMenu = row.key
            m.appMenuIndex = 0
        else if row.kind = "page"
            if key = "OK"
                if m.appSettings.enabled[row.key] and appEnabledPages(m.appSettings).Count() = 1
                    m.appMenuNote = "Keep at least one page enabled."
                else
                    m.appSettings.enabled[row.key] = not m.appSettings.enabled[row.key]
                end if
            else
                m.appSettings = appMovePage(m.appSettings,row.key,direction)
                for i = 0 to m.appSettings.order.Count() - 1
                    if m.appSettings.order[i] = row.key then m.appMenuIndex = i + 1
                end for
            end if
        else if row.kind = "text" and key = "OK"
            appOpenKeyboard(row)
            return true
        else if row.kind = "action" and key = "OK"
            appMenuAction(row.key)
            if m.appMenu = "" then return true
        else if row.values <> invalid
            if key = "OK" and row.values.Count() > 2
                appOpenChoicePicker(row)
                return true
            end if
            index = 0
            for i = 0 to row.values.Count() - 1
                if row.values[i] = m.appSettings[row.key] then index = i
            end for
            m.appSettings[row.key] = row.values[(index + direction + row.values.Count()) mod row.values.Count()]
        end if
    end if
    appSetVisibility(m.appCurrent)
    appApplyLayout()
    appDrawMenu()
    return true
end function
