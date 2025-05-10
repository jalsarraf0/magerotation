--=============== MageRotation.lua ===============
--  MageRotationAssistant v0.2
--  A minimalist Fire-mage rotation helper for Turtle WoW (Vanilla 1.12)
--------------------------------------------------

MageRotationDB = MageRotationDB or { pos = { x = 0, y = -120 }, scale = 1.0, alpha = 1.0 }

local SPELL_SCORCH    = GetSpellInfo(10205) or "Scorch"
local SPELL_FIREBALL  = GetSpellInfo(10151) or "Fireball"
local SPELL_FIREBLAST = GetSpellInfo(10199) or "Fire Blast"
local DEBUFF_VULN     = GetSpellInfo(22959) or "Fire Vulnerability"
local DEBUFF_IGNITE   = GetSpellInfo(12654) or "Ignite"

local MRA_Frame = CreateFrame("Frame", "MRA_Frame", UIParent)
local f = MRA_Frame

local function CreateHUD()
    f:SetScale(MageRotationDB.scale)
    f:SetAlpha(MageRotationDB.alpha)
    f:SetPoint("CENTER", UIParent, "CENTER", MageRotationDB.pos.x, MageRotationDB.pos.y)
    f:SetSize(64, 64)

    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetAllPoints(f)
    f.icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.text:SetPoint("TOP", f, "BOTTOM", 0, -2)

    f.barBG = f:CreateTexture(nil, "BACKGROUND")
    f.barBG:SetTexture(0, 0, 0, 0.6)
    f.barBG:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", -32, -6)
    f.barBG:SetSize(128, 12)

    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetTexture(1, 0.25, 0, 0.8)
    f.bar:SetPoint("LEFT", f.barBG, "LEFT", 0, 0)
    f.bar:SetHeight(12)

    f.tickText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.tickText:SetPoint("TOP", f.barBG, "BOTTOM", 0, -2)

    f:Hide()
end
CreateHUD()

SLASH_MRA1, SLASH_MRA2, SLASH_MRA3 = "/mra", "/magerotation", "/magerota"
SlashCmdList.MRA = function(msg)
    msg = msg:lower()
    if msg == "unlock" then
        f:EnableMouse(true); f:SetMovable(true)
        f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local x, y = self:GetCenter()
            local ux, uy = UIParent:GetCenter()
            MageRotationDB.pos.x = floor(x - ux + 0.5)
            MageRotationDB.pos.y = floor(y - uy + 0.5)
        end)
        print("|cff33ff99MRA|r: frame unlocked.")
    elseif msg == "lock" then
        f:SetScript("OnDragStart", nil); f:SetScript("OnDragStop", nil)
        f:EnableMouse(false)
        print("|cff33ff99MRA|r: frame locked.")
    elseif msg == "config" then
        print("|cff33ff99MRA config|r current: scale="..MageRotationDB.scale..", alpha="..MageRotationDB.alpha)
        print("Usage: /mra scale <0.5-2.0>  |  /mra alpha <0-1>")
    else
        local cmd, val = msg:match("^(%S+)%s+([%d%.]+)$")
        if cmd == "scale" then
            MageRotationDB.scale = tonumber(val) or MageRotationDB.scale
            f:SetScale(MageRotationDB.scale)
        elseif cmd == "alpha" then
            MageRotationDB.alpha = tonumber(val) or MageRotationDB.alpha
            f:SetAlpha(MageRotationDB.alpha)
        else
            print("|cff33ff99MRA|r commands: unlock, lock, config, scale <n>, alpha <n>")
        end
    end
end

local function HasFireVuln5()
    for i = 1, 16 do
        local name, _, count = UnitDebuff("target", i)
        if not name then break end
        if name == DEBUFF_VULN and count == 5 then return true end
    end
end

local function IgniteData()
    for i = 1, 16 do
        local name, _, _, _, _, duration, expiration = UnitDebuff("target", i)
        if not name then break end
        if name == DEBUFF_IGNITE then
            return true, duration or 4, expiration or (GetTime() + 4)
        end
    end
    return false
end

local function ManaPercent()
    local mana, max = UnitMana("player"), UnitManaMax("player")
    if max == 0 then return 0 end
    return floor(mana / max * 100 + 0.5)
end

local UPDATE_INTERVAL, elapsedTicker = 0.2, 0
local nextSpell, nextIcon = nil, nil

local function DecideNextSpell()
    if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then
        nextSpell = nil; return
    end

    if not HasFireVuln5() then
        nextSpell = SPELL_SCORCH; nextIcon = GetSpellTexture(SPELL_SCORCH); return
    end

    local hasIgnite, duration, expire = IgniteData()
    if hasIgnite then
        local remain = expire - GetTime()
        local start, cd = GetSpellCooldown(SPELL_FIREBLAST)
        if remain < 1.5 and cd == 0 then
            nextSpell = SPELL_FIREBLAST; nextIcon = GetSpellTexture(SPELL_FIREBLAST); return
        end
    end

    if ManaPercent() > 30 then
        nextSpell = SPELL_FIREBALL; nextIcon = GetSpellTexture(SPELL_FIREBALL)
    else
        nextSpell = SPELL_SCORCH; nextIcon = GetSpellTexture(SPELL_SCORCH)
    end
end

local igniteTickDamage = 0
local function ParseIgnite(msg)
    local amount = msg:match("%d+")
    if amount then igniteTickDamage = tonumber(amount) end
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
        self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:Show()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:Hide()
    elseif event:match("CHAT_MSG_SPELL_PERIODIC") then
        local msg = ...
        if msg and msg:find("Ignite") then ParseIgnite(msg) end
    end
end)
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnUpdate", function(self, elapsed)
    elapsedTicker = elapsedTicker + elapsed
    if elapsedTicker < UPDATE_INTERVAL then return end
    elapsedTicker = 0

    DecideNextSpell()

    if nextSpell then
        f.icon:SetTexture(nextIcon)
        f.text:SetText(nextSpell)

        local hasIgnite, duration, expire = IgniteData()
        if hasIgnite then
            local remain = expire - GetTime()
            local pct = remain / duration
            f.bar:SetWidth(pct * 128)
            f.bar:SetColorTexture(1, pct * 0.5, 0)
            f.barBG:Show(); f.bar:Show()
            f.tickText:SetText(string.format("Ignite %.1fs  |  %dd", remain, igniteTickDamage))
        else
            f.bar:SetWidth(0); f.barBG:Hide(); f.tickText:SetText("")
        end
    else
        f.icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
        f.text:SetText("")
        f.bar:SetWidth(0); f.barBG:Hide(); f.tickText:SetText("")
    end
end)
