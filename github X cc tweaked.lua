-- ============================================
-- CONFIG - CHANGE THESE 3 LINES
-- ============================================
local GITHUB_USER = "you229ssef"
local GITHUB_REPO = "CC-tweaked-folder"
local TOKEN = "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"  -- optional but recommended

local BRANCH = "main"
local SEEN_FILE = ".seen"

-- ============================================
-- API HELPERS
-- ============================================
local function apiGet(path)
    local url = "https://api.github.com/repos/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. path
    local headers = {}
    if TOKEN and TOKEN:sub(1,4) == "ghp_" then
        headers["Authorization"] = "token " .. TOKEN
    end
    local response = http.get(url, headers)
    if not response then return nil end
    local data = textutils.unserializeJSON(response.readAll())
    response.close()
    return data
end

local function rawGet(filename)
    local url = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/" .. BRANCH .. "/" .. filename
    local headers = {}
    if TOKEN and TOKEN:sub(1,4) == "ghp_" then
        headers["Authorization"] = "token " .. TOKEN
    end
    local response = http.get(url, headers)
    if not response then return nil end
    local data = response.readAll()
    response.close()
    return data
end

-- ============================================
-- FILE / DISK HELPERS
-- ============================================
local function loadSeen()
    if not fs.exists(SEEN_FILE) then return {} end
    local f = fs.open(SEEN_FILE, "r")
    local t = textutils.unserialize(f.readAll()) or {}
    f.close()
    return t
end

local function saveSeen(t)
    local f = fs.open(SEEN_FILE, "w")
    f.write(textutils.serialize(t))
    f.close()
end

local function findDisk()
    for _, side in ipairs({"left","right","top","bottom","front","back"}) do
        if peripheral.getType(side) == "drive" then
            local p = peripheral.wrap(side)
            if p.hasDisk() then
                return p.getMountPath(), p
            end
        end
    end
    if fs.exists("disk") then return "disk", nil end
    return nil, nil
end

-- ============================================
-- MAIN
-- ============================================
local function main()
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.cyan)
    print(string.rep("=", 40))
    print("      GITHUB SYNC - NO MANIFEST")
    print(string.rep("=", 40))
    term.setTextColor(colors.white)
    
    write("\nScanning repo... ")
    local contents = apiGet("/contents/")
    if not contents then
        print("FAILED")
        print("Check repo name / internet / token.")
        sleep(2)
        return
    end
    print("OK")
    
    -- Grab all .lua files from repo root
    local files = {}
    for _, item in ipairs(contents) do
        if item.type == "file" and item.name:match("%.lua$") then
            table.insert(files, item.name)
        end
    end
    
    if #files == 0 then
        print("No .lua files in repo root.")
        sleep(1.5)
        return
    end
    
    -- Compare with seen
    local seen = loadSeen()
    local newFiles = {}
    for _, f in ipairs(files) do
        if not seen[f] then table.insert(newFiles, f) end
    end
    
    -- DISPLAY
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.cyan)
    print("REPO: " .. GITHUB_REPO .. "  |  " .. #files .. " FILES")
    if #newFiles > 0 then
        term.setTextColor(colors.lime)
        print("NEW FILES: " .. #newFiles)
    end
    term.setTextColor(colors.white)
    print(string.rep("-", 40))
    
    for i, f in ipairs(files) do
        if seen[f] then
            term.setTextColor(colors.lightGray)
            print(string.format("  [%d] %s", i, f))
        else
            term.setTextColor(colors.yellow)
            print(string.format("  [%d] %s  <<< NEW", i, f))
            term.setTextColor(colors.white)
        end
    end
    
    print(string.rep("-", 40))
    print("Type:  new  |  all  |  1,3,5  |  exit")
    write("> ")
    local input = read()
    
    if input:lower() == "exit" then return end
    
    -- Parse selection
    local selected = {}
    if input:lower() == "all" then
        selected = files
    elseif input:lower() == "new" then
        selected = newFiles
        if #selected == 0 then
            print("Nothing new to grab.")
            sleep(1)
            return
        end
    else
        for num in input:gmatch("%d+") do
            local n = tonumber(num)
            if n and n >= 1 and n <= #files then
                table.insert(selected, files[n])
            end
        end
    end
    
    if #selected == 0 then
        print("No selection made.")
        sleep(1)
        return
    end
    
    -- DISK CHECK
    local diskPath, drive = findDisk()
    if not diskPath then
        term.setTextColor(colors.red)
        print("\n! INSERT FLOPPY DISK !")
        term.setTextColor(colors.white)
        sleep(1.5)
        return
    end
    
    print("\nDisk ready: /" .. diskPath .. "/")
    print("Copying " .. #selected .. " file(s)...\n")
    
    -- DOWNLOAD & COPY
    local copied = 0
    for _, f in ipairs(selected) do
        write(f .. " ... ")
        local content = rawGet(f)
        if not content then
            term.setTextColor(colors.red)
            print("FAIL")
            term.setTextColor(colors.white)
        else
            local out = fs.open(diskPath .. "/" .. f, "w")
            out.write(content)
            out.close()
            seen[f] = true
            copied = copied + 1
            term.setTextColor(colors.lime)
            print("OK")
            term.setTextColor(colors.white)
        end
    end
    
    saveSeen(seen)
    
    print("\nDone: " .. copied .. "/" .. #selected .. " copied.")
    
    if drive then
        write("Eject disk? (y/n) ")
        if read():lower() == "y" then
            drive.eject()
            print("Ejected.")
        end
    end
    
    print("Press any key...")
    os.pullEvent("key")
end

-- ============================================
-- AUTO-REFRESH LOOP
-- ============================================
while true do
    main()
    term.clear()
    term.setCursorPos(1,1)
    print("Waiting 30s... (press any key to sync now)")
    local timer = os.startTimer(30)
    while true do
        local ev = {os.pullEvent()}
        if ev[1] == "timer" and ev[2] == timer then break end
        if ev[1] == "key" then break end
    end
end
