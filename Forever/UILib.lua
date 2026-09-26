local addonName, addonTable = ...

addonTable.UILib = {}
local UILib = addonTable.UILib
local C = addonTable.Constants

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
  local g, s, c, sign = self:BreakdownCopper(copper)
  local signStr = ""
  if showSign then
    if (copper or 0) > 0 then
      signStr = "+"
    elseif (copper or 0) < 0 then
      signStr = "-"
    end
  end
  return string.format("%s%sg %ss %sc", signStr, self:FormatThousands(g), s, c)
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

  tab:SetScript("OnEnter", function(self)
    if not self.isActive then
      self.text:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
    end
  end)

  tab:SetScript("OnLeave", function(self)
    if not self.isActive then
      self.text:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
    end
  end)

  if onClick then
    tab:SetScript("OnClick", onClick)
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
    self.text:SetText(UILib:FormatMoneyString(copper, showSign))
  end

  return frame
end
