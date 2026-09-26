local addonName, addonTable = ...

addonTable.UILib = {}
local UILib = addonTable.UILib
local C = addonTable.Constants

-- Engine is loaded after UILib in XML; dynamic proxy ensures Engine calls resolve to addonTable.Engine
local Engine = setmetatable({}, {
  __index = function(_, k)
    local eng = addonTable.Engine
    if not eng then return nil end
    local v = eng[k]
    if type(v) == "function" then
      return function(self, ...)
        if self == Engine then
          return v(eng, ...)
        else
          return v(self, ...)
        end
      end
    end
    return v
  end,
  __newindex = function(_, k, v)
    if addonTable.Engine then
      addonTable.Engine[k] = v
    end
  end,
})

-------------------------------------------------------------------------------
-- CURRENCY FORMATTING (Thousand Separators on Gold)
-------------------------------------------------------------------------------

function UILib:FormatThousands(val)
  local formatted = tostring(math.floor(math.abs(val or 0)))
  while true do
    local k
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return formatted
end

function UILib:BreakdownCopper(copper)
  local absVal = math.floor(math.abs(copper or 0))
  local gold = math.floor(absVal / 10000)
  local silver = math.floor((absVal % 10000) / 100)
  local cop = absVal % 100
  local sign = (copper or 0) >= 0 and "+" or "-"
  return gold, silver, cop, sign
end

function UILib:FormatMoneyString(copper, showSign)
  return self:FormatMoneyWithTextures(copper, showSign)
end

function UILib:FormatMoneyWithTextures(copper, showSign)
  local g, s, c, sign = self:BreakdownCopper(copper)
  local signStr = ""
  if showSign then
    if (copper or 0) > 0 then
      signStr = "+ "
    elseif (copper or 0) < 0 then
      signStr = "- "
    end
  end
  return string.format(
    "%s%s |T%s:%d:%d:1:0|t  %d |T%s:%d:%d:1:0|t  %d |T%s:%d:%d:1:0|t",
    signStr,
    self:FormatThousands(g), C.COIN_TEXTURE_GOLD, C.COIN_SIZE, C.COIN_SIZE,
    s, C.COIN_TEXTURE_SILVER, C.COIN_SIZE, C.COIN_SIZE,
    c, C.COIN_TEXTURE_COPPER, C.COIN_SIZE, C.COIN_SIZE
  )
end

function UILib:FormatNetMoneyWithTextures(copper)
  local g, s, c = self:BreakdownCopper(copper)
  local sign = ""
  local colorCode = "ff8ca0ba"
  if (copper or 0) > 0 then
    sign = "+"
    colorCode = "ff00ff00"
  elseif (copper or 0) < 0 then
    sign = "-"
    colorCode = "ffff3333"
  end
  return string.format(
    "|c%s%s%s|r |T%s:%d:%d:1:0|t  |c%s%d|r |T%s:%d:%d:1:0|t  |c%s%d|r |T%s:%d:%d:1:0|t",
    colorCode, sign, self:FormatThousands(g), C.COIN_TEXTURE_GOLD, C.COIN_SIZE, C.COIN_SIZE,
    colorCode, s, C.COIN_TEXTURE_SILVER, C.COIN_SIZE, C.COIN_SIZE,
    colorCode, c, C.COIN_TEXTURE_COPPER, C.COIN_SIZE, C.COIN_SIZE
  )
end

function UILib:FormatSignedMoneyWithTextures(copper, isIncoming)
  local g, s, c = self:BreakdownCopper(copper)
  local sign = isIncoming and "+" or "-"
  local colorCode = isIncoming and "ff00ff00" or "ffff9900"
  return string.format(
    "|c%s%s%s|r |T%s:%d:%d:1:0|t  |c%s%d|r |T%s:%d:%d:1:0|t  |c%s%d|r |T%s:%d:%d:1:0|t",
    colorCode, sign, self:FormatThousands(g), C.COIN_TEXTURE_GOLD, C.COIN_SIZE, C.COIN_SIZE,
    colorCode, s, C.COIN_TEXTURE_SILVER, C.COIN_SIZE, C.COIN_SIZE,
    colorCode, c, C.COIN_TEXTURE_COPPER, C.COIN_SIZE, C.COIN_SIZE
  )
end

function UILib:FormatNetMoneyRateWithTextures(copperPerHour)
  return self:FormatNetMoneyWithTextures(copperPerHour) .. " |cff8ca0ba/ hr|r"
end

local MONTH_NAMES = {
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
}
UILib.MONTH_NAMES = MONTH_NAMES

function UILib:FormatMonthString(monthStr)
  local y, m = string.match(monthStr or "", "(%d+)-(%d+)")
  if y and m then
    local mIdx = tonumber(m)
    local name = MONTH_NAMES[mIdx] or ("Month " .. m)
    return string.format("%s %s", name, y)
  end
  return monthStr or ""
end

-------------------------------------------------------------------------------
-- COMPONENT FACTORIES
-------------------------------------------------------------------------------

-- 1. Inset Card Container
function UILib:CreateCard(parent, titleText, width, height, isGoldBorder)
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local card = CreateFrame("Frame", nil, parent, template)
  card:SetSize(width, height)
  card:SetBackdrop(C.CARD_BACKDROP)

  local bg = C.COLORS.CARD_BG
  card:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)

  if isGoldBorder then
    local gb = C.COLORS.GOLD_BORDER
    card:SetBackdropBorderColor(gb.r, gb.g, gb.b, gb.a)
  else
    local cb = C.COLORS.CARD_BORDER
    card:SetBackdropBorderColor(cb.r, cb.g, cb.b, cb.a)
  end

  if titleText and titleText ~= "" then
    local title = card:CreateFontString(nil, "OVERLAY")
    title:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "OUTLINE")
    title:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText(titleText)
    card.title = title
  end

  return card
end

-- 2. Blizzard Styled Button
function UILib:CreateButton(parent, text, width, height, onClick)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(width, height)
  btn:SetText(text)
  btn:SetNormalFontObject("GameFontHighlightSmall")
  if onClick then
    btn:SetScript("OnClick", onClick)
  end
  return btn
end

-- 3. View Switcher Tab Button
function UILib:CreateTabButton(parent, text, width, height, onClick)
  local tab = CreateFrame("Button", nil, parent)
  tab:SetSize(width, height)

  local textObj = tab:CreateFontString(nil, "OVERLAY")
  textObj:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "")
  textObj:SetShadowOffset(1, -1)
  textObj:SetShadowColor(0, 0, 0, 1.0)
  textObj:SetPoint("CENTER")
  textObj:SetText(text)
  textObj:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  tab.text = textObj

  tab.bg = tab:CreateTexture(nil, "BACKGROUND")
  tab.bg:SetAllPoints()
  tab.bg:SetColorTexture(0.06, 0.08, 0.12, 0.9)

  tab.highlight = tab:CreateTexture(nil, "BORDER")
  tab.highlight:SetAllPoints()
  tab.highlight:SetColorTexture(0.12, 0.16, 0.24, 0.8)
  tab.highlight:Hide()

  local accent = tab:CreateTexture(nil, "OVERLAY")
  accent:SetPoint("BOTTOMLEFT", 0, 0)
  accent:SetPoint("BOTTOMRIGHT", 0, 0)
  accent:SetHeight(2)
  accent:SetColorTexture(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b, 1.0)
  accent:Hide()
  tab.accent = accent

  function tab:SetActive(active)
    self.isActive = active
    if active then
      self.text:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
      self.bg:SetColorTexture(0.12, 0.16, 0.24, 1.0)
      self.highlight:Show()
      self.accent:Show()
    else
      self.text:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
      self.bg:SetColorTexture(0.06, 0.08, 0.12, 0.7)
      self.highlight:Hide()
      self.accent:Hide()
    end
  end

  function tab:SetDisabled(disabled)
    self.isDisabled = disabled
    if disabled then
      self:Disable()
      self.text:SetTextColor(0.35, 0.40, 0.48, 0.5)
      self.bg:SetColorTexture(0.04, 0.05, 0.08, 0.5)
      self.highlight:Hide()
      self.accent:Hide()
    else
      self:Enable()
      self:SetActive(self.isActive)
    end
  end

  tab:SetScript("OnEnter", function(self)
    if not self.isActive and not self.isDisabled then
      self.text:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
    end
  end)

  tab:SetScript("OnLeave", function(self)
    if not self.isActive and not self.isDisabled then
      self.text:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
    end
  end)

  if onClick then
    tab:SetScript("OnClick", function(self)
      if self.isDisabled then return end
      onClick(self)
    end)
  end

  return tab
end

-- 4. Scope Filter Toggle Button (Current Character, Alliance, Horde)
function UILib:CreateScopeButton(parent, text, width, height, scopeType, onClick)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(width, height)
  btn.scopeType = scopeType

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.05, 0.07, 0.10, 0.95)
  btn.bg = bg

  local border = btn:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", 1, -1)
  border:SetColorTexture(0.14, 0.17, 0.23, 0.8)
  btn.border = border

  local accent = btn:CreateTexture(nil, "OVERLAY")
  accent:SetPoint("BOTTOMLEFT", 0, 0)
  accent:SetPoint("BOTTOMRIGHT", 0, 0)
  accent:SetHeight(2)
  accent:Hide()
  btn.accent = accent

  local textObj = btn:CreateFontString(nil, "OVERLAY")
  textObj:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  textObj:SetShadowOffset(1, -1)
  textObj:SetShadowColor(0, 0, 0, 1.0)
  textObj:SetPoint("CENTER", 0, 0)
  textObj:SetText(text)
  textObj:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  btn.text = textObj

  btn:SetScript("OnEnter", function(self)
    if not self.isActive then
      self.bg:SetColorTexture(0.09, 0.12, 0.18, 0.95)
      self.border:SetColorTexture(0.24, 0.30, 0.42, 0.9)
      self.text:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
    end
  end)

  btn:SetScript("OnLeave", function(self)
    if not self.isActive then
      self.bg:SetColorTexture(0.05, 0.07, 0.10, 0.95)
      self.border:SetColorTexture(0.14, 0.17, 0.23, 0.8)
      self.text:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
    end
  end)

  function btn:SetActive(isActive)
    self.isActive = isActive
    if isActive then
      self.text:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
      self.accent:Show()
      if scopeType == "alliance" then
        self.bg:SetColorTexture(0.04, 0.08, 0.14, 0.98)
        self.border:SetColorTexture(C.COLORS.ALLIANCE.r, C.COLORS.ALLIANCE.g, C.COLORS.ALLIANCE.b, 0.9)
        self.accent:SetColorTexture(C.COLORS.ALLIANCE.r, C.COLORS.ALLIANCE.g, C.COLORS.ALLIANCE.b, 1.0)
      elseif scopeType == "horde" then
        self.bg:SetColorTexture(0.12, 0.05, 0.06, 0.98)
        self.border:SetColorTexture(C.COLORS.HORDE.r, C.COLORS.HORDE.g, C.COLORS.HORDE.b, 0.9)
        self.accent:SetColorTexture(C.COLORS.HORDE.r, C.COLORS.HORDE.g, C.COLORS.HORDE.b, 1.0)
      else
        self.bg:SetColorTexture(0.10, 0.08, 0.04, 0.98)
        self.border:SetColorTexture(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b, 0.9)
        self.accent:SetColorTexture(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b, 1.0)
      end
    else
      self.bg:SetColorTexture(0.05, 0.07, 0.10, 0.95)
      self.border:SetColorTexture(0.14, 0.17, 0.23, 0.8)
      self.accent:Hide()
      self.text:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
    end
  end

  if onClick then
    btn:SetScript("OnClick", onClick)
  end

  return btn
end

-- 5. Category Percentage Progress Bar
function UILib:CreateProgressBar(parent, width, height, isIncoming)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetSize(width, height)

  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.04, 0.06, 0.09, 0.9)
  bar.bg = bg

  local fill = bar:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
  fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  fill:SetWidth(0)

  if isIncoming then
    fill:SetColorTexture(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b, 0.85)
  else
    fill:SetColorTexture(C.COLORS.ORANGE.r, C.COLORS.ORANGE.g, C.COLORS.ORANGE.b, 0.85)
  end
  bar.fill = fill

  function bar:SetPercent(pct)
    local clamped = math.max(0, math.min(100, pct or 0))
    local w = math.floor((clamped / 100) * width)
    self.fill:SetWidth(w)
  end

  return bar
end

-- 5. Coin String Display (Triple Icons: Gold, Silver, Copper)
function UILib:CreateCoinDisplay(parent, fontSize)
  fontSize = fontSize or C.FONT_SIZE_NORMAL
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(160, fontSize + 4)

  local text = frame:CreateFontString(nil, "OVERLAY")
  text:SetFont(C.FONT_PRIMARY, fontSize, "OUTLINE")
  text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
  text:SetJustifyH("RIGHT")
  frame.text = text

  function frame:SetValue(copper, showSign)
    self.text:SetText(UILib:FormatMoneyWithTextures(copper, showSign))
  end

  function frame:SetPlainValue(copper, showSign)
    self.text:SetText(UILib:FormatMoneyWithTextures(copper, showSign))
  end

  return frame
end

-- 6. Confirmation Modal Dialog
function UILib:CreateConfirmationModal(parent, title, onConfirm)
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local modal = CreateFrame("Frame", nil, parent, template)
  modal:SetSize(420, 160)
  modal:SetPoint("CENTER", 0, 0)
  modal:SetFrameStrata("DIALOG")
  modal:SetBackdrop(C.MAIN_BACKDROP)
  modal:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
  modal:SetBackdropBorderColor(C.COLORS.GOLD_BORDER.r, C.COLORS.GOLD_BORDER.g, C.COLORS.GOLD_BORDER.b, 1)
  modal:EnableMouse(true)
  modal:Hide()

  local titleText = modal:CreateFontString(nil, "OVERLAY")
  titleText:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  titleText:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  titleText:SetPoint("TOP", 0, -14)
  titleText:SetText(title or "Confirmation")

  local bodyText = modal:CreateFontString(nil, "OVERLAY")
  bodyText:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  bodyText:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  bodyText:SetPoint("TOPLEFT", 20, -42)
  bodyText:SetPoint("BOTTOMRIGHT", -20, 48)
  bodyText:SetJustifyH("CENTER")
  bodyText:SetJustifyV("TOP")
  modal.bodyText = bodyText

  local btnCancel = self:CreateButton(modal, "Cancel", 80, 24, function()
    modal:Hide()
  end)
  btnCancel:SetPoint("BOTTOMLEFT", 60, 14)

  local btnConfirm = self:CreateButton(modal, "Confirm", 80, 24, function()
    modal:Hide()
    if modal.onConfirmCallback then
      modal.onConfirmCallback()
    end
  end)
  btnConfirm:SetPoint("BOTTOMRIGHT", -60, 14)

  function modal:ShowPrompt(message, confirmFunc)
    self.bodyText:SetText(message or "")
    self.onConfirmCallback = confirmFunc or onConfirm
    self:Show()
  end

  return modal
end

-- 7. Adaptive Cash Flow Sparkline Frame
function UILib:CreateSparklineFrame(parent, width, height)
  width = width or 676
  height = height or 54
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(width, height)

  -- Container Background
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.04, 0.06, 0.09, 0.85)

  local border = frame:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", 0, 0)
  border:SetPoint("BOTTOMRIGHT", 0, 0)
  border:SetColorTexture(0.12, 0.16, 0.23, 0.8)

  local innerBg = frame:CreateTexture(nil, "ARTWORK")
  innerBg:SetPoint("TOPLEFT", 1, -1)
  innerBg:SetPoint("BOTTOMRIGHT", -1, 1)
  innerBg:SetColorTexture(0.06, 0.08, 0.12, 0.95)

  -- Center baseline
  local midY = math.floor(height / 2) + 2
  local baseline = frame:CreateTexture(nil, "OVERLAY")
  baseline:SetPoint("LEFT", frame, "LEFT", 12, 4)
  baseline:SetPoint("RIGHT", frame, "RIGHT", -12, 4)
  baseline:SetHeight(1)
  baseline:SetColorTexture(0.20, 0.26, 0.36, 0.7)

  -- Title & Legend
  local title = frame:CreateFontString(nil, "OVERLAY")
  title:SetFont(C.FONT_PRIMARY, 9, "")
  title:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  title:SetPoint("TOPLEFT", 6, -3)
  title:SetText("CASH FLOW SPARKLINE")

  local legendIn = frame:CreateFontString(nil, "OVERLAY")
  legendIn:SetFont(C.FONT_PRIMARY, 9, "")
  legendIn:SetTextColor(C.COLORS.PROFIT.r, C.COLORS.PROFIT.g, C.COLORS.PROFIT.b)
  legendIn:SetPoint("TOPRIGHT", -70, -3)
  legendIn:SetText("Incoming")

  local legendOut = frame:CreateFontString(nil, "OVERLAY")
  legendOut:SetFont(C.FONT_PRIMARY, 9, "")
  legendOut:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
  legendOut:SetPoint("TOPRIGHT", -12, -3)
  legendOut:SetText("Outgoing")

  -- Time labels
  local lblStart = frame:CreateFontString(nil, "OVERLAY")
  lblStart:SetFont(C.FONT_PRIMARY, 9, "")
  lblStart:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  lblStart:SetPoint("BOTTOMLEFT", 6, 2)
  frame.lblStart = lblStart

  local lblMid = frame:CreateFontString(nil, "OVERLAY")
  lblMid:SetFont(C.FONT_PRIMARY, 9, "")
  lblMid:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  lblMid:SetPoint("BOTTOM", 0, 2)
  frame.lblMid = lblMid

  local lblEnd = frame:CreateFontString(nil, "OVERLAY")
  lblEnd:SetFont(C.FONT_PRIMARY, 9, "")
  lblEnd:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  lblEnd:SetPoint("BOTTOMRIGHT", -6, 2)
  frame.lblEnd = lblEnd

  -- Texture bar pool
  local barPool = {}
  local function GetBar(idx)
    if not barPool[idx] then
      local bar = frame:CreateTexture(nil, "OVERLAY")
      barPool[idx] = bar
    end
    return barPool[idx]
  end

  function frame:RenderSession(sessionData)
    for _, b in ipairs(barPool) do
      b:Hide()
    end

    if not sessionData then return end

    self.lblStart:SetText(sessionData.timeStart or "")
    self.lblEnd:SetText(sessionData.timeEnd or "")

    local sH, sM = string.match(sessionData.timeStart or "", "(%d+):(%d+)")
    local eH, eM = string.match(sessionData.timeEnd or "", "(%d+):(%d+)")
    if sH and sM and eH and eM then
      local startMin = tonumber(sH) * 60 + tonumber(sM)
      local endMin = tonumber(eH) * 60 + tonumber(eM)
      if endMin < startMin then endMin = endMin + 1440 end
      local midMin = math.floor((startMin + endMin) / 2) % 1440
      local midH = math.floor(midMin / 60)
      local midM = midMin % 60
      self.lblMid:SetText(string.format("%02d:%02d (Midpoint)", midH, midM))
    else
      self.lblMid:SetText("Midpoint")
    end

    local timeline = sessionData.timeline or {}
    local durationSecs = math.max(1, sessionData.duration or 60)
    local usableWidth = width - 24
    local maxBarH = 14

    local maxVal = 0
    for _, pt in ipairs(timeline) do
      if (pt.inc or 0) > maxVal then maxVal = pt.inc end
      if (pt.exp or 0) > maxVal then maxVal = pt.exp end
    end
    if maxVal == 0 then maxVal = 10000 end

    local barIdx = 1
    for _, pt in ipairs(timeline) do
      local normT = math.min(1.0, math.max(0.0, (pt.t or 0) / durationSecs))
      local posX = 12 + math.floor(normT * usableWidth)

      -- Incoming spike (Green, extends upward from baseline)
      if (pt.inc or 0) > 0 then
        local bar = GetBar(barIdx)
        barIdx = barIdx + 1
        local barH = math.max(3, math.min(maxBarH, math.floor(((pt.inc or 0) / maxVal) * maxBarH + 0.5)))
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", posX - 2, midY)
        bar:SetSize(4, barH)
        bar:SetColorTexture(0.0, 1.0, 0.25, 0.9)
        bar:Show()
      end

      -- Outgoing spike (Red, extends downward from baseline)
      if (pt.exp or 0) > 0 then
        local bar = GetBar(barIdx)
        barIdx = barIdx + 1
        local barH = math.max(3, math.min(maxBarH, math.floor(((pt.exp or 0) / maxVal) * maxBarH + 0.5)))
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", posX - 2, midY)
        bar:SetSize(4, barH)
        bar:SetColorTexture(1.0, 0.25, 0.25, 0.9)
        bar:Show()
      end
    end
  end

  return frame
end

-------------------------------------------------------------------------------
-- 8. DRAGGABLE FLOATING MICRO-HUD WIDGET
-------------------------------------------------------------------------------

function UILib:CreateMicroHUD(parent)
  local hud = CreateFrame("Frame", "GoblinJournalMicroHUD", UIParent)
  hud:SetSize(220, 52)
  hud:SetFrameStrata("HIGH")
  hud:SetClampedToScreen(true)
  hud:SetMovable(true)

  local pos = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.hudPos) or { "TOPLEFT", 200, -200 }
  hud:SetPoint(pos[1] or "TOPLEFT", UIParent, pos[1] or "TOPLEFT", pos[2] or 200, pos[3] or -200)

  local bg = hud:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.04, 0.05, 0.08, 0.88)
  hud.bg = bg

  local border = hud:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", 1, -1)
  border:SetColorTexture(0.16, 0.20, 0.28, 0.8)
  hud.border = border

  local titleBar = CreateFrame("Frame", nil, hud)
  titleBar:SetHeight(18)
  titleBar:SetPoint("TOPLEFT", 0, 18)
  titleBar:SetPoint("TOPRIGHT", 0, 18)

  local tbBg = titleBar:CreateTexture(nil, "BACKGROUND")
  tbBg:SetAllPoints()
  tbBg:SetColorTexture(0.08, 0.12, 0.18, 0.95)

  local tbBorder = titleBar:CreateTexture(nil, "BORDER")
  tbBorder:SetPoint("TOPLEFT", -1, 1)
  tbBorder:SetPoint("BOTTOMRIGHT", 1, -1)
  tbBorder:SetColorTexture(C.COLORS.GOLD_BORDER.r, C.COLORS.GOLD_BORDER.g, C.COLORS.GOLD_BORDER.b, 0.9)

  local tbTitle = titleBar:CreateFontString(nil, "OVERLAY")
  tbTitle:SetFont(C.FONT_PRIMARY, 9, "OUTLINE")
  tbTitle:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  tbTitle:SetPoint("LEFT", 6, 0)
  tbTitle:SetText("Goblin HUD (Unlocked)")

  titleBar:EnableMouse(true)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:SetScript("OnDragStart", function()
    hud:StartMoving()
  end)
  titleBar:SetScript("OnDragStop", function()
    hud:StopMovingOrSizing()
    local point, _, _, x, y = hud:GetPoint()
    if GoblinJournalDB and GoblinJournalDB.settings then
      GoblinJournalDB.settings.hudPos = { point, math.floor(x), math.floor(y) }
    end
  end)
  hud.titleBar = titleBar

  local rowDay = CreateFrame("Frame", nil, hud)
  rowDay:SetHeight(20)
  rowDay:SetPoint("TOPLEFT", 6, -4)
  rowDay:SetPoint("TOPRIGHT", -6, -4)

  local lblDay = rowDay:CreateFontString(nil, "OVERLAY")
  lblDay:SetFont(C.FONT_PRIMARY, 10, "OUTLINE")
  lblDay:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  lblDay:SetPoint("LEFT", 0, 0)
  lblDay:SetText("D:")

  local valDay = rowDay:CreateFontString(nil, "OVERLAY")
  valDay:SetFont(C.FONT_PRIMARY, 10, "")
  valDay:SetPoint("RIGHT", 0, 0)
  rowDay.val = valDay
  hud.rowDay = rowDay

  local rowSession = CreateFrame("Frame", nil, hud)
  rowSession:SetHeight(20)
  rowSession:SetPoint("TOPLEFT", 6, -26)
  rowSession:SetPoint("TOPRIGHT", -6, -26)

  local lblSession = rowSession:CreateFontString(nil, "OVERLAY")
  lblSession:SetFont(C.FONT_PRIMARY, 10, "OUTLINE")
  lblSession:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  lblSession:SetPoint("LEFT", 0, 0)
  lblSession:SetText("S:")

  local valSession = rowSession:CreateFontString(nil, "OVERLAY")
  valSession:SetFont(C.FONT_PRIMARY, 10, "")
  valSession:SetPoint("RIGHT", 0, 0)
  rowSession.val = valSession
  hud.rowSession = rowSession

  function hud:SetLocked(locked)
    if locked then
      self.titleBar:Hide()
      self.bg:SetColorTexture(0.04, 0.05, 0.08, 0.75)
      self.border:Hide()
      self:EnableMouse(false)
    else
      self.titleBar:Show()
      self.bg:SetColorTexture(0.06, 0.08, 0.12, 0.95)
      self.border:Show()
      self:EnableMouse(true)
    end
  end

  function hud:Update()
    local eng = addonTable.Engine or Engine
    if not eng or not eng.GetTodayDate then return end
    local today = eng:GetTodayDate()
    local dayData = eng:GetDayData(today)
    local netAmount = (dayData and dayData.net) or 0
    self.rowDay.val:SetText(UILib:FormatNetMoneyWithTextures(netAmount))

    if eng:IsSessionActive() then
      self.rowSession:Show()
      self:SetHeight(52)
      local sRec = (eng.GetActiveSessionRecord and eng:GetActiveSessionRecord()) or {}
      local inTot = (sRec.in_ah or 0) + (sRec.in_loot or 0) + (sRec.in_quest or 0) + (sRec.in_vendor or 0) + (sRec.in_trade or 0) + (sRec.in_misc or 0)
      local outTot = (sRec.out_repair or 0) + (sRec.out_ah or 0) + (sRec.out_vendor or 0) + (sRec.out_taxi or 0) + (sRec.out_trainer or 0) + (sRec.out_trade or 0) + (sRec.out_misc or 0)
      local sNet = inTot - outTot
      self.rowSession.val:SetText(UILib:FormatNetMoneyWithTextures(sNet))
    else
      self.rowSession:Hide()
      self:SetHeight(28)
    end
  end

  local updateElapsed = 0
  hud:SetScript("OnUpdate", function(self, elapsed)
    updateElapsed = updateElapsed + (elapsed or 0)
    local interval = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.hudInterval) or 5
    if updateElapsed >= interval then
      updateElapsed = 0
      self:Update()
    end
  end)

  function hud:SetInterval(interval)
    updateElapsed = 0
    self:Update()
  end

  local isLocked = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.hudLocked)
  hud:SetLocked(isLocked)

  if GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.hudShown == false then
    hud:Hide()
  else
    hud:Show()
  end

  hud:Update()
  return hud
end

-------------------------------------------------------------------------------
-- 9. MULTI-FORMAT FINANCIAL LEDGER EXPORT DIALOG
-------------------------------------------------------------------------------

function UILib:CreateExportModal(parent)
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local modal = CreateFrame("Frame", nil, parent, template)
  modal:SetSize(620, 350)
  modal:SetPoint("CENTER", 0, 0)
  modal:SetFrameStrata("DIALOG")
  modal:SetBackdrop(C.MAIN_BACKDROP)
  modal:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
  modal:SetBackdropBorderColor(C.COLORS.GOLD_BORDER.r, C.COLORS.GOLD_BORDER.g, C.COLORS.GOLD_BORDER.b, 1)
  modal:EnableMouse(true)
  modal:Hide()

  local headerTitle = modal:CreateFontString(nil, "OVERLAY")
  headerTitle:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  headerTitle:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  headerTitle:SetPoint("TOPLEFT", 16, -14)
  headerTitle:SetText("Export Financial Ledger")

  local btnCsv = self:CreateButton(modal, "RFC 4180 Format", 120, 20)
  btnCsv:SetPoint("TOPRIGHT", -150, -12)

  local btnXml = self:CreateButton(modal, "XML Spreadsheet 2003", 136, 20)
  btnXml:SetPoint("TOPRIGHT", -12, -12)

  local descText = modal:CreateFontString(nil, "OVERLAY")
  descText:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  descText:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  descText:SetPoint("TOPLEFT", 16, -42)
  descText:SetPoint("TOPRIGHT", -16, -42)
  descText:SetJustifyH("LEFT")

  local scroll = CreateFrame("ScrollFrame", "GoblinJournalExportScroll", modal, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 16, -64)
  scroll:SetPoint("BOTTOMRIGHT", -36, 48)

  local editBox = CreateFrame("EditBox", nil, scroll)
  editBox:SetMultiLine(true)
  editBox:SetMaxLetters(0)
  editBox:EnableMouse(true)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject("GameFontHighlightSmall")
  editBox:SetWidth(568)
  editBox:SetScript("OnEscapePressed", function() modal:Hide() end)
  editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  scroll:SetScrollChild(editBox)
  modal.editBox = editBox

  local copiedNotice = modal:CreateFontString(nil, "OVERLAY")
  copiedNotice:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "OUTLINE")
  copiedNotice:SetTextColor(C.COLORS.PROFIT.r, C.COLORS.PROFIT.g, C.COLORS.PROFIT.b)
  copiedNotice:SetPoint("BOTTOMLEFT", 16, 18)
  copiedNotice:SetText("Data selected! Press Ctrl+C to copy.")
  copiedNotice:Hide()
  modal.copiedNotice = copiedNotice

  local currentFormat = "csv"

  local function RefreshContent()
    local eng = addonTable.Engine or Engine
    if not eng then return end
    if currentFormat == "csv" then
      btnCsv:LockHighlight()
      btnXml:UnlockHighlight()
      descText:SetText("Copy and paste this RFC 4180 data into Google Sheets or CSV accounting tools:")
      editBox:SetText(eng:GenerateExportCSV())
    else
      btnXml:LockHighlight()
      btnCsv:UnlockHighlight()
      descText:SetText("Microsoft Excel XML Spreadsheet 2003. Opens natively in Excel with structured columns & types:")
      editBox:SetText(eng:GenerateExportXML())
    end
    editBox:HighlightText()
  end

  btnCsv:SetScript("OnClick", function()
    currentFormat = "csv"
    RefreshContent()
  end)

  btnXml:SetScript("OnClick", function()
    currentFormat = "xml"
    RefreshContent()
  end)

  local btnClose = self:CreateButton(modal, "Close", 80, 24, function()
    modal:Hide()
  end)
  btnClose:SetPoint("BOTTOMRIGHT", -16, 14)

  local btnCopy = self:CreateButton(modal, "Select All (Ctrl+C)", 140, 24, function()
    editBox:SetFocus()
    editBox:HighlightText()
    copiedNotice:Show()
    if C_Timer and C_Timer.After then
      C_Timer.After(2.5, function() copiedNotice:Hide() end)
    end
  end)
  btnCopy:SetPoint("RIGHT", btnClose, "LEFT", -8, 0)

  function modal:Open()
    currentFormat = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.exportFormat) or "csv"
    copiedNotice:Hide()
    RefreshContent()
    self:Show()
  end

  return modal
end

-------------------------------------------------------------------------------
-- 10. WEALTH GOALS CONTEXT ACTION MENU
-------------------------------------------------------------------------------

function UILib:CreateActionMenu(parent)
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local menu = CreateFrame("Frame", nil, parent, template)
  menu:SetSize(125, 96)
  menu:SetFrameStrata("TOOLTIP")
  menu:SetBackdrop(C.MAIN_BACKDROP)
  menu:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
  menu:SetBackdropBorderColor(C.COLORS.GOLD_BORDER.r, C.COLORS.GOLD_BORDER.g, C.COLORS.GOLD_BORDER.b, 1)
  menu:EnableMouse(true)
  menu:Hide()

  local btnEdit = self:CreateButton(menu, "Edit Goal", 113, 22)
  btnEdit:SetPoint("TOP", 0, -6)

  local btnComplete = self:CreateButton(menu, "Complete Goal", 113, 22)
  btnComplete:SetPoint("TOP", btnEdit, "BOTTOM", 0, -4)

  local btnDelete = self:CreateButton(menu, "Delete Goal", 113, 22)
  btnDelete:SetPoint("TOP", btnComplete, "BOTTOM", 0, -4)

  function menu:OpenForGoal(goal, anchorBtn, onEdit, onComplete, onDelete)
    self.currentGoal = goal
    self:ClearAllPoints()

    local btnBottom = anchorBtn:GetBottom() or 0
    if btnBottom < 120 then
      self:SetPoint("BOTTOMRIGHT", anchorBtn, "TOPRIGHT", 0, 2)
    else
      self:SetPoint("TOPRIGHT", anchorBtn, "BOTTOMRIGHT", 0, -2)
    end

    btnComplete:SetText(goal.completed and "Reopen Goal" or "Complete Goal")

    btnEdit:SetScript("OnClick", function()
      menu:Hide()
      if onEdit then onEdit(goal) end
    end)

    btnComplete:SetScript("OnClick", function()
      menu:Hide()
      if onComplete then onComplete(goal) end
    end)

    btnDelete:SetScript("OnClick", function()
      menu:Hide()
      if onDelete then onDelete(goal) end
    end)

    self:Show()
  end

  return menu
end

-------------------------------------------------------------------------------
-- 11. WEALTH GOAL EDIT MODAL
-------------------------------------------------------------------------------

function UILib:CreateEditGoalModal(parent, onSave)
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local modal = CreateFrame("Frame", nil, parent, template)
  modal:SetSize(460, 220)
  modal:SetPoint("CENTER", 0, 0)
  modal:SetFrameStrata("DIALOG")
  modal:SetBackdrop(C.MAIN_BACKDROP)
  modal:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
  modal:SetBackdropBorderColor(C.COLORS.GOLD_BORDER.r, C.COLORS.GOLD_BORDER.g, C.COLORS.GOLD_BORDER.b, 1)
  modal:EnableMouse(true)
  modal:Hide()

  local titleText = modal:CreateFontString(nil, "OVERLAY")
  titleText:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  titleText:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  titleText:SetPoint("TOP", 0, -14)
  titleText:SetText("Edit Wealth Milestone Goal")

  local lblOwner = modal:CreateFontString(nil, "OVERLAY")
  lblOwner:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  lblOwner:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  lblOwner:SetPoint("TOP", 0, -32)
  modal.lblOwner = lblOwner

  local lblTitle = modal:CreateFontString(nil, "OVERLAY")
  lblTitle:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  lblTitle:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  lblTitle:SetPoint("TOPLEFT", 24, -58)
  lblTitle:SetText("Goal Title / Item:")

  local inputTitle = CreateFrame("EditBox", nil, modal, "InputBoxTemplate")
  inputTitle:SetSize(410, 24)
  inputTitle:SetPoint("TOPLEFT", 28, -78)
  inputTitle:SetAutoFocus(false)
  modal.inputTitle = inputTitle

  local lblAmount = modal:CreateFontString(nil, "OVERLAY")
  lblAmount:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  lblAmount:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  lblAmount:SetPoint("TOPLEFT", 24, -114)
  lblAmount:SetText("Target Gold:")

  local inputAmount = CreateFrame("EditBox", nil, modal, "InputBoxTemplate")
  inputAmount:SetSize(160, 24)
  inputAmount:SetPoint("TOPLEFT", 28, -134)
  inputAmount:SetNumeric(true)
  inputAmount:SetAutoFocus(false)
  modal.inputAmount = inputAmount

  local btnCancel = self:CreateButton(modal, "Cancel", 80, 24, function()
    modal:Hide()
  end)
  btnCancel:SetPoint("BOTTOMLEFT", 60, 16)

  local btnSave = self:CreateButton(modal, "Save Changes", 110, 24, function()
    local t = inputTitle:GetText() or ""
    local a = tonumber(inputAmount:GetText() or "") or 0
    if t ~= "" and a > 0 then
      modal:Hide()
      if modal.onSaveCallback then
        modal.onSaveCallback(modal.targetGoalId, t, a)
      end
    end
  end)
  btnSave:SetPoint("BOTTOMRIGHT", -60, 16)

  function modal:OpenForGoal(goal, saveFunc)
    if not goal then return end
    self.targetGoalId = goal.id
    self.onSaveCallback = saveFunc or onSave
    self.lblOwner:SetText(string.format("Owner: %s (%s)", goal.charName or "Unknown", goal.faction or "Alliance"))
    self.inputTitle:SetText(goal.title or "")
    self.inputAmount:SetText(tostring(goal.targetGold or ""))
    self:Show()
  end

  return modal
end

-------------------------------------------------------------------------------
-- 12. CHECKBOX COMPONENT
-------------------------------------------------------------------------------

function UILib:CreateCheckbox(parent, labelText, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(22, 22)

  local text = cb:CreateFontString(nil, "OVERLAY")
  text:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  text:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  text:SetText(labelText or "")
  cb.text = text

  if onClick then
    cb:SetScript("OnClick", function(self)
      onClick(self:GetChecked())
    end)
  end

  return cb
end

-------------------------------------------------------------------------------
-- 13. SETTINGS MODAL
-------------------------------------------------------------------------------

function UILib:CreateSettingsModal(parent, onSettingChange)
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local modal = CreateFrame("Frame", nil, parent, template)
  modal:SetSize(460, 400)
  modal:SetPoint("CENTER", 0, 0)
  modal:SetFrameStrata("DIALOG")
  modal:SetBackdrop(C.MAIN_BACKDROP)
  modal:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
  modal:SetBackdropBorderColor(C.COLORS.GOLD_BORDER.r, C.COLORS.GOLD_BORDER.g, C.COLORS.GOLD_BORDER.b, 1)
  modal:EnableMouse(true)
  modal:Hide()

  local titleText = modal:CreateFontString(nil, "OVERLAY")
  titleText:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  titleText:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  titleText:SetPoint("TOPLEFT", 16, -14)
  titleText:SetText("Goblin Journal Settings")

  local subtitleText = modal:CreateFontString(nil, "OVERLAY")
  subtitleText:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  subtitleText:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  subtitleText:SetPoint("TOPRIGHT", -16, -16)
  subtitleText:SetText("Interface Options")

  -- Section 1: Default Startup View
  local sec1Title = modal:CreateFontString(nil, "OVERLAY")
  sec1Title:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "OUTLINE")
  sec1Title:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  sec1Title:SetPoint("TOPLEFT", 16, -42)
  sec1Title:SetText("Startup View")

  local views = { "day", "week", "month", "session", "wealth" }
  local viewLabels = { day = "Day", week = "Week", month = "Month", session = "Session", wealth = "Wealth" }
  local viewButtons = {}

  local prevBtn = nil
  for _, vMode in ipairs(views) do
    local btn = self:CreateScopeButton(modal, viewLabels[vMode], 66, 20, vMode, function()
      if GoblinJournalDB and GoblinJournalDB.settings then
        GoblinJournalDB.settings.selectedView = vMode
      end
      for _, b in pairs(viewButtons) do b:SetActive(false) end
      viewButtons[vMode]:SetActive(true)
      if onSettingChange then onSettingChange("selectedView", vMode) end
    end)
    if not prevBtn then
      btn:SetPoint("TOPLEFT", 16, -62)
    else
      btn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
    end
    prevBtn = btn
    viewButtons[vMode] = btn
  end

  -- Section 2: Minimap Button
  local sec2Title = modal:CreateFontString(nil, "OVERLAY")
  sec2Title:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "OUTLINE")
  sec2Title:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  sec2Title:SetPoint("TOPLEFT", 16, -96)
  sec2Title:SetText("Minimap Button")

  local cbMinimap = self:CreateCheckbox(modal, "Show Minimap Button", function(checked)
    if GoblinJournalDB and GoblinJournalDB.settings then
      GoblinJournalDB.settings.showMinimapBtn = checked
    end
    if addonTable.Minimap then
      if checked then addonTable.Minimap:Show() else addonTable.Minimap:Hide() end
    end
    if onSettingChange then onSettingChange("showMinimapBtn", checked) end
  end)
  cbMinimap:SetPoint("TOPLEFT", 16, -116)
  modal.cbMinimap = cbMinimap

  -- Section 3: Floating Micro-HUD Widget
  local sec3Title = modal:CreateFontString(nil, "OVERLAY")
  sec3Title:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "OUTLINE")
  sec3Title:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  sec3Title:SetPoint("TOPLEFT", 16, -148)
  sec3Title:SetText("Floating Micro-HUD Widget")

  local cbHudShow = self:CreateCheckbox(modal, "Enable Floating Micro-HUD", function(checked)
    if GoblinJournalDB and GoblinJournalDB.settings then
      GoblinJournalDB.settings.hudShown = checked
    end
    if onSettingChange then onSettingChange("hudShown", checked) end
  end)
  cbHudShow:SetPoint("TOPLEFT", 16, -168)
  modal.cbHudShow = cbHudShow

  local cbHudLock = self:CreateCheckbox(modal, "Lock HUD Position (Minimap Right-Click)", function(checked)
    if GoblinJournalDB and GoblinJournalDB.settings then
      GoblinJournalDB.settings.hudLocked = checked
    end
    if onSettingChange then onSettingChange("hudLocked", checked) end
  end)
  cbHudLock:SetPoint("TOPLEFT", 16, -194)
  modal.cbHudLock = cbHudLock

  local sec3Interval = modal:CreateFontString(nil, "OVERLAY")
  sec3Interval:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  sec3Interval:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  sec3Interval:SetPoint("TOPLEFT", 16, -220)
  sec3Interval:SetText("HUD Update Interval:")

  local intervals = { 1, 2, 5, 10, 30, 60 }
  local intervalLabels = { [1] = "1s", [2] = "2s", [5] = "5s", [10] = "10s", [30] = "30s", [60] = "60s" }
  local intervalButtons = {}
  local prevIntervalBtn = nil
  for _, intVal in ipairs(intervals) do
    local btn = self:CreateScopeButton(modal, intervalLabels[intVal], 44, 20, "interval_" .. intVal, function()
      if GoblinJournalDB and GoblinJournalDB.settings then
        GoblinJournalDB.settings.hudInterval = intVal
      end
      for _, b in pairs(intervalButtons) do b:SetActive(false) end
      intervalButtons[intVal]:SetActive(true)
      if onSettingChange then onSettingChange("hudInterval", intVal) end
    end)
    if not prevIntervalBtn then
      btn:SetPoint("TOPLEFT", 16, -238)
    else
      btn:SetPoint("LEFT", prevIntervalBtn, "RIGHT", 6, 0)
    end
    prevIntervalBtn = btn
    intervalButtons[intVal] = btn
  end

  -- Section 4: Session History Retention Cap
  local sec4Title = modal:CreateFontString(nil, "OVERLAY")
  sec4Title:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "OUTLINE")
  sec4Title:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  sec4Title:SetPoint("TOPLEFT", 16, -272)
  sec4Title:SetText("Session History Retention Cap")

  local caps = { 50, 100, 200, 0 }
  local capLabels = { [50] = "50", [100] = "100", [200] = "200", [0] = "Unlimited" }
  local capButtons = {}
  local prevCapBtn = nil
  for _, capVal in ipairs(caps) do
    local btn = self:CreateScopeButton(modal, capLabels[capVal], capVal == 0 and 78 or 46, 20, "cap_" .. capVal, function()
      local eng = addonTable.Engine or Engine
      if eng and eng.SetSessionCap then
        eng:SetSessionCap(capVal)
      end
      for _, b in pairs(capButtons) do b:SetActive(false) end
      capButtons[capVal]:SetActive(true)
      if onSettingChange then onSettingChange("sessionCap", capVal) end
    end)
    if not prevCapBtn then
      btn:SetPoint("TOPLEFT", 16, -292)
    else
      btn:SetPoint("LEFT", prevCapBtn, "RIGHT", 6, 0)
    end
    prevCapBtn = btn
    capButtons[capVal] = btn
  end

  -- Close Button
  local btnClose = self:CreateButton(modal, "Close", 80, 24, function()
    modal:Hide()
  end)
  btnClose:SetPoint("BOTTOMRIGHT", -16, 14)

  function modal:Open()
    local s = (GoblinJournalDB and GoblinJournalDB.settings) or C.DEFAULT_SETTINGS
    local curView = s.selectedView or "day"
    for vMode, b in pairs(viewButtons) do
      b:SetActive(vMode == curView)
    end

    cbMinimap:SetChecked(s.showMinimapBtn ~= false)
    cbHudShow:SetChecked(s.hudShown ~= false)
    cbHudLock:SetChecked(s.hudLocked == true)

    local curInterval = s.hudInterval or 5
    for intVal, b in pairs(intervalButtons) do
      b:SetActive(intVal == curInterval)
    end

    local eng = addonTable.Engine or Engine
    local curCap = (eng and eng.GetSessionCap and eng:GetSessionCap()) or 50
    for capVal, b in pairs(capButtons) do
      b:SetActive(capVal == curCap)
    end

    self:Show()
  end

  return modal
end

-------------------------------------------------------------------------------
-- 14. RESET MODAL (Granular Ledger Reset Dialog)
-------------------------------------------------------------------------------

function UILib:CreateResetModal(parent, onReset)
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local modal = CreateFrame("Frame", nil, parent, template)
  modal:SetSize(450, 240)
  modal:SetPoint("CENTER", 0, 0)
  modal:SetFrameStrata("DIALOG")
  modal:SetBackdrop(C.MAIN_BACKDROP)
  modal:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
  modal:SetBackdropBorderColor(C.COLORS.GOLD_BORDER.r, C.COLORS.GOLD_BORDER.g, C.COLORS.GOLD_BORDER.b, 1)
  modal:EnableMouse(true)
  modal:Hide()

  local titleText = modal:CreateFontString(nil, "OVERLAY")
  titleText:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  titleText:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  titleText:SetPoint("TOPLEFT", 16, -14)
  titleText:SetText("Reset Ledger Data")

  local subtitleText = modal:CreateFontString(nil, "OVERLAY")
  subtitleText:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  subtitleText:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  subtitleText:SetPoint("TOPRIGHT", -16, -16)
  subtitleText:SetText("Confirm Deletion")

  local divider = modal:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", 14, -34)
  divider:SetPoint("TOPRIGHT", -14, -34)
  divider:SetHeight(1)
  divider:SetColorTexture(C.COLORS.CARD_BORDER.r, C.COLORS.CARD_BORDER.g, C.COLORS.CARD_BORDER.b, 1.0)

  local secLabel = modal:CreateFontString(nil, "OVERLAY")
  secLabel:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "OUTLINE")
  secLabel:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  secLabel:SetPoint("TOPLEFT", 16, -44)
  secLabel:SetText("Select category to reset:")

  local optButtons = {}
  local options = { "day", "week", "month", "sessions", "wealth", "all" }
  local optLabels = {
    day = "Day",
    week = "Week",
    month = "Month",
    sessions = "Sessions",
    wealth = "Wealth",
    all = "All"
  }
  local actionLabels = {
    day = "Reset Day",
    week = "Reset Week",
    month = "Reset Month",
    sessions = "Reset Sessions",
    wealth = "Reset Wealth",
    all = "Reset All"
  }

  local currentOpt = "day"
  local descBox = modal:CreateFontString(nil, "OVERLAY")
  descBox:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  descBox:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  descBox:SetPoint("TOPLEFT", 16, -100)
  descBox:SetPoint("TOPRIGHT", -16, -100)
  descBox:SetJustifyH("LEFT")

  local warnText = modal:CreateFontString(nil, "OVERLAY")
  warnText:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  warnText:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
  warnText:SetPoint("TOPLEFT", 16, -156)
  warnText:SetText("Warning: This action permanently deletes records for the selected scope.")

  local btnConfirm = self:CreateButton(modal, "Reset Day", 110, 24, function()
    modal:Hide()
    if onReset then
      onReset(currentOpt)
    end
  end)
  btnConfirm:SetPoint("BOTTOMRIGHT", -16, 14)

  local btnCancel = self:CreateButton(modal, "Cancel", 75, 24, function()
    modal:Hide()
  end)
  btnCancel:SetPoint("RIGHT", btnConfirm, "LEFT", -8, 0)

  local function UpdateView(opt, ctx)
    currentOpt = opt or currentOpt
    for o, b in pairs(optButtons) do
      b:SetActive(o == currentOpt)
    end
    btnConfirm:SetText(actionLabels[currentOpt] or "Reset")

    local dateStr = (ctx and ctx.date) or "selected date"
    local weekStr = (ctx and ctx.week) or "current reset week"
    local monthStr = (ctx and ctx.month) or "selected month"
    local scopeStr = (ctx and ctx.scope) or "current"

    if currentOpt == "day" then
      descBox:SetText(string.format("Permanently delete daily ledger records for |cFFFFD700%s|r in |cFFFFD700%s|r scope.", dateStr, scopeStr))
    elseif currentOpt == "week" then
      descBox:SetText(string.format("Permanently delete weekly transaction records for |cFFFFD700%s|r in |cFFFFD700%s|r scope.", weekStr, scopeStr))
    elseif currentOpt == "month" then
      descBox:SetText(string.format("Permanently delete monthly transaction records for |cFFFFD700%s|r in |cFFFFD700%s|r scope.", monthStr, scopeStr))
    elseif currentOpt == "sessions" then
      descBox:SetText(string.format("Permanently delete all recorded session history in |cFFFFD700%s|r scope.", scopeStr))
    elseif currentOpt == "wealth" then
      descBox:SetText("Permanently delete all configured wealth milestone goals in current ruleset.")
    elseif currentOpt == "all" then
      descBox:SetText(string.format("Permanently delete all financial ledger records, recorded sessions, and wealth goals for |cFFFFD700%s|r scope.", scopeStr))
    end
  end

  local prevBtn = nil
  for _, optKey in ipairs(options) do
    local btn = self:CreateScopeButton(modal, optLabels[optKey], optKey == "sessions" and 68 or (optKey == "wealth" and 62 or 54), 22, optKey, function()
      UpdateView(optKey, modal.context)
    end)
    if not prevBtn then
      btn:SetPoint("TOPLEFT", 16, -66)
    else
      btn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
    end
    prevBtn = btn
    optButtons[optKey] = btn
  end

  function modal:Open(initialOpt, context)
    self.context = context
    if initialOpt == "session" then initialOpt = "sessions" end
    UpdateView(initialOpt or "day", context)
    self:Show()
  end

  return modal
end
