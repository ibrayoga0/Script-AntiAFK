script_name("AntiAFK")
script_author("Ibraheem") 
script_version("1.0 Free")

require "moonloader"
require "lib.moonloader"
local sampev = require "samp.events"
local inicfg = require 'inicfg'
local encoding = require 'encoding'
local font = renderCreateFont('Arial', 10, 4)

encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Constants
local MAX_USAGE = 1
local RESET_TIME = 43200 -- 12 jam dalam detik
local AUTO_SAVE_INTERVAL = 60 -- Auto save setiap 60 detik
local CONFIG_PATH = 'moonloader\\antiafk.ini'

-- Default config
local default_config = {
    data = {
        usageCount = 0,
        lastResetTime = 0,
        isLocked = false,
        lastSave = 0
    }
}

-- Variables
local settings = inicfg.load(default_config, CONFIG_PATH)
if not settings then
    settings = default_config
    inicfg.save(settings, CONFIG_PATH)
end

local active = true
local lastAFKNumber = nil
local timeUntilNext = 0
local lastResponseTime = 0
local lastPromotionTime = 0
local wasInGame = true
local lastAutoSave = 0

local STATUS = {
    POS_X = 15,
    POS_Y = 350,
    TEXT_COLOR = 0xFFFFFFFF,
    ACTIVE_COLOR = 0xFF00FF00,
    INACTIVE_COLOR = 0xFFFF0000,
    WAIT_COLOR = 0xFFFFFF00,
    BG_COLOR = 0x90000000
}

-- Fungsi untuk menyimpan settings
function saveSettings()
    return inicfg.save(settings, CONFIG_PATH)
end

function getTimeUntilReset()
    local timeLeft = (settings.data.lastResetTime + RESET_TIME) - os.time()
    if timeLeft <= 0 then return "0h 0m"
    else
        local hours = math.floor(timeLeft / 3600)
        local minutes = math.floor((timeLeft % 3600) / 60)
        return string.format("%dh %dm", hours, minutes)
    end
end

function checkAndResetUsage()
    if os.time() - settings.data.lastResetTime >= RESET_TIME then
        settings.data.usageCount = 0
        settings.data.isLocked = false
        settings.data.lastResetTime = os.time()
        saveSettings()
    end
end

function checkStatus()
    printStringNow("~g~Checking AntiAFK Status...", 3000)
    wait(1000)
    if settings.data.isLocked then
        printStringNow(string.format("~r~AntiAFK is Locked! Reset in %s", getTimeUntilReset()), 5000)
    else
        printStringNow(string.format("~g~Uses: %d/%d | Next Reset in %s", 
            settings.data.usageCount, MAX_USAGE, getTimeUntilReset()), 5000)
    end
end

function main()
    if not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    sampRegisterChatCommand("antiafk", cmd_antiafk)
    sampRegisterChatCommand("antiafkstatus", checkStatus)
    printStringNow("~g~AntiAFK Free Version Loaded!", 3000)
    
    -- Check status saat login
    wait(1000)
    checkStatus()
    
    while true do
        wait(0)
        
        -- Auto save
        if os.time() - lastAutoSave >= AUTO_SAVE_INTERVAL then
            saveSettings()
            lastAutoSave = os.time()
        end
        
        -- Check game focus
        local gameIsActive = not sampIsChatInputActive() and not sampIsDialogActive() 
            and not isSampfuncsConsoleActive() and not isPauseMenuActive()
        if gameIsActive ~= wasInGame then
            if gameIsActive then
                printStringNow("~y~Welcome back! Upgrade to Premium for more Features!", 5000)
            end
            wasInGame = gameIsActive
        end

        checkAndResetUsage()
        
        -- Render status box
        local lines = {
            "Anti AFK Status",
            active and "ACTIVE" or "INACTIVE",
            active and timeUntilNext > 0 and string.format("Next: %d sec", math.floor(timeUntilNext / 1000)) or "",
            string.format("Uses: %d/%d", settings.data.usageCount, MAX_USAGE),
            settings.data.isLocked and "LOCKED - Reset in " .. getTimeUntilReset() or "Free Version"
        }

        -- Calculate box dimensions
        local maxWidth = 0
        local height = 15
        for _, line in ipairs(lines) do
            if line ~= "" then
                height = height + 15
                local lineWidth = renderGetFontDrawTextLength(font, line)
                maxWidth = math.max(maxWidth, lineWidth)
            end
        end
        maxWidth = maxWidth + 20

        -- Draw background and text
        renderDrawBox(STATUS.POS_X, STATUS.POS_Y, maxWidth, height, STATUS.BG_COLOR)
        local y = STATUS.POS_Y + 5
        for i, line in ipairs(lines) do
            if line ~= "" then
                local color = STATUS.TEXT_COLOR
                if i == 2 then color = active and STATUS.ACTIVE_COLOR or STATUS.INACTIVE_COLOR
                elseif i == 3 then color = STATUS.WAIT_COLOR end
                renderFontDrawText(font, line, STATUS.POS_X + 10, y, color)
                y = y + 15
            end
        end

        -- Timer logic
        if active and not settings.data.isLocked then
            if timeUntilNext > 0 then
                timeUntilNext = timeUntilNext - 1
                if timeUntilNext <= 0 and lastAFKNumber then
                    if settings.data.usageCount >= MAX_USAGE then
                        settings.data.isLocked = true
                        active = false
                        saveSettings()
                        printStringNow("~r~AntiAFK limit reached! Reset in " .. getTimeUntilReset(), 5000)
                        wait(1000)
                        sampSendChat("/q")
                    else
                        respondToAFK()
                    end
                end
            end

            if os.time() - lastPromotionTime >= 1800 then
                printStringNow("~y~Upgrade to Premium for more Features!", 5000)
                lastPromotionTime = os.time()
            end
        end
    end
end

function cmd_antiafk()
    if settings.data.isLocked then
        printStringNow("~r~AntiAFK is locked! Reset in " .. getTimeUntilReset(), 5000)
        return
    end
    if active then
        printStringNow("~r~AntiAFK Deactivated", 3000)
    else
        printStringNow("~g~AntiAFK Activated", 3000)
    end
    active = not active
    timeUntilNext = 0
    lastAFKNumber = nil
    saveSettings()
end

function respondToAFK()
    if lastAFKNumber then
        wait(1000)
        settings.data.usageCount = settings.data.usageCount + 1
        saveSettings()
        sampSendChat("/afk " .. lastAFKNumber)
        timeUntilNext = 60000
        lastAFKNumber = nil
        printStringNow("~y~[" .. settings.data.usageCount .. "/" .. MAX_USAGE .. "] Upgrade to Premium for more Features!", 5000)
    end
end

function sampev.onServerMessage(color, text)
    if active and not settings.data.isLocked then
        local afkNumber = string.match(text, "/afk%s+(%d+)")
        if afkNumber then
            local currentTime = os.time()
            if currentTime - lastResponseTime >= 30 then
                lastAFKNumber = afkNumber
                timeUntilNext = 1000
                lastResponseTime = currentTime
            end
        end
    end
end

function sampev.onSendCommand(command)
    if string.lower(command) == "/q" or string.lower(command) == "/quit" then
        saveSettings()
    end
end

function onScriptTerminate(script, quitGame)
    if script == thisScript() then
        saveSettings()
    end
end