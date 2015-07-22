local myname, AWTY = ...

AWTY.MSG_KILL           = '%d more kills to next level'
AWTY.CONFIG_AVG_SIZE    = 3


function AWTY:init()
    self.killCounter = 0;
    self.rollingAverage = {};
    self.previousXPAmount = self:playerXP();
end

function AWTY:getRollingAvg()
    local total = 0;
    for i, v in ipairs(self.rollingAverage) do
        total = total + v
    end
    return total / #self.rollingAverage
end

function AWTY:updateRollingAvg(xpAmount)
    self.killCounter = self.killCounter + 1;
    self.rollingAverage[self.killCounter % self.CONFIG_AVG_SIZE] = xpAmount;
end

function AWTY:playerXP()
    return UnitXP('player')
end

function AWTY:playerXPMax()
    return UnitXPMax('player')
end

function AWTY:onXPGain()
    local playerXP = self:playerXP();
    local xpGain = playerXP - self.previousXPAmount;
    local remainingXP = self:playerXPMax() - playerXP;

    self:updateRollingAvg(xpGain);
    self:displayMessage(remainingXP / self:getRollingAvg());

    self.previousXPAmount = playerXP;
end

function AWTY:displayMessage(killsRemaining)
    print(string.format(self.MSG_KILL, killsRemaining));
end



AWTY.eventFrame = CreateFrame('FRAME', 'AWTY_EventsFrame');
AWTY.eventFrameMap = {};

function AWTY.eventFrameMap:PLAYER_ENTERING_WORLD(...)
    AWTY:init();
end

function AWTY.eventFrameMap:PLAYER_XP_UPDATE(...)
    AWTY:onXPGain();
end

function AWTY.eventFrameMap:PLAYER_LEVEL_UP(...)
    -- AWTY.previousXPAmount = UnitXP('player');
end

AWTY.eventFrame:SetScript('OnEvent',
    function(self, event, ...)
        AWTY.eventFrameMap[event](self, ...);
    end);

for k, v in pairs(AWTY.eventFrameMap) do
    AWTY.eventFrame:RegisterEvent(k);
end
