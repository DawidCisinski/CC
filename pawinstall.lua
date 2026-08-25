--[[
    PAWINSTALL — GitHub-based installer for ComputerCraft programs
    ---------------------------------------------------------------
    This script downloads a program definition file (PAWINSTALL_DATA.txt)
    from a GitHub repository and installs all required program files
    into /ProgramFiles/<programName>.

    Developers:
    - USER and REPO can be passed via command-line arguments (...).
    - If arguments are missing, default empty strings are used.
    - Program metadata must be stored in PAWINSTALL_DATA.txt (serialized table).
    - Supported file extensions: .txt, .lua
    - Main file must exist inside program.programFiles.

    PAWINSTALL_DATA.txt — Program Definition File
    ---------------------------------------------
    This file describes how PAWINSTALL should install a program from GitHub.
    It must contain a Lua table serialized using textutils.serialize().

    GENERAL RULES:
    - The file MUST be valid Lua table syntax.
    - The file MUST NOT contain trailing commas.
    - The file MUST NOT contain floating-point numbers (use strings instead).
    - The file MUST NOT contain comments.
    - The file MAY NOT contain BOM (installer strips BOM automatically).
    - Keys MUST be simple strings.
    - Values MUST be strings or tables.

    REQUIRED FIELDS:
    ---------------------------------------------------------
    programName      (string)
        Human-readable program name.
        Used to generate the launcher file and installation folder.

    version          (string)
        Program version. Must be a string, not a number.

    mainFile         (string)
        The main executable file. Must exist inside programFiles.

    programFiles     (table of strings)
        List of all files to download from the repository.
        Supported extensions: .lua, .txt

    EXAMPLE (VALID):
    ---------------------------------------------------------
    {
      programName = "MyApp",
      version = "1.0",
      mainFile = "main.lua",
      programFiles = {
        "main.lua",
        "config.txt"
      }
    }

    EXAMPLE (INVALID):
    ---------------------------------------------------------
    {
      programName = "MyApp",       <-- OK
      version = 1.0,               <-- INVALID: float number
      mainFile = "main.lua",       <-- OK
      programFiles = {             <-- OK
        "main.lua",                <-- INVALID: trailing comma
      },                           <-- INVALID: trailing comma
    }

    INSTALLATION RULES:
    ---------------------------------------------------------
    - All files are downloaded from:
        https://raw.githubusercontent.com/<USER>/<REPO>/main/<file>

    - Installed program files go to:
        /ProgramFiles/<lowercase(programName)>

    - A launcher file is created at:
        /<lowercase(programName)>.lua

    - Launcher forwards arguments:
        shell.run("/ProgramFiles/<name>/<mainFile>", unpack({...}))

    - If mainFile is missing in programFiles → installation fails.

    - If any file has unsupported extension → installation fails.

    - If PAWINSTALL_DATA.txt cannot be parsed → installation fails.

--]]


local PARMS = { ... }

local USER = ""
local REPO = ""

-- Command-line parameters override defaults
if PARMS[1] then USER = PARMS[1] end
if PARMS[2] then REPO = PARMS[2] end

-- Returns valid extension or false if unsupported
local function file_exp(file)
    if file:sub(#file - 3, #file) == ".txt" then return ".txt" end
    if file:sub(#file - 3, #file) == ".lua" then return ".lua" end
    return false
end

-- Builds a raw.githubusercontent.com URL for a file
local function getUrl(user, repo, file)
    return "https://raw.githubusercontent.com/" ..
        user .. "/" .. repo .. "/main/" .. textutils.urlEncode(file)
end

-- Downloads a file from GitHub, throws on failure
local function get(user, repo, file)
    local h = http.get(getUrl(user, repo, file))
    if not h then error("HTTP request failed", 0) end

    local data = h.readAll()
    h.close()

    if not data then error("Empty file data", 0) end
    return data
end

-- Ensures a clean directory (deletes if exists)
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

-- Writes data to a file, throws on failure
local function save(file, data)
    local f = fs.open(file, "w")
    if not f then error("Cannot open file for writing", 0) end
    f.write(data)
    f.close()
end

-- Main installation routine
local function download(user, repo)

    -- Load and parse PAWINSTALL_DATA.txt
    local raw = get(user, repo, "PAWINSTALL_DATA.txt")
    raw = raw:gsub("^\239\187\191", "") -- Remove UTF-8 BOM if present

    local program = textutils.unserialize(raw)
    if not program then error("Invalid PAWINSTALL_DATA format", 0) end

    -- Ensure global ProgramFiles directory exists
    if not fs.exists("/ProgramFiles") then
        fs.makeDir("/ProgramFiles")
    end

    -- Create program folder (lowercase, no spaces)
    local appFolder = "/ProgramFiles/" .. string.lower(program.programName:gsub(" ", ""))
    prepareFolder(appFolder)

    -- Validate that mainFile exists in programFiles
    local mainExists = false
    for _, file in ipairs(program.programFiles) do
        if file == program.mainFile then
            mainExists = true
        end
    end
    if not mainExists then error("mainFile not found in programFiles", 0) end

    -- Download all program files
    for _, file in ipairs(program.programFiles) do
        if file_exp(file) then
            -- Protected download call
            local ok, data = pcall(get, user, repo, file)
            if not ok then error("Failed to download file: " .. file, 0) end

            save(appFolder .. "/" .. file, data)
        else
            error("Unsupported file extension: " .. file, 0)
        end
    end

    -- Create launcher file in root directory
    save("/" .. string.lower(program.programName) .. ".lua",
        'local a={...}; shell.run("' .. appFolder .. "/" .. program.mainFile .. '", unpack(a))')

    -- Installation complete
    print("!Installation complete " .. program.programName .. " version: " .. program.version)
end

-- Execute installation
download(USER, REPO)
