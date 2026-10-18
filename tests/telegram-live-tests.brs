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
    markers = CreateObject("roRegex", "<div[^>]*data-post=" + chr(34) + telegramChannel() + "/[0-9]+" + chr(34) + "[^>]*>", "is").MatchAll(html)
    for each marker in markers
        segment = marker[0] + telegramDivBody(mid(html, html.Instr(marker[0]) + 1)) + "</div>"
        if segment.Instr("js-message_reply_text") >= 0
            own = CreateObject("roRegex", "<div[^>]*class=" + chr(34) + "[^" + chr(34) + "]*\bjs-message_text\b[^" + chr(34) + "]*" + chr(34) + "[^>]*>", "is").Match(segment)
            if own.Count() > 0
                expected = telegramPlainText(telegramDivBody(mid(segment, segment.Instr(own[0]) + 1)))
                actual = telegramParsePosts(segment, telegramChannel())
                if expected <> ""
                    if actual.Count() <> 1
                        print "FAIL: Live reply body missing"
                        return
                    end if
                    if actual[0].text <> expected
                        print "FAIL: Live reply includes quoted text"
                        return
                    end if
                    print "Verified own-body selection on live reply post "; actual[0].id
                end if
                exit for
            end if
        end if
    end for
    print "PASS: Live Telegram feed parsed"
end sub
