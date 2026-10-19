sub init()
    m.top.functionName = "downloadNews"
end sub

sub downloadNews()
    selectedCategories = m.top.categories
    if type(selectedCategories) <> "roArray" then selectedCategories = []
    if selectedCategories.Count() = 0 then selectedCategories = ["Technology","Science","Economy"]
    section = CreateObject("roRegistrySection", "KagiNews")
    cached = []
    if section.Exists("stories")
        text = section.Read("stories")
        if text <> "" then cached = newsCachedStories(ParseJson(text))
    end if
    allowed = []
    for each story in cached
        for each category in selectedCategories
            if story.category = category then allowed.Push(story)
        end for
    end for
    cached = allowed
    if cached.Count() > 0 then m.top.result = {stories:cached, delayed:true}
    feeds = []
    delayed = false
    for each category in newsCategories()
        enabled = false
        for each name in selectedCategories
            if name = category.name then enabled = true
        end for
        if not enabled then continue for
        items = newsParseFeed(fetchNewsFeed(category.file), category.name)
        if items.Count() = 0
            delayed = true
            for each story in cached
                if story.category = category.name then items.Push(story)
            end for
        end if
        feeds.Push(items)
    end for
    stories = newsChooseStories(feeds)
    if stories.Count() > 0
        section.Write("stories", FormatJson({stories:stories}))
        section.Flush()
    else
        stories = cached
    end if
    m.top.result = {stories:stories, delayed:delayed}
end sub

function fetchNewsFeed(file as string) as dynamic
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnableEncodings(true)
    transfer.AddHeader("User-Agent", "RokuSleepClock/1.0 (https://github.com/kai3hu/roku-sleep-clock)")
    transfer.SetUrl("https://news.kagi.com/" + file)
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
