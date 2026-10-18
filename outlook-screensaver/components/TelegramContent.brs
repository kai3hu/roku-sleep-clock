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
                text = telegramPlainText(telegramDivBody(mid(body, body.Instr(textMatch[0]) + 1)))
                dateMatch = CreateObject("roRegex", "<time[^>]*datetime=" + q + "([^" + q + "]+)" + q, "is").Match(body)
                if text <> "" and dateMatch.Count() > 1
                    result.Push({id:val(item[1]), text:text, timestamp:dateMatch[1], url:"https://t.me/" + channel + "/" + item[1]})
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
            width = width + 28
        else
            width = width + 17
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
        if telegramTextWidth(line + char, font) > width and line <> ""
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

' Keep whole short posts together. Overflowing posts continue across columns/pages.
function telegramBuildPages(posts as object, font as dynamic) as object
    pages = []
    cards = []
    heights = [0, 0]
    lineHeight = 38
    if font <> invalid then lineHeight = font.GetOneLineHeight() + 2
    ' Leave safe vertical headroom for SceneGraph's CJK glyph ascent/descent.
    if lineHeight < 42 then lineHeight = 42
    capacity = int((620 - 60) / lineHeight)
    if capacity < 1 then capacity = 1
    for each post in posts
        lines = telegramWrapLines(post.text, font)
        if lines.Count() > capacity
            ' Long posts receive an exclusive full-width page before any continuation.
            if cards.Count() > 0 then pages.Push(cards)
            cards = []
            heights = [0, 0]
            wideLines = telegramWrapLines(post.text, font, 1640)
            offset = 0
            while offset < wideLines.Count()
                count = wideLines.Count() - offset
                if count > capacity then count = capacity
                part = []
                for i = offset to offset + count - 1
                    part.Push(wideLines[i])
                end for
                pages.Push([{post:post, x:0, y:0, width:1650, text:part.Join(chr(10)), lines:count, height:count * lineHeight + 8, continued:offset > 0}])
                offset = offset + count
            end while
        else
            offset = 0
            while offset < lines.Count()
                column = 0
                if heights[1] < heights[0] then column = 1
                remaining = lines.Count() - offset
                room = int((620 - heights[column] - 60) / lineHeight)
                ' If a complete post fits an empty column, do not split it into leftover space.
                if room < 1 or (remaining <= capacity and remaining > room)
                    if cards.Count() > 0 then pages.Push(cards)
                    cards = []
                    heights = [0, 0]
                    column = 0
                    room = capacity
                end if
                count = remaining
                if count > room then count = room
                part = []
                for i = offset to offset + count - 1
                    part.Push(lines[i])
                end for
                height = count * lineHeight + 8
                cards.Push({post:post, x:column * 860, y:heights[column], width:790, text:part.Join(chr(10)), lines:count, height:height, continued:offset > 0})
                heights[column] = heights[column] + height + 52
                offset = offset + count
            end while
        end if
    end for
    if cards.Count() > 0 then pages.Push(cards)
    return pages
end function

function telegramLocalTime(stamp as string) as string
    date = CreateObject("roDateTime")
    date.FromISO8601String(stamp)
    date.ToLocalTime()
    return padTwo(date.GetMonth()) + "/" + padTwo(date.GetDayOfMonth()) + " " + padTwo(date.GetHours()) + ":" + padTwo(date.GetMinutes())
end function
