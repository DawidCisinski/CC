local PARMS = { ... }
local OPTIONS = {}
local MODEM = peripheral.find("modem")
local CLIENT_IP = os.getComputerID()
GUEST_PASSWORD = "default"


local SERVERS_LIST = {}
local SERVER_IP = -1

local USER = { type = "none", password = "none", key = "none" }

--===========================================================

if not MODEM then
    print("FATAL ERROR: install modem")
    error("", 0)
end

MODEM.open(CLIENT_IP)

local function system_reset_options()
    SERVERS_LIST = {}
    SERVER_IP = -1
    USER = { type = "none", password = "none", key = "none" }
end

--===========================================================

local function clear()
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
end

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


local function dialog(title, options, files)
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

local function rdialog(title, options)
    local selected = 1

    while true do
        clear()
        rprint("yellow", "\n" .. title)
        print("")

        for i, opt in ipairs(options) do
            if i == selected then
                rprint("yellow",
                    ">> " .. "id: " .. opt.ip .. " / repo:" .. tostring(opt.repo) .. " / www:" .. tostring(opt.www))
            else
                print("   " .. "id: " .. opt.ip .. " / repo:" .. tostring(opt.repo) .. " / www:" .. tostring(opt.www))
            end
        end

        local event, key = os.pullEvent("key")

        if key == keys.up then
            selected = selected - 1
            if selected < 1 then selected = #options end
        elseif key == keys.down then
            selected = selected + 1
            if selected > #options then selected = 1 end
        elseif key == keys.enter then
            return options[selected].ip
        end
    end
end

local function rinput(text, USER, pass)
    local user_icon = "[N]"
    if USER.type == "guest" then user_icon = "[G]" end
    if USER.type == "user" then user_icon = "[U]" end
    if USER.type == "admin" then user_icon = "[A]" end

    print("")

    rwrite("blue", user_icon .. " ")
    rwrite("yellow", text .. " >> ")
    return read(pass):gsub(" ", "")
end

local function reader(title, list_text)
    clear()
    rprint("yellow", "\n" .. title .. "\n")

    local _, h = term.getSize()
    local maxY = h - 3

    for j, v in ipairs(list_text) do
        print(j, v)

        local _, y = term.getCursorPos()

        if y >= maxY then
            rprint("yellow", "\n[nextpage]")
            os.pullEvent("key")
            clear()
            rprint("yellow", title .. "\n")
        end
    end
end

local function system_boot()
    system_reset_options()
    clear()
    rprint("yellow", "Pawsoft v.2.2 (client)")
    print("use [connect] to select server")
    print("type [help] for commands")
end

--===========================================================

local function server_info(message)
    if message.info then
        rprint("blue", "(server) Info:", message.info)
    elseif message.ok == "_" then
    elseif message.ok then
        rprint("green", "(server)", message.ok)
    else
        rprint("red", "(server) Error:", message.error)
    end
end

local function send(message_in, SERVER_IP)
    message_in.password = USER.password
    MODEM.transmit(tonumber(SERVER_IP), CLIENT_IP, message_in)

    local timerID = os.startTimer(3)

    while true do
        local event, side, channel, replyChannel, message = os.pullEvent()

        if event == "modem_message" then
            if replyChannel == tonumber(SERVER_IP) then
                server_info(message)
                return message
            end
        end

        if event == "timer" and side == timerID then
            message = { error = "connection lost" }
            server_info(message)
            sleep(2)
            system_boot()
            return message
        end
    end
end


local function multi_send()
    local found = { { ip = -1, repo = "null", www = "null" } }

    for ip = 0, 100 do
        MODEM.transmit(ip, CLIENT_IP, { cmd = "ping" })
    end

    local timerID = os.startTimer(3)

    while true do
        local event, side, channel, replyChannel, message = os.pullEvent()

        if event == "modem_message" then
            if type(message) == "table" and message.ok == "pong" then
                table.insert(found, {
                    ip = replyChannel,
                    repo = message.repo,
                    www = message.www,
                })
            end
        end

        if event == "timer" and side == timerID then
            return found
        end
    end
end

--===========================================================

local function hash64(str)
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


function encrypt(str, key)
    return xorStream(str, key)
end

function decrypt(str, key)
    return xorStream(str, key)
end

--===========================================================

local function connect()
    clear()
    write("Please wait...")
    local selected = rdialog("Select server", multi_send())
    local password
    if selected == -1 then selected = 101 end

    local _, name = dialog("Select account type", { "guest", "user", "admin" })
    if name == "guest" then
        password = GUEST_PASSWORD
    else
        password = rinput("Enter password", USER, "*")
    end

    local msg = {
        cmd = "_registration",
        user_type = name
    }
    local msg_out = send(msg, selected)
    if msg_out.scode then
        USER.password = hash64(password .. msg_out.scode)
        USER.key = hash64(password)
        local msg_out = send({ cmd = "_login", }, selected)
        if msg_out.ok then
            USER.type = name
            SERVER_IP = selected
        end
    end
end

local function list(patrick)
    local msg = send({ cmd = "list" }, SERVER_IP)

    if type(msg.list) == "table" then
        if not patrick then
            print("Files on disk:")
            for _, v in ipairs(msg.list) do
                if v:sub(1, 1) == "$" then
                    write(" - ")
                    rprint("orange", v)
                else
                    print(" - " .. v)
                end
            end
        else
            return msg.list
        end
    end
end

local function get(type)
    local file

    if type == 2 then
        file = "index.txt"
    else
        _, file = dialog("Select file", list(true))
    end

    local msg_out = send({
        cmd = "get",
        file = file,
    }, SERVER_IP)

    if msg_out.ok then
        local data = decrypt(msg_out.data, USER.key)
        if not type then
            local f = fs.open(file, "w")
            rprint("green", "Downloaded: " .. file)
            f.write(data)
            f.close()
        elseif type == 1 then
            local f = fs.open("temp.txt", "w")
            f.write(data)
            f.close()

            clear()

            shell.run("edit", "temp.txt")
        elseif type == 2 then
            clear()
            print(data)
        end
    end
end

local function push()
    local files = fs.list("/")
    local i = 1
    while i <= #files do
        local f = files[i]
        if not f:lower():match("%.txt$") then
            table.remove(files, i)
        else
            i = i + 1
        end
    end

    local _, file = dialog("Select file", files)

    if not fs.exists(file) then
        print("File does not exist:", file)
        return
    end

    local f = fs.open(file, "r")
    local data = encrypt(f.readAll(), USER.key)
    f.close()

    local res = send({
        cmd = "push",
        file = file,
        data = data,
    }, SERVER_IP)
end

--===========================================================

system_boot()


while true do
    local cmd = rinput("server " .. SERVER_IP, USER)

    if cmd == "exit" or cmd == "stop" then
        break
    elseif cmd == "connect" or cmd == "con" then
        connect()
    elseif cmd == "list" then
        list()
    elseif cmd == "get" then
        get()
    elseif cmd == "open" then
        get(1)
    elseif cmd == "www" then
        get(2)
    elseif cmd == "push" then
        push()
    else
        if SERVER_IP == -1 then
            server_info({ error = "connection lost" })
        else
            send({ cmd = cmd }, SERVER_IP)
        end
    end
end

rprint("blue", "client closed\n")
MODEM.close(CLIENT_IP)
