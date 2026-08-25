local PARMS = { ... }
if PARMS[1] == "v" then print("PawLib v.1.0") end

local function file_exp(file)
    if file:sub(#file - 3, #file) == ".txt" then return ".txt" end
    if file:sub(#file - 3, #file) == ".lua" then return ".lua" end
    return false
end

local function prepareFolder(path)
    if fs.exists(path) then
        if fs.isDir(path) then
            fs.delete(path)
            fs.makeDir(path)
        end
    else
        fs.makeDir(path)
    end
end

local function save_list(file, list)
    local f = fs.open(file, "w")

    f.write(textutils.serialize(list))
    f.close()
end

local function open_list(file)
    if not fs.exists(file) then
        return false
    end

    local f = fs.open(file, "r")

    if not f then
        return false
    end

    local data = f.readAll()
    f.close()

    return textutils.unserialize(data)
end

local function save(file, data)
    -- [[ text ]]
    local f = fs.open(file, "w")
    f.write(data)
    f.close()
end

local function open(file, data)
    if not fs.exists(file) then
        return false
    end

    local f = fs.open(file, "r")

    if not f then
        return false
    end

    local data = f.readAll()
    f.close()

    return data
end

local function startup_overwrite(data, end_of_file)
    -- [[ text ]]
    local old_startup = ""
    local f = fs.open("startup.lua", "w")
    f.write(data .. old_startup)
    f.close()
end

--===========================================================

local function run(file)
    shell.run(file)
end

local function clear()
    term.clear()
    term.setCursorPos(1, 1)
end

local function line()
    local w = term.getSize()
    print(string.rep("-", w))
end

--===========================================================

local function rprint(colorName, text, text2)
    if not text2 then text2 = "" end
    term.setTextColor(colors[colorName])
    print(text, text2)
    term.setTextColor(colors.white)
end

local function rwrite(colorName, text)
    term.setTextColor(colors[colorName])
    write(text)
    term.setTextColor(colors.white)
end

--===========================================================

local function dialog(title, options)
    local selected = 1

    while true do
        clear()
        rprint("yellow", "\n" .. title)
        print("")

        for i, opt in ipairs(options) do
            if i == selected then
                rprint("yellow", ">> " .. opt)
            else
                print("   " .. opt)
            end

            local event, key = os.pullEvent("key")

            if key == keys.up then
                selected = selected - 1
                if selected < 1 then selected = #options end
            elseif key == keys.down then
                selected = selected + 1
                if selected > #options then selected = 1 end
            elseif key == keys.enter then
                return selected, options[selected]
            end
        end
    end
end

local function rinput(text, info, pass)
    rwrite("blue", info)
    rwrite("yellow", text .. " >> ")
    return read(pass):gsub(" ", "")
end

local function reader(title, list_text)
    clear()
    rprint("yellow", "\n" .. title .. "\n")

    local _, h = term.getSize()
    local maxY = h - 2

    for j, v in ipairs(list_text) do
        print(v)

        local _, y = term.getCursorPos()

        if y >= maxY then
            rprint("yellow", "\n[nextpage]")
            os.pullEvent("key")
            clear()
            rprint("yellow", "\n" .. title .. "\n")
        end
    end
end
