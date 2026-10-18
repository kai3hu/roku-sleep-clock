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
    now = CreateObject("roDateTime")
    m.top.result = {available:posts.Count() > 0, posts:posts, fetchedAt:now.ToISOString()}
end sub
