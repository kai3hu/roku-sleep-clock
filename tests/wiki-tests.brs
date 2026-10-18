sub Main()
    m.failures = 0
    dates = wikiRecentDates("2026-01-02")
    check(dates.Join(",") = "2026-01-02,2026-01-01,2025-12-31,2025-12-30,2025-12-29", "Five daily dates cross the year boundary")
    check(wikiRecentDates("2024-03-01")[1] = "2024-02-29", "Leap day is retained")
    check(wikiRecentDates("2026-11-02")[1] = "2026-11-01", "Calendar dates are independent of DST")
    sample = {title:"Sample_article", extract:"A short plain-text article.", content_urls:{desktop:{page:"https://en.wikipedia.org/wiki/Sample_article"}}}
    article = wikiParseArticle(sample, "2026-10-18")
    check(article.title = "Sample article" and article.featuredDate = "2026-10-18", "Plain title and featured date")
    check(wikiParseArticle(invalid, "2026-10-18") = invalid, "Missing article is ignored")
    check(wikiParseArticle({}, "2026-10-18") = invalid, "Incomplete article is ignored")
    sample.content_urls.desktop.page = "https://example.com/not-wikipedia"
    check(wikiParseArticle(sample, "2026-10-18") = invalid, "Only Wikipedia source links are accepted")
    check(wikiShortText(" hello" + chr(10) + " world ", 100) = "hello world", "Whitespace is normalized")
    longText = ""
    for i = 1 to 200
        longText = longText + "sample "
    end for
    shortened = wikiShortText(longText, 600)
    check(len(shortened) <= 600 and right(shortened, 3) = "...", "Long excerpts fit the single-page limit")
    check(wikiCachedArticles(invalid).Count() = 0, "Invalid cache is harmless")
    check(wikiCachedArticles({articles:[{}, article, invalid]}).Count() = 1, "Cache entries are validated")

    m.wikiArticles = []
    for i = 1 to 5
        m.wikiArticles.Push({title:"Article " + i.ToStr(), extract:"Sample", url:"https://en.wikipedia.org/wiki/" + i.ToStr(), featuredDate:"2026-10-18"})
    end for
    m.pendingWikiArticles = invalid
    m.rotationPage = "agenda"
    m.nextWikiIndex = 0
    m.heading = {visible:true}
    m.agenda = {visible:true}
    m.weatherGroup = {visible:true}
    m.wikiGroup = {visible:false}
    m.pageTimer = {control:"start"}
    m.rotationTimer = {control:"start", duration:180}
    m.top = {nodes:{wikiHeading:{text:""}, wikiTitle:{text:""}, wikiExtract:{text:""}, wikiUrl:{text:""}}, FindNode:findMockWikiNode}
    for i = 0 to 10
        rotateContent()
        check(m.rotationPage = "wiki" and m.rotationTimer.duration = 60, "Article interval lasts 60 seconds")
        check(m.top.nodes.wikiTitle.text = "Article " + ((i mod 5) + 1).ToStr(), "Articles loop in order without skipping")
        check(m.wikiGroup.visible and not m.agenda.visible and not m.weatherGroup.visible, "Exactly one content page is visible")
        check(m.pageTimer.control = "stop", "Agenda pagination pauses on article pages")
        rotateContent()
        check(m.rotationPage = "agenda" and m.rotationTimer.duration = 180, "Agenda returns for 180 seconds between articles")
        check(not m.wikiGroup.visible and m.agenda.visible and m.weatherGroup.visible, "Agenda and weather return together")
    end for
    m.wikiArticles = []
    rotateContent()
    check(m.rotationPage = "agenda" and m.rotationTimer.duration = 180, "No articles means no empty page")

    m.wikiArticles = [article]
    m.nextWikiIndex = 0
    m.wikiTask = {result:{articles:[article], complete:true, day:"2026-10-18"}}
    rotateContent()
    onWikiChanged()
    check(m.pendingWikiArticles.Count() = 1 and m.rotationPage = "wiki", "New data waits until the current article finishes")
    rotateContent()
    check(m.pendingWikiArticles = invalid and m.rotationPage = "agenda", "Pending data is installed at a page boundary")
    check(m.wikiLoadedDay = "2026-10-18", "Successful collection is marked for the local day")
    print "WIKI_TEST_FAILURES="; m.failures
end sub

function findMockWikiNode(id as string) as object
    return m.nodes[id]
end function

sub check(condition as boolean, message as string)
    if condition then return
    print "FAIL: "; message
    m.failures = m.failures + 1
end sub
