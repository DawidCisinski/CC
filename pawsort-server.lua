local PARMS = { ... }
local MODEM = peripheral.find("modem")
local SERVER_IP = os.getComputerID()

--===========================================================

if not PARMS[1] then PARMS[1] = "Set admin password" end
if not PARMS[2] then PARMS[2] = "Set user password" end
if not PARMS[3] then PARMS[3] = "default" end

local USER = 0
local PASSWORDS = {}
PASSWORDS["guest"] = { power = 1, password = PARMS[3] }
PASSWORDS["user"] = { power = 2, password = PARMS[2] }
PASSWORDS["admin"] = { power = 3, password = PARMS[1] }

local SESSIONS = {}

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
    return "none", false
end

local function hasWebsite()
    if fs.exists("disk/index.txt") then return true end
    return false
end

local _, hasRepo = getDiskPath()

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
    rprint("yellow", "Pawsoft v.2.0 (server)")
    print("pawsoft-server [admin password] [user password]\n")
    if full_info then
        print(" Server IP: " .. SERVER_IP)
        print(" Admin password: " .. PASSWORDS["admin"].password)
        print(" User password: " .. PASSWORDS["user"].password)
        print(" Website: " .. tostring(hasWebsite()))
        print(" Printer: (wip)")
        print(" Repo disk patch: /" .. getDiskPath() .. "\n")

        line()
        print(
            "index.txt on the disk enables the www server.\nFiles starting with '$' are protected\nand require a valid login.")
        line()
    end
end

local function system_boot()
    system_info(true)
    print("\nPress any key to continue...")
    os.pullEvent("key")
    system_info()
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

local function addRecord(client_ip, user_type, scode)
    SESSIONS[client_ip] = {
        password = hash64(PASSWORDS[user_type].password .. scode),
        ip = client_ip,
        power = PASSWORDS[user_type].power
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
    MODEM.transmit(senderIP, SERVER_IP, { ok = "pong", repo = hasRepo, www = hasWebsite() })
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



local function push()

end

local COMMANDS = {
    { name = "_registration", starter = _registration, class = -1 },
    { name = "_login",        starter = _login,        class = -1 },
    { name = "ping",          starter = ping,          class = -1 },
    { name = "push",          starter = push,          class = 3 }

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
                        command.starter(senderIP, msg)
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

system_boot()

local function console_loop()
    while true do
        --local cmd = rinput("server")
        local cmd = read()
        if cmd == "stop" then return end
        if cmd == "info" then system_boot() end
        if cmd == "clear" then clear() end
    end
end

--===========================================================

parallel.waitForAny(server_loop, console_loop)

rprint("blue", "server closed\n")
MODEM.close(SERVER_IP)
