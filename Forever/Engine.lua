local addonName, addonTable = ...

addonTable.Engine = {}
local Engine = addonTable.Engine
local C = addonTable.Constants
local UILib = addonTable.UILib

-- State tracking machine
local state = {
  lastMoney = 0,
  isMerchantOpen = false,
  isAuctionOpen = false,
  isMailOpen = false,
  isLootOpen = false,
  isTaxiOpen = false,
  isTrainerOpen = false,
  isTradeOpen = false,
  repairTriggered = false,
  questTurninTriggered = false,
  lastLootTime = 0,
  mailWasFromAH = false
}

-------------------------------------------------------------------------------
-- RULESET & CHARACTER IDENTIFICATION
-------------------------------------------------------------------------------

function Engine:GetCurrentRuleset()
  if C_GameRules and Enum and Enum.GameRule then
    if Enum.GameRule.HardcoreRuleset and C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset) then
      return "Hardcore"
    elseif Enum.GameRule.RPRuleset and C_GameRules.IsGameRuleActive(Enum.GameRule.RPRuleset) then
      return "RP"
    elseif Enum.GameRule.PvPRuleset and C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset) then
      return "PvP"
    end
  end

  local realm = GetRealmName()
  if realm and realm ~= "" then
    return realm
  end

  return "Normal"
end

function Engine:GetPlayerCharacterKey()
  local name = UnitName("player") or "Unknown"
  local realm = GetRealmName() or "Default"
  return name .. " - " .. realm
end

function Engine:RegisterPlayer()
  local charKey = self:GetPlayerCharacterKey()
  local name = UnitName("player") or "Unknown"
  local realm = GetRealmName() or "Default"
  local ruleset = self:GetCurrentRuleset()
  local faction = UnitFactionGroup("player") or "Neutral"
  local _, class = UnitClass("player")

  GoblinJournalDB.characters = GoblinJournalDB.characters or {}
  GoblinJournalDB.characters[charKey] = {
    name = name,
    realm = realm,
    ruleset = ruleset,
    faction = faction,
    class = class or "WARRIOR",
    lastSeen = time and time() or 0
  }

  GoblinJournalDB.ledger = GoblinJournalDB.ledger or {}
  GoblinJournalDB.ledger[ruleset] = GoblinJournalDB.ledger[ruleset] or {}
  GoblinJournalDB.ledger[ruleset][charKey] = GoblinJournalDB.ledger[ruleset][charKey] or {}

  return charKey, ruleset, faction
end

-------------------------------------------------------------------------------
-- DATABASE INITIALIZATION (100% Flat Integer Partitioned Storage)
-------------------------------------------------------------------------------

local function InitDatabase()
  GoblinJournalDB = GoblinJournalDB or {}
  GoblinJournalDB.settings = GoblinJournalDB.settings or {}
  for k, v in pairs(C.DEFAULT_SETTINGS) do
    if GoblinJournalDB.settings[k] == nil then
      GoblinJournalDB.settings[k] = v
    end
  end

  GoblinJournalDB.characters = GoblinJournalDB.characters or {}
  GoblinJournalDB.ledger = GoblinJournalDB.ledger or {}

  local charKey, ruleset = Engine:RegisterPlayer()

  -- Backward-compatibility migration: migrate legacy flat GoblinJournalDB.days if present
  if GoblinJournalDB.days and next(GoblinJournalDB.days) then
    for dateStr, rec in pairs(GoblinJournalDB.days) do
      if not GoblinJournalDB.ledger[ruleset][charKey][dateStr] then
        GoblinJournalDB.ledger[ruleset][charKey][dateStr] = rec
      end
    end
  end
end

function Engine:GetTodayDate()
  return date("%Y-%m-%d")
end

function Engine:GetTodayMonth()
  return date("%Y-%m")
end

function Engine:GetTodayYear()
  return date("%Y")
end

local function EnsureDayRecord(dateStr)
  local charKey = Engine:GetPlayerCharacterKey()
  local ruleset = Engine:GetCurrentRuleset()

  GoblinJournalDB.ledger = GoblinJournalDB.ledger or {}
  GoblinJournalDB.ledger[ruleset] = GoblinJournalDB.ledger[ruleset] or {}
  GoblinJournalDB.ledger[ruleset][charKey] = GoblinJournalDB.ledger[ruleset][charKey] or {}

  if not GoblinJournalDB.ledger[ruleset][charKey][dateStr] then
    GoblinJournalDB.ledger[ruleset][charKey][dateStr] = {
      -- Income Categories
      in_ah = 0,
      in_loot = 0,
      in_quest = 0,
      in_vendor = 0,
      in_trade = 0,
      in_misc = 0,
      -- Expense Categories
      out_repair = 0,
      out_ah = 0,
      out_vendor = 0,
      out_taxi = 0,
      out_trainer = 0,
      out_trade = 0,
      out_misc = 0
    }
  end
  return GoblinJournalDB.ledger[ruleset][charKey][dateStr]
end

-------------------------------------------------------------------------------
-- TRANSACTION CLASSIFICATION & INCREMENT (Zero Bloat)
-------------------------------------------------------------------------------

local function RecordDelta(delta)
  if delta == 0 then return end

  local today = Engine:GetTodayDate()
  local record = EnsureDayRecord(today)
  local isIncome = (delta > 0)
  local amount = math.abs(delta)

  local now = GetTime()

  if isIncome then
    -- Determine incoming category
    if state.questTurninTriggered then
      record.in_quest = record.in_quest + amount
      state.questTurninTriggered = false
    elseif state.isLootOpen or (now - state.lastLootTime < 2) then
      record.in_loot = record.in_loot + amount
    elseif state.isAuctionOpen then
      record.in_ah = record.in_ah + amount
    elseif state.isMailOpen then
      if state.mailWasFromAH then
        record.in_ah = record.in_ah + amount
      else
        record.in_trade = record.in_trade + amount
      end
    elseif state.isTradeOpen then
      record.in_trade = record.in_trade + amount
    elseif state.isMerchantOpen then
      record.in_vendor = record.in_vendor + amount
    else
      record.in_misc = record.in_misc + amount
    end
  else
    -- Determine outgoing category
    if state.repairTriggered then
      record.out_repair = record.out_repair + amount
      state.repairTriggered = false
    elseif state.isMerchantOpen then
      record.out_vendor = record.out_vendor + amount
    elseif state.isAuctionOpen then
      record.out_ah = record.out_ah + amount
    elseif state.isTaxiOpen then
      record.out_taxi = record.out_taxi + amount
    elseif state.isTrainerOpen then
      record.out_trainer = record.out_trainer + amount
    elseif state.isTradeOpen or state.isMailOpen then
      record.out_trade = record.out_trade + amount
    else
      record.out_misc = record.out_misc + amount
    end
  end

  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
end

-------------------------------------------------------------------------------
-- SCOPED AGGREGATION ENGINE (Character, Alliance, Horde)
-------------------------------------------------------------------------------

function Engine:GetScopedDays(scope, ruleset)
  scope = scope or (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  ruleset = ruleset or self:GetCurrentRuleset()

  local result = {}
  local rulesetLedger = GoblinJournalDB and GoblinJournalDB.ledger and GoblinJournalDB.ledger[ruleset]
  if not rulesetLedger then return result end

  local targetChars = {}
  if scope == "character" then
    local charKey = self:GetPlayerCharacterKey()
    table.insert(targetChars, charKey)
  elseif scope == "alliance" then
    if GoblinJournalDB.characters then
      for cKey, cMeta in pairs(GoblinJournalDB.characters) do
        if cMeta.ruleset == ruleset and cMeta.faction == "Alliance" then
          table.insert(targetChars, cKey)
        end
      end
    end
  elseif scope == "horde" then
    if GoblinJournalDB.characters then
      for cKey, cMeta in pairs(GoblinJournalDB.characters) do
        if cMeta.ruleset == ruleset and cMeta.faction == "Horde" then
          table.insert(targetChars, cKey)
        end
      end
    end
  end

  for _, cKey in ipairs(targetChars) do
    local charDays = rulesetLedger[cKey]
    if charDays then
      for dStr, d in pairs(charDays) do
        if not result[dStr] then
          result[dStr] = {
            in_ah = 0, in_loot = 0, in_quest = 0, in_vendor = 0, in_trade = 0, in_misc = 0,
            out_repair = 0, out_ah = 0, out_vendor = 0, out_taxi = 0, out_trainer = 0, out_trade = 0, out_misc = 0
          }
        end
        local r = result[dStr]
        for _, cat in ipairs(C.INCOME_CATEGORIES) do
          r[cat.id] = (r[cat.id] or 0) + (d[cat.id] or 0)
        end
        for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
          r[cat.id] = (r[cat.id] or 0) + (d[cat.id] or 0)
        end
      end
    end
  end

  return result
end

function Engine:GetDayData(dateStr, scope, ruleset)
  dateStr = dateStr or self:GetTodayDate()
  local daysMap = self:GetScopedDays(scope, ruleset)
  local rec = daysMap[dateStr] or {
    in_ah = 0, in_loot = 0, in_quest = 0, in_vendor = 0, in_trade = 0, in_misc = 0,
    out_repair = 0, out_ah = 0, out_vendor = 0, out_taxi = 0, out_trainer = 0, out_trade = 0, out_misc = 0
  }

  local inTotal = 0
  for _, cat in ipairs(C.INCOME_CATEGORIES) do
    inTotal = inTotal + (rec[cat.id] or 0)
  end

  local outTotal = 0
  for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
    outTotal = outTotal + (rec[cat.id] or 0)
  end

  local calcPct = function(amt, total)
    if total > 0 then
      return math.floor(((amt or 0) / total) * 100 + 0.5)
    end
    return 0
  end

  local inCategories = {}
  for _, cat in ipairs(C.INCOME_CATEGORIES) do
    local amt = rec[cat.id] or 0
    table.insert(inCategories, {
      key = cat.key,
      name = cat.name,
      amount = amt,
      pct = calcPct(amt, inTotal)
    })
  end

  local outCategories = {}
  for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
    local amt = rec[cat.id] or 0
    table.insert(outCategories, {
      key = cat.key,
      name = cat.name,
      amount = amt,
      pct = calcPct(amt, outTotal)
    })
  end

  return {
    date = dateStr,
    month = string.sub(dateStr, 1, 7),
    year = string.sub(dateStr, 1, 4),
    inTotal = inTotal,
    outTotal = outTotal,
    net = inTotal - outTotal,
    inCategories = inCategories,
    outCategories = outCategories
  }
end

function Engine:GetMonthData(monthStr, scope, ruleset)
  monthStr = monthStr or self:GetTodayMonth()
  local daysMap = self:GetScopedDays(scope, ruleset)

  local monthTotals = {
    in_ah = 0, in_loot = 0, in_quest = 0, in_vendor = 0, in_trade = 0, in_misc = 0,
    out_repair = 0, out_ah = 0, out_vendor = 0, out_taxi = 0, out_trainer = 0, out_trade = 0, out_misc = 0
  }
  local daysList = {}

  for dStr, d in pairs(daysMap) do
    if string.sub(dStr, 1, 7) == monthStr then
      local dayIn = 0
      for _, cat in ipairs(C.INCOME_CATEGORIES) do
        local amt = d[cat.id] or 0
        monthTotals[cat.id] = (monthTotals[cat.id] or 0) + amt
        dayIn = dayIn + amt
      end

      local dayOut = 0
      for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
        local amt = d[cat.id] or 0
        monthTotals[cat.id] = (monthTotals[cat.id] or 0) + amt
        dayOut = dayOut + amt
      end

      -- Only include days that have actual transaction activity
      if dayIn > 0 or dayOut > 0 then
        table.insert(daysList, {
          date = dStr,
          inTotal = dayIn,
          outTotal = dayOut,
          net = dayIn - dayOut
        })
      end
    end
  end

  -- Sort descending (newest day at top)
  table.sort(daysList, function(a, b) return a.date > b.date end)

  local inTotal = 0
  for _, cat in ipairs(C.INCOME_CATEGORIES) do
    inTotal = inTotal + (monthTotals[cat.id] or 0)
  end

  local outTotal = 0
  for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
    outTotal = outTotal + (monthTotals[cat.id] or 0)
  end

  local calcPct = function(amt, total)
    if total > 0 then
      return math.floor(((amt or 0) / total) * 100 + 0.5)
    end
    return 0
  end

  local inCategories = {}
  for _, cat in ipairs(C.INCOME_CATEGORIES) do
    local amt = monthTotals[cat.id] or 0
    table.insert(inCategories, {
      key = cat.key,
      name = cat.name,
      amount = amt,
      pct = calcPct(amt, inTotal)
    })
  end

  local outCategories = {}
  for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
    local amt = monthTotals[cat.id] or 0
    table.insert(outCategories, {
      key = cat.key,
      name = cat.name,
      amount = amt,
      pct = calcPct(amt, outTotal)
    })
  end

  return {
    month = monthStr,
    inTotal = inTotal,
    outTotal = outTotal,
    net = inTotal - outTotal,
    inCategories = inCategories,
    outCategories = outCategories,
    days = daysList
  }
end

function Engine:GetYearData(yearStr, scope, ruleset)
  yearStr = yearStr or self:GetTodayYear()
  local daysMap = self:GetScopedDays(scope, ruleset)
  local monthKeysMap = {}

  for dStr, d in pairs(daysMap) do
    if string.sub(dStr, 1, 4) == yearStr then
      local dayIn = 0
      for _, cat in ipairs(C.INCOME_CATEGORIES) do
        dayIn = dayIn + (d[cat.id] or 0)
      end
      local dayOut = 0
      for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
        dayOut = dayOut + (d[cat.id] or 0)
      end
      if dayIn > 0 or dayOut > 0 then
        local mKey = string.sub(dStr, 1, 7)
        monthKeysMap[mKey] = true
      end
    end
  end

  local sortedMonths = {}
  for mKey in pairs(monthKeysMap) do
    table.insert(sortedMonths, mKey)
  end
  table.sort(sortedMonths, function(a, b) return a > b end)

  local monthsList = {}
  for _, mKey in ipairs(sortedMonths) do
    local mData = self:GetMonthData(mKey, scope, ruleset)
    local monthName = UILib:FormatMonthString(mKey)

    table.insert(monthsList, {
      key = mKey,
      name = monthName,
      inTotal = mData.inTotal,
      outTotal = mData.outTotal,
      net = mData.net
    })
  end

  return monthsList
end

function Engine:ResetDay(dateStr)
  dateStr = dateStr or self:GetTodayDate()
  local charKey = self:GetPlayerCharacterKey()
  local ruleset = self:GetCurrentRuleset()
  if GoblinJournalDB and GoblinJournalDB.ledger and GoblinJournalDB.ledger[ruleset] and GoblinJournalDB.ledger[ruleset][charKey] then
    GoblinJournalDB.ledger[ruleset][charKey][dateStr] = nil
  end
  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
end

function Engine:ResetAll()
  local scope = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  local ruleset = self:GetCurrentRuleset()
  local charKey = self:GetPlayerCharacterKey()

  if scope == "character" then
    if GoblinJournalDB and GoblinJournalDB.ledger and GoblinJournalDB.ledger[ruleset] then
      GoblinJournalDB.ledger[ruleset][charKey] = {}
    end
  elseif scope == "alliance" then
    if GoblinJournalDB and GoblinJournalDB.characters and GoblinJournalDB.ledger and GoblinJournalDB.ledger[ruleset] then
      for cKey, cMeta in pairs(GoblinJournalDB.characters) do
        if cMeta.ruleset == ruleset and cMeta.faction == "Alliance" then
          GoblinJournalDB.ledger[ruleset][cKey] = {}
        end
      end
    end
  elseif scope == "horde" then
    if GoblinJournalDB and GoblinJournalDB.characters and GoblinJournalDB.ledger and GoblinJournalDB.ledger[ruleset] then
      for cKey, cMeta in pairs(GoblinJournalDB.characters) do
        if cMeta.ruleset == ruleset and cMeta.faction == "Horde" then
          GoblinJournalDB.ledger[ruleset][cKey] = {}
        end
      end
    end
  end

  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
end

-------------------------------------------------------------------------------
-- EVENT LISTENER FRAME
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("CHAT_MSG_MONEY")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("TAXIMAP_OPENED")
eventFrame:RegisterEvent("TAXIMAP_CLOSED")
eventFrame:RegisterEvent("TRAINER_SHOW")
eventFrame:RegisterEvent("TRAINER_CLOSED")
eventFrame:RegisterEvent("TRADE_SHOW")
eventFrame:RegisterEvent("TRADE_CLOSED")
eventFrame:RegisterEvent("MAIL_SHOW")
eventFrame:RegisterEvent("MAIL_CLOSED")
eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local loadedName = ...
    if loadedName == addonName then
      InitDatabase()
      state.lastMoney = GetMoney()

      local function SafeHook(funcName, hookFunc)
        if hooksecurefunc then
          hooksecurefunc(funcName, hookFunc)
        elseif _G[funcName] then
          local orig = _G[funcName]
          _G[funcName] = function(...)
            hookFunc(...)
            return orig(...)
          end
        end
      end

      -- Hook Repair All Items
      SafeHook("RepairAllItems", function()
        state.repairTriggered = true
      end)

      -- Hook SendMail
      SafeHook("SendMail", function()
        state.isMailOpen = true
      end)
    end

  elseif event == "PLAYER_LOGIN" then
    Engine:RegisterPlayer()
    state.lastMoney = GetMoney()

  elseif event == "PLAYER_MONEY" then
    local current = GetMoney()
    local delta = current - state.lastMoney
    state.lastMoney = current
    RecordDelta(delta)

  elseif event == "MERCHANT_SHOW" then
    state.isMerchantOpen = true
    state.repairTriggered = false

  elseif event == "MERCHANT_CLOSED" then
    state.isMerchantOpen = false
    state.repairTriggered = false

  elseif event == "AUCTION_HOUSE_SHOW" then
    state.isAuctionOpen = true

  elseif event == "AUCTION_HOUSE_CLOSED" then
    state.isAuctionOpen = false

  elseif event == "LOOT_OPENED" then
    state.isLootOpen = true

  elseif event == "LOOT_CLOSED" then
    state.isLootOpen = false

  elseif event == "CHAT_MSG_MONEY" then
    state.lastLootTime = GetTime()

  elseif event == "QUEST_TURNED_IN" then
    state.questTurninTriggered = true

  elseif event == "TAXIMAP_OPENED" then
    state.isTaxiOpen = true

  elseif event == "TAXIMAP_CLOSED" then
    state.isTaxiOpen = false

  elseif event == "TRAINER_SHOW" then
    state.isTrainerOpen = true

  elseif event == "TRAINER_CLOSED" then
    state.isTrainerOpen = false

  elseif event == "TRADE_SHOW" then
    state.isTradeOpen = true

  elseif event == "TRADE_CLOSED" then
    state.isTradeOpen = false

  elseif event == "MAIL_SHOW" then
    state.isMailOpen = true
    state.mailWasFromAH = false

  elseif event == "MAIL_CLOSED" then
    state.isMailOpen = false
    state.mailWasFromAH = false

  elseif event == "MAIL_INBOX_UPDATE" then
    -- Inspect selected mail item for Auction House tag
    if InboxItemCanDelete and GetInboxHeaderInfo then
      local numItems = GetInboxNumItems and GetInboxNumItems() or 0
      for i = 1, numItems do
        local _, _, sender = GetInboxHeaderInfo(i)
        if sender and (string.find(string.lower(sender), "auction") or string.find(sender, "AH")) then
          state.mailWasFromAH = true
          break
        end
      end
    end
  end
end)
