local help = [[
    <red>Usage: fm <command> <args><reset>
    <red>Commands:<reset>
        <green>status<reset>  - Show current status (character, effects, allies)
        <green>config<reset>  - View/change FieryMud configuration
        <green>reload<reset>  - Reload scripts from disk
        <green>reset<reset>   - Destroy and rebuild the GUI (use when UI is broken)
        <green>version<reset> - Show FieryMud GUI version and credits
]]

    if not matches[2] then
        cecho(help)
    return
end

local command, args = matches[2]:match("(%w+)%s*(.*)")
if command == "help" then
    cecho(help)
elseif command == "status" then
    Fierymud.Commands:status()
elseif command == "reload" then
    Fierymud.Commands:reload()
elseif command == "reset" then
    Fierymud.Commands:reset()
elseif command == "config" then
    Fierymud.Config:do_config(args)
elseif command == "version" then
    cecho("<green>FieryMud GUI Version: <white>" .. getPackageInfo("FierymudOfficial", "version") .. "<reset>\n")
    cecho("<green>Written by <red>Strider.<reset>\n")
    cecho("Report bugs and request features here: https://github.com/stridera/FierymudMudletClient/issues\n")
    cecho("<red>Pull requests welcome.<reset>\n")
else
    cecho("<red>Unknown command: " .. command .. "<reset>\n")
    cecho(help)
end
