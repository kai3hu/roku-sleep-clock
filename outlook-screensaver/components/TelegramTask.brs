sub init()
    m.top.functionName = "downloadTelegram"
end sub

sub downloadTelegram()
    html = telegramDownload("https://t.me/s/" + telegramChannel(), 20000)
    if html = invalid
        m.top.result = {available:false}
        return
    end if
    parsed = telegramParsePosts(html, telegramChannel())
    posts = []
    nextCache = {}
    if m.articleCache = invalid then m.articleCache = {}
    delayed = false
    now = CreateObject("roDateTime")
    fetchedAt = now.ToISOString()
    seconds = now.AsSeconds()
    for each post in parsed
        if post.sourceOnly
            path = telegramTelegraphPath(post.articleUrl)
            article = invalid
            cached = m.articleCache[post.articleUrl]
            if cached <> invalid
                article = cached.article
                if seconds - cached.fetchedAt >= 3600 then article = invalid
            end if
            if article = invalid and path <> ""
                json = telegramDownload("https://api.telegra.ph/getPage/" + path + "?return_content=true", 10000)
                if json <> invalid
                    article = telegramParseArticle(ParseJson(json), post.articleUrl)
                    if article <> invalid then cached = {article:article, fetchedAt:seconds}
                end if
            end if
            if article = invalid
                delayed = true
                if cached <> invalid then article = cached.article
            end if
            if article <> invalid
                posts.Push(telegramPostWithArticle(post, article))
                nextCache[post.articleUrl] = cached
            end if
            ' Never substitute a caption for an inaccessible source article.
        else
            posts.Push(post)
        end if
    end for
    ' Keep only articles referenced by this six-post collection, in memory only.
    m.articleCache = nextCache
    pages = []
    if posts.Count() > 0
        ' Font measurement belongs on TASK, never SceneGraph init/render.
        registry = CreateObject("roFontRegistry")
        font = invalid
        if registry <> invalid
            if registry.Register("pkg:/fonts/NotoSansSC-Regular.otf")
                families = registry.GetFamilies()
                for each family in families
                    if family.Instr("Noto Sans SC") >= 0 then font = registry.GetFont(family, 30, false, false)
                end for
            end if
        end if
        pages = telegramBuildPages(posts, font)
    end if
    m.top.result = {available:pages.Count() > 0, posts:posts, pages:pages, fetchedAt:fetchedAt, delayed:delayed}
end sub

function telegramDownload(url as string, timeout as integer) as dynamic
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnableEncodings(true)
    transfer.AddHeader("User-Agent", "RokuSleepClock/1.0 (https://github.com/kai3hu/roku-sleep-clock)")
    transfer.SetUrl(url)
    if not transfer.AsyncGetToString()
        return invalid
    end if
    response = wait(timeout, port)
    if response = invalid
        transfer.AsyncCancel()
        return invalid
    end if
    if type(response) <> "roUrlEvent"
        return invalid
    end if
    if response.GetResponseCode() <> 200
        return invalid
    end if
    text = response.GetString()
    if text = "" or len(text) > 2097152 then return invalid
    return text
end function
