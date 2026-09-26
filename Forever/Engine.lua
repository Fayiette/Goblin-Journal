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
  mailWasFromAH = false,
  -- Session tracking state
  sessionActive = false,
  sessionStartTime = 0,
  sessionStartDate = "",
  sessionStartClock = "",
  sessionRecord = nil,
  sessionTimeline = nil
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
  GoblinJournalDB.sessions = GoblinJournalDB.sessions or {}
  GoblinJournalDB.wealthGoals = GoblinJournalDB.wealthGoals or {}

  local charKey, ruleset = Engine:RegisterPlayer()

  GoblinJournalDB.sessions[ruleset] = GoblinJournalDB.sessions[ruleset] or {}
  GoblinJournalDB.sessions[ruleset][charKey] = GoblinJournalDB.sessions[ruleset][charKey] or {}
  GoblinJournalDB.wealthGoals[ruleset] = GoblinJournalDB.wealthGoals[ruleset] or {}

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
      out_misc = 0,
      -- Zone-level accounting
      zones = {}
    }
  else
    GoblinJournalDB.ledger[ruleset][charKey][dateStr].zones = GoblinJournalDB.ledger[ruleset][charKey][dateStr].zones or {}
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
  local catId

  if isIncome then
    -- Determine incoming category
    if state.questTurninTriggered then
      catId = "in_quest"
      state.questTurninTriggered = false
    elseif state.isLootOpen or (now - state.lastLootTime < 2) then
      catId = "in_loot"
    elseif state.isAuctionOpen then
      catId = "in_ah"
    elseif state.isMailOpen then
      if state.mailWasFromAH then
        catId = "in_ah"
      else
        catId = "in_trade"
      end
    elseif state.isTradeOpen then
      catId = "in_trade"
    elseif state.isMerchantOpen then
      catId = "in_vendor"
    else
      catId = "in_misc"
    end
  else
    -- Determine outgoing category
    if state.repairTriggered then
      catId = "out_repair"
      state.repairTriggered = false
    elseif state.isMerchantOpen then
      catId = "out_vendor"
    elseif state.isAuctionOpen then
      catId = "out_ah"
    elseif state.isTaxiOpen then
      catId = "out_taxi"
    elseif state.isTrainerOpen then
      catId = "out_trainer"
    elseif state.isTradeOpen or state.isMailOpen then
      catId = "out_trade"
    else
      catId = "out_misc"
    end
  end

  record[catId] = (record[catId] or 0) + amount

  -- Zone attribution
  local currentZone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "Unknown"
  if not currentZone or currentZone == "" then currentZone = "Unknown" end
  record.zones = record.zones or {}
  record.zones[currentZone] = record.zones[currentZone] or { inTotal = 0, outTotal = 0 }
  if isIncome then
    record.zones[currentZone].inTotal = (record.zones[currentZone].inTotal or 0) + amount
  else
    record.zones[currentZone].outTotal = (record.zones[currentZone].outTotal or 0) + amount
  end
  record.zones[currentZone][catId] = (record.zones[currentZone][catId] or 0) + amount

  -- Dual-write to active session if running
  if state.sessionActive and state.sessionRecord then
    state.sessionRecord[catId] = (state.sessionRecord[catId] or 0) + amount
    if state.sessionTimeline then
      local relTime = math.max(0, math.floor(now - state.sessionStartTime))
      table.insert(state.sessionTimeline, {
        t = relTime,
        inc = (isIncome and amount or 0),
        exp = (not isIncome and amount or 0)
      })
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
        if d.zones then
          r.zones = r.zones or {}
          for zName, zData in pairs(d.zones) do
            r.zones[zName] = r.zones[zName] or { inTotal = 0, outTotal = 0 }
            r.zones[zName].inTotal = (r.zones[zName].inTotal or 0) + (zData.inTotal or 0)
            r.zones[zName].outTotal = (r.zones[zName].outTotal or 0) + (zData.outTotal or 0)
            for _, cat in ipairs(C.INCOME_CATEGORIES) do
              r.zones[zName][cat.id] = (r.zones[zName][cat.id] or 0) + (zData[cat.id] or 0)
            end
            for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
              r.zones[zName][cat.id] = (r.zones[zName][cat.id] or 0) + (zData[cat.id] or 0)
            end
          end
        end
      end
    end
  end

  return result
end

function Engine:GetResetWeekRange(timestamp)
  timestamp = timestamp or time()
  local epochOffset = C.WOW_RESET_EPOCH_OFFSET or 486000
  local cycleSeconds = C.WOW_RESET_CYCLE_SECONDS or 604800
  local cycleStart = timestamp - ((timestamp - epochOffset) % cycleSeconds)
  local cycleEnd = cycleStart + cycleSeconds - 1
  local weekKey = date("%Y-%m-%d", cycleStart)
  local label = date("%b %d, %Y", cycleStart) .. " - " .. date("%b %d, %Y", cycleEnd)
  return weekKey, label, cycleStart, cycleEnd
end

function Engine:GetDayData(dateStr, scope, ruleset, zoneFilter)
  dateStr = dateStr or self:GetTodayDate()
  local daysMap = self:GetScopedDays(scope, ruleset)
  local rec = daysMap[dateStr] or {
    in_ah = 0, in_loot = 0, in_quest = 0, in_vendor = 0, in_trade = 0, in_misc = 0,
    out_repair = 0, out_ah = 0, out_vendor = 0, out_taxi = 0, out_trainer = 0, out_trade = 0, out_misc = 0
  }

  local src = rec
  if zoneFilter and zoneFilter ~= "All" then
    src = (rec.zones and rec.zones[zoneFilter]) or {}
  end

  local inTotal = 0
  for _, cat in ipairs(C.INCOME_CATEGORIES) do
    inTotal = inTotal + (src[cat.id] or 0)
  end

  local outTotal = 0
  for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
    outTotal = outTotal + (src[cat.id] or 0)
  end

  local calcPct = function(amt, total)
    if total > 0 then
      return math.floor(((amt or 0) / total) * 100 + 0.5)
    end
    return 0
  end

  local inCategories = {}
  for _, cat in ipairs(C.INCOME_CATEGORIES) do
    local amt = src[cat.id] or 0
    table.insert(inCategories, {
      key = cat.key,
      name = cat.name,
      amount = amt,
      pct = calcPct(amt, inTotal)
    })
  end

  local outCategories = {}
  for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
    local amt = src[cat.id] or 0
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

function Engine:GetWeekData(weekKey, scope, ruleset, zoneFilter)
  local y, m, d = string.match(weekKey or "", "^(%d+)-(%d+)-(%d+)$")
  local startTime
  if y and m and d then
    startTime = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 15, min = 0, sec = 0 })
  else
    local _, _, cStart = self:GetResetWeekRange()
    startTime = cStart
    weekKey = date("%Y-%m-%d", startTime)
  end

  local _, label = self:GetResetWeekRange(startTime)
  local daysMap = self:GetScopedDays(scope, ruleset)

  local weekTotals = {
    in_ah = 0, in_loot = 0, in_quest = 0, in_vendor = 0, in_trade = 0, in_misc = 0,
    out_repair = 0, out_ah = 0, out_vendor = 0, out_taxi = 0, out_trainer = 0, out_trade = 0, out_misc = 0
  }
  local daysList = {}

  for dayIdx = 0, 6 do
    local dayTime = startTime + (dayIdx * 86400)
    local dayStr = date("%Y-%m-%d", dayTime)
    local dayRec = daysMap[dayStr]
    if dayRec then
      local src = dayRec
      if zoneFilter and zoneFilter ~= "All" then
        src = (dayRec.zones and dayRec.zones[zoneFilter]) or {}
      end

      local dayIn = 0
      for _, cat in ipairs(C.INCOME_CATEGORIES) do
        local amt = src[cat.id] or 0
        weekTotals[cat.id] = (weekTotals[cat.id] or 0) + amt
        dayIn = dayIn + amt
      end

      local dayOut = 0
      for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
        local amt = src[cat.id] or 0
        weekTotals[cat.id] = (weekTotals[cat.id] or 0) + amt
        dayOut = dayOut + amt
      end

      if dayIn > 0 or dayOut > 0 then
        table.insert(daysList, {
          date = dayStr,
          inTotal = dayIn,
          outTotal = dayOut,
          net = dayIn - dayOut
        })
      end
    end
  end

  table.sort(daysList, function(a, b) return a.date > b.date end)

  local inTotal = 0
  for _, cat in ipairs(C.INCOME_CATEGORIES) do
    inTotal = inTotal + (weekTotals[cat.id] or 0)
  end

  local outTotal = 0
  for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
    outTotal = outTotal + (weekTotals[cat.id] or 0)
  end

  local calcPct = function(amt, total)
    if total > 0 then
      return math.floor(((amt or 0) / total) * 100 + 0.5)
    end
    return 0
  end

  local inCategories = {}
  for _, cat in ipairs(C.INCOME_CATEGORIES) do
    local amt = weekTotals[cat.id] or 0
    table.insert(inCategories, {
      key = cat.key,
      name = cat.name,
      amount = amt,
      pct = calcPct(amt, inTotal)
    })
  end

  local outCategories = {}
  for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
    local amt = weekTotals[cat.id] or 0
    table.insert(outCategories, {
      key = cat.key,
      name = cat.name,
      amount = amt,
      pct = calcPct(amt, outTotal)
    })
  end

  return {
    weekKey = weekKey,
    label = label,
    inTotal = inTotal,
    outTotal = outTotal,
    net = inTotal - outTotal,
    inCategories = inCategories,
    outCategories = outCategories,
    days = daysList
  }
end

function Engine:GetMonthData(monthStr, scope, ruleset, zoneFilter)
  monthStr = monthStr or self:GetTodayMonth()
  local daysMap = self:GetScopedDays(scope, ruleset)

  local monthTotals = {
    in_ah = 0, in_loot = 0, in_quest = 0, in_vendor = 0, in_trade = 0, in_misc = 0,
    out_repair = 0, out_ah = 0, out_vendor = 0, out_taxi = 0, out_trainer = 0, out_trade = 0, out_misc = 0
  }
  local daysList = {}

  for dStr, d in pairs(daysMap) do
    if string.sub(dStr, 1, 7) == monthStr then
      local src = d
      if zoneFilter and zoneFilter ~= "All" then
        src = (d.zones and d.zones[zoneFilter]) or {}
      end

      local dayIn = 0
      for _, cat in ipairs(C.INCOME_CATEGORIES) do
        local amt = src[cat.id] or 0
        monthTotals[cat.id] = (monthTotals[cat.id] or 0) + amt
        dayIn = dayIn + amt
      end

      local dayOut = 0
      for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
        local amt = src[cat.id] or 0
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

function Engine:GetAvailableZones(viewMode, dateOrWeekOrMonth, scope, ruleset)
  local daysMap = self:GetScopedDays(scope, ruleset)
  local zoneMap = {}

  if viewMode == "day" then
    local d = daysMap[dateOrWeekOrMonth or self:GetTodayDate()]
    if d and d.zones then
      for zName, zData in pairs(d.zones) do
        if ((zData.inTotal or 0) > 0) or ((zData.outTotal or 0) > 0) then
          zoneMap[zName] = true
        end
      end
    end
  elseif viewMode == "week" then
    local y, m, d = string.match(dateOrWeekOrMonth or "", "^(%d+)-(%d+)-(%d+)$")
    local startTime
    if y and m and d then
      startTime = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 15, min = 0, sec = 0 })
    else
      local _, _, cStart = self:GetResetWeekRange()
      startTime = cStart
    end
    for dayIdx = 0, 6 do
      local dayStr = date("%Y-%m-%d", startTime + (dayIdx * 86400))
      local dayRec = daysMap[dayStr]
      if dayRec and dayRec.zones then
        for zName, zData in pairs(dayRec.zones) do
          if ((zData.inTotal or 0) > 0) or ((zData.outTotal or 0) > 0) then
            zoneMap[zName] = true
          end
        end
      end
    end
  elseif viewMode == "month" then
    local monthPrefix = string.sub(dateOrWeekOrMonth or self:GetTodayMonth(), 1, 7)
    for dStr, d in pairs(daysMap) do
      if string.sub(dStr, 1, 7) == monthPrefix and d.zones then
        for zName, zData in pairs(d.zones) do
          if ((zData.inTotal or 0) > 0) or ((zData.outTotal or 0) > 0) then
            zoneMap[zName] = true
          end
        end
      end
    end
  end

  local sortedZones = {}
  for zName in pairs(zoneMap) do
    table.insert(sortedZones, zName)
  end
  table.sort(sortedZones)
  table.insert(sortedZones, 1, "All")
  return sortedZones
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

local function GetTargetCharsForScope(scope, ruleset)
  scope = scope or (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  ruleset = ruleset or Engine:GetCurrentRuleset()
  local targetChars = {}

  if scope == "character" then
    table.insert(targetChars, Engine:GetPlayerCharacterKey())
  elseif scope == "alliance" then
    if GoblinJournalDB and GoblinJournalDB.characters then
      for cKey, cMeta in pairs(GoblinJournalDB.characters) do
        if cMeta.ruleset == ruleset and cMeta.faction == "Alliance" then
          table.insert(targetChars, cKey)
        end
      end
    end
  elseif scope == "horde" then
    if GoblinJournalDB and GoblinJournalDB.characters then
      for cKey, cMeta in pairs(GoblinJournalDB.characters) do
        if cMeta.ruleset == ruleset and cMeta.faction == "Horde" then
          table.insert(targetChars, cKey)
        end
      end
    end
  else
    if GoblinJournalDB and GoblinJournalDB.characters then
      for cKey, cMeta in pairs(GoblinJournalDB.characters) do
        if cMeta.ruleset == ruleset then
          table.insert(targetChars, cKey)
        end
      end
    end
    if #targetChars == 0 then
      table.insert(targetChars, Engine:GetPlayerCharacterKey())
    end
  end
  return targetChars
end

function Engine:ResetDay(dateStr, scope, ruleset)
  dateStr = dateStr or self:GetTodayDate()
  ruleset = ruleset or self:GetCurrentRuleset()
  local targetChars = GetTargetCharsForScope(scope, ruleset)

  if GoblinJournalDB and GoblinJournalDB.ledger and GoblinJournalDB.ledger[ruleset] then
    for _, cKey in ipairs(targetChars) do
      if GoblinJournalDB.ledger[ruleset][cKey] then
        GoblinJournalDB.ledger[ruleset][cKey][dateStr] = nil
      end
    end
  end

  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
  return true
end

function Engine:ResetWeek(weekKey, scope, ruleset)
  ruleset = ruleset or self:GetCurrentRuleset()
  local y, m, d = string.match(weekKey or "", "^(%d+)-(%d+)-(%d+)$")
  local startTime
  if y and m and d then
    startTime = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 15, min = 0, sec = 0 })
  else
    local _, _, cStart = self:GetResetWeekRange()
    startTime = cStart
  end

  local targetChars = GetTargetCharsForScope(scope, ruleset)
  if GoblinJournalDB and GoblinJournalDB.ledger and GoblinJournalDB.ledger[ruleset] then
    for _, cKey in ipairs(targetChars) do
      if GoblinJournalDB.ledger[ruleset][cKey] then
        for dayIdx = 0, 6 do
          local dStr = date("%Y-%m-%d", startTime + (dayIdx * 86400))
          GoblinJournalDB.ledger[ruleset][cKey][dStr] = nil
        end
      end
    end
  end

  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
  return true
end

function Engine:ResetMonth(monthStr, scope, ruleset)
  monthStr = monthStr or self:GetTodayMonth()
  ruleset = ruleset or self:GetCurrentRuleset()
  local targetChars = GetTargetCharsForScope(scope, ruleset)

  if GoblinJournalDB and GoblinJournalDB.ledger and GoblinJournalDB.ledger[ruleset] then
    for _, cKey in ipairs(targetChars) do
      local charLedger = GoblinJournalDB.ledger[ruleset][cKey]
      if charLedger then
        local toDelete = {}
        for dStr in pairs(charLedger) do
          if string.sub(dStr, 1, 7) == monthStr then
            table.insert(toDelete, dStr)
          end
        end
        for _, dStr in ipairs(toDelete) do
          charLedger[dStr] = nil
        end
      end
    end
  end

  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
  return true
end

function Engine:ResetSessions(scope, ruleset)
  ruleset = ruleset or self:GetCurrentRuleset()
  local targetChars = GetTargetCharsForScope(scope, ruleset)

  if GoblinJournalDB and GoblinJournalDB.sessions and GoblinJournalDB.sessions[ruleset] then
    for _, cKey in ipairs(targetChars) do
      GoblinJournalDB.sessions[ruleset][cKey] = {}
    end
  end

  if state.sessionActive then
    state.sessionActive = false
    state.sessionRecord = nil
    state.sessionTimeline = nil
  end

  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
  return true
end

function Engine:ResetWealthGoals(scope, ruleset)
  ruleset = ruleset or self:GetCurrentRuleset()
  scope = scope or (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  local playerKey = self:GetPlayerCharacterKey()

  if GoblinJournalDB and GoblinJournalDB.wealthGoals and GoblinJournalDB.wealthGoals[ruleset] then
    if scope == "character" then
      local remaining = {}
      for _, g in ipairs(GoblinJournalDB.wealthGoals[ruleset]) do
        if g.charKey ~= playerKey then
          table.insert(remaining, g)
        end
      end
      GoblinJournalDB.wealthGoals[ruleset] = remaining
    elseif scope == "alliance" then
      local remaining = {}
      for _, g in ipairs(GoblinJournalDB.wealthGoals[ruleset]) do
        if string.lower(g.faction or "") ~= "alliance" then
          table.insert(remaining, g)
        end
      end
      GoblinJournalDB.wealthGoals[ruleset] = remaining
    elseif scope == "horde" then
      local remaining = {}
      for _, g in ipairs(GoblinJournalDB.wealthGoals[ruleset]) do
        if string.lower(g.faction or "") ~= "horde" then
          table.insert(remaining, g)
        end
      end
      GoblinJournalDB.wealthGoals[ruleset] = remaining
    else
      GoblinJournalDB.wealthGoals[ruleset] = {}
    end
  end

  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
  return true
end

function Engine:ResetAll(scope, ruleset)
  ruleset = ruleset or self:GetCurrentRuleset()
  local targetChars = GetTargetCharsForScope(scope, ruleset)

  if GoblinJournalDB and GoblinJournalDB.ledger and GoblinJournalDB.ledger[ruleset] then
    for _, cKey in ipairs(targetChars) do
      GoblinJournalDB.ledger[ruleset][cKey] = {}
    end
  end

  if GoblinJournalDB and GoblinJournalDB.sessions and GoblinJournalDB.sessions[ruleset] then
    for _, cKey in ipairs(targetChars) do
      GoblinJournalDB.sessions[ruleset][cKey] = {}
    end
  end

  if state.sessionActive then
    state.sessionActive = false
    state.sessionRecord = nil
    state.sessionTimeline = nil
  end

  self:ResetWealthGoals(scope, ruleset)

  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
  return true
end

-------------------------------------------------------------------------------
-- SESSION TRACKING & RETENTION ENGINE
-------------------------------------------------------------------------------

function Engine:IsSessionActive()
  return state.sessionActive == true
end

function Engine:GetSessionElapsed()
  if not state.sessionActive then return 0 end
  return math.max(0, math.floor(GetTime() - state.sessionStartTime))
end

function Engine:GetSessionStartTimeFormatted()
  return state.sessionStartClock or ""
end

function Engine:GetActiveSessionRecord()
  return state.sessionRecord
end

function Engine:StartSession()
  if state.sessionActive then return false end

  state.sessionActive = true
  state.sessionStartTime = GetTime()
  state.sessionStartDate = self:GetTodayDate()
  state.sessionStartClock = date("%H:%M")
  state.sessionStartZone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "Unknown"
  if not state.sessionStartZone or state.sessionStartZone == "" then state.sessionStartZone = "Unknown" end
  state.sessionRecord = {
    in_ah = 0, in_loot = 0, in_quest = 0, in_vendor = 0, in_trade = 0, in_misc = 0,
    out_repair = 0, out_ah = 0, out_vendor = 0, out_taxi = 0, out_trainer = 0, out_trade = 0, out_misc = 0
  }
  state.sessionTimeline = {}

  DEFAULT_CHAT_FRAME:AddMessage("|cFFCFA84AGoblin Journal:|r |cFF00FF00Session Timer started.|r", 1, 1, 1)

  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
  return true
end

function Engine:StopSession()
  if not state.sessionActive then return false end

  state.sessionActive = false
  local endClock = date("%H:%M")
  local durationSecs = math.max(1, math.floor(GetTime() - state.sessionStartTime))
  local charKey = self:GetPlayerCharacterKey()
  local ruleset = self:GetCurrentRuleset()
  local charName = UnitName("player") or "Unknown"

  GoblinJournalDB.sessions = GoblinJournalDB.sessions or {}
  GoblinJournalDB.sessions[ruleset] = GoblinJournalDB.sessions[ruleset] or {}
  GoblinJournalDB.sessions[ruleset][charKey] = GoblinJournalDB.sessions[ruleset][charKey] or {}

  local sRec = state.sessionRecord or {}
  local sessionObj = {
    charName = charName,
    charKey = charKey,
    ruleset = ruleset,
    zone = state.sessionStartZone or "Unknown",
    date = state.sessionStartDate,
    timeStart = state.sessionStartClock,
    timeEnd = endClock,
    duration = durationSecs,
    timeline = state.sessionTimeline or {},
    in_ah = sRec.in_ah or 0,
    in_loot = sRec.in_loot or 0,
    in_quest = sRec.in_quest or 0,
    in_vendor = sRec.in_vendor or 0,
    in_trade = sRec.in_trade or 0,
    in_misc = sRec.in_misc or 0,
    out_repair = sRec.out_repair or 0,
    out_ah = sRec.out_ah or 0,
    out_vendor = sRec.out_vendor or 0,
    out_taxi = sRec.out_taxi or 0,
    out_trainer = sRec.out_trainer or 0,
    out_trade = sRec.out_trade or 0,
    out_misc = sRec.out_misc or 0
  }

  table.insert(GoblinJournalDB.sessions[ruleset][charKey], 1, sessionObj)
  self:EnforceSessionCap(ruleset, charKey)

  state.sessionRecord = nil
  state.sessionTimeline = nil

  DEFAULT_CHAT_FRAME:AddMessage("|cFFCFA84AGoblin Journal:|r |cFFFF9900Session Timer stopped and recorded.|r", 1, 1, 1)

  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
  return sessionObj
end

function Engine:GetSessionCap()
  if GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.sessionCap ~= nil then
    return GoblinJournalDB.settings.sessionCap
  end
  return C.DEFAULT_SESSION_CAP or 50
end

function Engine:SetSessionCap(newCap)
  GoblinJournalDB.settings = GoblinJournalDB.settings or {}
  GoblinJournalDB.settings.sessionCap = newCap
  self:EnforceSessionCap()
  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
end

function Engine:EnforceSessionCap(targetRuleset, targetCharKey)
  local cap = self:GetSessionCap()
  if cap <= 0 then return end -- 0 means Unlimited

  local sessionsDB = GoblinJournalDB and GoblinJournalDB.sessions
  if not sessionsDB then return end

  if targetRuleset and targetCharKey then
    local list = sessionsDB[targetRuleset] and sessionsDB[targetRuleset][targetCharKey]
    if list then
      while #list > cap do
        table.remove(list)
      end
    end
  else
    for rSet, charMap in pairs(sessionsDB) do
      for cKey, list in pairs(charMap) do
        while #list > cap do
          table.remove(list)
        end
      end
    end
  end
end

function Engine:GetScopedSessions(scope, ruleset)
  scope = scope or (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  ruleset = ruleset or self:GetCurrentRuleset()

  local result = {}
  local sessionsDB = GoblinJournalDB and GoblinJournalDB.sessions and GoblinJournalDB.sessions[ruleset]
  if not sessionsDB then return result end

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
    local list = sessionsDB[cKey]
    if list then
      for _, sessionEntry in ipairs(list) do
        table.insert(result, sessionEntry)
      end
    end
  end

  table.sort(result, function(a, b)
    if (a.date or "") ~= (b.date or "") then
      return (a.date or "") > (b.date or "")
    end
    return (a.timeStart or "") > (b.timeStart or "")
  end)

  return result
end

function Engine:GetSessionData(s)
  if not s then return nil end

  local inTotal = 0
  for _, cat in ipairs(C.INCOME_CATEGORIES) do
    inTotal = inTotal + (s[cat.id] or 0)
  end

  local outTotal = 0
  for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
    outTotal = outTotal + (s[cat.id] or 0)
  end

  local calcPct = function(amt, total)
    if total > 0 then
      return math.floor(((amt or 0) / total) * 100 + 0.5)
    end
    return 0
  end

  local inCategories = {}
  for _, cat in ipairs(C.INCOME_CATEGORIES) do
    local amt = s[cat.id] or 0
    table.insert(inCategories, {
      key = cat.key,
      name = cat.name,
      amount = amt,
      pct = calcPct(amt, inTotal)
    })
  end

  local outCategories = {}
  for _, cat in ipairs(C.EXPENSE_CATEGORIES) do
    local amt = s[cat.id] or 0
    table.insert(outCategories, {
      key = cat.key,
      name = cat.name,
      amount = amt,
      pct = calcPct(amt, outTotal)
    })
  end

  local net = inTotal - outTotal
  local durationSecs = s.duration or 0
  local copperPerHour = 0
  if durationSecs > 0 then
    copperPerHour = math.floor((net / durationSecs) * 3600 + 0.5)
  end

  return {
    charName = s.charName or "Unknown",
    zone = s.zone or "Unknown",
    date = s.date or "",
    timeStart = s.timeStart or "",
    timeEnd = s.timeEnd or "",
    duration = durationSecs,
    timeline = s.timeline or {},
    inTotal = inTotal,
    outTotal = outTotal,
    net = net,
    copperPerHour = copperPerHour,
    inCategories = inCategories,
    outCategories = outCategories
  }
end

function Engine:FormatDuration(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  local h = math.floor(seconds / 3600)
  local m = math.floor((seconds % 3600) / 60)
  local s = seconds % 60
  return string.format("%dh %02dm %02ds", h, m, s)
end

function Engine:FormatElapsed(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  local h = math.floor(seconds / 3600)
  local m = math.floor((seconds % 3600) / 60)
  local s = seconds % 60
  return string.format("%02d:%02d:%02d", h, m, s)
end

-------------------------------------------------------------------------------
-- FINANCIAL LEDGER EXPORT ENGINE (RFC 4180 CSV & XML SPREADSHEET 2003)
-------------------------------------------------------------------------------

local function EscapeXml(str)
  if not str then return "" end
  str = tostring(str)
  str = string.gsub(str, "&", "&amp;")
  str = string.gsub(str, "<", "&lt;")
  str = string.gsub(str, ">", "&gt;")
  str = string.gsub(str, '"', "&quot;")
  str = string.gsub(str, "'", "&apos;")
  return str
end

function Engine:GenerateExportCSV(scope, ruleset)
  scope = scope or (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  ruleset = ruleset or self:GetCurrentRuleset()
  local charName = UnitName("player") or "Unknown"

  local headers = {
    '"Date"',
    '"Character"',
    '"Ruleset"',
    '"Zone"',
    '"Incoming Copper"',
    '"Outgoing Copper"',
    '"Net Copper"',
    '"Net Gold Decimal"',
    '"AH In"',
    '"Loot In"',
    '"Quest In"',
    '"Vendor In"',
    '"Trade In"',
    '"Misc In"',
    '"Repair Out"',
    '"AH Out"',
    '"Vendor Out"',
    '"Taxi Out"',
    '"Trainer Out"',
    '"Trade Out"',
    '"Misc Out"'
  }

  local lines = { table.concat(headers, ",") }
  local daysMap = self:GetScopedDays(scope, ruleset)

  local sortedDates = {}
  for dStr in pairs(daysMap) do
    table.insert(sortedDates, dStr)
  end
  table.sort(sortedDates, function(a, b) return a > b end)

  for _, dStr in ipairs(sortedDates) do
    local d = daysMap[dStr]
    local inTotal = (d.in_ah or 0) + (d.in_loot or 0) + (d.in_quest or 0) + (d.in_vendor or 0) + (d.in_trade or 0) + (d.in_misc or 0)
    local outTotal = (d.out_repair or 0) + (d.out_ah or 0) + (d.out_vendor or 0) + (d.out_taxi or 0) + (d.out_trainer or 0) + (d.out_trade or 0) + (d.out_misc or 0)
    local net = inTotal - outTotal
    local netGoldDecimal = string.format("%.4f", net / 10000)

    local rowValues = {
      string.format('"%s"', dStr),
      string.format('"%s"', charName),
      string.format('"%s"', ruleset),
      '"All"',
      inTotal,
      outTotal,
      net,
      netGoldDecimal,
      d.in_ah or 0,
      d.in_loot or 0,
      d.in_quest or 0,
      d.in_vendor or 0,
      d.in_trade or 0,
      d.in_misc or 0,
      d.out_repair or 0,
      d.out_ah or 0,
      d.out_vendor or 0,
      d.out_taxi or 0,
      d.out_trainer or 0,
      d.out_trade or 0,
      d.out_misc or 0
    }
    table.insert(lines, table.concat(rowValues, ","))
  end

  return table.concat(lines, "\r\n")
end

function Engine:GenerateExportXML(scope, ruleset)
  scope = scope or (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  ruleset = ruleset or self:GetCurrentRuleset()
  local charName = UnitName("player") or "Unknown"

  local headers = {
    "Date", "Character", "Ruleset", "Zone",
    "Incoming Copper", "Outgoing Copper", "Net Copper", "Net Gold Decimal",
    "AH In", "Loot In", "Quest In", "Vendor In", "Trade In", "Misc In",
    "Repair Out", "AH Out", "Vendor Out", "Taxi Out", "Trainer Out", "Trade Out", "Misc Out"
  }

  local lines = {}
  table.insert(lines, '<?xml version="1.0" encoding="UTF-8"?>')
  table.insert(lines, '<?mso-application progid="Excel.Sheet"?>')
  table.insert(lines, '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"')
  table.insert(lines, ' xmlns:o="urn:schemas-microsoft-com:office:office"')
  table.insert(lines, ' xmlns:x="urn:schemas-microsoft-com:office:excel"')
  table.insert(lines, ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"')
  table.insert(lines, ' xmlns:html="http://www.w3.org/TR/REC-html40">')
  table.insert(lines, ' <DocumentProperties xmlns="urn:schemas-microsoft-com:office:office">')
  table.insert(lines, '  <Title>Goblin Journal Financial Ledger</Title>')
  table.insert(lines, '  <Author>Goblin Journal</Author>')
  table.insert(lines, string.format('  <Created>%s</Created>', date("!%Y-%m-%dT%H:%M:%SZ")))
  table.insert(lines, ' </DocumentProperties>')
  table.insert(lines, ' <Styles>')
  table.insert(lines, '  <Style ss:ID="Default" ss:Name="Normal"><Alignment ss:Vertical="Bottom"/><Font ss:FontName="Segoe UI" ss:Size="10"/></Style>')
  table.insert(lines, '  <Style ss:ID="HeaderStyle"><Font ss:FontName="Segoe UI" ss:Size="10" ss:Color="#FFFFFF" ss:Bold="1"/><Interior ss:Color="#1A2738" ss:Pattern="Solid"/><Alignment ss:Horizontal="Center" ss:Vertical="Center"/><Borders><Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#3F68A3"/></Borders></Style>')
  table.insert(lines, '  <Style ss:ID="DateStyle"><Alignment ss:Horizontal="Center"/><NumberFormat ss:Format="yyyy-mm-dd"/></Style>')
  table.insert(lines, '  <Style ss:ID="IntegerStyle"><Alignment ss:Horizontal="Right"/><NumberFormat ss:Format="#,##0"/></Style>')
  table.insert(lines, '  <Style ss:ID="GoldStyle"><Alignment ss:Horizontal="Right"/><NumberFormat ss:Format="#,##0.0000"/></Style>')
  table.insert(lines, ' </Styles>')
  table.insert(lines, ' <Worksheet ss:Name="Financial Ledger">')
  table.insert(lines, '  <Table ss:DefaultRowHeight="18">')
  table.insert(lines, '   <Column ss:Width="85"/>')
  table.insert(lines, '   <Column ss:Width="95"/>')
  table.insert(lines, '   <Column ss:Width="85"/>')
  table.insert(lines, '   <Column ss:Width="120"/>')
  table.insert(lines, '   <Column ss:Width="105"/>')
  table.insert(lines, '   <Column ss:Width="105"/>')
  table.insert(lines, '   <Column ss:Width="95"/>')
  table.insert(lines, '   <Column ss:Width="105"/>')
  for i = 1, 13 do
    table.insert(lines, '   <Column ss:Width="75"/>')
  end

  table.insert(lines, '   <Row ss:StyleID="HeaderStyle" ss:Height="22">')
  for _, h in ipairs(headers) do
    table.insert(lines, string.format('    <Cell><Data ss:Type="String">%s</Data></Cell>', EscapeXml(h)))
  end
  table.insert(lines, '   </Row>')

  local daysMap = self:GetScopedDays(scope, ruleset)
  local sortedDates = {}
  for dStr in pairs(daysMap) do
    table.insert(sortedDates, dStr)
  end
  table.sort(sortedDates, function(a, b) return a > b end)

  for _, dStr in ipairs(sortedDates) do
    local d = daysMap[dStr]
    local inTotal = (d.in_ah or 0) + (d.in_loot or 0) + (d.in_quest or 0) + (d.in_vendor or 0) + (d.in_trade or 0) + (d.in_misc or 0)
    local outTotal = (d.out_repair or 0) + (d.out_ah or 0) + (d.out_vendor or 0) + (d.out_taxi or 0) + (d.out_trainer or 0) + (d.out_trade or 0) + (d.out_misc or 0)
    local net = inTotal - outTotal
    local netGoldDecimal = string.format("%.4f", net / 10000)

    table.insert(lines, '   <Row>')
    table.insert(lines, string.format('    <Cell ss:StyleID="DateStyle"><Data ss:Type="String">%s</Data></Cell>', EscapeXml(dStr)))
    table.insert(lines, string.format('    <Cell><Data ss:Type="String">%s</Data></Cell>', EscapeXml(charName)))
    table.insert(lines, string.format('    <Cell><Data ss:Type="String">%s</Data></Cell>', EscapeXml(ruleset)))
    table.insert(lines, '    <Cell><Data ss:Type="String">All</Data></Cell>')
    table.insert(lines, string.format('    <Cell ss:StyleID="IntegerStyle"><Data ss:Type="Number">%d</Data></Cell>', inTotal))
    table.insert(lines, string.format('    <Cell ss:StyleID="IntegerStyle"><Data ss:Type="Number">%d</Data></Cell>', outTotal))
    table.insert(lines, string.format('    <Cell ss:StyleID="IntegerStyle"><Data ss:Type="Number">%d</Data></Cell>', net))
    table.insert(lines, string.format('    <Cell ss:StyleID="GoldStyle"><Data ss:Type="Number">%s</Data></Cell>', netGoldDecimal))

    local cats = {
      d.in_ah or 0, d.in_loot or 0, d.in_quest or 0, d.in_vendor or 0, d.in_trade or 0, d.in_misc or 0,
      d.out_repair or 0, d.out_ah or 0, d.out_vendor or 0, d.out_taxi or 0, d.out_trainer or 0, d.out_trade or 0, d.out_misc or 0
    }
    for _, catVal in ipairs(cats) do
      table.insert(lines, string.format('    <Cell ss:StyleID="IntegerStyle"><Data ss:Type="Number">%d</Data></Cell>', catVal))
    end
    table.insert(lines, '   </Row>')
  end

  table.insert(lines, '  </Table>')
  table.insert(lines, ' </Worksheet>')
  table.insert(lines, '</Workbook>')

  return table.concat(lines, "\r\n")
end

-------------------------------------------------------------------------------
-- WEALTH GOALS DATABASE & PROGRESS ENGINE
-------------------------------------------------------------------------------

function Engine:GetWealthGoals(scope, ruleset)
  if scope and (scope ~= "character" and scope ~= "alliance" and scope ~= "horde") and (ruleset == "character" or ruleset == "alliance" or ruleset == "horde" or ruleset == nil) then
    scope, ruleset = ruleset, scope
  end
  scope = scope or (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  ruleset = ruleset or self:GetCurrentRuleset()

  -- Migrate any goals mistakenly saved under "character" key
  if GoblinJournalDB and GoblinJournalDB.wealthGoals and GoblinJournalDB.wealthGoals["character"] and #GoblinJournalDB.wealthGoals["character"] > 0 then
    GoblinJournalDB.wealthGoals[ruleset] = GoblinJournalDB.wealthGoals[ruleset] or {}
    for _, g in ipairs(GoblinJournalDB.wealthGoals["character"]) do
      table.insert(GoblinJournalDB.wealthGoals[ruleset], g)
    end
    GoblinJournalDB.wealthGoals["character"] = nil
  end

  local allGoals = (GoblinJournalDB and GoblinJournalDB.wealthGoals and GoblinJournalDB.wealthGoals[ruleset]) or {}
  local playerKey = self:GetPlayerCharacterKey()

  local filtered = {}
  for _, g in ipairs(allGoals) do
    if scope == "character" then
      if g.charKey == playerKey then
        table.insert(filtered, g)
      end
    elseif scope == "alliance" then
      if string.lower(g.faction or "") == "alliance" then
        table.insert(filtered, g)
      end
    elseif scope == "horde" then
      if string.lower(g.faction or "") == "horde" then
        table.insert(filtered, g)
      end
    else
      table.insert(filtered, g)
    end
  end
  return filtered
end

function Engine:AddWealthGoal(title, targetGold)
  title = tostring(title or ""):match("^%s*(.-)%s*$")
  if not title or title == "" then return nil, "Empty title" end
  targetGold = tonumber(targetGold) or 0
  if targetGold <= 0 then return nil, "Invalid amount" end

  local charKey, ruleset, faction = self:RegisterPlayer()
  local charName = UnitName("player") or "Unknown"

  GoblinJournalDB.wealthGoals = GoblinJournalDB.wealthGoals or {}
  GoblinJournalDB.wealthGoals[ruleset] = GoblinJournalDB.wealthGoals[ruleset] or {}

  local hasActive = false
  for _, g in ipairs(GoblinJournalDB.wealthGoals[ruleset]) do
    if g.charKey == charKey and g.isCurrentTarget and not g.completed then
      hasActive = true
      break
    end
  end

  local newGoal = {
    id = "goal_" .. time() .. "_" .. math.random(100, 999),
    title = title,
    targetGold = targetGold,
    charName = charName,
    charKey = charKey,
    faction = faction or "Alliance",
    completed = false,
    isCurrentTarget = not hasActive
  }

  table.insert(GoblinJournalDB.wealthGoals[ruleset], 1, newGoal)
  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
  return newGoal
end

function Engine:UpdateWealthGoal(goalId, newTitle, newTargetGold)
  local ruleset = self:GetCurrentRuleset()
  local goals = (GoblinJournalDB and GoblinJournalDB.wealthGoals and GoblinJournalDB.wealthGoals[ruleset]) or {}
  for _, g in ipairs(goals) do
    if g.id == goalId then
      if newTitle and newTitle ~= "" then
        g.title = newTitle
      end
      if newTargetGold and tonumber(newTargetGold) and tonumber(newTargetGold) > 0 then
        g.targetGold = tonumber(newTargetGold)
      end
      if addonTable.UI and addonTable.UI.Refresh then
        addonTable.UI:Refresh()
      end
      return true
    end
  end
  return false
end

function Engine:ToggleWealthGoalCompleted(goalId)
  local ruleset = self:GetCurrentRuleset()
  local charKey = self:GetPlayerCharacterKey()
  local goals = (GoblinJournalDB and GoblinJournalDB.wealthGoals and GoblinJournalDB.wealthGoals[ruleset]) or {}
  for _, g in ipairs(goals) do
    if g.id == goalId then
      g.completed = not g.completed
      if g.completed and g.isCurrentTarget then
        g.isCurrentTarget = false
        for _, other in ipairs(goals) do
          if other.charKey == charKey and not other.completed then
            other.isCurrentTarget = true
            break
          end
        end
      end
      if addonTable.UI and addonTable.UI.Refresh then
        addonTable.UI:Refresh()
      end
      return true
    end
  end
  return false
end

function Engine:SetWealthGoalActive(goalId)
  local ruleset = self:GetCurrentRuleset()
  local goals = (GoblinJournalDB and GoblinJournalDB.wealthGoals and GoblinJournalDB.wealthGoals[ruleset]) or {}
  local targetGoal
  for _, g in ipairs(goals) do
    if g.id == goalId then
      targetGoal = g
      break
    end
  end

  if not targetGoal or targetGoal.completed then return false end

  for _, g in ipairs(goals) do
    if g.charKey == targetGoal.charKey then
      g.isCurrentTarget = false
    end
  end
  targetGoal.isCurrentTarget = true

  if addonTable.UI and addonTable.UI.Refresh then
    addonTable.UI:Refresh()
  end
  return true
end

function Engine:DeleteWealthGoal(goalId)
  local ruleset = self:GetCurrentRuleset()
  local goals = (GoblinJournalDB and GoblinJournalDB.wealthGoals and GoblinJournalDB.wealthGoals[ruleset]) or {}
  local removeIdx
  local wasActive = false
  local cKey

  for i, g in ipairs(goals) do
    if g.id == goalId then
      removeIdx = i
      wasActive = g.isCurrentTarget
      cKey = g.charKey
      break
    end
  end

  if removeIdx then
    table.remove(goals, removeIdx)
    if wasActive and cKey then
      for _, other in ipairs(goals) do
        if other.charKey == cKey and not other.completed then
          other.isCurrentTarget = true
          break
        end
      end
    end
    if addonTable.UI and addonTable.UI.Refresh then
      addonTable.UI:Refresh()
    end
    return true
  end
  return false
end

function Engine:GetActiveWealthGoal(ruleset)
  ruleset = ruleset or self:GetCurrentRuleset()
  local playerKey = self:GetPlayerCharacterKey()
  local goals = (GoblinJournalDB and GoblinJournalDB.wealthGoals and GoblinJournalDB.wealthGoals[ruleset]) or {}

  for _, g in ipairs(goals) do
    if g.charKey == playerKey and g.isCurrentTarget and not g.completed then
      local currentMoney = GetMoney()
      local targetCopper = (g.targetGold or 0) * 10000
      local pct = 0
      if targetCopper > 0 then
        pct = math.min(100, math.floor((currentMoney / targetCopper) * 100 + 0.5))
      end
      return g, currentMoney, targetCopper, pct
    end
  end
  return nil
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
