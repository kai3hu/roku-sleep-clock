sub Main()
    m.failures = 0
    m.newsStories = []
    categories = ["Technology", "Science", "Economy"]
    for i = 0 to 8
        m.newsStories.Push({title:"Story " + (i + 1).ToStr(), summary:"Sample news summary", sourceUrl:"https://example.com/" + i.ToStr(), url:"https://example.com/" + i.ToStr(), category:categories[i mod 3], edition:"2026-10-18"})
    end for
    m.pendingNewsStories = invalid
    m.newsDelayed = false
    m.rotationPage = "agenda"
    m.nextNewsIndex = 0
    m.heading = {visible:true}
    m.today = {visible:true, text:""}
    m.todayBody = {visible:true, text:"", font:{size:34}}
    m.todayItems = []
    m.todayPage = 0
    m.agenda = {visible:true, text:""}
    m.agendaLines = []
    m.agendaPage = 0
    m.weatherGroup = {visible:true}
    m.newsGroup = {visible:false}
    m.telegramPosts = []
    m.telegramGroup = {visible:false}
    m.pageTimer = {control:"start"}
    m.rotationTimer = {control:"start", duration:120}
    m.top = {nodes:{newsHeading:{text:""}, newsTitle:{text:""}, newsSummary:{text:""}, newsUrl:{text:""}}, FindNode:findMockNewsNode}
    for i = 0 to 17
        rotateContent()
        check(m.rotationPage = "news" and m.rotationTimer.duration = 60, "News lasts one minute")
        check(m.top.nodes.newsTitle.text = "Story " + ((i mod 9) + 1).ToStr(), "Stories loop without skipping")
        check(m.newsGroup.visible and not m.todayBody.visible and not m.agenda.visible, "News has exclusive content visibility")
        check(m.pageTimer.control = "stop", "Agenda pagination pauses during news")
        rotateContent()
        check(m.rotationPage = "agenda" and m.rotationTimer.duration = 120, "Agenda returns for two minutes")
        check(m.todayBody.visible and m.weatherGroup.visible and not m.newsGroup.visible, "Today and weather return with the agenda")
    end for
    m.todayItems = [{timeLabel:"09:00",title:"First task"},{timeLabel:"10:00",title:"Second task"},{timeLabel:"11:00",title:"Third task"},{timeLabel:"15:00",title:"Fourth task"}]
    showTodayPage()
    check(m.todayBody.text.Instr("First task") >= 0 and m.todayBody.text.Instr("Fourth task") < 0, "Today has its own large three-event page")
    nextAgendaPage()
    check(m.todayBody.text.Instr("Fourth task") >= 0 and m.today.text.Instr("2 OF 2") >= 0, "Today's remaining tasks are paginated")
    m.todayItems = [{timeLabel:"09:00",title:"One task"}]
    m.todayPage = 0
    showTodayPage()
    check(m.todayBody.font.size = 38, "Sparse days use a larger font")
    m.todayItems = []
    showTodayPage()
    check(m.todayBody.text = "No events today", "Empty today view remains useful")
    original = m.newsStories
    rotateContent()
    m.newsTask = {result:{stories:[original[0]], delayed:false}}
    onNewsChanged()
    check(m.pendingNewsStories.Count() = 1 and m.newsStories.Count() = 9, "News refresh does not replace the article mid-minute")
    rotateContent()
    check(m.newsStories.Count() = 1, "Pending news is installed at the page boundary")
    m.telegramPosts = [{text:"Message"}]
    m.telegramPages = [[], []]
    m.telegramPageIndex = 0
    m.telegramPagesUpdated = "10/18 01:00"
    m.telegramDelayed = false
    m.telegramGrid = {getChildCount:emptyGridCount, removeChildrenIndex:clearEmptyGrid}
    m.top.nodes.telegramStatus = {text:""}
    rotateContent()
    rotateContent()
    check(m.rotationPage = "telegram" and m.telegramGroup.visible and not m.newsGroup.visible and not m.todayBody.visible, "Telegram follows news with exclusive visibility")
    check(m.rotationTimer.duration = 60 and m.telegramPageIndex = 1, "Telegram displays one page per minute-long visit")
    rotateContent()
    rotateContent()
    rotateContent()
    check(m.telegramPageIndex = 2, "Next Telegram visit resumes the next page")
    m.telegramTask = {result:{available:true, posts:[{text:"Updated message"}], pages:[[], [], []], fetchedAt:"2026-10-18T07:00:00Z"}}
    onTelegramChanged()
    check(m.telegramAvailablePages.Count() = 3 and m.telegramPages.Count() = 2, "Task-prepared pages wait for the current snapshot")
    rotateContent()
    rotateContent()
    rotateContent()
    check(m.telegramPages.Count() = 3 and m.telegramPageIndex = 1, "New collection consumes prepared pages without render-thread pagination")
    m.telegramTask.result = {available:false}
    onTelegramChanged()
    check(m.telegramDelayed and m.telegramAvailablePages.Count() = 3, "Failed Telegram refresh retains usable pages")
    ' Real reader rendering exercises SG fonts, timer overrides and continuation.
    m.displayColor = "0x0C0C0CFF"
    m.telegramGrid.createChild = mockReaderLabel
    m.top.nodes.telegramHeading = {text:""}
    m.top.nodes.telegramAttribution = {text:""}
    longText = ""
    for i = 1 to 900
        longText = longText + chr(20013)
    end for
    m.telegramPages = telegramBuildPages([{id:12,text:longText,isArticle:true,author:"Author",timestamp:"2026-10-18T07:00:00Z"},{id:13,text:"Next message",timestamp:"2026-10-18T07:00:00Z"}], invalid)
    m.telegramPageIndex = 0
    m.rotationPage = "news"
    rotateContent()
    check(m.rotationPage = "telegram" and m.telegramPageIndex = 1, "First article page is rendered")
    check(m.rotationTimer.duration >= 90, "Reader overrides the default minute with article reading time")
    check(m.top.nodes.telegramHeading.text.Instr("ARTICLE") > 0, "Source content is identified as an article")
    check(m.top.nodes.telegramStatus.text.Instr("Next page in") > 0, "Reading countdown is visible")
    rotateContent()
    check(m.rotationPage = "telegram" and m.telegramPageIndex = 2, "Continuation pages advance without agenda or news interruptions")
    check(m.top.nodes.telegramStatus.text.Instr("Update delayed") > 0, "Delayed-data notice survives the new reader")
    rotateContent()
    check(m.rotationPage = "agenda" and m.rotationTimer.duration = 120, "Article completion returns to agenda before the next message")
    print "NEWS_SCENE_TEST_FAILURES="; m.failures
end sub

function mockReaderLabel(kind as string) as object
    return {}
end function

function emptyGridCount() as integer
    return 0
end function

sub clearEmptyGrid(count as integer, index as integer)
end sub

function findMockNewsNode(id as string) as object
    return m.nodes[id]
end function

sub check(condition as boolean, message as string)
    if condition then return
    print "FAIL: "; message
    m.failures = m.failures + 1
end sub
