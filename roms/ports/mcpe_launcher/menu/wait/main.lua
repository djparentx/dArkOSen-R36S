local font
local bg
local t = 0
local dir = nil
local total = 0
local done = 0
local poll = 0

local function measure()
    if not dir or total <= 0 then return end
    local p = io.popen('du -sk "' .. dir .. '" 2>/dev/null')
    if not p then return end
    local out = p:read("*l")
    p:close()
    local kb = tonumber(out and out:match("^(%d+)"))
    if kb then done = kb end
end

function love.load(args)
    font = love.graphics.newFont("font_testo.ttf", 24)
    bg = love.graphics.newImage("bg.jpg")
    for _, a in ipairs(args or {}) do
        if tonumber(a) then
            total = tonumber(a)
        elseif a:sub(1, 1) == "/" then
            dir = a
        end
    end
end

function love.update(dt)
    t = t + dt
    poll = poll + dt
    if poll >= 0.5 then
        poll = 0
        measure()
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    local cy = math.floor(h * 0.5)
    love.graphics.clear(0, 0, 0)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bg, 0, 0, 0, w / bg:getWidth(), h / bg:getHeight())
    love.graphics.setColor(0.15, 0.12, 0.15, 0.6)
    love.graphics.rectangle("fill", 0, cy - 80, w, 160)
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Extracting APK... Please wait", 0, cy - 60, w, "center")
    if total > 0 then
        local frac = math.min(done / total, 0.99)
        local bw, bh = math.floor(w * 0.7), 24
        local bx, by = math.floor((w - bw) / 2), math.floor(cy)
        love.graphics.setColor(0.25, 0.25, 0.25)
        love.graphics.rectangle("fill", bx, by, bw, bh)
        love.graphics.setColor(0.33, 0.69, 0.2)
        love.graphics.rectangle("fill", bx, by, math.floor(bw * frac), bh)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", bx, by, bw, bh)
        love.graphics.printf(math.floor(frac * 100) .. "%", 0, by + bh + 10, w, "center")
    else
        love.graphics.printf(string.rep(".", math.floor(t * 2) % 4), 0, cy, w, "center")
    end
end
