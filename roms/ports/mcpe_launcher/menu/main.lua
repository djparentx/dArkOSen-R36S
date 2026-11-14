local ACCENT  = {0.20, 0.80, 0.40}
local FG      = {1.00, 1.00, 1.00}
local DIM     = {0.50, 0.50, 0.50}
local BLOCK_H = 52
local PADDING = 20
local LIST_TOP = 90
local PIN_GAP = 10
local PINNED_BLOCK_H = PIN_GAP + 1 + PIN_GAP + BLOCK_H*3
local FOOTER_TEXT_H = 24
local MAIN_RESERVE = PINNED_BLOCK_H + FOOTER_TEXT_H
local APK_RESERVE  = 58

local fontTitolo
local fontTesto
local fontHint
local bgImage
local W, H

local BASEDIR = os.getenv("MCPE_GAMEDIR")
local VERDIR  = BASEDIR.."/versions"
local APKDIR  = BASEDIR.."/Setup Apk"
local MENUDIR = BASEDIR.."/menu"
local CONFIRM_B = (os.getenv("MCPE_CONFIRM_SDL") or "a"):lower() == "b"
local OK_L = (os.getenv("MCPE_CONFIRM_LABEL") or "A"):upper() == "B" and "B" or "A"
local BACK_L = OK_L == "A" and "B" or "A"
local PORT_VERSION = ""
do
    local vf = io.open(BASEDIR.."/version.txt", "r")
    if vf then PORT_VERSION = (vf:read("*l") or ""):gsub("%s", ""); vf:close() end
end

local screen  = "main"
local selMain = 1
local selApk  = 1
local selArch = 1
local versions = {}
local apks = {}
local archOptions = {}
local pendingApk = nil
local confirmDelete = nil
local confirmDeleteVer = nil

local function scanVersions()
    local out = {}
    local p = io.popen("ls -d '"..VERDIR.."'/*/ 2>/dev/null")
    if p then
        for line in p:lines() do
            local name = line:match(".+/(.-)/$")
            if name then out[#out+1] = name end
        end
        p:close()
    end
    table.sort(out)
    return out
end

local function scanApks()
    local out = {}
    local p = io.popen("ls -p '"..APKDIR.."' 2>/dev/null")
    if p then
        for line in p:lines() do
            if not line:match("/$") and line:lower():match("%.apk$") then
                out[#out+1] = line
            end
        end
        p:close()
    end
    table.sort(out)
    return out
end

local function refresh()
    versions = scanVersions()
    apks = scanApks()
end

local function checkApkArchs(path)
    local hasArmhf, hasArm64 = false, false
    local p = io.popen("unzip -l '"..path.."' 2>/dev/null")
    if p then
        for line in p:lines() do
            if line:find("lib/armeabi-v7a", 1, true) then hasArmhf = true end
            if line:find("lib/arm64-v8a", 1, true) then hasArm64 = true end
        end
        p:close()
    end
    return hasArmhf, hasArm64
end

local function writeSelected(ver)
    local f = io.open(MENUDIR.."/selected_version.txt", "w")
    if f then f:write(ver); f:close() end
    love.event.quit(0)
end

local function writeApkSelected(name)
    local f = io.open(MENUDIR.."/setup_apk_selected.txt", "w")
    if f then f:write(name); f:close() end
    love.event.quit(0)
end

local function writeApkArch(value)
    local f = io.open(MENUDIR.."/setup_apk_arch.txt", "w")
    if f then f:write(value); f:close() end
end

local function maxVisible(reserve)
    local n = math.floor((H - LIST_TOP - reserve) / BLOCK_H)
    if n < 1 then n = 1 end
    return n
end

local function scrollOffset(sel, total, visible)
    if total <= visible then return 0 end
    local off = sel - 1 - math.floor(visible/2)
    if off < 0 then off = 0 end
    if off > total - visible then off = total - visible end
    return off
end

local function drawRow(x, y, w, label, selected, color, selColor)
    if selected then
        love.graphics.setColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.15)
        love.graphics.rectangle("fill", x, y+4, w, BLOCK_H-8, 6, 6)
        love.graphics.setColor(ACCENT)
        love.graphics.rectangle("fill", x, y+4, 4, BLOCK_H-8, 2, 2)
        love.graphics.setColor(selColor)
    else
        love.graphics.setColor(color)
    end
    love.graphics.printf(label, x+16, y+(BLOCK_H-16)/2, w, "left")
end

local function drawMain()
    local total = #versions
    local visible = maxVisible(MAIN_RESERVE)
    local clampedSel = math.min(math.max(selMain, 1), math.max(total, 1))
    local off = scrollOffset(clampedSel, total, visible)

    love.graphics.setFont(fontTesto)
    for row = 1, math.min(visible, total) do
        local i = row + off
        local v = versions[i]
        if v then
            local y = LIST_TOP + (row-1)*BLOCK_H
            if confirmDeleteVer == v then
                drawRow(PADDING, y, 320, v, i == selMain, {0.75,0.25,0.2}, {1.0,0.35,0.3})
            else
                drawRow(PADDING, y, 320, v, i == selMain, DIM, FG)
            end
        end
    end

    local pinnedRows = math.min(total, visible)
    local pinnedY = LIST_TOP + pinnedRows*BLOCK_H
    love.graphics.setColor(DIM)
    love.graphics.rectangle("fill", PADDING, pinnedY+PIN_GAP, 320, 1)

    local setupY  = pinnedY + PIN_GAP + 1 + PIN_GAP
    local updateY = setupY + BLOCK_H
    local exitY   = updateY + BLOCK_H

    drawRow(PADDING, setupY,  320, "[ Setup Apk ]",   selMain == total+1, {0.75,0.6,0.2}, {1.0,0.8,0.25})
    drawRow(PADDING, updateY, 320, "[ Update Port ]", selMain == total+2, {0.25,0.6,0.8}, {0.4,0.82,1.0})
    drawRow(PADDING, exitY,   320, "Exit",            selMain == total+3, {0.6,0.2,0.2},  {0.9,0.3,0.3})

    love.graphics.setFont(fontHint)
    if confirmDeleteVer then
        love.graphics.setColor(1.0,0.35,0.3)
        love.graphics.printf("Delete? X=Yes   "..BACK_L.."=No", PADDING+16, H-FOOTER_TEXT_H+4, 320, "left")
    elseif selMain == total+2 then
        love.graphics.setColor(DIM)
        local label = PORT_VERSION ~= "" and ("Installed: v"..PORT_VERSION) or ""
        love.graphics.printf(label, PADDING+16, H-FOOTER_TEXT_H+4, 320, "left")
    elseif selMain <= total then
        love.graphics.setColor(DIM)
        local label = "X=Delete"
        if total > visible then label = clampedSel.."/"..total.."   "..label end
        love.graphics.printf(label, PADDING+16, H-FOOTER_TEXT_H+4, 320, "left")
    elseif total > visible then
        love.graphics.setColor(DIM)
        love.graphics.printf(clampedSel.."/"..total, PADDING+16, H-FOOTER_TEXT_H+4, 320, "left")
    end
end

local function drawApk()
    love.graphics.setFont(fontTesto)
    if #apks == 0 then
        love.graphics.setColor(DIM)
        love.graphics.printf("No APK found.", PADDING+16, LIST_TOP+10, 320, "left")
        love.graphics.printf("Copy .apk files into:", PADDING+16, LIST_TOP+42, 320, "left")
        love.graphics.printf("mcpe_launcher/Setup Apk/", PADDING+16, LIST_TOP+68, 320, "left")
        love.graphics.printf("("..BACK_L.." = back)", PADDING+16, LIST_TOP+104, 320, "left")
        return
    end

    local total = #apks
    local visible = maxVisible(APK_RESERVE)
    local off = scrollOffset(selApk, total, visible)

    for row = 1, math.min(visible, total) do
        local i = row + off
        local a = apks[i]
        if a then
            local y = LIST_TOP + (row-1)*BLOCK_H
            if confirmDelete == a then
                drawRow(PADDING, y, 320, a, i == selApk, {0.75,0.25,0.2}, {1.0,0.35,0.3})
            else
                drawRow(PADDING, y, 320, a, i == selApk, DIM, FG)
            end
        end
    end

    love.graphics.setFont(fontHint)
    if confirmDelete then
        love.graphics.setColor(1.0,0.35,0.3)
        love.graphics.printf("Delete? X=Yes   "..BACK_L.."=No", PADDING+16, H-APK_RESERVE+6, 320, "left")
    else
        love.graphics.setColor(DIM)
        love.graphics.printf(OK_L.."=Setup   X=Delete   "..BACK_L.."=Back", PADDING+16, H-APK_RESERVE+6, 320, "left")
    end
    if total > visible then
        love.graphics.setColor(DIM)
        love.graphics.printf(selApk.."/"..total, PADDING+16, H-APK_RESERVE+6+22, 320, "left")
    end
end

local function drawArch()
    love.graphics.setFont(fontTesto)
    for i, label in ipairs(archOptions) do
        local y = LIST_TOP + (i-1)*BLOCK_H
        drawRow(PADDING, y, 320, label, i == selArch, DIM, FG)
    end
    love.graphics.setFont(fontHint)
    love.graphics.setColor(DIM)
    love.graphics.printf(OK_L.."=Confirm   "..BACK_L.."=Back", PADDING+16, H-APK_RESERVE+6, 320, "left")
end

function love.load()
    bgImage = love.graphics.newImage("bg.jpg")
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    fontTitolo = love.graphics.newFont("font_titolo.ttf", 24)
    fontTesto  = love.graphics.newFont("font_testo.ttf", 16)
    fontHint   = love.graphics.newFont("font_testo.ttf", 13)

    os.execute("mkdir -p '"..APKDIR.."'")
    refresh()
end

function love.draw()
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(bgImage, 0, 0, 0, W/bgImage:getWidth(), H/bgImage:getHeight())
    love.graphics.setColor(0.15,0.12,0.15,0.55)
    love.graphics.rectangle("fill", 0, 0, 360, H)

    love.graphics.setColor(ACCENT)
    love.graphics.setFont(fontTitolo)
    local title = "MCPE Launcher"
    if screen == "apk" then
        title = "Setup Apk"
    elseif screen == "archchoice" then
        title = "Select Architecture"
    end
    love.graphics.printf(title, 36, 30, 320, "left")

    love.graphics.setColor(DIM)
    love.graphics.rectangle("fill", PADDING*3, 62, 280, 1)

    if screen == "main" then
        drawMain()
    elseif screen == "apk" then
        drawApk()
    else
        drawArch()
    end
end

local function moveSel(dir)
    if screen == "main" then
        confirmDeleteVer = nil
        local n = #versions + 3
        selMain = selMain + dir
        if selMain < 1 then selMain = n end
        if selMain > n then selMain = 1 end
    elseif screen == "archchoice" then
        local n = #archOptions
        if n < 1 then return end
        selArch = selArch + dir
        if selArch < 1 then selArch = n end
        if selArch > n then selArch = 1 end
    else
        confirmDelete = nil
        local n = #apks
        if n < 1 then return end
        selApk = selApk + dir
        if selApk < 1 then selApk = n end
        if selApk > n then selApk = 1 end
    end
end

local function activate()
    if screen == "main" then
        local total = #versions
        if selMain <= total then
            confirmDeleteVer = nil
            writeSelected(versions[selMain])
        elseif selMain == total+1 then
            refresh()
            screen = "apk"
            selApk = 1
            confirmDelete = nil
        elseif selMain == total+2 then
            local f = io.open(MENUDIR.."/update_request.txt", "w")
            if f then f:write("1"); f:close() end
            love.event.quit(0)
        else
            writeSelected("")
        end
    elseif screen == "apk" then
        local a = apks[selApk]
        if a then
            confirmDelete = nil
            local hasArmhf, hasArm64 = checkApkArchs(APKDIR.."/"..a)
            if hasArmhf and hasArm64 then
                pendingApk = a
                archOptions = {"Both", "ARM32", "ARM64"}
                selArch = 1
                screen = "archchoice"
            else
                writeApkSelected(a)
            end
        end
    else
        local archValues = {"both", "armhf", "arm64"}
        writeApkArch(archValues[selArch] or "both")
        writeApkSelected(pendingApk)
    end
end

local function deleteArmed()
    if screen ~= "apk" then return end
    local cur = apks[selApk]
    if not cur then confirmDelete = nil; return end
    if confirmDelete == cur then
        os.remove(APKDIR.."/"..cur)
        confirmDelete = nil
        refresh()
        if selApk > #apks then selApk = #apks end
        if selApk < 1 then selApk = 1 end
    else
        confirmDelete = cur
    end
end

local function deleteVerArmed()
    if screen ~= "main" then return end
    local total = #versions
    if selMain > total then confirmDeleteVer = nil; return end
    local cur = versions[selMain]
    if not cur then confirmDeleteVer = nil; return end
    if confirmDeleteVer == cur then
        os.execute("rm -rf '"..VERDIR.."/"..cur.."'")
        confirmDeleteVer = nil
        refresh()
        if selMain > #versions then selMain = #versions end
        if selMain < 1 then selMain = 1 end
    else
        confirmDeleteVer = cur
    end
end

local function goBack()
    if screen == "apk" then
        if confirmDelete then
            confirmDelete = nil
        else
            screen = "main"
        end
    elseif screen == "archchoice" then
        pendingApk = nil
        screen = "apk"
    else
        if confirmDeleteVer then
            confirmDeleteVer = nil
        else
            writeSelected("")
        end
    end
end

function love.keypressed(key)
    if key == "up" or key == "dpup" then
        moveSel(-1)
    elseif key == "down" or key == "dpdown" then
        moveSel(1)
    elseif key == "return" or key == "a" or key == "space" then
        activate()
    elseif key == "x" then
        if screen == "main" then deleteVerArmed() else deleteArmed() end
    elseif key == "escape" then
        goBack()
    end
end

function love.gamepadpressed(joystick, button)
    if CONFIRM_B then
        if button == "a" then button = "b" elseif button == "b" then button = "a" end
    end
    if button == "dpup" then love.keypressed("up")
    elseif button == "dpdown" then love.keypressed("down")
    elseif button == "a" then love.keypressed("return")
    elseif button == "x" then love.keypressed("x")
    elseif button == "b" then love.keypressed("escape")
    end
end
