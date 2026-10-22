' Render the actual settings-created node coordinates, using synthetic data only.
sub settingsPreview()
    initMockApp()
    m.clock.text = "23:48"
    m.appSettings.clockFont = "Roboto Mono"
    m.appMenu = "Clock"
    m.appMenuIndex = 0
    m.appMenuNote = ""
    appDrawMenu()
    screens = {settings:settingsPreviewNodes()}
    appOpenChoicePicker(appSettingRows("Clock")[0])
    screens.fonts = settingsPreviewNodes()
    print FormatJson(screens)
end sub

function settingsPreviewNodes() as object
    result = []
    for each node in m.appOverlay.children
        item = {kind:node.kind,x:node.translation[0],y:node.translation[1],width:node.width,height:node.height,color:node.color,text:node.text}
        if node.kind = "Label"
            item.size = node.font.size
            item.uri = node.font.uri
            item.align = node.horizAlign
            item.wrap = node.wrap
        end if
        result.Push(item)
    end for
    return result
end function
