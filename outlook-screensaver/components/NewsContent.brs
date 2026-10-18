function newsCategories() as object
    return [{name:"Technology", file:"tech.json"}, {name:"Science", file:"science.json"}, {name:"Economy", file:"economy.json"}]
end function

function newsCleanText(value as string) as string
    text = CreateObject("roRegex", "\[[^\]]+#[0-9]+\]", "i").ReplaceAll(value, "")
    text = text.Replace("**", "").Replace("*", "")
    return shortText(text, len(text) + 1)
end function

function newsPoliticalHeadline(title as string) as boolean
    pattern = "(^|[^a-z])(politics|political|election|elections|trump|biden|putin|netanyahu|ceasefire|war|missiles|parliament|senate)([^a-z]|$)"
    return CreateObject("roRegex", pattern, "i").IsMatch(title)
end function

function newsValidateStory(item as dynamic) as dynamic
    if type(item) <> "roAssociativeArray" then return invalid
    if not isText(item.title) or not isText(item.summary) or not isText(item.sourceUrl) then return invalid
    if not isText(item.category) or not isText(item.edition) then return invalid
    if item.title.Trim() = "" or item.summary.Trim() = "" then return invalid
    if left(item.sourceUrl, 8) <> "https://" then return invalid
    if item.category <> "Technology" and item.category <> "Science" and item.category <> "Economy" then return invalid
    return {title:shortText(item.title, 120), summary:shortText(item.summary, 650), sourceUrl:item.sourceUrl, category:item.category, edition:left(item.edition, 10), url:item.sourceUrl}
end function

function newsParseFeed(data as dynamic, category as string) as object
    normal = []
    political = []
    if type(data) <> "roAssociativeArray" then return normal
    if type(data.clusters) <> "roArray" then return normal
    stampType = type(data.timestamp)
    if stampType <> "Integer" and stampType <> "roInt" and stampType <> "Float" and stampType <> "roFloat" and stampType <> "Double" and stampType <> "roDouble" and stampType <> "LongInteger" and stampType <> "roLongInteger" then return normal
    date = CreateObject("roDateTime")
    date.FromSeconds(int(data.timestamp))
    edition = localDateKey(date)
    for each cluster in data.clusters
        if type(cluster) = "roAssociativeArray"
            if isText(cluster.title) and isText(cluster.short_summary) and type(cluster.articles) = "roArray"
                source = ""
                for each article in cluster.articles
                    if type(article) = "roAssociativeArray"
                        if isText(article.link)
                            if left(article.link, 8) = "https://" and source = "" then source = article.link
                        end if
                    end if
                end for
                item = newsValidateStory({title:newsCleanText(cluster.title), summary:newsCleanText(cluster.short_summary), sourceUrl:source, category:category, edition:edition})
                if item <> invalid
                    if newsPoliticalHeadline(item.title)
                        political.Push(item)
                    else
                        normal.Push(item)
                    end if
                end if
            end if
        end if
    end for
    for each item in political
        normal.Push(item)
    end for
    return normal
end function

function newsChooseStories(feeds as object) as object
    result = []
    seen = {}
    ' Interleave topics so every three visits include Tech, Science and Economy.
    for row = 0 to 2
        for each feed in feeds
            if feed.Count() > row
                item = feed[row]
                key = lcase(item.title)
                if not seen.DoesExist(key) and not seen.DoesExist(item.sourceUrl)
                    result.Push(item)
                    seen[key] = true
                    seen[item.sourceUrl] = true
                end if
            end if
        end for
    end for
    return result
end function

function newsCachedStories(cache as dynamic) as object
    result = []
    if type(cache) <> "roAssociativeArray" then return result
    if type(cache.stories) <> "roArray" then return result
    for each item in cache.stories
        story = newsValidateStory(item)
        if story <> invalid and result.Count() < 9 then result.Push(story)
    end for
    return result
end function
