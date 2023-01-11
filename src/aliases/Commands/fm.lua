if not matches[2] then
    cecho([[
<red>Usage: fm <command> <args><reset>
<red>Commands:<reset>
    <green>reload<reset> - Reload the FieryMud GUI and Scripts
    <green>config<reset> - FieryMud Config
    <green>version<reset> - Show FieryMud GUI Version and Credits
    ]])
    return
end

local command, args = matches[2]:match("(%w+)\s*(.*)")
if command == "reload" then
    Fierymud.Commands:reload()
elseif command == "config" then
    Fierymud.Config:do_config(args)
elseif command == "version" then
    cecho("<green>FieryMud GUI Version: <white>" .. getPackageInfo("FierymudOfficial", "version") .. "<reset>\n")
    cecho("<green>Written by <red>Strider.<reset>\n")
    cecho("Report bugs and request features here: https://github.com/stridera/FierymudMudletClient/issues\n")
    cecho("<red>Pull requests welcome.<reset>\n")
end
