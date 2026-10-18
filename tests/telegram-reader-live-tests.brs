' Optional network integration, with ignored fixtures downloaded by the helper.
sub Main()
    html = ReadAsciiFile("pkg:/.tools/telegram-feed.html")
    data = ParseJson(ReadAsciiFile("pkg:/.tools/telegram-articles.json"))
    parsed = telegramParsePosts(html, telegramChannel())
    posts = []
    sourceCount = 0
    for each post in parsed
        if post.sourceOnly
            article = telegramParseArticle(data[post.articleUrl], post.articleUrl)
            if article = invalid
                print "FAIL: Source article missing for post "; post.id
                return
            end if
            posts.Push(telegramPostWithArticle(post, article))
            sourceCount = sourceCount + 1
        else
            posts.Push(post)
        end if
    end for
    if posts.Count() = 0
        print "FAIL: Empty public feed"
        return
    end if
    pages = telegramBuildPages(posts, invalid)
    for each post in posts
        original = post.text.Replace(chr(10), "").Replace(" ", "")
        restored = ""
        for each page in pages
            if page.Count() <> 1
                print "FAIL: Multiple messages on one page"
                return
            end if
            card = page[0]
            if card.post.id = post.id then restored = restored + card.text.Replace(chr(10), "").Replace(" ", "")
        end for
        if restored <> original
            print "FAIL: Article or message characters were lost on pagination"
            return
        end if
    end for
    print "Verified source articles: "; sourceCount
    print "READER_PAGES_JSON="; readerFixtureJson(pages)
end sub

' The desktop interpreter's FormatJson does not escape strings or shared references.
function readerFixtureJson(value as dynamic) as string
    if value = invalid then return "null"
    if isText(value)
        q = chr(34)
        escaped = value.Replace("\", "\\").Replace(q, "\" + q)
        escaped = escaped.Replace(chr(10), "\n").Replace(chr(13), "\r").Replace(chr(9), "\t")
        return q + escaped + q
    end if
    parts = []
    if type(value) = "roArray"
        for each child in value
            parts.Push(readerFixtureJson(child))
        end for
        return "[" + parts.Join(",") + "]"
    end if
    if type(value) = "roAssociativeArray"
        for each key in value
            parts.Push(readerFixtureJson(key) + ":" + readerFixtureJson(value[key]))
        end for
        return "{" + parts.Join(",") + "}"
    end if
    if type(value) = "Boolean" or type(value) = "roBoolean"
        if value then return "true"
        return "false"
    end if
    return value.ToStr().Trim()
end function
