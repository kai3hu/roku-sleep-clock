sub init()
    m.top.functionName = "downloadTelegram"
end sub

sub downloadTelegram()
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnableEncodings(true)
    transfer.AddHeader("User-Agent", "RokuSleepClock/1.0 (https://github.com/kai3hu/roku-sleep-clock)")
    transfer.SetUrl("https://t.me/s/" + telegramChannel())
    if not transfer.AsyncGetToString()
        m.top.result = {available:false}
        return
    end if
    response = wait(20000, port)
    if response = invalid
        transfer.AsyncCancel()
        m.top.result = {available:false}
        return
    end if
    if type(response) <> "roUrlEvent"
        m.top.result = {available:false}
        return
    end if
    if response.GetResponseCode() <> 200
        m.top.result = {available:false}
        return
    end if
    posts = telegramParsePosts(response.GetString(), telegramChannel())
    pages = []
    if posts.Count() > 0
        ' This function runs on TASK, not the SceneGraph init/render thread.
        registry = CreateObject("roFontRegistry")
        font = invalid
        if registry <> invalid
            if registry.Register("pkg:/fonts/NotoSansSC-Regular.otf")
                families = registry.GetFamilies()
                for each family in families
                    if family.Instr("Noto Sans SC") >= 0 then font = registry.GetFont(family, 26, false, false)
                end for
            end if
        end if
        ' The layout helper also handles missing metrics with conservative widths.
        pages = telegramBuildPages(posts, font)
    end if
    now = CreateObject("roDateTime")
    m.top.result = {available:pages.Count() > 0, posts:posts, pages:pages, fetchedAt:now.ToISOString()}
end sub
