-- create a basic frame for recieving events
local ADDON_NAME = 'AreWeThereYet'
local AWTY = CreateFrame('Frame', ADDON_NAME, UIParent)

local IS_WOW_CLASSIC = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

AWTY.CONFIG = {
    AVG_RECORD_COUNT    = 3,
    MAX_LEVEL           = 120,
}
AWTY.MESSAGES = {
    ON_XP_GAIN          = '%d more kills to level %d',
    ON_LEVEL_GAIN       = 'Congrats on reaching level %d',
}
AWTY.FLAGS = {
    NEW_LEVEL           = nil,
    HAVE_BONUS_XP       = false,
}

if IS_WOW_CLASSIC then
    AWTY.CONFIG.MAX_LEVEL = 60
end

local function table_insert(t, v)
    table.insert(t, v)
end
local function table_pop(t)
    table.remove(t, 1)
end
local math_abs, math_ceil = math.abs, math.ceil

AWTY:RegisterEvent('ADDON_LOADED')
function AWTY:EVENT_ADDON_LOADED(this)
    self:RegisterEvent('PLAYER_ENTERING_WORLD')
end

function AWTY:EVENT_PLAYER_ENTERING_WORLD()
    if self:getPlayerLevel() < self.CONFIG.MAX_LEVEL then
        self:RegisterEvent('PLAYER_XP_UPDATE')
        self:RegisterEvent('PLAYER_LEVEL_UP')
        self:RegisterEvent('UPDATE_EXHAUSTION')
    end

    self.previousRestedAmount = self:getPlayerBonusXP()
    self.previousXPAmount = self:getPlayerXP()
    self.currentLevel = self:getPlayerLevel()
    self.xpMax = self:getPlayerXPMax()
    self.minXPFromQuest = self:getPlayerMockXPValue() * 3
    self.rollingAverage = {self:getPlayerMockXPValue()}
    self.FLAGS.HAVE_BONUS_XP = self:getPlayerBonusXP() > 0
end

function AWTY:EVENT_PLAYER_XP_UPDATE(unitID)
    if unitID == 'player' then
        if self.FLAGS.NEW_LEVEL ~= nil then
            if self:getPlayerLevel() >= self.FLAGS.NEW_LEVEL then
                -- everything is kosher now and we can handle the new level
                self.xpMax = self:getPlayerXPMax()
                self.minXPFromQuest = self:getPlayerMockXPValue() * 3

                self.FLAGS.NEW_LEVEL = nil
            end
        end

        local currentXP = self:getPlayerXP()
        local xpDiff = currentXP - self.previousXPAmount
        self.previousXPAmount = currentXP

        self:updateRollingAvg(xpDiff)

        self:sendMessage('ON_XP_GAIN', self:getRemainingKills(), self.currentLevel + 1)
    end
end

function AWTY:EVENT_PLAYER_LEVEL_UP(newLevel, ...)
    -- UnitLevel('player') and the like are unreliable while handling this event
    -- so we'll just note that it happened and handle things later
    self:sendMessage('ON_LEVEL_GAIN', newLevel)

    if newLevel >= self.CONFIG.MAX_LEVEL then
        self:UnregisterEvent('PLAYER_XP_UPDATE')
        self:UnregisterEvent('PLAYER_LEVEL_UP')
        self:UnregisterEvent('UPDATE_EXHAUSTION')
    end

    self.currentLevel = newLevel
    self.previousXPAmount = 0
    self.FLAGS.NEW_LEVEL = newLevel
end

function AWTY:EVENT_UPDATE_EXHAUSTION()
    self.previousRestedAmount = self:getPlayerBonusXP()
    self.FLAGS.HAVE_BONUS_XP = self.previousRestedAmount > 0
end

function AWTY:getPlayerLevel()
    return UnixLevel('player')
end

function AWTY:getPlayerXP()
    return UnitXP('player')
end

function AWTY:getPlayerBonusXP()
    return GetXPExhaustion() or 0
end

function AWTY:getPlayerXPMax()
    return UnitXPMax('player')
end

function AWTY:getPlayerMockXPValue()
    return self.xpMax * 0.05 * (math_abs(self.CONFIG.MAX_LEVEL - self:getPlayerLevel()) / self.CONFIG.MAX_LEVEL)

function AWTY:updateRollingAvg(xpAmount)
    if xpAmount < self.minXPFromQuest then
        if self.FLAGS.HAVE_BONUS_XP then
            xpAmount = xpAmount / 2
        end
        table_insert(self.rollingAverage, xpAmount)
    end
    while #self.rollingAverage > self.CONFIG.AVG_RECORD_COUNT do
        table_pop(self.rollingAverage)
    end
end

function AWTY:getRollingAvg()
    local avg, total = 0, 0
    for i, v in ipairs(self.rollingAverage) do
        total = total + v
    end

    if total == 0 or #self.rollingAverage == 0 then
        -- avoid division by zero
        avg = self:getPlayerMockXPValue()
    else
        avg = total / #self.rollingAverage
    end

    return avg
end

function AWTY:getRemainingKills()
    local remainingKills, remainingXP = 0, self.xpMax - self.previousXPAmount
    if self.FLAGS.HAVE_BONUS_XP then
        if self.previousRestedAmount > remainingXP then
            return remainingXP / (self:getRollingAvg() * 2)
        else
            remainingKills = math_ceil(self.previousRestedAmount / (self:getRollingAvg() * 2))
            remainingXP = remainingXP - self.previousRestedAmount
        end
    end

    remainingKills = remainingKills + math_ceil(remainingXP / self:getRollingAvg())

    return remainingKills
end

function AWTY:sendMessage(messageKey, ...)
    print('[' .. ADDON_NAME .. ']: ' .. string.format(self.MESSAGES[messageKey], ...))
end

AWTY:SetScript('OnEvent', function(this, event, ...)
    this['EVENT_' .. event](this, ...)
end)
