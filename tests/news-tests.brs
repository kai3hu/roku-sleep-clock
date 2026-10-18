sub Main()
    m.failures = 0
    feeds = []
    for each category in newsCategories()
        clusters = [newsFixture("Election campaign debate", "Political summary", "politics")]
        for i = 1 to 3
            clusters.Push(newsFixture(category.name + " story " + i.ToStr(), "A useful summary [example.com#1] with *plain text*.", category.name + i.ToStr()))
        end for
        parsed = newsParseFeed({timestamp:1792308924, clusters:clusters}, category.name)
        check(parsed.Count() = 4 and parsed[0].title = category.name + " story 1", "Political headlines are ranked behind topical reporting")
        check(parsed[0].summary = "A useful summary with plain text.", "Citation markers and Markdown are cleaned")
        feeds.Push(parsed)
    end for
    stories = newsChooseStories(feeds)
    check(stories.Count() = 9, "Three stories from each preferred topic")
    check(stories[0].category = "Technology" and stories[1].category = "Science" and stories[2].category = "Economy", "Topics are interleaved")
    check(newsParseFeed(invalid, "Science").Count() = 0, "Network or parse failure is harmless")
    check(newsParseFeed({timestamp:"invalid", clusters:[]}, "Science").Count() = 0, "Invalid publication timestamps are ignored")
    check(newsParseFeed({timestamp:1792308924, clusters:[{}]}, "Science").Count() = 0, "Incomplete stories are ignored")
    check(newsValidateStory({title:"A",summary:"B",sourceUrl:"http://example.com",category:"Science",edition:"2026-10-18"}) = invalid, "Only HTTPS source links are retained")
    check(newsValidateStory({title:"A",summary:"B",sourceUrl:"https://example.com",category:"World",edition:"2026-10-18"}) = invalid, "General world/politics categories are excluded")
    check(newsCachedStories({stories:[stories[0], {}]}).Count() = 1, "Public news cache is schema-validated")
    check(newsChooseStories([feeds[0], feeds[0], []]).Count() = 3, "Cross-category duplicates are not repeated")
    print "NEWS_TEST_FAILURES="; m.failures
end sub

function newsFixture(title as string, summary as string, key as string) as object
    return {title:title, short_summary:summary, articles:[{link:"https://example.com/" + key}]}
end function

sub check(condition as boolean, message as string)
    if condition then return
    print "FAIL: "; message
    m.failures = m.failures + 1
end sub
