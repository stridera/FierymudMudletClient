FierymudRs = FierymudRs or {}
FierymudRs.Utils = FierymudRs.Utils or {}
FierymudRs.Utils.File = FierymudRs.Utils.File or {}


function FierymudRs.Utils.File:exists(file)
    local f = io.open(getMudletHomeDir()..'/'..file, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

function FierymudRs.Utils.File:load(file)
    local f = assert(io.open(getMudletHomeDir()..'/'..file, 'r'), 'File not found: '..file)
    local t = f:read('*a')
    f:close()
    return yajl.to_value(t)
end

function FierymudRs.Utils.File:save(file, table)
    local f = assert(io.open(getMudletHomeDir()..'/'..file, 'w'), 'File could not be created/opened: '..file)
    local t = yajl.to_string(table)
    f:write(t)
    f:close()
    return table
end
