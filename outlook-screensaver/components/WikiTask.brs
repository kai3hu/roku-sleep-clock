sub init()
    m.top.functionName = "downloadWiki"
end sub

sub downloadWiki()
    section = CreateObject("roRegistrySection", "DailyWikipedia")
    cached = wikiCachedArticles(ParseJson(section.Read("articles")))
    if cached.Count() > 0
        m.top.result = {articles:cached, day:m.top.day, complete:false}
    end if
    articles = []
    seen = {}
    for each day in wikiRecentDates(m.top.day)
        article = invalid
        for each item in cached
            if item.featuredDate = day then article = item
        end for
        if article = invalid
            data = fetchWikiFeed(day)
            if type(data) = "roAssociativeArray" then article = wikiParseArticle(data.tfa, day)
        end if
        if article <> invalid
            if not seen.DoesExist(article.url)
                articles.Push(article)
                seen[article.url] = true
            end if
        end if
    end for
    complete = articles.Count() = 5
    if articles.Count() > 0
        section.Write("articles", FormatJson({articles:articles}))
        section.Flush()
    else
        articles = cached
    end if
    m.top.result = {articles:articles, day:m.top.day, complete:complete}
end sub

function fetchWikiFeed(day as string) as dynamic
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnableEncodings(true)
    transfer.AddHeader("User-Agent", "RokuSleepClock/1.0 (https://github.com/kai3hu/roku-sleep-clock)")
    transfer.SetUrl("https://en.wikipedia.org/api/rest_v1/feed/featured/" + day.Replace("-", "/"))
    if not transfer.AsyncGetToString() then return invalid
    response = wait(15000, port)
    if response = invalid
        transfer.AsyncCancel()
        return invalid
    end if
    if type(response) <> "roUrlEvent" then return invalid
    if response.GetResponseCode() <> 200 then return invalid
    return ParseJson(response.GetString())
end function
