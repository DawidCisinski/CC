local PARMS = { ... }

local USER = ""
local REPO = ""

-- parametry mają priorytet
if PARMS[1] then USER = PARMS[1] end
if PARMS[2] then REPO = PARMS[2] end

local function file_exp(file)
    if file:sub(#file - 3, #file) == ".txt" then return ".txt" end
    if file:sub(#file - 3, #file) == ".lua" then return ".lua" end
    return false
end

local function getUrl(user, repo, file)
    return "https://raw.githubusercontent.com/" ..
        user .. "/" .. repo .. "/main/" .. textutils.urlEncode(file)
end

local function get(user, repo, file)
    local h = http.get(getUrl(user, repo, file))
    if not h then error("HTTP request failed", 0) end
    local data = h.readAll()
    h.close()
    if not data then error("Empty file data", 0) end
    return data
end

local function prepareFolder(path)
    if fs.exists(path) then
        if fs.isDir(path) then
            fs.delete(path)
            fs.makeDir(path)
        else
            error("Path exists but is not a directory", 0)
        end
    else
        fs.makeDir(path)
    end
end

local function save(file, data)
    local f = fs.open(file, "w")
    if not f then error("Cannot open file for writing", 0) end
    f.write(data)
    f.close()
end

local function download(user, repo)
    local raw = get(user, repo, "PAWINSTALL_DATA.txt")
    raw = raw:gsub("^\239\187\191", "") -- usuń BOM
    local program = textutils.unserialize(raw)
    if not program then error("Invalid PAWINSTALL_DATA format", 0) end

    if not fs.exists("/ProgramFiles") then
        fs.makeDir("/ProgramFiles")
    end

    local appFolder = "/ProgramFiles/" .. string.lower(program.programName:gsub(" ", ""))
    prepareFolder(appFolder)

    local mainExists = false
    for _, file in ipairs(program.programFiles) do
        if file == program.mainFile then
            mainExists = true
        end
    end
    if not mainExists then error("mainFile not found in programFiles", 0) end

    for _, file in ipairs(program.programFiles) do
        if file_exp(file) then
            local ok, data = pcall(get, user, repo, file)
            if not ok then error("Failed to download file: " .. file, 0) end
            save(appFolder .. "/" .. file, data)
        else
            error("Unsupported file extension: " .. file, 0)
        end
    end

    save("/" .. string.lower(program.programName) .. ".lua",
        'local a={...}; shell.run("' .. appFolder .. "/" .. program.mainFile .. '", unpack(a))')

    print("!Installation complete " .. program.programName .. " version: " .. program.version)
end

download(USER, REPO)
