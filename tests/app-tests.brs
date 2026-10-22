sub Main(preview = false as boolean)
    if preview
        settingsPreview()
        return
    end if
    m.failures = 0
    settings = appDefaults()
    check(appEnabledPages(settings).Join(",") = "dashboard,news,telegram", "App defaults enable useful pages without duplicate agenda/weather views")
    check(settings.displayTimeout = 300, "Default idle timeout is five minutes")
    corrupt = {order:["news","news","bad"],enabled:{dashboard:false,agenda:false,weather:false,news:false,telegram:false,clock:false},layout:{bad:true},displayTimeout:-1,telegramChannel:"../../private",calendarUrl:"http://bad/link"}
    normalized = appNormalizeSettings(corrupt)
    check(normalized.order.Count() = 6 and normalized.order[0] = "news", "Corrupt page orders are deduplicated and repaired")
    check(appEnabledPages(normalized).Join(",") = "clock", "At least one page survives corrupt or empty configuration")
    check(normalized.layout = "Balanced" and normalized.displayTimeout = 300, "Malformed saved values fall back to defaults")
    wrongTypes = appNormalizeSettings({layout:true,displayTimeout:"Never",nightStart:[],nightLevel:17})
    check(wrongTypes.layout = "Balanced" and wrongTypes.nightStart = 23 and wrongTypes.displayTimeout = 300, "Wrong scalar types in registry data cannot crash startup")
    check(normalized.telegramChannel = "DNSPODT" and normalized.calendarUrl = "", "Invalid channel and non-HTTPS calendar links are rejected")
    settings.startup = "weather"
    check(appStartupPage(settings) = "dashboard", "Disabled startup page falls back to first enabled page")
    settings.startup = "last"
    settings.lastPage = "news"
    check(appStartupPage(settings) = "news", "Last-viewed startup page is restored")
    check(appNeighbor(settings, "dashboard", 1) = "news" and appNeighbor(settings, "dashboard", -1) = "telegram", "Remote navigation wraps and skips disabled pages")
    settings = appMovePage(settings, "telegram", -1)
    settings = appMovePage(settings, "telegram", -1)
    check(appNeighbor(settings, "dashboard", 1) = "telegram", "Reordered pages drive navigation and rotation")
    settings = appDefaults()
    check(appNeedsData(settings, "calendar") and appNeedsData(settings, "weather"), "Dashboard keeps its calendar/weather dependencies active")
    settings.enabled.dashboard = false
    check(not appNeedsData(settings, "calendar") and not appNeedsData(settings, "weather"), "Disabled pages stop unused data requests")
    settings.technology = false
    settings.science = false
    settings.economy = false
    check(not appNeedsData(settings, "news"), "No enabled news categories means no news requests")
    settings = appDefaults()
    check(not appShouldSleep(settings,299,false) and appShouldSleep(settings,300,false), "Black screen starts at the exact idle boundary")
    check(not appShouldSleep(settings,900,true), "Sleeping state is not repeatedly re-entered")
    settings.displayTimeout = 0
    check(not appShouldSleep(settings,86400,false), "Never timeout supports overnight display")
    check(appTextColor(settings,23) = "0x0C0C0CFF" and appTextColor(settings,7) = "0x242424FF", "App preserves 23:00-06:59 nighttime palette")
    settings.nightStart = 8
    settings.nightEnd = 17
    check(appNight(settings,12) and not appNight(settings,23), "Daytime sleep schedules work without a midnight crossing")
    settings.wakeBoost = true
    check(appTextColor(settings,12,true) = "0x484848FF", "Reading boost is explicitly opt-in")
    check(appDuration(settings,"telegram",120) = 120, "Normal article speed preserves worker reading time")
    settings.readingSpeed = "Slow"
    check(appDuration(settings,"telegram",120) = 180, "Slow article mode extends reading time")
    raw = {available:true,temperature:"20C",description:"Clear",icon:"sun",low:10,high:30,forecast:[{timestamp:1,hour:"12:00",value:20,icon:"sun"}]}
    fahrenheit = appWeatherUnits(raw,"F")
    check(fahrenheit.temperature = "68" + chr(176) + "F" and fahrenheit.low = 50 and fahrenheit.high = 86, "Weather unit conversion updates labels and chart range")
    check(raw.forecast[0].value = 20, "Temperature conversion never mutates cached Celsius data")
    initMockApp()
    check(onKeyEvent("right",true) and m.appCurrent = "news", "Right key switches to the next enabled page")
    check(m.appManualPaused and m.rotationTimer.control = "stop", "Manual navigation pauses automatic page changes")
    appSleep()
    savedIndex = m.telegramPageIndex
    check(m.appSleeping and not m.content.visible and not m.appChrome.visible, "Idle black screen hides content and all chrome")
    check(onKeyEvent("right",true) and m.appCurrent = "news", "First remote press only wakes; it does not also navigate")
    check(onKeyEvent("right",true) and m.appCurrent = "news", "Holding the wake key cannot accidentally turn a page")
    check(onKeyEvent("right",false), "Wake key release is consumed")
    check(not m.appSleeping and m.content.visible and m.telegramPageIndex = savedIndex, "Wake restores the same page and reading position")
    check(not onKeyEvent("right",false) and m.appCurrent = "news", "Key-release events do not navigate")
    onKeyEvent("right",true)
    check(m.appCurrent = "telegram", "Second direction press navigates normally")
    onKeyEvent("play",true)
    check(not m.appPlaying, "Play button pauses a running carousel")
    onKeyEvent("play",true)
    check(m.appPlaying and not m.appManualPaused and m.rotationTimer.control = "start", "Play resumes automatic rotation")
    m.appIdleClock.value = 300000
    appTick()
    check(m.appSleeping, "Actual app tick enters black screen on idle")
    onKeyEvent("OK",true)
    check(m.appMenu = "" and m.appCurrent = "telegram", "Wake OK is consumed without opening navigation")
    onKeyEvent("OK",false)
    onKeyEvent("OK",true)
    check(m.appMenu = "Navigate", "A subsequent OK opens navigation")
    onKeyEvent("back",true)
    check(m.appMenu = "", "Back closes navigation without exiting the app")
    appOpenMenu("Settings")
    m.appSettings.layout = "Minimal"
    m.appSettings.enabled.news = false
    appCloseMenu(false)
    check(m.appSettings.layout = "Balanced" and m.appSettings.enabled.news, "Cancel restores the committed layout and page choices")
    appOpenMenu("Settings")
    appOpenKeyboard({key:"telegramChannel",label:"Channel"})
    m.appKeyboard.text = "@ExampleChannel"
    check(appSaveKeyboardValue() and m.appSettings.telegramChannel = "ExampleChannel", "Public channel entry is validated and normalized")
    m.appIdleClock.value = 300000
    appTick()
    check(m.appSleeping and m.appKeyboard = invalid and m.appSettings.telegramChannel = "DNSPODT", "Idle black screen also cancels unsaved keyboard input safely")
    onKeyEvent("OK",true)
    onKeyEvent("OK",false)
    appOpenMenu("Settings")
    appOpenKeyboard({key:"calendarUrl",label:"Calendar URL"})
    m.appKeyboard.text = "https://example.com/private.ics"
    appDrawKeyboard()
    check(appSaveKeyboardValue() and not m.appSettings.useBundledCalendar, "Masked ICS entry switches to the saved override")
    appCloseMenu(false)
    check(m.appSettings.calendarUrl = "" and m.appSettings.useBundledCalendar, "Cancel discards the ICS override")
    appOpenMenu("Settings")
    m.appSettings.layout = "Agenda Focus"
    m.appSettings.enabled.telegram = false
    appCloseMenu(true)
    check(m.appCommitted.layout = "Agenda Focus" and not m.appCommitted.enabled.telegram, "Save commits layout and page choices")
    check(m.appCurrent = "dashboard", "Disabling the current page selects a valid replacement")
    check(not onKeyEvent("back",true), "Back on Dashboard falls through to Roku's app exit")
    m.appRequests.calendar = "old request"
    check(not appAcceptResult("calendar") and m.appPendingRefresh.calendar, "Late responses from superseded settings are discarded")
    appRequestStarted("calendar")
    check(appAcceptResult("calendar"), "Responses matching current settings are accepted")
    m.appSettings.calendarAllowed = false
    m.appCommitted.calendarAllowed = false
    check(not appAcceptResult("calendar"), "Disconnected Outlook results cannot repopulate cleared tasks")
    m.appCommitted = appDefaults()
    m.appSettings.calendarUrl = "https://example.com/unsaved.ics"
    appRequestStarted("calendar")
    check(m.appRequests.calendar = appSourceKey("calendar",m.appCommitted), "Unsaved account drafts never change network request configuration")
    m.appSettings = appDefaults()
    m.appCommitted = appDefaults()
    m.appCurrent = "telegram"
    m.rotationPage = "telegram"
    m.appSettings.enabled.dashboard = false
    m.appSettings.enabled.news = false
    m.appCommitted = appNormalizeSettings(m.appSettings)
    m.appManualPaused = false
    m.appSleeping = false
    m.appPlaying = true
    m.telegramPages = telegramBuildPages([{id:1,text:"Old post",timestamp:"2026-10-18T07:00:00Z"}],invalid)
    m.telegramAvailablePages = telegramBuildPages([{id:2,text:"New post",timestamp:"2026-10-18T07:00:00Z"}],invalid)
    m.telegramPageIndex = 1
    m.appTelegramShown = true
    m.telegramUpdated = "10/18 02:00"
    m.telegramDelayed = false
    appRotate()
    check(m.telegramPages[0][0].post.id = 2 and m.telegramPageIndex = 1, "Telegram-only rotation consumes refreshed snapshots at message boundaries")
    m.appSettings = appDefaults()
    m.appCommitted = appDefaults()
    m.appMenu = "Settings"
    m.appSettings.layout = "Minimal"
    m.appSettingsDirty = true
    m.appStorage = {state:"stop"}
    appTick()
    check(m.appStorage.control = "run" and m.appStorage.settings.layout = "Balanced", "Background save writes committed settings, never an unsaved preview")
    initMockApp()
    m.appNewsShown = false
    m.newsStories = [{title:"First",summary:"First story",category:"Science",edition:"2026-10-18",sourceUrl:"https://example.com/1",url:"https://example.com/1"},{title:"Second",summary:"Second story",category:"Science",edition:"2026-10-18",sourceUrl:"https://example.com/2",url:"https://example.com/2"}]
    appShowPage("news",false,true)
    check(m.appNewsIndex = 0 and m.top.nodes.newsTitle.text = "First", "First automatic news visit does not skip the first story")
    appShowPage("dashboard",false)
    appShowPage("news",false,true)
    check(m.appNewsIndex = 1, "Subsequent automatic news visits advance one story")
    m.appSettings.clockSize = 140
    appApplyLayout()
    check(m.clock.font.size = 110, "Large clock setting cannot overlap article reading space")
    m.appSettings.enabled.news = false
    m.appSettings.enabled.dashboard = false
    m.appSettings.enabled.telegram = false
    m.appSettings.enabled.clock = true
    appOpenMenu("Settings")
    m.appSettings.enabled.dashboard = false
    m.appSettings.enabled.news = false
    m.appSettings.enabled.telegram = false
    m.appSettings.enabled.clock = true
    m.appMenu = "Pages"
    m.appMenuIndex = 6
    appMenuKey("OK")
    check(m.appSettings.enabled.clock and m.appMenuNote.Instr("at least one") > 0, "Page settings UI refuses to switch off the last enabled page")
    testCalendarRangeAndCity()
    testKeepRunning()
    testClockAndSettings()
    print "APP_TEST_FAILURES="; m.failures
end sub

sub testCalendarRangeAndCity()
    initMockApp()
    m.calendarTask.uri = "https://example.com/calendar.ics"
    m.calendarTask.success = true
    m.calendarTask.agenda = "Mon 09:00 Existing task"
    m.calendarTask.todayItems = [{timeLabel:"09:00",title:"Today's task"}]
    m.calendarTask.today = "TODAY / 1 event"
    appRequestStarted("calendar")
    onTodayItemsChanged()
    onAgendaChanged()
    oldText = m.agenda.text
    oldToday = m.todayBody.text
    appOpenMenu("Settings")
    m.appSettings.calendarDays = 3
    appCloseMenu(true)
    check(m.appPendingRefresh.calendar, "Changing the calendar range queues a refresh")
    check(m.agenda.text = oldText and m.agendaLines.Count() = 1, "Range-only changes keep the current agenda visible while refreshing")
    check(m.todayBody.text = oldToday and m.todayItems.Count() = 1, "Range-only changes do not erase today's independent task list")
    check(m.calendarTask.uri = "https://example.com/calendar.ics", "Display filters do not disconnect an unchanged calendar account")
    onAgendaChanged()
    check(m.agenda.text = oldText and m.appPendingRefresh.calendar, "An old in-flight range response is ignored without clearing the visible agenda")
    appRequestStarted("calendar")
    onTodayItemsChanged()
    onAgendaChanged()
    check(m.agenda.text = oldText and m.heading.text = "NEXT 3 DAYS", "An unchanged calendar response repaints the chosen range correctly")
    appOpenMenu("Settings")
    m.appSettings.calendarDays = 7
    appCloseMenu(true)
    check(m.agenda.text = oldText, "Expanding the range also retains the last good agenda")
    appOpenMenu("Settings")
    m.appSettings.calendarAllowed = false
    appCloseMenu(true)
    check(m.agenda.text = "" and m.todayItems.Count() = 0, "Disconnect still clears private calendar content immediately")
    appOpenMenu("Settings")
    m.appSettings.calendarAllowed = true
    appCloseMenu(true)
    appRequestStarted("calendar")
    onTodayItemsChanged()
    onAgendaChanged()
    check(m.agenda.text = oldText and m.todayItems.Count() = 1, "Reconnecting the same account can restore an identical response")

    initMockApp()
    m.temperature = mockNode()
    m.weatherIcon = mockNode()
    m.weatherDescription = mockNode()
    m.weatherChart = mockNode()
    m.weatherForecast = mockNode()
    m.weatherRange = m.top.nodes.weatherRange
    m.hasWeather = false
    raw = {available:true,city:"Tuscaloosa",temperature:"20C",description:"Clear",icon:"sun",low:10,high:30,forecast:[]}
    check(appWeatherCity("35406") = "Tuscaloosa", "Default city is visible before the weather request completes")
    check(appWeatherCity("98101") = "Weather", "Unknown postal codes are never used as city headings")
    check(appWeatherCity("98101",{city:"Seattle"}) = "Seattle", "Other postal codes display their resolved city")
    check(appWeatherCity("Tuscaloosa 35406") = "Tuscaloosa", "Postal codes are stripped from fallback headings")
    check(appWeatherUnits(raw,"F").city = "Tuscaloosa", "Unit conversion preserves city metadata")
    m.weatherTask = {result:raw}
    appRequestStarted("weather")
    onWeatherChanged()
    check(m.top.nodes.weatherLocation.text = "TUSCALOOSA", "Dashboard displays the resolved city, not the configured ZIP code")
    m.appSettings.units = "F"
    m.appCommitted.units = "F"
    onWeatherChanged()
    check(m.top.nodes.weatherLocation.text = "TUSCALOOSA", "City label survives Fahrenheit conversion")
    m.appWeatherRaw = invalid
    m.appCommitted.weatherLocation = "Seattle, Washington"
    m.appSettings.weatherLocation = "Seattle, Washington"
    appApplyLayout()
    check(m.top.nodes.weatherLocation.text = "SEATTLE", "A changed location cannot retain the previous city's label while loading")
end sub

sub initMockApp()
    m.interactive = true
    m.appReady = true
    m.appSettings = appDefaults()
    m.appCommitted = appDefaults()
    m.appSleeping = false
    m.appPlaying = true
    m.appManualPaused = false
    m.appMenu = ""
    m.appMenuZone = "rows"
    m.appFooterIndex = 0
    m.appCategoryIndex = 0
    m.appPicker = invalid
    m.appConfirm = invalid
    m.appKeyboard = invalid
    m.appCurrent = "dashboard"
    m.appStatus = {calendar:"Ready",weather:"Ready",news:"Ready",telegram:"Ready"}
    m.appIdleClock = mockClock(0)
    m.appUptime = mockClock(0)
    appResetKeepRunningState()
    m.appKeepVideo = {state:"stopped",control:"stop",content:invalid,errorCode:0}
    m.appKeepContent = {url:"pkg:/media/hourly-black.mp4",streamFormat:"mp4"}
    m.appRotationClock = mockClock(0)
    m.appArmedSeconds = 120
    m.appRemaining = 120
    m.appSettingsDirty = false
    m.appSaveRetryAt = 0
    m.appStorage = {state:"run"}
    m.appPendingRefresh = {}
    m.appRequests = {}
    m.appTelegramShown = false
    m.appPendingNews = invalid
    m.appNewsIndex = 0
    m.newsStories = []
    m.telegramPages = []
    m.telegramAvailablePages = []
    m.telegramPosts = []
    m.telegramPageIndex = 0
    m.rotationPage = "dashboard"
    m.rotationTimer = {control:"stop",duration:120}
    m.pageTimer = {control:"stop"}
    m.displayColor = ""
    m.content = mockNode()
    m.appChrome = mockNode()
    m.appDate = mockNode()
    m.appHint = mockNode()
    m.appOverlay = mockNode()
    m.todayItems = []
    m.todayPage = 0
    m.agendaLines = []
    m.agendaPage = 0
    m.clock = mockNode()
    m.clock.opacity = 1
    m.clock.font.uri = "font:SystemFontFile"
    m.clockPrevious = mockNode()
    m.clockPrevious.opacity = 0
    m.clockPeriod = mockNode()
    m.clockPeriod.visible = false
    m.clockFx = {control:"stop",state:"stopped"}
    m.clockIn = {}
    m.clockOut = {}
    m.clockLift = {}
    m.clockDrop = {}
    m.appClockBase = [0,0]
    m.appClockSleepAt = 0
    m.appClockSleepSlot = -1
    m.appClockSleepSeed = 0
    m.today = mockNode()
    m.todayBody = mockNode()
    m.heading = mockNode()
    m.agenda = mockNode()
    m.weatherGroup = mockNode()
    m.newsGroup = mockNode()
    m.telegramGroup = mockNode()
    m.telegramGrid = mockNode()
    m.calendarTask = {state:"stop",uri:""}
    nodes = {}
    for each id in ["weatherLocation","weatherChart","weatherForecast","weatherRange","weatherForecastHeading","newsTitle","newsSummary","newsUrl","newsHeading","newsAttribution","telegramHeading","telegramStatus","telegramAttribution"]
        nodes[id] = mockNode()
    end for
    m.top = {nodes:nodes,FindNode:mockFindNode,setFocus:mockFocus,lastExitReason:"Unknown"}
end sub

function mockNode() as object
    return {font:{size:30},text:"",visible:true,color:"",translation:[0,0],scale:[1,1],children:[],createChild:mockCreateChild,getChildCount:mockChildCount,getChild:mockGetChild,removeChildrenIndex:mockClear,subtype:mockSubtype}
end function
function mockCreateChild(kind as string) as object
    child = mockNode()
    child.kind = kind
    m.children.Push(child)
    return child
end function
function mockChildCount() as integer
    return m.children.Count()
end function
sub mockClear(count as integer, index as integer)
    for i = 1 to count
        m.children.Delete(index)
    end for
end sub
function mockGetChild(index as integer) as object
    return m.children[index]
end function
function mockSubtype() as string
    if m.kind <> invalid then return m.kind
    return "Group"
end function
function mockFocus(focus as boolean) as boolean
    return true
end function
function mockFindNode(id as string) as object
    return m.nodes[id]
end function
function mockClock(seconds as integer) as object
    return {value:seconds * 1000,Mark:mockMark,TotalMilliseconds:mockMilliseconds}
end function
sub mockMark()
    m.value = 0
end sub
function mockMilliseconds() as integer
    return m.value
end function
sub check(condition as boolean, message as string)
    if condition then return
    print "FAIL: "; message
    m.failures = m.failures + 1
end sub
