sub Main()
    feeds = []
    for each category in newsCategories()
        data = ParseJson(ReadAsciiFile("pkg:/.tools/kagi-" + category.file))
        stories = newsParseFeed(data, category.name)
        if stories.Count() = 0
            print "FAIL: No usable live stories for "; category.name
            return
        end if
        print "Parsed "; stories.Count(); " live "; category.name; " stories"
        feeds.Push(stories)
    end for
    result = newsChooseStories(feeds)
    if result.Count() < 6
        print "FAIL: Too few stories from the preferred topics"
        return
    end if
    print "PASS: Live Kagi News feeds parsed and interleaved"
end sub
