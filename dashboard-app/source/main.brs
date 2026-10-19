sub Main(args = invalid as dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("SleepDashboardScene")
    if type(args) = "roAssociativeArray"
        reason = args.lastExitOrTerminationReason
        if type(reason) = "String" or type(reason) = "roString"
            if CreateObject("roRegex", "^EXIT_[A-Z0-9_]{1,80}$", "").IsMatch(reason)
                scene.lastExitReason = reason
                print "[SleepDashboard] Previous exit: "; reason
            end if
        end if
    end if
    screen.Show()
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent"
            if event.IsScreenClosed() then return
        end if
    end while
end sub
