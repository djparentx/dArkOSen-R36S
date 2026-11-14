local font, fontSmall, bg
local statusFile = nil
local state = "STEP"
local result = ""
local message = "Checking for updates..."
local t = 0
local poll = 0
local okLabel = (os.getenv("MCPE_CONFIRM_LABEL") or "A"):upper() == "B" and "B" or "A"

local function readStatus()
    if not statusFile then return end
    local f = io.open(statusFile, "r")
    if not f then return end
    local line = f:read("*l")
    f:close()
    if not line or line == "" then return end
    local kind, a, b = line:match("^([^|]*)|([^|]*)|?(.*)$")
    if kind == "END" then
        state = "END"
        result = a or ""
        message = (b ~= nil and b ~= "") and b or a
    elseif kind == "STEP" then
        state = "STEP"
        message = a or message
    end
end

function love.load(args)
    font = love.graphics.newFont("font_testo.ttf", 22)
    fontSmall = love.graphics.newFont("font_testo.ttf", 16)
    bg = love.graphics.newImage("bg.jpg")
    for _, a in ipairs(args or {}) do
        if a:sub(1, 1) == "/" then statusFile = a end
    end
    readStatus()
end

function love.update(dt)
    t = t + dt
    poll = poll + dt
    if poll >= 0.25 then
        poll = 0
        if state ~= "END" then readStatus() end
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(0, 0, 0)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bg, 0, 0, 0, w / bg:getWidth(), h / bg:getHeight())
    love.graphics.setColor(0.15, 0.12, 0.15, 0.7)
    love.graphics.rectangle("fill", 0, h / 2 - 100, w, 200)
    love.graphics.setFont(font)
    love.graphics.setColor(0.4, 0.82, 1.0)
    love.graphics.printf("Update Port", 0, h / 2 - 84, w, "center")
    if state == "END" then
        if result == "ok" then
            love.graphics.setColor(0.45, 0.9, 0.45)
        elseif result == "err" then
            love.graphics.setColor(1.0, 0.45, 0.4)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.printf(message, w * 0.06, h / 2 - 30, w * 0.88, "center")
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf(okLabel .. " = OK", 0, h / 2 + 54, w, "center")
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(message, w * 0.06, h / 2 - 30, w * 0.88, "center")
        love.graphics.printf(string.rep(".", math.floor(t * 2) % 4), 0, h / 2 + 20, w, "center")
    end
end

local function close()
    if state == "END" then love.event.quit(0) end
end

function love.keypressed(key)
    close()
end

function love.gamepadpressed(joystick, button)
    close()
end
