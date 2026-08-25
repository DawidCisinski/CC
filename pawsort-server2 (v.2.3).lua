local PARMS = { ... }
local MODEM = peripheral.find("modem")
local SERVER_IP = os.getComputerID()

--===========================================================

local USER = 0
local PASSWORDS = {}
PASSWORDS["guest"] = { power = 1, password = PARMS[3] }
PASSWORDS["user"] = { power = 2, password = PARMS[2] }
PASSWORDS["admin"] = { power = 3, password = PARMS[1] }

local SESSIONS = {}

if not fs.exists("$options.txt") then
    local f = fs.open("$options.txt", "w")
    f.write("passwords @default_guest_password@user_password@admin_password@")
    f.close()
end


local f = fs.open("$options.txt", "r")
local data = f.readAll()
f.close()
local passwords = {}
for s in string.gmatch(data, "[^@]+") do
    table.insert(passwords, s)
end


if not PARMS[1] then PARMS[1] = passwords[4] end
if not PARMS[2] then PARMS[2] = passwords[3] end
if not PARMS[3] then PARMS[3] = passwords[2] end

PASSWORDS["guest"].password = PARMS[3]
PASSWORDS["user"].password = PARMS[2]
PASSWORDS["admin"].password = PARMS[1]

if not MODEM then
    print("FATAL ERROR: install modem")
    error("", 0)
end

MODEM.open(SERVER_IP)

--===========================================================

local function getDiskPath()
    if fs.exists("disk") and fs.isDir("disk") then
        return "disk", true
    end
    return "none"
end

local function hasWebsite()
    if fs.exists("disk/index.txt") then return true end
    return false
end

local _, hasRepo = getDiskPath()

local function hasPrinter()
    return peripheral.find("printer") ~= nil
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

local function line()
    local w = term.getSize()
    print(string.rep("-", w))
end

local function serverprint(text)
    print("(server): " .. text)
end

--===========================================================

local function system_info(full_info)
    clear()
    rprint("yellow", "Pawsoft v.2.3 (server)")
    print("pawsoft-server [admin password] [user password]")
    print("type [help] for commands\n")
    if full_info then
        print(" Server IP: " .. SERVER_IP)
        print(" Admin password: " .. PASSWORDS["admin"].password)
        print(" User password: " .. PASSWORDS["user"].password)
        print(" Guest password: " .. PASSWORDS["guest"].password)
        print(" Website: " .. tostring(hasWebsite()))
        print(" Printer: " .. tostring(hasPrinter()))
        print(" Repo disk patch: /" .. getDiskPath() .. "\n")

        line()
        print(
            "index.txt on the disk enables the www server.\nFiles starting with '$' are protected\nand require a valid login.")
        line()
    end
end

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

local function addRecord(client_ip, user_type, scode)
    SESSIONS[client_ip] = {
        password = hash64(PASSWORDS[user_type].password .. scode),
        ip = client_ip,
        power = PASSWORDS[user_type].power,
        key = hash64(PASSWORDS[user_type].password)
    }
end

local function verification(SESSIONS, message, senderIP)
    local session = SESSIONS[senderIP]

    if not session then
        return false
    end

    if session.ip ~= senderIP then
        return false
    end

    if type(message.password) ~= "string" then
        return false
    end

    if message.password == session.password then
        return true
    end

    return false
end


--===========================================================

local function ping(senderIP, msg)
    MODEM.transmit(senderIP, SERVER_IP, { ok = "pong", repo = hasRepo, www = hasWebsite(), printer = hasPrinter() })
end


local function _registration(senderIP, msg)
    if msg.user_type ~= "guest" and
        msg.user_type ~= "user" and
        msg.user_type ~= "admin" then
        MODEM.transmit(senderIP, SERVER_IP, { error = "invalid user type" })
        return
    end

    local SCODE = math.random(1000, 9999)
    addRecord(senderIP, msg.user_type, SCODE)
    MODEM.transmit(senderIP, SERVER_IP, { scode = SCODE, ok = "_" })
    serverprint("ip:" .. SESSIONS[senderIP].ip .. " password: " .. SESSIONS[senderIP].password) -- TEST
end


local function _login(senderIP, msg)
    if verification(SESSIONS, msg, senderIP) then
        MODEM.transmit(senderIP, SERVER_IP, { ok = "Logged in" })
    else
        MODEM.transmit(senderIP, SERVER_IP, { error = "Access denied" })
    end
end

local function list(senderIP, msg)
    if getDiskPath() == "none" then
        MODEM.transmit(senderIP, SERVER_IP, {
            error = "No disk inserted"
        })
    else
        MODEM.transmit(senderIP, SERVER_IP, { list = fs.list(getDiskPath()), ok = "_" })
    end
end

local function get(senderIP, msg, USER)
    if not (msg.file:sub(1, 1) == "$" and USER < 2) then
        if getDiskPath() == "none" then
            MODEM.transmit(senderIP, SERVER_IP, {
                error = "No disk inserted"
            })
        else
            local path = getDiskPath() .. "/" .. msg.file:gsub("/", "")
            if fs.exists(path) then
                local f = fs.open(path, "r")
                local data = f.readAll()
                f.close()

                MODEM.transmit(
                    senderIP,
                    SERVER_IP,
                    { data = encrypt(data, SESSIONS[senderIP].key), ok = "_" }
                )
            else
                MODEM.transmit(
                    senderIP,
                    SERVER_IP,
                    { error = "bad path" }
                )
            end
        end
    else
        MODEM.transmit(
            senderIP,
            SERVER_IP,
            { error = "Access denied" }
        )
    end
end

local function push(senderIP, msg, USER)
    if not ((msg.file == "index.txt" or msg.file:sub(1, 1) == "$") and USER < 3) then
        if not getDiskPath() then
            MODEM.transmit(senderIP, SERVER_IP, {
                error = "No disk inserted"
            })
        elseif fs.isReadOnly(getDiskPath()) then
            MODEM.transmit(senderIP, SERVER_IP, {
                error = "Disk is read-only"
            })
        else
            local path = getDiskPath() .. "/" .. msg.file:gsub("/", "")

            local f = fs.open(path, "w")
            f.write(decrypt(msg.data, SESSIONS[senderIP].key))
            f.close()

            MODEM.transmit(senderIP, SERVER_IP, {
                ok = "saved"
            })
        end
    else
        MODEM.transmit(
            senderIP,
            SERVER_IP,
            { error = "Access denied" }
        )
    end
end

local function remoteprint(senderIP, msg, USER)
    local printer = peripheral.find("printer")

    if not printer then
        MODEM.transmit(senderIP, SERVER_IP, {
            error = "No printer connected"
        })
    elseif not printer.newPage() then
        MODEM.transmit(senderIP, SERVER_IP, {
            error = "No paper"
        })
    else
        for line in msg.data:gmatch("[^\r\n]+") do
            printer.write(line)
            local _, y = printer.getCursorPos()
            printer.setCursorPos(1, y + 1)
        end

        printer.endPage()

        MODEM.transmit(senderIP, SERVER_IP, {
            ok = "printed"
        })
    end
end


local COMMANDS = {
    { name = "_registration", starter = _registration, class = -1 },
    { name = "_login",        starter = _login,        class = -1 },
    { name = "ping",          starter = ping,          class = -1 },
    { name = "list",          starter = list,          class = 1 },
    { name = "get",           starter = get,           class = 1 },
    { name = "print",         starter = remoteprint,   class = 2 },
    { name = "push",          starter = push,          class = 2 }

}

--===========================================================

local function server_loop()
    while true do
        local _, _, receiverIP, senderIP, msg = os.pullEvent("modem_message")
        if receiverIP == SERVER_IP and type(msg) == "table" then
            USER = 0

            if verification(SESSIONS, msg, senderIP) then
                USER = SESSIONS[senderIP].power
            end

            serverprint("p: " .. USER)

            local found = false

            for _, command in ipairs(COMMANDS) do
                if command.name == msg.cmd then
                    found = true
                    if USER >= command.class then
                        command.starter(senderIP, msg, USER)
                    else
                        MODEM.transmit(senderIP, SERVER_IP, { error = "invalid user" })
                    end
                    break
                end
            end

            if not found then
                MODEM.transmit(senderIP, SERVER_IP, { error = "unknown command" })
            end
        end
    end
end

--===========================================================

local function mount(emu)
    local f = fs.open("startup.txt", "w")

    if emu then
        f.write([[
ccemux.attach("right", "disk_drive", { id = 0 })

ccemux.attach("left", "disk_drive", { id = 1 })

ccemux.attach("top", "wireless_modem", {
    range = 64,
    interdimensional = false,
    world = "main",
    posX = 0,
    posY = 0,
    posZ = 0,
})

shell.run("pawsort-server.lua")
]])
    else
        f.write([[
shell.run("pawsort-server.lua")
]])
    end

    f.close()

    if fs.exists("startup.lua") then
        fs.delete("startup.lua")
    end

    fs.move("startup.txt", "startup.lua")
end

local function help()
    clear()
    print("Commands:")
    print("")
    print("  help       Display this help message")
    print("  info       Show system information")
    print("  mount      Mount server in startup.lua")
    print("  emumount   Mount server in startup.lua for CCEmuX")
    print("  clear      Clear the terminal screen")
    print("  cls        Alias for clear")
    print("  stop       Exit the program")
end

--===========================================================

system_info(true)

local function console_loop()
    while true do
        --local cmd = rinput("server")
        local cmd = read()
        if cmd == "stop" then return end
        if cmd == "info" then system_info(true) end
        if cmd == "help" then help() end
        if cmd == "emumount" then mount(true) end
        if cmd == "mount" then mount(false) end
        if cmd == "clear" or cmd == "cls" then clear() end
    end
end

--===========================================================

parallel.waitForAny(server_loop, console_loop)

rprint("blue", "server closed\n")
MODEM.close(SERVER_IP)
