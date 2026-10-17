-- PawLib v1.0

local pawlib = {}

--===========================================================
-- FILES
--===========================================================

function pawlib.file_exp(file)
    if file:sub(-4) == ".txt" then return ".txt" end
    if file:sub(-4) == ".lua" then return ".lua" end
    return false
end

function pawlib.prepareFolder(path)
    if fs.exists(path) then
        fs.delete(path)
    end

    fs.makeDir(path)
end

function pawlib.save_list(file, list)
    local f = fs.open(file, "w")
    if not f then return false end

    f.write(textutils.serialize(list))
    f.close()

    return true
end

function pawlib.open_list(file)
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

function pawlib.save_file(file, data)
    local f = fs.open(file, "w")
    if not f then
        return false
    end

    f.write(data)
    f.close()

    return true
end

function pawlib.open_file(file)
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

function pawlib.startup_overwrite(data, end_of_file)
    local old_startup = pawlib.open_file("startup.lua") or ""

    local f = fs.open("startup.lua", "w")
    if not f then
        return false
    end

    if end_of_file then
        f.write(old_startup .. data)
    else
        f.write(data .. old_startup)
    end

    f.close()
    return true
end

--===========================================================
-- SYSTEM
--===========================================================

function pawlib.run(file)
    shell.run(file)
end

function pawlib.clear()
    term.clear()
    term.setCursorPos(1, 1)
end

function pawlib.line()
    local w = term.getSize()
    print(string.rep("-", w))
end

--===========================================================
-- COLORS
--===========================================================

function pawlib.rprint(colorName, text, text2)
    text2 = text2 or ""

    term.setTextColor(colors[colorName] or colors.white)
    print(text, text2)
    term.setTextColor(colors.white)
end

function pawlib.rwrite(colorName, text)
    term.setTextColor(colors[colorName] or colors.white)
    write(text)
    term.setTextColor(colors.white)
end

--===========================================================
-- INPUT
--===========================================================

function pawlib.rinput(info, text, key, pass)
    pawlib.rwrite("blue", info)
    pawlib.rwrite("yellow", text .. key)

    return read(pass):gsub(" ", "")
end

--===========================================================
-- DIALOG
--===========================================================

function pawlib.dialog(title, options)
    local selected = 1

    while true do
        pawlib.clear()

        pawlib.rprint("yellow", "\n" .. title)
        print()

        for i, opt in ipairs(options) do
            if not (opt:sub(1, 1) == "$" or opt == "index.txt") then
                if i == selected then
                    pawlib.rprint("yellow", ">> " .. opt)
                else
                    print("   " .. opt)
                end
            elseif opt:sub(1, 1) == "$" then
                if i == selected then
                    pawlib.rprint("yellow", ">> " .. opt .. " (protected)")
                else
                    pawlib.rprint("orange", "   " .. opt)
                end
            else
                if i == selected then
                    pawlib.rprint("yellow", ">> " .. opt .. " (www)")
                else
                    pawlib.rprint("blue", "   " .. opt)
                end
            end
        end

        local _, key = os.pullEvent("key")

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

function pawlib.reader(title, list_text)
    pawlib.clear()

    pawlib.rprint("yellow", "\n" .. title .. "\n")

    local _, h = term.getSize()
    local maxY = h - 2

    for _, v in ipairs(list_text) do
        print(v)

        local _, y = term.getCursorPos()

        if y >= maxY then
            pawlib.rprint("yellow", "\n[nextpage]")
            os.pullEvent("key")

            pawlib.clear()
            pawlib.rprint("yellow", "\n" .. title .. "\n")
        end
    end
end

--===========================================================
-- CRYPTO
--===========================================================

function pawlib.hash64(str)
    local h1 = 0x811C9DC5
    local h2 = 0x243F6A88
    local p1 = 0x01000193
    local p2 = 0x85EBCA6B

    for i = 1, #str do
        local b = string.byte(str, i)

        h1 = bit32.bxor(h1, b)
        h1 = (h1 * p1) % 0x100000000

        local r1 = bit32.lshift(h1, 5) % 0x100000000
        local l1 = bit32.rshift(h1, 2)

        h1 = bit32.bxor(r1, l1)

        h2 = bit32.bxor(h2, b)
        h2 = (h2 * p2) % 0x100000000

        local r2 = bit32.lshift(h2, 7) % 0x100000000
        local l2 = bit32.rshift(h2, 3)

        h2 = bit32.bxor(r2, l2)
    end

    return string.format("%08x%08x", h1, h2)
end

local function keyBytes(key)
    local t = {}

    for i = 1, #key do
        t[i] = string.byte(key, i)
    end

    return t
end

local function xorStream(data, key)
    local kb = keyBytes(key)
    local klen = #kb

    local out = {}

    for i = 1, #data do
        local b = string.byte(data, i)
        local k = kb[((i - 1) % klen) + 1]

        out[i] = string.char(bit32.bxor(b, k))
    end

    return table.concat(out)
end

function pawlib.encrypt(str, key)
    return xorStream(str, key)
end

function pawlib.decrypt(str, key)
    return xorStream(str, key)
end

--===========================================================
-- RANDOM
--===========================================================

function pawlib.random(from, to)
    return math.random(from, to)
end

--===========================================================

return pawlib