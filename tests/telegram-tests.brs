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
    sourceMarkup = "<a href=" + q + "https://telegra.ph/Example-10-18" + q + ">Caption</a> | <a href=" + q + "https://mp.weixin.qq.com/s/example" + q + ">Source</a>"
    sourcePosts = telegramParsePosts(telegramFixture(11, sourceMarkup), "DNSPODT")
    check(sourcePosts[0].sourceOnly and sourcePosts[0].articleUrl = "https://telegra.ph/Example-10-18", "Source-ending posts follow their Telegraph article, not the caption or reply")
    check(not telegramSourceLinks(sourceMarkup, "Source followed by more text").sourceOnly, "Source must be the final word")
    check(telegramSourceLinks(sourceMarkup, "Caption SOURCE.").sourceOnly, "Source detection tolerates case and punctuation")
    check(telegramTelegraphPath("https://telegra.ph/Example-10-18?x=1") = "Example-10-18", "Article paths omit query strings")
    check(telegramTelegraphPath("https://telegra.ph/%E4%B8%AD-10-18") = "%E4%B8%AD-10-18", "Encoded non-Latin article paths are preserved")
    unsafe = ["http://telegra.ph/test", "https://telegra.ph.evil.com/test", "https://telegra.ph@evil.com/test", "https://evil.com/test", "https://telegra.ph/../test", "https://telegra.ph/%2fsecret", "https://telegra.ph/%255csecret", "https://telegra.ph/%QQ", "https://telegra.ph/"]
    for each url in unsafe
        check(telegramTelegraphPath(url) = "", "Unsafe or malformed article URLs are rejected")
    end for
    articleData = {ok:true, result:{title:"Article title", author_name:"Author", content:[{tag:"p",children:["First ",{tag:"strong",children:["paragraph"]},"."]},{tag:"figure",children:[{tag:"img",attrs:{src:"https://example.com/private"}},{tag:"figcaption",children:["A caption"]}]},{tag:"p",children:["Last paragraph."]},{tag:"iframe",children:["Unwanted embedded text"]}]}}
    article = telegramParseArticle(articleData, "https://telegra.ph/Example-10-18")
    check(article.text = "First paragraph." + chr(10) + "A caption" + chr(10) + "Last paragraph.", "Article paragraphs and inline text survive without media or HTML")
    fullPost = telegramPostWithArticle(sourcePosts[0], article)
    check(fullPost.isArticle and fullPost.text.Instr("Caption | Source") < 0 and fullPost.text.Instr("Article title") = 0, "Article replaces the Telegram caption completely")
    check(fullPost.text.Instr("Last paragraph.") > 0 and fullPost.id = 11, "Complete source body retains original post identity")
    check(telegramParseArticle({ok:false}, "") = invalid, "API failures cannot become article pages")
    check(telegramParseArticle({ok:true,result:{title:"Empty",content:[]}}, "") = invalid, "Empty articles are not displayed")
    nested = "Deep text"
    for i = 0 to 34
        nested = {tag:"strong",children:[nested]}
    end for
    check(telegramParseArticle({ok:true,result:{title:"Too deep",content:[nested]}}, "") = invalid, "Depth limits reject an article instead of silently omitting text")
    check(telegramReadingSeconds("Short post", false) = 60 and telegramReadingSeconds("Short article", true) = 90, "Messages and articles have distinct minimum reading times")
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
        posts.Push({id:size, text:text})
    end for
    font = {GetOneLineWidth:mockWidth, GetOneLineHeight:mockHeight}
    pages = telegramBuildPages(posts, font)
    check(pages.Count() = 6, "Short and medium messages each receive their own page")
    total = 0
    for each cards in pages
        check(cards.Count() = 1, "Exactly one message is shown at a time")
        for each card in cards
            check(card.width = 1650 and card.x = 0 and card.y = 0, "Every message uses the full reading width")
            check(card.height <= 600, "Body lines stay above the footer")
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
    pages = telegramBuildPages([{id:1, text:wide + wide + wide, isArticle:true}, {id:2,text:"Next message"}], invalid)
    check(pages.Count() > 1, "Long messages continue onto subsequent pages")
    total = 0
    for i = 0 to pages.Count() - 2
        page = pages[i]
        for each card in page
            check(card.width = 1650 and page.Count() = 1, "Long messages receive exclusive full-width pages")
            total = total + len(card.text.Replace(chr(10), ""))
            check(card.part = i + 1 and card.parts = pages.Count() - 1, "Each article has its own page count")
            check(card.duration >= 90 and card.duration <= 180, "Article pages receive longer reading time")
        end for
    end for
    check(total = 900, "Every wide character survives continuation pagination")
    check(pages[0][0].lines - pages[1][0].lines <= 1, "Article pages are balanced to avoid a nearly empty final page")
    check(telegramHasContinuation(pages, 1), "Same-article continuation advances immediately")
    check(not telegramHasContinuation(pages, pages.Count() - 1), "A different message waits for the next Telegram visit")
    check(not telegramHasContinuation(pages, pages.Count()), "End of collection returns to agenda")
    check(not telegramHasContinuation([[], []], 1), "Empty pages cannot trigger continuation")
    check(telegramReadingSeconds(wide + wide + wide, true) = 180, "Long articles cap per-page reading time")
    check(telegramReadingSeconds(wide + wide + wide, false) = 150, "Ordinary messages cap per-page reading time")
    paragraphs = telegramWrapLines("First" + chr(10) + chr(10) + "Last", font, 1600)
    check(paragraphs.Count() = 3 and paragraphs[1] = "", "Paragraph separation survives line wrapping")
    onePage = telegramBuildPages([{text:wide + wide}], invalid)
    check(onePage.Count() = 1 and onePage[0][0].width = 1650, "A post too long for a column can fit whole on one full-width page")
    check(telegramBuildPages([], font).Count() = 0, "Empty data produces no placeholder cards")
    for each size in [24,30,36]
        sized = telegramBuildPages([{id:5,text:wide + wide + wide}], invalid, size)
        total = 0
        for each page in sized
            card = page[0]
            total = total + len(card.text.Replace(chr(10),""))
            check(card.height <= 600, "All app font sizes keep reading pages inside the body area")
            for each line in card.lineTexts
                check(telegramTextWidth(line,invalid,size) <= 1600, "Fallback glyph widths scale safely with app font size")
            end for
        end for
        check(total = 900, "Font-size changes preserve complete article text")
    end for
    manyParagraphs = []
    for i = 1 to 170
        manyParagraphs.Push("Paragraph")
    end for
    balanced = telegramBuildPages([{id:20,text:manyParagraphs.Join(chr(10)),isArticle:true}], font)
    check(balanced.Count() = 14, "Very long articles receive all required pages")
    for each page in balanced
        check(page[0].lines >= 12 and page[0].lines <= 13, "Even very long articles avoid orphan final pages")
    end for
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
