sub Main()
    m.failures = 0
    q = chr(34)
    check(telegramParsePosts("<html>Login required</html>", "DNSPODT").Count() = 0, "Login and error pages do not produce posts")
    check(telegramDivBody("<div>one<div>nested</div>two</div>ignored") = "one<div>nested</div>two", "Nested div boundaries")
    check(telegramPlainText("<script>bad()</script>Hello<br/><b>world</b> &amp; &#65; &#x42;") = "Hello world & A B", "Markup and numeric entities become plain text")
    html = ""
    for i = 1 to 8
        html = html + telegramFixture(i, "Post " + i.ToStr() + "<div><b> nested</b></div>")
    end for
    html = html + telegramFixture(9, "") + telegramFixture(8, "Duplicate")
    posts = telegramParsePosts(html, "DNSPODT")
    check(posts.Count() = 6, "At most six recent text posts")
    check(posts[0].id = 8 and posts[5].id = 3, "Newest text messages first, media-only and duplicate posts skipped")
    check(posts[0].text = "Post 8 nested", "Nested content is preserved")
    check(posts[0].url = "https://t.me/DNSPODT/8", "Source URLs are constructed from the selected channel")
    check(telegramParsePosts(html, "OtherChannel").Count() = 0, "Wrong-channel messages are ignored")
    reply = "<a class=" + q + "tgme_widget_message_reply" + q + "><div class=" + q + "tgme_widget_message_text js-message_reply_text" + q + ">Quoted old message</div></a>"
    fixture = telegramFixture(10, "Own complete message")
    bodyAt = fixture.Instr("<div class=" + q + "tgme_widget_message_text")
    fixture = left(fixture, bodyAt) + reply + mid(fixture, bodyAt + 1)
    replyPosts = telegramParsePosts(fixture, "DNSPODT")
    check(replyPosts.Count() = 1 and replyPosts[0].text = "Own complete message", "Reply previews are excluded without losing the actual reply")
    check(telegramParsePosts(fixture.Replace("Own complete message", ""), "DNSPODT").Count() = 0, "Quote-only wrappers are not mistaken for new messages")
    check(telegramPlainText("<blockquote>Own quoted reporting</blockquote>") = "Own quoted reporting", "Blockquotes belonging to the actual post remain intact")
    phase = {page:"agenda", nextIndex:0}
    for i = 0 to 9
        phase = screensaverNextPhase(phase.page, phase.nextIndex, 5, true)
        check(phase.page = "news" and phase.duration = 60 and phase.index = i mod 5, "News sequence remains in order")
        phase = screensaverNextPhase(phase.page, phase.nextIndex, 5, true)
        check(phase.page = "telegram" and phase.duration = 60, "Telegram follows each news story for one minute")
        phase = screensaverNextPhase(phase.page, phase.nextIndex, 5, true)
        check(phase.page = "agenda" and phase.duration = 120, "Agenda returns for two minutes")
    end for
    check(screensaverNextPhase("news", 1, 5, false).page = "agenda", "Unavailable Telegram skips its page")
    check(screensaverNextPhase("agenda", 0, 0, true).page = "telegram", "Telegram works when news is unavailable")
    check(screensaverNextPhase("agenda", 0, 0, false).duration = 120, "No feeds keeps the agenda visible")
    posts = []
    sizes = [10, 700, 45, 80, 600, 20]
    for each size in sizes
        text = ""
        for i = 1 to size
            text = text + "a"
        end for
        posts.Push({text:text})
    end for
    font = {GetOneLineWidth:mockWidth, GetOneLineHeight:mockHeight}
    pages = telegramBuildPages(posts, font)
    check(pages[0][1].height > pages[0][0].height, "Long messages receive more height than short messages")
    total = 0
    for each cards in pages
        ends = [0, 0]
        for each card in cards
            column = int(card.x / 860)
            check(card.y >= ends[column], "Masonry cards do not overlap")
            check(card.y + card.height + 35 <= 620, "Cards stay above the footer")
            ends[column] = card.y + card.height + 35
            total = total + len(card.text.Replace(chr(10), ""))
            for each line in card.text.Split(chr(10))
                check(telegramTextWidth(line, font) <= card.width - 10, "Every measured line fits its allocated width")
            end for
        end for
    end for
    check(total = 1455, "Full messages are preserved across all pages without truncation")
    wide = ""
    for i = 1 to 300
        wide = wide + chr(20013)
    end for
    pages = telegramBuildPages([{text:wide + wide + wide}], invalid)
    check(pages.Count() > 1, "Long messages continue onto subsequent pages")
    total = 0
    for each page in pages
        for each card in page
            check(card.width = 1650 and page.Count() = 1, "Long messages receive exclusive full-width pages")
            total = total + len(card.text.Replace(chr(10), ""))
        end for
    end for
    check(total = 900, "Every wide character survives continuation pagination")
    onePage = telegramBuildPages([{text:wide + wide}], invalid)
    check(onePage.Count() = 1 and onePage[0][0].width = 1650, "A post too long for a column can fit whole on one full-width page")
    check(telegramBuildPages([], font).Count() = 0, "Empty data produces no placeholder cards")
    print "TELEGRAM_TEST_FAILURES="; m.failures
end sub

function telegramFixture(id as integer, text as string) as string
    q = chr(34)
    return "<div class=" + q + "tgme_widget_message js-widget_message" + q + " data-post=" + q + "DNSPODT/" + id.ToStr() + q + "><div class=" + q + "tgme_widget_message_text js-message_text" + q + ">" + text + "</div><time datetime=" + q + "2026-10-18T05:00:00+00:00" + q + ">05:00</time></div>"
end function

function mockWidth(text as string, maximum as integer) as integer
    return len(text) * 14
end function

function mockHeight() as integer
    return 36
end function

sub check(condition as boolean, message as string)
    if condition then return
    print "FAIL: "; message
    m.failures = m.failures + 1
end sub
