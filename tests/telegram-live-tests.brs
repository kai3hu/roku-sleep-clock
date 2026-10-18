' Optional integration check after downloading t.me/s/DNSPODT to the ignored fixture.
sub Main()
    html = ReadAsciiFile("pkg:/.tools/telegram-feed.html")
    posts = telegramParsePosts(html, telegramChannel())
    if posts.Count() <> 6
        print "FAIL: Expected six text messages from the live public channel"
        return
    end if
    for each post in posts
        if post.text = "" or post.timestamp = "" or post.url = ""
            print "FAIL: Missing live post data"
            return
        end if
        print "Parsed live post "; post.id; " / characters "; len(post.text)
    end for
    print "PASS: Live Telegram feed parsed"
end sub
