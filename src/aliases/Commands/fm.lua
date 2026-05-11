local help = [[
    <red>Usage: fm <command> <args><reset>
    <red>Commands:<reset>
        <green>status<reset>        - Show current status (character, effects, allies)
        <green>config<reset>        - View/change FieryMud configuration
        <green>reload<reset>        - Reload scripts from disk
        <green>reset<reset>         - Destroy and rebuild the GUI (use when UI is broken)
        <green>tracker reset<reset> - Re-baseline the session XP / gold tracker
        <green>tag <name><reset>    - Tag the current room with a name
        <green>untag <name><reset>  - Remove a previously-saved tag
        <green>goto [name]<reset>   - Walk to a tagged room; bare 'fm goto' lists tags
        <green>cq <cmd><reset>      - Queue a combat command (one fires per prompt)
        <green>cq list<reset>       - Show the current command queue
        <green>cq clear<reset>      - Empty the queue
        <green>cq pause / resume<reset> - Pause / resume queue advance
        <green>inv<reset>           - Toggle the Inventory window (click items for actions)
        <green>eq<reset>            - Toggle the Equipment window
        <green>version<reset>       - Show FieryMud GUI version and credits
]]

    if not matches[2] then
        cecho(help)
    return
end

local command, args = matches[2]:match("(%w+)%s*(.*)")
if command == "help" then
    cecho(help)
elseif command == "status" then
    FierymudRs.Commands:status()
elseif command == "reload" then
    FierymudRs.Commands:reload()
elseif command == "reset" then
    FierymudRs.Commands:reset()
elseif command == "config" then
    FierymudRs.Config:do_config(args)
elseif command == "tracker" then
    if args == "reset" then
        if FierymudRs.Tracker and FierymudRs.Tracker.reset then
            FierymudRs.Tracker:reset()
            cecho("<green>Tracker session reset.<reset>\n")
        else
            cecho("<red>Tracker subsystem not initialized.<reset>\n")
        end
    else
        cecho("<red>Usage: fm tracker reset<reset>\n")
    end
elseif command == "goto" then
    if FierymudRs.Mapper and FierymudRs.Mapper.gotoTag then
        FierymudRs.Mapper:gotoTag(args)
    else
        cecho("<red>Mapper subsystem not initialized.<reset>\n")
    end
elseif command == "tag" then
    if FierymudRs.Mapper and FierymudRs.Mapper.tagRoom then
        FierymudRs.Mapper:tagRoom(args)
    else
        cecho("<red>Mapper subsystem not initialized.<reset>\n")
    end
elseif command == "untag" then
    if FierymudRs.Mapper and FierymudRs.Mapper.untagRoom then
        FierymudRs.Mapper:untagRoom(args)
    else
        cecho("<red>Mapper subsystem not initialized.<reset>\n")
    end
elseif command == "cq" then
    if not FierymudRs.CombatQueue then
        cecho("<red>CombatQueue subsystem not initialized.<reset>\n")
    elseif args == "" or args == "list" then
        FierymudRs.CombatQueue:list()
    elseif args == "clear" then
        FierymudRs.CombatQueue:clear()
    elseif args == "pause" then
        FierymudRs.CombatQueue:pause()
    elseif args == "resume" then
        FierymudRs.CombatQueue:resume()
    else
        FierymudRs.CombatQueue:push(args)
    end
elseif command == "inv" then
    if FierymudRs.Inventory and FierymudRs.Inventory.toggle then
        FierymudRs.Inventory:toggle("inv")
    else
        cecho("<red>Inventory subsystem not initialized.<reset>\n")
    end
elseif command == "eq" then
    if FierymudRs.Inventory and FierymudRs.Inventory.toggle then
        FierymudRs.Inventory:toggle("wear")
    else
        cecho("<red>Inventory subsystem not initialized.<reset>\n")
    end
elseif command == "version" then
    cecho("<green>FieryMud GUI Version: <white>" .. getPackageInfo("FierymudRs", "version") .. "<reset>\n")
    cecho("<green>Written by <red>Strider.<reset>\n")
    cecho("Report bugs and request features here: https://github.com/stridera/FierymudMudletClient/issues\n")
    cecho("<red>Pull requests welcome.<reset>\n")
else
    cecho("<red>Unknown command: " .. command .. "<reset>\n")
    cecho(help)
end
