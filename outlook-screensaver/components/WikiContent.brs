function wikiDateKey(date as object) as string
    return date.GetYear().ToStr() + "-" + wikiPad(date.GetMonth()) + "-" + wikiPad(date.GetDayOfMonth())
end function

function wikiPad(value as integer) as string
    if value < 10 then return "0" + value.ToStr()
    return value.ToStr()
end function

function wikiRecentDates(day as string) as object
    date = CreateObject("roDateTime")
    date.FromISO8601String(day + "T12:00:00Z")
    stamp = date.AsSeconds()
    result = []
    for i = 0 to 4
        date.FromSeconds(stamp - i * 86400)
        result.Push(wikiDateKey(date))
    end for
    return result
end function

function wikiIsString(value as dynamic) as boolean
    return type(value) = "String" or type(value) = "roString"
end function

function wikiShortText(value as string, limit as integer) as string
    text = value.Replace(chr(13), " ").Replace(chr(10), " ").Replace(chr(9), " ").Trim()
    while text.Instr("  ") >= 0
        text = text.Replace("  ", " ")
    end while
    if len(text) <= limit then return text
    words = left(text, limit - 3).Split(" ")
    if words.Count() > 1 then words.Pop()
    return words.Join(" ") + "..."
end function

function wikiParseArticle(data as dynamic, day as string) as dynamic
    if type(data) <> "roAssociativeArray" then return invalid
    if not wikiIsString(data.title) or not wikiIsString(data.extract) then return invalid
    if data.title.Trim() = "" or data.extract.Trim() = "" then return invalid
    urls = data.content_urls
    if type(urls) <> "roAssociativeArray" then return invalid
    if type(urls.desktop) <> "roAssociativeArray" then return invalid
    url = urls.desktop.page
    if not wikiIsString(url) then return invalid
    if left(url, 30) <> "https://en.wikipedia.org/wiki/" then return invalid
    return {
        title: wikiShortText(data.title.Replace("_", " "), 110)
        extract: wikiShortText(data.extract, 600)
        url: url
        featuredDate: day
    }
end function

function wikiCachedArticles(cache as dynamic) as object
    result = []
    if type(cache) <> "roAssociativeArray" then return result
    if type(cache.articles) <> "roArray" then return result
    for each item in cache.articles
        if type(item) = "roAssociativeArray"
            if wikiIsString(item.featuredDate)
                article = wikiParseArticle({title:item.title, extract:item.extract, content_urls:{desktop:{page:item.url}}}, item.featuredDate)
                if article <> invalid and result.Count() < 5 then result.Push(article)
            end if
        end if
    end for
    return result
end function

' Alternate every agenda interval with the next single article.
function wikiNextPhase(current as string, nextIndex as integer, count as integer) as object
    if current = "agenda" and count > 0
        index = nextIndex mod count
        return {page:"wiki", duration:60, index:index, nextIndex:(index + 1) mod count}
    end if
    return {page:"agenda", duration:180, index:-1, nextIndex:nextIndex}
end function
