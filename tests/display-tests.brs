sub Main()
    m.displayColor = ""
    m.iconTint = ""
    clock = mockNode("Label", [])
    agenda = mockNode("Label", [])
    bar = mockNode("Rectangle", [])
    icon = mockNode("Poster", [])
    weather = mockNode("Group", [bar, icon])
    wikiTitle = mockNode("Label", [])
    wiki = mockNode("Group", [wikiTitle])
    wiki.visible = false
    m.content = mockNode("Group", [clock, agenda, weather, wiki])

    applyDisplaySchedule(23)
    if clock.color <> "0x0C0C0CFF" or agenda.color <> clock.color or bar.color <> clock.color or icon.blendColor <> "0x555555FF"
        print "FAIL: Night palette must dim text, chart and icon"
        return
    end if
    if not weather.visible or not agenda.visible
        print "FAIL: Night mode must keep all information visible"
        return
    end if
    applyDisplaySchedule(0)
    if wikiTitle.color <> clock.color or wiki.visible
        print "FAIL: Hidden article text must dim without changing page visibility"
        return
    end if
    applyDisplaySchedule(6)
    if clock.color <> "0x0C0C0CFF"
        print "FAIL: The overnight palette must survive midnight"
        return
    end if
    applyDisplaySchedule(7)
    if wikiTitle.color <> "0x242424FF"
        print "FAIL: Articles must follow daytime brightness"
        return
    end if
    if clock.color <> "0x242424FF" or bar.color <> clock.color or icon.blendColor <> "0xFFFFFFFF"
        print "FAIL: Morning must brighten every information type"
        return
    end if
    applyDisplaySchedule(22)
    if clock.color <> "0x242424FF"
        print "FAIL: Day palette must last until 22:59"
        return
    end if
    applyDisplaySchedule(23)
    if clock.color <> "0x0C0C0CFF" or not weather.visible or not agenda.visible
        print "FAIL: 23:00 must dim the interface without hiding it"
        return
    end if
    print "PASS: Text, chart and icon brightness transitions without hiding content"
end sub

function mockNode(kind as string, children as object) as object
    return {
        kind: kind
        children: children
        visible: true
        color: ""
        blendColor: ""
        subtype: mockSubtype
        getChildCount: mockChildCount
        getChild: mockChild
    }
end function

function mockSubtype() as string
    return m.kind
end function

function mockChildCount() as integer
    return m.children.Count()
end function

function mockChild(index as integer) as object
    return m.children[index]
end function
