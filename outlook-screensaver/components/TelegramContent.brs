function telegramChannel() as string
    return "DNSPODT"
end function
' Extract a balanced div, including nested quotes and custom emoji wrappers.
function telegramDivBody(markup as string) as string
    tags = CreateObject("roRegex", "<div\b[^>]*>|</div\s*>", "is").MatchAll(markup)
    if tags.Count() = 0 then return ""
    depth = 0
    cursor = 0
    first = 0
    for each tag in tags
        tail = mid(markup, cursor + 1)
        position = cursor + tail.Instr(tag[0])
        if left(lcase(tag[0]), 2) = "</"
            depth = depth - 1
            if depth = 0 then return mid(markup, first + 1, position - first)
        else
            if depth = 0 then first = position + len(tag[0])
            depth = depth + 1
        end if
        cursor = position + len(tag[0])
    end for
    return ""
end function

function telegramPlainText(markup as string) as string
    text = CreateObject("roRegex", "<(script|style)\b[^>]*>.*?</\1\s*>", "is").ReplaceAll(markup, " ")
    text = CreateObject("roRegex", "<br\s*/?>|</(p|div|blockquote)\s*>", "is").ReplaceAll(text, " ")
    text = CreateObject("roRegex", "<[^>]*>", "is").ReplaceAll(text, "")
    entities = CreateObject("roRegex", "&#(x[0-9a-f]+|[0-9]+);", "i").MatchAll(text)
    for each entity in entities
        code = 0
        if left(lcase(entity[1]), 1) = "x"
            for i = 2 to len(entity[1])
                digit = "0123456789abcdef".Instr(lcase(mid(entity[1], i, 1)))
                code = code * 16 + digit
            end for
        else
            code = val(entity[1])
        end if
        replacement = " "
        if code >= 32 and code <= 65535 then replacement = chr(code)
        text = text.Replace(entity[0], replacement)
    end for
    text = text.Replace("&nbsp;", " ").Replace("&quot;", chr(34)).Replace("&apos;", "'")
    text = text.Replace("&lt;", "<").Replace("&gt;", ">").Replace("&amp;", "&")
    return shortText(text.Replace(chr(160), " "), len(text) + 1)
end function

function telegramParsePosts(html as string, channel as string) as object
    result = []
    q = chr(34)
    marker = "<div[^>]*data-post=" + q + channel + "/([0-9]+)" + q + "[^>]*>"
    matches = CreateObject("roRegex", marker, "is").MatchAll(html)
    remaining = html
    seen = {}
    for each item in matches
        start = remaining.Instr(item[0])
        if start >= 0
            remaining = mid(remaining, start + 1)
            body = telegramDivBody(remaining)
            remaining = mid(remaining, len(item[0]) + 1)
            ' Reply previews use js-message_reply_text, never the post's own body class.
            textTag = "<div[^>]*class=" + q + "[^" + q + "]*\bjs-message_text\b[^" + q + "]*" + q + "[^>]*>"
            textMatch = CreateObject("roRegex", textTag, "is").Match(body)
            if textMatch.Count() > 0 and not seen.DoesExist(item[1])
                ownMarkup = telegramDivBody(mid(body, body.Instr(textMatch[0]) + 1))
                text = telegramPlainText(ownMarkup)
                dateMatch = CreateObject("roRegex", "<time[^>]*datetime=" + q + "([^" + q + "]+)" + q, "is").Match(body)
                if text <> "" and dateMatch.Count() > 1
                    links = telegramSourceLinks(ownMarkup, text)
                    result.Push({id:val(item[1]), text:text, timestamp:dateMatch[1], url:"https://t.me/" + channel + "/" + item[1], sourceOnly:links.sourceOnly, articleUrl:links.articleUrl})
                    seen[item[1]] = true
                end if
            end if
        end if
    end for
    result.SortBy("id", "r")
    while result.Count() > 6
        result.Pop()
    end while
    return result
end function

function telegramTextWidth(text as string, font as dynamic) as integer
    if font <> invalid then return font.GetOneLineWidth(text, 100000)
    width = 0
    for i = 1 to len(text)
        if asc(mid(text, i, 1)) > 255
            width = width + 34
        else
            width = width + 34
        end if
    end for
    return width
end function

function telegramLastSpace(text as string) as integer
    for i = len(text) to 1 step -1
        if mid(text, i, 1) = " " then return i - 1
    end for
    return -1
end function

function telegramWrapLines(text as string, font as dynamic, width = 780 as integer) as object
    lines = []
    line = ""
    for i = 1 to len(text)
        char = mid(text, i, 1)
        if char = chr(10)
            lines.Push(line.Trim())
            line = ""
        else if telegramTextWidth(line + char, font) > width and line <> ""
            splitAt = telegramLastSpace(line)
            carry = char
            if splitAt > len(line) / 2
                carry = mid(line, splitAt + 2) + char
                line = left(line, splitAt)
            end if
            lines.Push(line.Trim())
            line = carry.Trim()
        else
            line = line + char
        end if
    end for
    if line.Trim() <> "" then lines.Push(line.Trim())
    return lines
end function

' Each message owns the entire reading area, including all continuation pages.
function telegramBuildPages(posts as object, font as dynamic) as object
    pages = []
    lineHeight = 46
    if font <> invalid then lineHeight = font.GetOneLineHeight() + 2
    if lineHeight < 46 then lineHeight = 46
    capacity = int(600 / lineHeight)
    if capacity < 1 then capacity = 1
    for each post in posts
        lines = telegramWrapLines(post.text, font, 1600)
        offset = 0
        parts = int((lines.Count() + capacity - 1) / capacity)
        baseSize = 0
        extraLines = 0
        if parts > 0
            baseSize = int(lines.Count() / parts)
            extraLines = lines.Count() mod parts
        end if
        partIndex = 1
        while offset < lines.Count()
            count = baseSize
            if partIndex <= extraLines then count = count + 1
            part = []
            for i = offset to offset + count - 1
                part.Push(lines[i])
            end for
            text = part.Join(chr(10))
            isArticle = post.isArticle = true
            duration = telegramReadingSeconds(text, isArticle)
            pages.Push([{post:post, x:0, y:0, width:1650, text:text, lineTexts:part, lineHeight:lineHeight, lines:count, height:count * lineHeight, continued:offset > 0, part:partIndex, parts:parts, duration:duration}])
            offset = offset + count
            partIndex = partIndex + 1
        end while
    end for
    return pages
end function

function telegramReadingSeconds(text as string, isArticle as boolean) as integer
    cjk = 0
    words = 0
    inWord = false
    for i = 1 to len(text)
        char = mid(text, i, 1)
        if asc(char) > 255
            cjk = cjk + 1
            inWord = false
        else if char <> " " and char <> chr(10) and char <> chr(13) and char <> chr(9)
            if not inWord then words = words + 1
            inWord = true
        else
            inWord = false
        end if
    end for
    seconds = int(cjk / 5 + words / 3.3 + 15.999)
    minimum = 60
    maximum = 150
    if isArticle
        minimum = 90
        maximum = 180
    end if
    if seconds < minimum then seconds = minimum
    if seconds > maximum then seconds = maximum
    return seconds
end function

function telegramHasContinuation(pages as object, nextIndex as integer) as boolean
    if nextIndex < 1 or nextIndex >= pages.Count() then return false
    previous = pages[nextIndex - 1]
    following = pages[nextIndex]
    if previous.Count() = 0 or following.Count() = 0 then return false
    return following[0].continued = true and previous[0].post.id = following[0].post.id
end function

' Accept only public Telegraph article paths, never arbitrary linked hosts.
function telegramTelegraphPath(url as string) as string
    match = CreateObject("roRegex", "^https://telegra[.]ph/([^?#]+)([?#].*)?$", "i").Match(url)
    if match.Count() < 2 then return ""
    raw = match[1]
    if len(raw) > 2048 then return ""
    if CreateObject("roRegex", "%[0-9a-f]{2}", "i").ReplaceAll(raw, "").Instr("%") >= 0 then return ""
    slug = raw.Unescape()
    if slug = "" or slug.Instr("..") >= 0 then return ""
    if CreateObject("roRegex", "[/\\?#%\x00-\x1f]", "").IsMatch(slug) then return ""
    return slug.Escape()
end function

function telegramSourceLinks(markup as string, text as string) as object
    result = {sourceOnly:CreateObject("roRegex", "\bsource[\s.!:;]*$", "i").IsMatch(text), articleUrl:""}
    if not result.sourceOnly then return result
    q = chr(34)
    anchors = CreateObject("roRegex", "<a\b[^>]*href=" + q + "([^" + q + "]+)" + q, "is").MatchAll(markup)
    for each anchor in anchors
        url = anchor[1].Replace("&amp;", "&")
        path = telegramTelegraphPath(url)
        if path <> ""
            result.articleUrl = "https://telegra.ph/" + path
            return result
        end if
    end for
    return result
end function

' Telegraph content is structured JSON, not HTML. Ignore embedded media.
function telegramArticleNodeText(node as dynamic, depth = 0 as integer, state = invalid as dynamic) as string
    if state = invalid then state = {complete:true}
    if depth > 32
        state.complete = false
        return ""
    end if
    if isText(node) then return node
    if type(node) = "roArray"
        text = ""
        for each child in node
            text = text + telegramArticleNodeText(child, depth + 1, state)
        end for
        return text
    end if
    if type(node) <> "roAssociativeArray" then return ""
    if not isText(node.tag) then return ""
    tag = lcase(node.tag)
    if tag = "img" or tag = "video" or tag = "iframe" or tag = "script" or tag = "style" then return ""
    if tag = "br" or tag = "hr" then return chr(10)
    text = telegramArticleNodeText(node.children, depth + 1, state)
    if tag = "p" or tag = "h3" or tag = "h4" or tag = "blockquote" or tag = "li" or tag = "pre" or tag = "figure" or tag = "figcaption" or tag = "ul" or tag = "ol" or tag = "aside"
        return chr(10) + text + chr(10)
    end if
    return text
end function

function telegramNormalizeArticle(text as string) as string
    text = text.Replace(chr(13), "").Replace(chr(160), " ")
    paragraphs = []
    for each line in text.Split(chr(10))
        cleaned = CreateObject("roRegex", "[ \t]+", "").ReplaceAll(line, " ").Trim()
        if cleaned <> "" then paragraphs.Push(cleaned)
    end for
    return paragraphs.Join(chr(10))
end function

function telegramParseArticle(data as dynamic, url as string) as dynamic
    if type(data) <> "roAssociativeArray" then return invalid
    if data.ok <> true then return invalid
    page = data.result
    if type(page) <> "roAssociativeArray" then return invalid
    if not isText(page.title) or type(page.content) <> "roArray" then return invalid
    state = {complete:true}
    text = telegramNormalizeArticle(telegramArticleNodeText(page.content, 0, state))
    if not state.complete then return invalid
    if text = "" then return invalid
    title = telegramNormalizeArticle(page.title)
    author = ""
    if isText(page.author_name) then author = shortText(page.author_name, 100)
    return {title:title, text:text, author:author, url:url}
end function

function telegramPostWithArticle(post as object, article as object) as object
    return {id:post.id, timestamp:post.timestamp, url:post.url, isArticle:true, articleUrl:article.url, author:article.author, text:article.title + chr(10) + chr(10) + article.text}
end function

function telegramLocalTime(stamp as string) as string
    date = CreateObject("roDateTime")
    date.FromISO8601String(stamp)
    date.ToLocalTime()
    return padTwo(date.GetMonth()) + "/" + padTwo(date.GetDayOfMonth()) + " " + padTwo(date.GetHours()) + ":" + padTwo(date.GetMinutes())
end function
