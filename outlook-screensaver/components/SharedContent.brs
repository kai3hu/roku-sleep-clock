function localDateKey(date as object) as string
    return date.GetYear().ToStr() + "-" + padTwo(date.GetMonth()) + "-" + padTwo(date.GetDayOfMonth())
end function

function padTwo(value as integer) as string
    if value < 10 then return "0" + value.ToStr()
    return value.ToStr()
end function

function isText(value as dynamic) as boolean
    return type(value) = "String" or type(value) = "roString"
end function

function shortText(value as string, limit as integer) as string
    text = value.Replace(chr(13), " ").Replace(chr(10), " ").Replace(chr(9), " ").Trim()
    while text.Instr("  ") >= 0
        text = text.Replace("  ", " ")
    end while
    if len(text) <= limit then return text
    words = left(text, limit - 3).Split(" ")
    if words.Count() > 1 then words.Pop()
    return words.Join(" ") + "..."
end function

function newsNextPhase(current as string, nextIndex as integer, count as integer) as object
    if current = "agenda" and count > 0
        index = nextIndex mod count
        return {page:"news", duration:60, index:index, nextIndex:(index + 1) mod count}
    end if
    return {page:"agenda", duration:120, index:-1, nextIndex:nextIndex}
end function

function screensaverNextPhase(current as string, nextIndex as integer, newsCount as integer, hasTelegram as boolean) as object
    if current = "news" and hasTelegram then return {page:"telegram", duration:60, index:-1, nextIndex:nextIndex}
    if current = "agenda" and newsCount = 0 and hasTelegram then return {page:"telegram", duration:60, index:-1, nextIndex:nextIndex}
    return newsNextPhase(current, nextIndex, newsCount)
end function
