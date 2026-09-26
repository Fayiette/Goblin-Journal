local addonName, addonTable = ...

addonTable.UI = {}
local UI = addonTable.UI
local C = addonTable.Constants
local UILib = addonTable.UILib
local Engine = addonTable.Engine

-- UI State
local state = {
  activeView = "day", -- "day", "week", "month", "session", "wealth"
  selectedDate = nil,
  selectedWeekKey = nil,
  selectedMonth = nil,
  selectedYear = nil,
  selectedZone = "All",
  selectedSessionIndex = nil,
  isSessionDetailActive = false,
}

-- UI Widget References (Consolidated table to avoid Lua 5.1 60 upvalue limit)
local w = {
  inCatRows = {},
  outCatRows = {},
  weekInCatRows = {},
  weekOutCatRows = {},
  monthInCatRows = {},
  monthOutCatRows = {},
  sessionInCatRows = {},
  sessionOutCatRows = {},
  dayTableRows = {},
  weekTableRows = {},
  monthTableRows = {},
  sessionTableRows = {},
  wealthTableRows = {},
  zonePills = {},
}

-------------------------------------------------------------------------------
-- ROW BUILDERS (Frame Pooling - Zero Allocation on Update)
-------------------------------------------------------------------------------

local function CreateCategoryRow(parent, yOffset, isIncoming)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(C.CARD_CAT_WIDTH - 20, 22)
  row:SetPoint("TOPLEFT", 10, yOffset)

  local name = row:CreateFontString(nil, "OVERLAY")
  name:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  name:SetPoint("LEFT", 0, 0)
  name:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  name:SetWidth(115)
  name:SetJustifyH("LEFT")
  row.name = name

  local bar = UILib:CreateProgressBar(row, 55, 5, isIncoming)
  bar:SetPoint("LEFT", name, "RIGHT", 4, 0)
  row.bar = bar

  local pct = row:CreateFontString(nil, "OVERLAY")
  pct:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  pct:SetPoint("LEFT", bar, "RIGHT", 4, 0)
  pct:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  pct:SetWidth(30)
  pct:SetJustifyH("RIGHT")
  row.pct = pct

  local amount = row:CreateFontString(nil, "OVERLAY")
  amount:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "OUTLINE")
  amount:SetPoint("RIGHT", 0, 0)
  amount:SetJustifyH("RIGHT")
  row.amount = amount

  return row
end

local function CreateLedgerRow(parent, yOffset)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(C.CARD_BOTTOM_WIDTH - 20, 20)
  row:SetPoint("TOPLEFT", 10, yOffset)

  local bg = row:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(C.COLORS.ROW_HOVER.r, C.COLORS.ROW_HOVER.g, C.COLORS.ROW_HOVER.b, 0)
  row.bg = bg

  local activeHighlight = row:CreateTexture(nil, "BORDER")
  activeHighlight:SetPoint("TOPLEFT", 0, 0)
  activeHighlight:SetPoint("BOTTOMLEFT", 0, 0)
  activeHighlight:SetWidth(3)
  activeHighlight:SetColorTexture(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b, 1)
  activeHighlight:Hide()
  row.activeHighlight = activeHighlight

  local col1 = row:CreateFontString(nil, "OVERLAY")
  col1:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  col1:SetPoint("LEFT", 6, 0)
  col1:SetWidth(110)
  col1:SetJustifyH("LEFT")
  row.col1 = col1

  local col2 = row:CreateFontString(nil, "OVERLAY")
  col2:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  col2:SetPoint("LEFT", col1, "RIGHT", 14, 0)
  col2:SetWidth(140)
  col2:SetJustifyH("LEFT")
  row.col2 = col2

  local col3 = row:CreateFontString(nil, "OVERLAY")
  col3:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  col3:SetPoint("LEFT", col2, "RIGHT", 14, 0)
  col3:SetWidth(140)
  col3:SetJustifyH("LEFT")
  row.col3 = col3

  local col4 = row:CreateFontString(nil, "OVERLAY")
  col4:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "OUTLINE")
  col4:SetPoint("LEFT", col3, "RIGHT", 14, 0)
  col4:SetWidth(130)
  col4:SetJustifyH("RIGHT")
  row.col4 = col4

  local btnAction = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  btnAction:SetSize(60, 16)
  btnAction:SetPoint("RIGHT", -6, 0)
  btnAction:SetText("Select")
  btnAction:SetNormalFontObject("GameFontHighlightSmall")
  row.btnAction = btnAction

  row:SetScript("OnEnter", function(self)
    self.bg:SetColorTexture(C.COLORS.ROW_HOVER.r, C.COLORS.ROW_HOVER.g, C.COLORS.ROW_HOVER.b, 0.4)
  end)

  row:SetScript("OnLeave", function(self)
    if not self.isActive then
      self.bg:SetColorTexture(C.COLORS.ROW_HOVER.r, C.COLORS.ROW_HOVER.g, C.COLORS.ROW_HOVER.b, 0)
    else
      self.bg:SetColorTexture(C.COLORS.ROW_ACTIVE.r, C.COLORS.ROW_ACTIVE.g, C.COLORS.ROW_ACTIVE.b, 0.6)
    end
  end)

  function row:SetActive(active)
    self.isActive = active
    if active then
      self.activeHighlight:Show()
      self.bg:SetColorTexture(C.COLORS.ROW_ACTIVE.r, C.COLORS.ROW_ACTIVE.g, C.COLORS.ROW_ACTIVE.b, 0.6)
    else
      self.activeHighlight:Hide()
      self.bg:SetColorTexture(C.COLORS.ROW_HOVER.r, C.COLORS.ROW_HOVER.g, C.COLORS.ROW_HOVER.b, 0)
    end
  end

  return row
end

local function CreateSessionRow(parent, yOffset)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(C.CARD_BOTTOM_WIDTH - 20, 24)
  row:SetPoint("TOPLEFT", 10, yOffset)

  local bg = row:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(C.COLORS.ROW_HOVER.r, C.COLORS.ROW_HOVER.g, C.COLORS.ROW_HOVER.b, 0)
  row.bg = bg

  local col1 = row:CreateFontString(nil, "OVERLAY")
  col1:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  col1:SetPoint("LEFT", 6, 0)
  col1:SetWidth(180)
  col1:SetJustifyH("LEFT")
  row.col1 = col1

  local colZone = row:CreateFontString(nil, "OVERLAY")
  colZone:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  colZone:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  colZone:SetPoint("LEFT", col1, "RIGHT", 8, 0)
  colZone:SetWidth(95)
  colZone:SetJustifyH("LEFT")
  row.colZone = colZone

  local col2 = row:CreateFontString(nil, "OVERLAY")
  col2:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  col2:SetPoint("LEFT", colZone, "RIGHT", 8, 0)
  col2:SetWidth(95)
  col2:SetJustifyH("LEFT")
  row.col2 = col2

  local col3 = row:CreateFontString(nil, "OVERLAY")
  col3:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  col3:SetPoint("LEFT", col2, "RIGHT", 8, 0)
  col3:SetWidth(95)
  col3:SetJustifyH("LEFT")
  row.col3 = col3

  local col4 = row:CreateFontString(nil, "OVERLAY")
  col4:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  col4:SetPoint("LEFT", col3, "RIGHT", 8, 0)
  col4:SetWidth(110)
  col4:SetJustifyH("RIGHT")
  row.col4 = col4

  local btnAction = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  btnAction:SetSize(45, 18)
  btnAction:SetPoint("RIGHT", -6, 0)
  btnAction:SetText("View")
  btnAction:SetNormalFontObject("GameFontHighlightSmall")
  row.btnAction = btnAction

  row:SetScript("OnEnter", function(self)
    self.bg:SetColorTexture(C.COLORS.ROW_HOVER.r, C.COLORS.ROW_HOVER.g, C.COLORS.ROW_HOVER.b, 0.4)
  end)

  row:SetScript("OnLeave", function(self)
    self.bg:SetColorTexture(C.COLORS.ROW_HOVER.r, C.COLORS.ROW_HOVER.g, C.COLORS.ROW_HOVER.b, 0)
  end)

  return row
end

local function CreateWealthRow(parent, yOffset)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(C.CARD_BOTTOM_WIDTH - 20, 26)
  row:SetPoint("TOPLEFT", 10, yOffset)

  local bg = row:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(C.COLORS.ROW_HOVER.r, C.COLORS.ROW_HOVER.g, C.COLORS.ROW_HOVER.b, 0)
  row.bg = bg

  -- 1. Status / Active Button / Label
  local btnStatus = UILib:CreateButton(row, "Set Active", 74, 18)
  btnStatus:SetPoint("LEFT", 4, 0)
  row.btnStatus = btnStatus

  local statusLabel = row:CreateFontString(nil, "OVERLAY")
  statusLabel:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "OUTLINE")
  statusLabel:SetPoint("LEFT", 6, 0)
  statusLabel:Hide()
  row.statusLabel = statusLabel

  -- 2. Title
  local colTitle = row:CreateFontString(nil, "OVERLAY")
  colTitle:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  colTitle:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  colTitle:SetPoint("LEFT", 84, 0)
  colTitle:SetWidth(175)
  colTitle:SetJustifyH("LEFT")
  row.colTitle = colTitle

  -- 3. Progress / Target (Combined column: bar + text + pct)
  local barFrame = CreateFrame("Frame", nil, row)
  barFrame:SetSize(75, 6)
  barFrame:SetPoint("LEFT", colTitle, "RIGHT", 8, 0)

  local barBg = barFrame:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints()
  barBg:SetColorTexture(0.04, 0.06, 0.09, 0.9)

  local barFill = barFrame:CreateTexture(nil, "ARTWORK")
  barFill:SetPoint("TOPLEFT", 0, 0)
  barFill:SetPoint("BOTTOMLEFT", 0, 0)
  barFill:SetWidth(0)
  barFill:SetColorTexture(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b, 0.9)
  barFrame.fill = barFill
  row.barFrame = barFrame

  local colProgress = row:CreateFontString(nil, "OVERLAY")
  colProgress:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  colProgress:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  colProgress:SetPoint("LEFT", barFrame, "RIGHT", 6, 0)
  colProgress:SetWidth(115)
  colProgress:SetJustifyH("LEFT")
  row.colProgress = colProgress

  -- 4. Character & Faction
  local colChar = row:CreateFontString(nil, "OVERLAY")
  colChar:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  colChar:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  colChar:SetPoint("LEFT", colProgress, "RIGHT", 6, 0)
  colChar:SetWidth(105)
  colChar:SetJustifyH("LEFT")
  row.colChar = colChar

  -- 5. Manage Button
  local btnManage = UILib:CreateButton(row, "Manage", 60, 18)
  btnManage:SetPoint("RIGHT", -6, 0)
  row.btnManage = btnManage

  return row
end

-------------------------------------------------------------------------------
-- MAIN FRAME INITIALIZATION
-------------------------------------------------------------------------------

local function BuildUI()
  if w.mainFrame then return end

  state.selectedDate = Engine:GetTodayDate()
  state.selectedMonth = Engine:GetTodayMonth()
  state.selectedYear = Engine:GetTodayYear()

  -- 1. Outer Frame (Fixed Height: 615px)
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  w.mainFrame = CreateFrame("Frame", "GoblinJournalFrame", UIParent, template)
  w.mainFrame:Hide()
  w.mainFrame:SetSize(C.FRAME_WIDTH, C.FRAME_HEIGHT)
  w.mainFrame:SetPoint("CENTER")
  w.mainFrame:SetFrameStrata("MEDIUM")
  w.mainFrame:SetMovable(true)
  w.mainFrame:EnableMouse(true)
  w.mainFrame:SetClampedToScreen(true)
  w.mainFrame:RegisterForDrag("LeftButton")
  w.mainFrame:SetScript("OnDragStart", w.mainFrame.StartMoving)
  w.mainFrame:SetScript("OnDragStop", w.mainFrame.StopMovingOrSizing)
  w.mainFrame:SetBackdrop(C.MAIN_BACKDROP)

  local bg = C.COLORS.CARD_BG
  w.mainFrame:SetBackdropColor(bg.r, bg.g, bg.b, 0.96)
  local gb = C.COLORS.GOLD_BORDER
  w.mainFrame:SetBackdropBorderColor(gb.r, gb.g, gb.b, 1.0)

  table.insert(UISpecialFrames, "GoblinJournalFrame")

  -- 2. Header
  local header = CreateFrame("Frame", nil, w.mainFrame)
  header:SetSize(C.FRAME_WIDTH, 44)
  header:SetPoint("TOPLEFT", 0, 0)

  local coinIcon = header:CreateTexture(nil, "ARTWORK")
  coinIcon:SetSize(22, 22)
  coinIcon:SetPoint("TOPLEFT", 12, -10)
  coinIcon:SetTexture(C.LOGO_TEXTURE or C.COIN_TEXTURE_GOLD)

  local title = header:CreateFontString(nil, "OVERLAY")
  title:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TITLE, "OUTLINE")
  title:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  title:SetPoint("LEFT", coinIcon, "RIGHT", 6, 0)
  title:SetText(C.TITLE)

  -- Version tag at half font size (9pt)
  local verTag = header:CreateFontString(nil, "OVERLAY")
  verTag:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_VERSION, "")
  verTag:SetTextColor(C.COLORS.VERSION.r, C.COLORS.VERSION.g, C.COLORS.VERSION.b)
  verTag:SetPoint("LEFT", title, "RIGHT", 6, -3)
  verTag:SetText("v" .. C.VERSION)

  local subtitle = header:CreateFontString(nil, "OVERLAY")
  subtitle:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  subtitle:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  subtitle:SetPoint("TOPLEFT", coinIcon, "BOTTOMLEFT", 0, -2)
  subtitle:SetText("Daily & Monthly Financial Accounting Ledger")

  local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
  closeBtn:SetSize(22, 22)
  closeBtn:SetPoint("TOPRIGHT", -8, -6)
  closeBtn:SetScript("OnClick", function() w.mainFrame:Hide() end)

  -- Active ruleset badge next to close button
  w.rulesetBadge = header:CreateFontString(nil, "OVERLAY")
  w.rulesetBadge:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  w.rulesetBadge:SetTextColor(C.COLORS.VERSION.r, C.COLORS.VERSION.g, C.COLORS.VERSION.b)
  w.rulesetBadge:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)

  -- Export Button next to ruleset badge
  w.btnExport = UILib:CreateButton(header, "Export", 54, 18, function()
    if w.exportModal then
      w.exportModal:Open()
    end
  end)
  w.btnExport:SetPoint("RIGHT", w.rulesetBadge, "LEFT", -6, 0)

  -- Scope Filter Buttons directly under X (WCAG 2 AAA Contrast & Legibility)
  w.btnScopeHorde = UILib:CreateScopeButton(header, "Horde", 52, 20, "horde", function()
    UI:SetScope("horde")
  end)
  w.btnScopeHorde:SetPoint("TOPRIGHT", header, "TOPRIGHT", -8, -25)

  w.btnScopeAlliance = UILib:CreateScopeButton(header, "Alliance", 62, 20, "alliance", function()
    UI:SetScope("alliance")
  end)
  w.btnScopeAlliance:SetPoint("RIGHT", w.btnScopeHorde, "LEFT", -4, 0)

  w.btnScopeChar = UILib:CreateScopeButton(header, "Current Character", 116, 20, "character", function()
    UI:SetScope("character")
  end)
  w.btnScopeChar:SetPoint("RIGHT", w.btnScopeAlliance, "LEFT", -4, 0)

  -- 3. Navigation Bar (Tabs + Navigators)
  local navBar = CreateFrame("Frame", nil, w.mainFrame)
  navBar:SetSize(C.FRAME_WIDTH - 20, 36)
  navBar:SetPoint("TOPLEFT", 10, -48)

  w.tabDay = UILib:CreateTabButton(navBar, "Day", 52, 26, function()
    UI:SetView("day")
  end)
  w.tabDay:SetPoint("LEFT", 0, 0)

  w.tabWeek = UILib:CreateTabButton(navBar, "Week", 54, 26, function()
    UI:SetView("week")
  end)
  w.tabWeek:SetPoint("LEFT", w.tabDay, "RIGHT", 4, 0)

  w.tabMonth = UILib:CreateTabButton(navBar, "Month", 58, 26, function()
    UI:SetView("month")
  end)
  w.tabMonth:SetPoint("LEFT", w.tabWeek, "RIGHT", 4, 0)

  w.tabSession = UILib:CreateTabButton(navBar, "Session", 64, 26, function()
    UI:SetView("session")
  end)
  w.tabSession:SetPoint("LEFT", w.tabMonth, "RIGHT", 4, 0)

  w.tabWealth = UILib:CreateTabButton(navBar, "Wealth", 64, 26, function()
    UI:SetView("wealth")
  end)
  w.tabWealth:SetPoint("LEFT", w.tabSession, "RIGHT", 4, 0)

  -- Date Navigator Group (Day / Week / Month Views)
  w.navDateGroup = CreateFrame("Frame", nil, navBar)
  w.navDateGroup:SetPoint("LEFT", w.tabWealth, "RIGHT", 8, 0)
  w.navDateGroup:SetPoint("RIGHT", navBar, "RIGHT", 0, 0)
  w.navDateGroup:SetHeight(36)

  w.btnToday = UILib:CreateButton(w.navDateGroup, "Today", 76, 22, function()
    UI:SetToday()
  end)
  w.btnToday:SetPoint("RIGHT", w.navDateGroup, "RIGHT", 0, 0)

  w.btnNextDate = UILib:CreateButton(w.navDateGroup, ">", 22, 22, function()
    UI:NavigateDate(1)
  end)
  w.btnNextDate:SetPoint("RIGHT", w.btnToday, "LEFT", -4, 0)

  w.btnPrevDate = UILib:CreateButton(w.navDateGroup, "<", 22, 22, function()
    UI:NavigateDate(-1)
  end)
  w.btnPrevDate:SetPoint("LEFT", w.navDateGroup, "LEFT", 4, 0)

  w.dateLabel = w.navDateGroup:CreateFontString(nil, "OVERLAY")
  w.dateLabel:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  w.dateLabel:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  w.dateLabel:SetPoint("LEFT", w.btnPrevDate, "RIGHT", 4, 0)
  w.dateLabel:SetPoint("RIGHT", w.btnNextDate, "LEFT", -4, 0)
  w.dateLabel:SetJustifyH("CENTER")

  -- Session Controls Group (Session View)
  w.navSessionGroup = CreateFrame("Frame", nil, navBar)
  w.navSessionGroup:SetPoint("LEFT", w.tabWealth, "RIGHT", 8, 0)
  w.navSessionGroup:SetPoint("RIGHT", navBar, "RIGHT", 0, 0)
  w.navSessionGroup:SetHeight(36)
  w.navSessionGroup:Hide()

  w.btnToggleTimer = UILib:CreateButton(w.navSessionGroup, "Start Timer", 90, 22, function()
    UI:ToggleSessionTimer()
  end)
  w.btnToggleTimer:SetPoint("RIGHT", w.navSessionGroup, "RIGHT", 0, 0)

  w.btnBack = UILib:CreateButton(w.navSessionGroup, "Back", 54, 22, function()
    UI:BackToSessionLedger()
  end)
  w.btnBack:SetPoint("LEFT", w.navSessionGroup, "LEFT", 0, 0)
  w.btnBack:Hide()

  w.sessionNavLabel = w.navSessionGroup:CreateFontString(nil, "OVERLAY")
  w.sessionNavLabel:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  w.sessionNavLabel:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  w.sessionNavLabel:SetPoint("LEFT", w.btnBack, "RIGHT", 8, 0)
  w.sessionNavLabel:SetPoint("RIGHT", w.btnToggleTimer, "LEFT", -8, 0)
  w.sessionNavLabel:SetJustifyH("LEFT")

  -- Wealth Controls Group (Wealth View)
  w.navWealthGroup = CreateFrame("Frame", nil, navBar)
  w.navWealthGroup:SetPoint("LEFT", w.tabWealth, "RIGHT", 8, 0)
  w.navWealthGroup:SetPoint("RIGHT", navBar, "RIGHT", 0, 0)
  w.navWealthGroup:SetHeight(36)
  w.navWealthGroup:Hide()

  w.wealthNavLabel = w.navWealthGroup:CreateFontString(nil, "OVERLAY")
  w.wealthNavLabel:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  w.wealthNavLabel:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  w.wealthNavLabel:SetPoint("LEFT", 0, 0)
  w.wealthNavLabel:SetText("Wealth Goals Ledger")

  w.btnFocusNewGoal = UILib:CreateButton(w.navWealthGroup, "+ New Goal", 85, 22, function()
    if w.newGoalTitleInput then
      w.newGoalTitleInput:SetFocus()
    end
  end)
  w.btnFocusNewGoal:SetPoint("RIGHT", 0, 0)

  -- 4. Hero Summary Card (Center: Net Result (+/- in Green/Red))
  w.heroCard = UILib:CreateCard(w.mainFrame, "", C.FRAME_WIDTH - 20, C.HERO_BANNER_HEIGHT, false)
  w.heroCard:SetPoint("TOPLEFT", 10, -84)

  -- Income Column
  local lblIn = w.heroCard:CreateFontString(nil, "OVERLAY")
  lblIn:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  lblIn:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  lblIn:SetPoint("TOPLEFT", 14, -10)
  lblIn:SetText("TOTAL INCOMING")

  w.heroIncomeDisplay = w.heroCard:CreateFontString(nil, "OVERLAY")
  w.heroIncomeDisplay:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  w.heroIncomeDisplay:SetPoint("TOPLEFT", lblIn, "BOTTOMLEFT", 0, -4)
  w.heroIncomeDisplay:SetTextColor(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)

  -- Outgoing Column
  local lblOut = w.heroCard:CreateFontString(nil, "OVERLAY")
  lblOut:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  lblOut:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  lblOut:SetPoint("TOPRIGHT", -14, -10)
  lblOut:SetText("TOTAL OUTGOING")

  w.heroExpenseDisplay = w.heroCard:CreateFontString(nil, "OVERLAY")
  w.heroExpenseDisplay:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  w.heroExpenseDisplay:SetPoint("TOPRIGHT", lblOut, "BOTTOMRIGHT", 0, -4)
  w.heroExpenseDisplay:SetTextColor(C.COLORS.ORANGE.r, C.COLORS.ORANGE.g, C.COLORS.ORANGE.b)

  -- Net Center Display
  local lblNet = w.heroCard:CreateFontString(nil, "OVERLAY")
  lblNet:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  lblNet:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  lblNet:SetPoint("TOP", 0, -8)
  lblNet:SetText("NET RESULT")

  w.heroNetText = w.heroCard:CreateFontString(nil, "OVERLAY")
  w.heroNetText:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_HERO_NET, "OUTLINE")
  w.heroNetText:SetPoint("TOP", lblNet, "BOTTOM", 0, -3)

  w.heroNetBadge = w.heroCard:CreateFontString(nil, "OVERLAY")
  w.heroNetBadge:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  w.heroNetBadge:SetPoint("TOP", w.heroNetText, "BOTTOM", 0, -2)

  -----------------------------------------------------------------------------
  -- DAY VIEW CONTAINER
  -----------------------------------------------------------------------------
  w.dayViewContainer = CreateFrame("Frame", nil, w.mainFrame)
  w.dayViewContainer:SetSize(C.FRAME_WIDTH - 20, 400)
  w.dayViewContainer:SetPoint("TOPLEFT", 10, -170)

  -- Top-Left Card: Day Incoming Categories
  local inCard = UILib:CreateCard(w.dayViewContainer, "Incoming by Source", C.CARD_CAT_WIDTH, C.CARD_CAT_HEIGHT, false)
  inCard:SetPoint("TOPLEFT", 0, 0)
  w.inCardTitleBadge = inCard:CreateFontString(nil, "OVERLAY")
  w.inCardTitleBadge:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "OUTLINE")
  w.inCardTitleBadge:SetPoint("TOPRIGHT", -10, -8)
  w.inCardTitleBadge:SetTextColor(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)
  for idx, cat in ipairs(C.INCOME_CATEGORIES) do
    local row = CreateCategoryRow(inCard, -26 - (idx - 1) * 26, true)
    row.name:SetText(cat.name)
    w.inCatRows[cat.id] = row
  end

  -- Top-Right Card: Day Outgoing Categories
  local outCard = UILib:CreateCard(w.dayViewContainer, "Outgoing by Expense", C.CARD_CAT_WIDTH, C.CARD_CAT_HEIGHT, false)
  outCard:SetPoint("TOPRIGHT", 0, 0)
  w.outCardTitleBadge = outCard:CreateFontString(nil, "OVERLAY")
  w.outCardTitleBadge:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "OUTLINE")
  w.outCardTitleBadge:SetPoint("TOPRIGHT", -10, -8)
  w.outCardTitleBadge:SetTextColor(C.COLORS.ORANGE.r, C.COLORS.ORANGE.g, C.COLORS.ORANGE.b)
  for idx, cat in ipairs(C.EXPENSE_CATEGORIES) do
    local row = CreateCategoryRow(outCard, -24 - (idx - 1) * 24, false)
    row.name:SetText(cat.name)
    w.outCatRows[cat.id] = row
  end

  -- Bottom Card: Day-by-Day Monthly Performance Table
  local dayTableCard = UILib:CreateCard(w.dayViewContainer, "Day-by-Day Monthly Performance", C.CARD_BOTTOM_WIDTH, C.CARD_BOTTOM_HEIGHT, false)
  dayTableCard:SetPoint("TOPLEFT", 0, -214)

  -- Header Titles for Table
  local thDate = dayTableCard:CreateFontString(nil, "OVERLAY")
  thDate:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  thDate:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  thDate:SetPoint("TOPLEFT", 16, -26)
  thDate:SetText("DATE")

  local thIn = dayTableCard:CreateFontString(nil, "OVERLAY")
  thIn:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  thIn:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  thIn:SetPoint("LEFT", thDate, "RIGHT", 82, 0)
  thIn:SetText("TOTAL INCOME")

  local thOut = dayTableCard:CreateFontString(nil, "OVERLAY")
  thOut:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  thOut:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  thOut:SetPoint("LEFT", thIn, "RIGHT", 68, 0)
  thOut:SetText("TOTAL EXPENSES")

  local thNet = dayTableCard:CreateFontString(nil, "OVERLAY")
  thNet:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  thNet:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  thNet:SetPoint("LEFT", thOut, "RIGHT", 62, 0)
  thNet:SetText("DAILY NET (+/-)")

  for i = 1, 6 do
    local r = CreateLedgerRow(dayTableCard, -42 - (i - 1) * 21)
    table.insert(w.dayTableRows, r)
  end

  w.dayTableEmpty = dayTableCard:CreateFontString(nil, "OVERLAY")
  w.dayTableEmpty:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "")
  w.dayTableEmpty:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  w.dayTableEmpty:SetPoint("CENTER", 0, -10)
  w.dayTableEmpty:SetText("No daily transactions recorded for this month.")
  w.dayTableEmpty:Hide()

  -----------------------------------------------------------------------------
  -- WEEK VIEW CONTAINER (Feature G: WoW Reset Week View)
  -----------------------------------------------------------------------------
  w.weekViewContainer = CreateFrame("Frame", nil, w.mainFrame)
  w.weekViewContainer:SetSize(C.FRAME_WIDTH - 20, 400)
  w.weekViewContainer:SetPoint("TOPLEFT", 10, -170)
  w.weekViewContainer:Hide()

  -- Top-Left Card: Weekly Incoming Categories
  local weekInCard = UILib:CreateCard(w.weekViewContainer, "Weekly Incoming by Source", C.CARD_CAT_WIDTH, C.CARD_CAT_HEIGHT, false)
  weekInCard:SetPoint("TOPLEFT", 0, 0)
  w.weekInCardTitleBadge = weekInCard:CreateFontString(nil, "OVERLAY")
  w.weekInCardTitleBadge:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "OUTLINE")
  w.weekInCardTitleBadge:SetPoint("TOPRIGHT", -10, -8)
  w.weekInCardTitleBadge:SetTextColor(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)
  for idx, cat in ipairs(C.INCOME_CATEGORIES) do
    local row = CreateCategoryRow(weekInCard, -26 - (idx - 1) * 26, true)
    row.name:SetText(cat.name)
    w.weekInCatRows[cat.id] = row
  end

  -- Top-Right Card: Weekly Outgoing Categories
  local weekOutCard = UILib:CreateCard(w.weekViewContainer, "Weekly Outgoing by Expense", C.CARD_CAT_WIDTH, C.CARD_CAT_HEIGHT, false)
  weekOutCard:SetPoint("TOPRIGHT", 0, 0)
  w.weekOutCardTitleBadge = weekOutCard:CreateFontString(nil, "OVERLAY")
  w.weekOutCardTitleBadge:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "OUTLINE")
  w.weekOutCardTitleBadge:SetPoint("TOPRIGHT", -10, -8)
  w.weekOutCardTitleBadge:SetTextColor(C.COLORS.ORANGE.r, C.COLORS.ORANGE.g, C.COLORS.ORANGE.b)
  for idx, cat in ipairs(C.EXPENSE_CATEGORIES) do
    local row = CreateCategoryRow(weekOutCard, -24 - (idx - 1) * 24, false)
    row.name:SetText(cat.name)
    w.weekOutCatRows[cat.id] = row
  end

  -- Bottom Card: 7-Day Performance Table
  local weekTableCard = UILib:CreateCard(w.weekViewContainer, "7-Day Performance Table", C.CARD_BOTTOM_WIDTH, C.CARD_BOTTOM_HEIGHT, false)
  weekTableCard:SetPoint("TOPLEFT", 0, -214)

  local wthDate = weekTableCard:CreateFontString(nil, "OVERLAY")
  wthDate:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  wthDate:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  wthDate:SetPoint("TOPLEFT", 16, -26)
  wthDate:SetText("DATE")

  local wthIn = weekTableCard:CreateFontString(nil, "OVERLAY")
  wthIn:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  wthIn:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  wthIn:SetPoint("LEFT", wthDate, "RIGHT", 82, 0)
  wthIn:SetText("TOTAL INCOME")

  local wthOut = weekTableCard:CreateFontString(nil, "OVERLAY")
  wthOut:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  wthOut:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  wthOut:SetPoint("LEFT", wthIn, "RIGHT", 68, 0)
  wthOut:SetText("TOTAL EXPENSES")

  local wthNet = weekTableCard:CreateFontString(nil, "OVERLAY")
  wthNet:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  wthNet:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  wthNet:SetPoint("LEFT", wthOut, "RIGHT", 62, 0)
  wthNet:SetText("DAILY NET (+/-)")

  for i = 1, 7 do
    local r = CreateLedgerRow(weekTableCard, -42 - (i - 1) * 21)
    table.insert(w.weekTableRows, r)
  end

  w.weekTableEmpty = weekTableCard:CreateFontString(nil, "OVERLAY")
  w.weekTableEmpty:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "")
  w.weekTableEmpty:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  w.weekTableEmpty:SetPoint("CENTER", 0, -10)
  w.weekTableEmpty:SetText("No daily transactions recorded for this week.")
  w.weekTableEmpty:Hide()

  -----------------------------------------------------------------------------
  -- MONTH VIEW CONTAINER
  -----------------------------------------------------------------------------
  w.monthViewContainer = CreateFrame("Frame", nil, w.mainFrame)
  w.monthViewContainer:SetSize(C.FRAME_WIDTH - 20, 400)
  w.monthViewContainer:SetPoint("TOPLEFT", 10, -170)
  w.monthViewContainer:Hide()

  -- Top-Left Card: Monthly Aggregated Revenue
  local monthInCard = UILib:CreateCard(w.monthViewContainer, "Monthly Top Revenue", C.CARD_CAT_WIDTH, C.CARD_CAT_HEIGHT, false)
  monthInCard:SetPoint("TOPLEFT", 0, 0)
  w.monthInCardTitleBadge = monthInCard:CreateFontString(nil, "OVERLAY")
  w.monthInCardTitleBadge:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "OUTLINE")
  w.monthInCardTitleBadge:SetPoint("TOPRIGHT", -10, -8)
  w.monthInCardTitleBadge:SetTextColor(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)
  for idx, cat in ipairs(C.INCOME_CATEGORIES) do
    local row = CreateCategoryRow(monthInCard, -26 - (idx - 1) * 26, true)
    row.name:SetText(cat.name)
    w.monthInCatRows[cat.id] = row
  end

  -- Top-Right Card: Monthly Aggregated Expenses
  local monthOutCard = UILib:CreateCard(w.monthViewContainer, "Monthly Top Expenses", C.CARD_CAT_WIDTH, C.CARD_CAT_HEIGHT, false)
  monthOutCard:SetPoint("TOPRIGHT", 0, 0)
  w.monthOutCardTitleBadge = monthOutCard:CreateFontString(nil, "OVERLAY")
  w.monthOutCardTitleBadge:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "OUTLINE")
  w.monthOutCardTitleBadge:SetPoint("TOPRIGHT", -10, -8)
  w.monthOutCardTitleBadge:SetTextColor(C.COLORS.ORANGE.r, C.COLORS.ORANGE.g, C.COLORS.ORANGE.b)
  for idx, cat in ipairs(C.EXPENSE_CATEGORIES) do
    local row = CreateCategoryRow(monthOutCard, -24 - (idx - 1) * 24, false)
    row.name:SetText(cat.name)
    w.monthOutCatRows[cat.id] = row
  end

  -- Bottom Card: Month-by-Month Annual Performance Table
  local monthTableCard = UILib:CreateCard(w.monthViewContainer, "Month-by-Month Annual Performance", C.CARD_BOTTOM_WIDTH, C.CARD_BOTTOM_HEIGHT, false)
  monthTableCard:SetPoint("TOPLEFT", 0, -214)

  local mthDate = monthTableCard:CreateFontString(nil, "OVERLAY")
  mthDate:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  mthDate:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  mthDate:SetPoint("TOPLEFT", 16, -26)
  mthDate:SetText("MONTH")

  local mthIn = monthTableCard:CreateFontString(nil, "OVERLAY")
  mthIn:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  mthIn:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  mthIn:SetPoint("LEFT", mthDate, "RIGHT", 74, 0)
  mthIn:SetText("TOTAL INCOME")

  local mthOut = monthTableCard:CreateFontString(nil, "OVERLAY")
  mthOut:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  mthOut:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  mthOut:SetPoint("LEFT", mthIn, "RIGHT", 68, 0)
  mthOut:SetText("TOTAL EXPENSES")

  local mthNet = monthTableCard:CreateFontString(nil, "OVERLAY")
  mthNet:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  mthNet:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  mthNet:SetPoint("LEFT", mthOut, "RIGHT", 62, 0)
  mthNet:SetText("MONTHLY NET (+/-)")

  for i = 1, 6 do
    local r = CreateLedgerRow(monthTableCard, -42 - (i - 1) * 21)
    table.insert(w.monthTableRows, r)
  end

  w.monthTableEmpty = monthTableCard:CreateFontString(nil, "OVERLAY")
  w.monthTableEmpty:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "")
  w.monthTableEmpty:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  w.monthTableEmpty:SetPoint("CENTER", 0, -10)
  w.monthTableEmpty:SetText("No monthly transactions recorded for this year.")
  w.monthTableEmpty:Hide()

  -----------------------------------------------------------------------------
  -- SESSION VIEW CONTAINER
  -----------------------------------------------------------------------------
  w.sessionViewContainer = CreateFrame("Frame", nil, w.mainFrame)
  w.sessionViewContainer:SetSize(C.FRAME_WIDTH - 20, 488)
  w.sessionViewContainer:SetPoint("TOPLEFT", 10, -84)
  w.sessionViewContainer:Hide()

  -----------------------------------------------------------------------------
  -- SESSION LIST CONTAINER (Pure Recorded Sessions Ledger)
  -----------------------------------------------------------------------------
  w.sessionListContainer = CreateFrame("Frame", nil, w.sessionViewContainer)
  w.sessionListContainer:SetSize(C.FRAME_WIDTH - 20, 488)
  w.sessionListContainer:SetPoint("TOPLEFT", 0, 0)

  local sessionListCard = UILib:CreateCard(w.sessionListContainer, "Recorded Sessions Ledger", C.FRAME_WIDTH - 20, 480, false)
  sessionListCard:SetPoint("TOPLEFT", 0, 0)

  -- Session Cap Controls in Card Header
  w.capBtnUnlimited = UILib:CreateScopeButton(sessionListCard, "Unlimited", 68, 20, "cap0", function()
    UI:OnSessionCapClicked(0)
  end)
  w.capBtnUnlimited:SetPoint("TOPRIGHT", sessionListCard, "TOPRIGHT", -10, -6)

  w.capBtn200 = UILib:CreateScopeButton(sessionListCard, "200", 38, 20, "cap200", function()
    UI:OnSessionCapClicked(200)
  end)
  w.capBtn200:SetPoint("RIGHT", w.capBtnUnlimited, "LEFT", -4, 0)

  w.capBtn100 = UILib:CreateScopeButton(sessionListCard, "100", 38, 20, "cap100", function()
    UI:OnSessionCapClicked(100)
  end)
  w.capBtn100:SetPoint("RIGHT", w.capBtn200, "LEFT", -4, 0)

  w.capBtn50 = UILib:CreateScopeButton(sessionListCard, "50", 38, 20, "cap50", function()
    UI:OnSessionCapClicked(50)
  end)
  w.capBtn50:SetPoint("RIGHT", w.capBtn100, "LEFT", -4, 0)

  local capLabel = sessionListCard:CreateFontString(nil, "OVERLAY")
  capLabel:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  capLabel:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  capLabel:SetPoint("RIGHT", w.capBtn50, "LEFT", -6, 0)
  capLabel:SetText("Session Cap:")

  -- Table Header Titles
  local sthCol1 = sessionListCard:CreateFontString(nil, "OVERLAY")
  sthCol1:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  sthCol1:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  sthCol1:SetPoint("TOPLEFT", 16, -32)
  sthCol1:SetWidth(180)
  sthCol1:SetJustifyH("LEFT")
  sthCol1:SetText("SESSION / RECORD WINDOW")

  local sthColZone = sessionListCard:CreateFontString(nil, "OVERLAY")
  sthColZone:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  sthColZone:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  sthColZone:SetPoint("LEFT", sthCol1, "RIGHT", 8, 0)
  sthColZone:SetWidth(95)
  sthColZone:SetJustifyH("LEFT")
  sthColZone:SetText("ZONE")

  local sthCol2 = sessionListCard:CreateFontString(nil, "OVERLAY")
  sthCol2:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  sthCol2:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  sthCol2:SetPoint("LEFT", sthColZone, "RIGHT", 8, 0)
  sthCol2:SetWidth(95)
  sthCol2:SetJustifyH("LEFT")
  sthCol2:SetText("TOTAL INCOME")

  local sthCol3 = sessionListCard:CreateFontString(nil, "OVERLAY")
  sthCol3:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  sthCol3:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  sthCol3:SetPoint("LEFT", sthCol2, "RIGHT", 8, 0)
  sthCol3:SetWidth(95)
  sthCol3:SetJustifyH("LEFT")
  sthCol3:SetText("TOTAL EXPENSES")

  local sthCol4 = sessionListCard:CreateFontString(nil, "OVERLAY")
  sthCol4:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  sthCol4:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  sthCol4:SetPoint("LEFT", sthCol3, "RIGHT", 8, 0)
  sthCol4:SetWidth(110)
  sthCol4:SetJustifyH("RIGHT")
  sthCol4:SetText("SESSION NET (+/-)")

  local sthCol5 = sessionListCard:CreateFontString(nil, "OVERLAY")
  sthCol5:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  sthCol5:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  sthCol5:SetPoint("RIGHT", -16, 0)
  sthCol5:SetPoint("TOP", sthCol1, "TOP", 0, 0)
  sthCol5:SetWidth(45)
  sthCol5:SetJustifyH("CENTER")
  sthCol5:SetText("ACTION")

  for i = 1, 14 do
    local r = CreateSessionRow(sessionListCard, -48 - (i - 1) * 28)
    table.insert(w.sessionTableRows, r)
  end

  w.sessionTableEmpty = sessionListCard:CreateFontString(nil, "OVERLAY")
  w.sessionTableEmpty:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "")
  w.sessionTableEmpty:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  w.sessionTableEmpty:SetPoint("CENTER", 0, -10)
  w.sessionTableEmpty:SetText("No recorded sessions found for current scope.")
  w.sessionTableEmpty:Hide()

  -----------------------------------------------------------------------------
  -- SESSION DETAIL CONTAINER (Isolated Session Breakdown)
  -----------------------------------------------------------------------------
  w.sessionDetailContainer = CreateFrame("Frame", nil, w.sessionViewContainer)
  w.sessionDetailContainer:SetSize(C.FRAME_WIDTH - 20, 400)
  w.sessionDetailContainer:SetPoint("TOPLEFT", 0, -86)
  w.sessionDetailContainer:Hide()

  -- Top-Left Card: Session Incoming Categories
  local sessionInCard = UILib:CreateCard(w.sessionDetailContainer, "Session Incoming by Source", C.CARD_CAT_WIDTH, C.CARD_CAT_HEIGHT, false)
  sessionInCard:SetPoint("TOPLEFT", 0, 0)
  w.sessionCatTotalIn = sessionInCard:CreateFontString(nil, "OVERLAY")
  w.sessionCatTotalIn:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "OUTLINE")
  w.sessionCatTotalIn:SetPoint("TOPRIGHT", -10, -8)
  w.sessionCatTotalIn:SetTextColor(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)
  for idx, cat in ipairs(C.INCOME_CATEGORIES) do
    local row = CreateCategoryRow(sessionInCard, -26 - (idx - 1) * 26, true)
    row.name:SetText(cat.name)
    w.sessionInCatRows[cat.id] = row
  end

  -- Top-Right Card: Session Outgoing Categories
  local sessionOutCard = UILib:CreateCard(w.sessionDetailContainer, "Session Outgoing by Expense", C.CARD_CAT_WIDTH, C.CARD_CAT_HEIGHT, false)
  sessionOutCard:SetPoint("TOPRIGHT", 0, 0)
  w.sessionCatTotalOut = sessionOutCard:CreateFontString(nil, "OVERLAY")
  w.sessionCatTotalOut:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "OUTLINE")
  w.sessionCatTotalOut:SetPoint("TOPRIGHT", -10, -8)
  w.sessionCatTotalOut:SetTextColor(C.COLORS.ORANGE.r, C.COLORS.ORANGE.g, C.COLORS.ORANGE.b)
  for idx, cat in ipairs(C.EXPENSE_CATEGORIES) do
    local row = CreateCategoryRow(sessionOutCard, -24 - (idx - 1) * 24, false)
    row.name:SetText(cat.name)
    w.sessionOutCatRows[cat.id] = row
  end

  -- Bottom Card: Session Performance & Metrics + Adaptive Sparkline
  local sessionMetricsCard = UILib:CreateCard(w.sessionDetailContainer, "Session Performance & Metrics", C.CARD_BOTTOM_WIDTH, C.CARD_BOTTOM_HEIGHT, false)
  sessionMetricsCard:SetPoint("TOPLEFT", 0, -214)

  -- Metric Box 1: Duration
  local mBox1 = CreateFrame("Frame", nil, sessionMetricsCard)
  mBox1:SetSize(145, 42)
  mBox1:SetPoint("TOPLEFT", 14, -26)
  local mTitle1 = mBox1:CreateFontString(nil, "OVERLAY")
  mTitle1:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  mTitle1:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  mTitle1:SetPoint("TOPLEFT", 0, 0)
  mTitle1:SetText("DURATION")
  w.metricDuration = mBox1:CreateFontString(nil, "OVERLAY")
  w.metricDuration:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  w.metricDuration:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  w.metricDuration:SetPoint("TOPLEFT", mTitle1, "BOTTOMLEFT", 0, -2)

  -- Metric Box 2: Gold Rate
  local mBox2 = CreateFrame("Frame", nil, sessionMetricsCard)
  mBox2:SetSize(165, 42)
  mBox2:SetPoint("LEFT", mBox1, "RIGHT", 10, 0)
  local mTitle2 = mBox2:CreateFontString(nil, "OVERLAY")
  mTitle2:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  mTitle2:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  mTitle2:SetPoint("TOPLEFT", 0, 0)
  mTitle2:SetText("GOLD RATE")
  w.metricGPH = mBox2:CreateFontString(nil, "OVERLAY")
  w.metricGPH:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  w.metricGPH:SetPoint("TOPLEFT", mTitle2, "BOTTOMLEFT", 0, -2)

  -- Metric Box 3: Character & Realm
  local mBox3 = CreateFrame("Frame", nil, sessionMetricsCard)
  mBox3:SetSize(165, 42)
  mBox3:SetPoint("LEFT", mBox2, "RIGHT", 10, 0)
  local mTitle3 = mBox3:CreateFontString(nil, "OVERLAY")
  mTitle3:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  mTitle3:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  mTitle3:SetPoint("TOPLEFT", 0, 0)
  mTitle3:SetText("CHARACTER & REALM")
  w.metricChar = mBox3:CreateFontString(nil, "OVERLAY")
  w.metricChar:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  w.metricChar:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  w.metricChar:SetPoint("TOPLEFT", mTitle3, "BOTTOMLEFT", 0, -2)

  -- Metric Box 4: Recorded Window
  local mBox4 = CreateFrame("Frame", nil, sessionMetricsCard)
  mBox4:SetSize(165, 42)
  mBox4:SetPoint("LEFT", mBox3, "RIGHT", 10, 0)
  local mTitle4 = mBox4:CreateFontString(nil, "OVERLAY")
  mTitle4:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  mTitle4:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  mTitle4:SetPoint("TOPLEFT", 0, 0)
  mTitle4:SetText("RECORDED WINDOW")
  w.metricTimeRange = mBox4:CreateFontString(nil, "OVERLAY")
  w.metricTimeRange:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "OUTLINE")
  w.metricTimeRange:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  w.metricTimeRange:SetPoint("TOPLEFT", mTitle4, "BOTTOMLEFT", 0, -2)

  -- Adaptive Cash Flow Sparkline
  w.sessionSparkline = UILib:CreateSparklineFrame(sessionMetricsCard, 676, 56)
  w.sessionSparkline:SetPoint("TOPLEFT", 12, -92)

  -----------------------------------------------------------------------------
  -- WEALTH VIEW CONTAINER (Feature A: Dedicated Wealth Goals Ledger Page)
  -----------------------------------------------------------------------------
  w.wealthViewContainer = CreateFrame("Frame", nil, w.mainFrame)
  w.wealthViewContainer:SetSize(C.FRAME_WIDTH - 20, 480)
  w.wealthViewContainer:SetPoint("TOPLEFT", 10, -84)
  w.wealthViewContainer:Hide()

  -- Top Inline Creation Toolbar Card
  local toolbarCard = UILib:CreateCard(w.wealthViewContainer, "", C.FRAME_WIDTH - 20, 40, false)
  toolbarCard:SetPoint("TOPLEFT", 0, 0)

  local lblNewGoal = toolbarCard:CreateFontString(nil, "OVERLAY")
  lblNewGoal:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "OUTLINE")
  lblNewGoal:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  lblNewGoal:SetPoint("LEFT", 12, 0)
  lblNewGoal:SetText("+ New Goal:")

  local inputTitle = CreateFrame("EditBox", nil, toolbarCard, "InputBoxTemplate")
  inputTitle:SetSize(220, 22)
  inputTitle:SetPoint("LEFT", lblNewGoal, "RIGHT", 10, 0)
  inputTitle:SetAutoFocus(false)
  w.newGoalTitleInput = inputTitle

  local lblGold = toolbarCard:CreateFontString(nil, "OVERLAY")
  lblGold:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  lblGold:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  lblGold:SetPoint("LEFT", inputTitle, "RIGHT", 8, 0)
  lblGold:SetText("Target Gold:")

  local inputAmount = CreateFrame("EditBox", nil, toolbarCard, "InputBoxTemplate")
  inputAmount:SetSize(100, 22)
  inputAmount:SetPoint("LEFT", lblGold, "RIGHT", 8, 0)
  inputAmount:SetNumeric(true)
  inputAmount:SetAutoFocus(false)
  w.newGoalAmountInput = inputAmount

  local btnSaveGoal = UILib:CreateButton(toolbarCard, "Save Goal", 80, 22, function()
    local t = inputTitle:GetText() or ""
    local cleanTitle = t:match("^%s*(.-)%s*$")
    local a = tonumber(inputAmount:GetText() or "")
    if cleanTitle and cleanTitle ~= "" and a and a > 0 then
      Engine:AddWealthGoal(cleanTitle, a)
      inputTitle:SetText("")
      inputAmount:SetText("")
      inputTitle:ClearFocus()
      inputAmount:ClearFocus()
      UI:Refresh()
    end
  end)
  btnSaveGoal:SetPoint("LEFT", inputAmount, "RIGHT", 10, 0)
  w.btnSaveNewGoal = btnSaveGoal

  inputTitle:SetScript("OnEnterPressed", function()
    inputAmount:SetFocus()
  end)
  inputAmount:SetScript("OnEnterPressed", function()
    btnSaveGoal:Click()
  end)

  -- Wealth Ledger Table Card
  local wealthTableCard = UILib:CreateCard(w.wealthViewContainer, "Wealth Goals Ledger", C.FRAME_WIDTH - 20, 432, false)
  wealthTableCard:SetPoint("TOPLEFT", 0, -46)

  local wthCol1 = wealthTableCard:CreateFontString(nil, "OVERLAY")
  wthCol1:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  wthCol1:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  wthCol1:SetPoint("TOPLEFT", 14, -28)
  wthCol1:SetText("STATUS / ACTIVE")

  local wthCol2 = wealthTableCard:CreateFontString(nil, "OVERLAY")
  wthCol2:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  wthCol2:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  wthCol2:SetPoint("LEFT", wthCol1, "RIGHT", 24, 0)
  wthCol2:SetText("GOAL TITLE")

  local wthCol3 = wealthTableCard:CreateFontString(nil, "OVERLAY")
  wthCol3:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  wthCol3:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  wthCol3:SetPoint("LEFT", wthCol2, "RIGHT", 106, 0)
  wthCol3:SetText("PROGRESS / TARGET")

  local wthCol4 = wealthTableCard:CreateFontString(nil, "OVERLAY")
  wthCol4:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  wthCol4:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  wthCol4:SetPoint("LEFT", wthCol3, "RIGHT", 124, 0)
  wthCol4:SetText("CHARACTER")

  local wthCol5 = wealthTableCard:CreateFontString(nil, "OVERLAY")
  wthCol5:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  wthCol5:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  wthCol5:SetPoint("RIGHT", -16, 0)
  wthCol5:SetPoint("TOP", wthCol1, "TOP", 0, 0)
  wthCol5:SetText("ACTIONS")

  for i = 1, 13 do
    local r = CreateWealthRow(wealthTableCard, -46 - (i - 1) * 28)
    table.insert(w.wealthTableRows, r)
  end

  w.wealthTableEmpty = wealthTableCard:CreateFontString(nil, "OVERLAY")
  w.wealthTableEmpty:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "")
  w.wealthTableEmpty:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  w.wealthTableEmpty:SetPoint("CENTER", 0, -10)
  w.wealthTableEmpty:SetText("No wealth goals found for current scope. Create a new goal above!")
  w.wealthTableEmpty:Hide()

  -----------------------------------------------------------------------------
  -- BOTTOM ZONE NAV BAR (Feature B: Zone & Dungeon Profitability Tracking)
  -----------------------------------------------------------------------------
  w.zoneNavBar = CreateFrame("Frame", nil, w.mainFrame)
  w.zoneNavBar:SetSize(C.FRAME_WIDTH - 20, 24)
  w.zoneNavBar:SetPoint("BOTTOMLEFT", 10, 36)

  local zoneLabel = w.zoneNavBar:CreateFontString(nil, "OVERLAY")
  zoneLabel:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "OUTLINE")
  zoneLabel:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  zoneLabel:SetPoint("LEFT", 0, 0)
  zoneLabel:SetText("Zone:")
  w.zoneNavLabel = zoneLabel

  -----------------------------------------------------------------------------
  -- MODALS & OVERLAYS
  -----------------------------------------------------------------------------
  w.microHUD = UILib:CreateMicroHUD(UIParent)
  w.exportModal = UILib:CreateExportModal(w.mainFrame)
  w.settingsModal = UILib:CreateSettingsModal(w.mainFrame, function(key, val)
    if key == "hudLocked" and w.microHUD then
      w.microHUD:SetLocked(val)
    elseif key == "hudShown" and w.microHUD then
      if val then w.microHUD:Show() else w.microHUD:Hide() end
    elseif key == "hudInterval" and w.microHUD then
      if w.microHUD.SetInterval then
        w.microHUD:SetInterval(val)
      end
    end
    UI:Refresh()
  end)
  w.wealthActionMenu = UILib:CreateActionMenu(w.mainFrame)
  w.editGoalModal = UILib:CreateEditGoalModal(w.mainFrame, function(goalId, title, targetGold)
    Engine:UpdateWealthGoal(goalId, title, targetGold)
    UI:Refresh()
  end)
  w.deleteGoalModal = UILib:CreateConfirmationModal(w.mainFrame, "Delete Wealth Goal")
  w.sessionCapModal = UILib:CreateConfirmationModal(w.mainFrame, "Session Retention Cap")

  -- 5. Footer
  local footer = CreateFrame("Frame", nil, w.mainFrame)
  footer:SetSize(C.FRAME_WIDTH - 20, 28)
  footer:SetPoint("BOTTOMLEFT", 10, 6)

  local purseLabel = footer:CreateFontString(nil, "OVERLAY")
  purseLabel:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  purseLabel:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  purseLabel:SetPoint("LEFT", 0, 0)
  purseLabel:SetText("Backpack:")

  w.purseDisplay = footer:CreateFontString(nil, "OVERLAY")
  w.purseDisplay:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "OUTLINE")
  w.purseDisplay:SetPoint("LEFT", purseLabel, "RIGHT", 6, 0)

  -- Wealth Goal Mini Widget
  local goalWidget = CreateFrame("Frame", nil, footer)
  goalWidget:SetSize(280, 24)
  goalWidget:SetPoint("LEFT", w.purseDisplay, "RIGHT", 24, 0)
  w.wealthGoalWidget = goalWidget

  local fGoalTitle = goalWidget:CreateFontString(nil, "OVERLAY")
  fGoalTitle:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "OUTLINE")
  fGoalTitle:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  fGoalTitle:SetPoint("LEFT", 0, 0)
  w.footerGoalTitle = fGoalTitle

  local fGoalProg = goalWidget:CreateFontString(nil, "OVERLAY")
  fGoalProg:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  fGoalProg:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  fGoalProg:SetPoint("LEFT", fGoalTitle, "RIGHT", 6, 0)
  w.footerGoalProgress = fGoalProg

  local fGoalBar = CreateFrame("Frame", nil, goalWidget)
  fGoalBar:SetSize(110, 4)
  fGoalBar:SetPoint("LEFT", fGoalProg, "RIGHT", 6, 0)

  local fGoalBarBg = fGoalBar:CreateTexture(nil, "BACKGROUND")
  fGoalBarBg:SetAllPoints()
  fGoalBarBg:SetColorTexture(0.04, 0.06, 0.09, 0.8)

  local fGoalBarFill = fGoalBar:CreateTexture(nil, "ARTWORK")
  fGoalBarFill:SetPoint("TOPLEFT", 0, 0)
  fGoalBarFill:SetPoint("BOTTOMLEFT", 0, 0)
  fGoalBarFill:SetWidth(0)
  fGoalBarFill:SetColorTexture(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b, 0.9)
  w.footerGoalBarFill = fGoalBarFill

  local btnSettings = UILib:CreateButton(footer, "Settings", 64, 20, function()
    if w.settingsModal then
      w.settingsModal:Open()
    end
  end)
  btnSettings:SetPoint("RIGHT", 0, 0)
  w.btnSettings = btnSettings

  local btnReset = UILib:CreateButton(footer, "Reset", 55, 20, function()
    UI:ShowResetConfirmModal()
  end)
  btnReset:SetPoint("RIGHT", btnSettings, "LEFT", -6, 0)
  w.btnReset = btnReset

  -- 6. Granular Reset Modal
  w.resetModal = UILib:CreateResetModal(w.mainFrame, function(opt)
    local curScope = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
    local curRuleset = Engine:GetCurrentRuleset()

    if opt == "day" then
      local dStr = state.selectedDate or Engine:GetTodayDate()
      Engine:ResetDay(dStr, curScope, curRuleset)
      print(string.format("%s%s:|r Day records for |cFFFFD700%s|r (%s scope) have been reset.", C.COLORS.GOLD.hex, C.TITLE, dStr, curScope))
    elseif opt == "week" then
      local wKey = state.selectedWeekKey or Engine:GetResetWeekRange()
      Engine:ResetWeek(wKey, curScope, curRuleset)
      print(string.format("%s%s:|r Week records for |cFFFFD700%s|r (%s scope) have been reset.", C.COLORS.GOLD.hex, C.TITLE, wKey, curScope))
    elseif opt == "month" then
      local mStr = state.selectedMonth or Engine:GetTodayMonth()
      Engine:ResetMonth(mStr, curScope, curRuleset)
      print(string.format("%s%s:|r Month records for |cFFFFD700%s|r (%s scope) have been reset.", C.COLORS.GOLD.hex, C.TITLE, mStr, curScope))
    elseif opt == "sessions" then
      Engine:ResetSessions(curScope, curRuleset)
      print(string.format("%s%s:|r Recorded sessions (%s scope) have been reset.", C.COLORS.GOLD.hex, C.TITLE, curScope))
    elseif opt == "wealth" then
      Engine:ResetWealthGoals(curScope, curRuleset)
      print(string.format("%s%s:|r Wealth goals (%s ruleset) have been reset.", C.COLORS.GOLD.hex, C.TITLE, curRuleset))
    elseif opt == "all" then
      Engine:ResetAll(curScope, curRuleset)
      print(string.format("%s%s:|r All financial records (%s scope) have been reset.", C.COLORS.GOLD.hex, C.TITLE, curScope))
    end
    UI:Refresh()
  end)

  function UI:ShowResetConfirmModal()
    if w.resetModal then
      local curScope = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
      local ctx = {
        date = state.selectedDate or Engine:GetTodayDate(),
        week = state.selectedWeekKey or Engine:GetResetWeekRange(),
        month = state.selectedMonth or Engine:GetTodayMonth(),
        scope = curScope
      }
      w.resetModal:Open(state.activeView or "day", ctx)
    end
  end

  w.mainFrame:Hide()
end

function UI:Initialize()
  if w.mainFrame then return end
  BuildUI()
end

-------------------------------------------------------------------------------
-- REFRESH & RENDER
-------------------------------------------------------------------------------

function UI:RenderDayView(currentScope)
  w.heroCard:Show()
  w.dayViewContainer:Show()

  local dayData = Engine:GetDayData(state.selectedDate, currentScope, nil, state.selectedZone)
  w.dateLabel:SetText(state.selectedDate)
  w.btnToday:SetText("Today")

  -- Hero Card
  w.heroIncomeDisplay:SetText(UILib:FormatMoneyWithTextures(dayData.inTotal, false))
  w.heroExpenseDisplay:SetText(UILib:FormatMoneyWithTextures(dayData.outTotal, false))

  local net = dayData.net
  if net > 0 then
    w.heroNetText:SetTextColor(C.COLORS.PROFIT.r, C.COLORS.PROFIT.g, C.COLORS.PROFIT.b)
    w.heroNetText:SetText("+" .. UILib:FormatMoneyWithTextures(net, false))
    w.heroNetBadge:SetTextColor(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)
    w.heroNetBadge:SetText("Surplus (Profit)")
  elseif net < 0 then
    w.heroNetText:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
    w.heroNetText:SetText("-" .. UILib:FormatMoneyWithTextures(math.abs(net), false))
    w.heroNetBadge:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
    w.heroNetBadge:SetText("Deficit (Loss)")
  else
    w.heroNetText:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
    w.heroNetText:SetText(UILib:FormatMoneyWithTextures(0, false))
    w.heroNetBadge:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
    w.heroNetBadge:SetText("Balanced")
  end

  -- Day Category Headers Badges
  w.inCardTitleBadge:SetText(UILib:FormatSignedMoneyWithTextures(dayData.inTotal, true))
  w.outCardTitleBadge:SetText(UILib:FormatSignedMoneyWithTextures(dayData.outTotal, false))

  -- Day Category Rows
  for _, cat in ipairs(dayData.inCategories) do
    local rowKey = cat.key and ("in_" .. cat.key) or nil
    local row = rowKey and w.inCatRows[rowKey]
    if row then
      row.pct:SetText((cat.pct or 0) .. "%")
      row.bar:SetPercent(cat.pct or 0)
      row.amount:SetText(UILib:FormatMoneyWithTextures(cat.amount or 0, false))
    end
  end

  for _, cat in ipairs(dayData.outCategories) do
    local rowKey = cat.key and ("out_" .. cat.key) or nil
    local row = rowKey and w.outCatRows[rowKey]
    if row then
      row.pct:SetText((cat.pct or 0) .. "%")
      row.bar:SetPercent(cat.pct or 0)
      row.amount:SetText(UILib:FormatMoneyWithTextures(cat.amount or 0, false))
    end
  end

  -- Day-by-Day Monthly Performance Table for selected month (Descending)
  local currentMonthKey = string.sub(state.selectedDate, 1, 7)
  local monthData = Engine:GetMonthData(currentMonthKey, currentScope, nil, state.selectedZone)

  if #monthData.days == 0 then
    w.dayTableEmpty:Show()
  else
    w.dayTableEmpty:Hide()
  end

  for i, row in ipairs(w.dayTableRows) do
    local item = monthData.days[i]
    if item then
      row:Show()
      row.col1:SetText(item.date)
      row.col2:SetText(UILib:FormatMoneyWithTextures(item.inTotal, false))
      row.col3:SetText(UILib:FormatMoneyWithTextures(item.outTotal, false))
      row.col4:SetText(UILib:FormatNetMoneyWithTextures(item.net))

      local isSelected = (item.date == state.selectedDate)
      row:SetActive(isSelected)

      row:SetScript("OnClick", function()
        UI:SetDate(item.date)
      end)
      row.btnAction:SetScript("OnClick", function()
        UI:SetDate(item.date)
      end)
    else
      row:Hide()
    end
  end
end

function UI:RenderWeekView(currentScope)
  w.heroCard:Show()
  w.weekViewContainer:Show()

  if not state.selectedWeekKey then
    state.selectedWeekKey = Engine:GetResetWeekRange()
  end

  local weekData = Engine:GetWeekData(state.selectedWeekKey, currentScope, nil, state.selectedZone)
  w.dateLabel:SetText(weekData.label or state.selectedWeekKey)
  w.btnToday:SetText("This Week")

  -- Hero Card
  w.heroIncomeDisplay:SetText(UILib:FormatMoneyWithTextures(weekData.inTotal, false))
  w.heroExpenseDisplay:SetText(UILib:FormatMoneyWithTextures(weekData.outTotal, false))

  local net = weekData.net
  if net > 0 then
    w.heroNetText:SetTextColor(C.COLORS.PROFIT.r, C.COLORS.PROFIT.g, C.COLORS.PROFIT.b)
    w.heroNetText:SetText("+" .. UILib:FormatMoneyWithTextures(net, false))
    w.heroNetBadge:SetTextColor(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)
    w.heroNetBadge:SetText("Weekly Surplus (Profit)")
  elseif net < 0 then
    w.heroNetText:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
    w.heroNetText:SetText("-" .. UILib:FormatMoneyWithTextures(math.abs(net), false))
    w.heroNetBadge:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
    w.heroNetBadge:SetText("Weekly Deficit (Loss)")
  else
    w.heroNetText:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
    w.heroNetText:SetText(UILib:FormatMoneyWithTextures(0, false))
    w.heroNetBadge:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
    w.heroNetBadge:SetText("Balanced")
  end

  -- Week Category Headers Badges
  w.weekInCardTitleBadge:SetText(UILib:FormatSignedMoneyWithTextures(weekData.inTotal, true))
  w.weekOutCardTitleBadge:SetText(UILib:FormatSignedMoneyWithTextures(weekData.outTotal, false))

  -- Week Category Rows
  for _, cat in ipairs(weekData.inCategories) do
    local rowKey = cat.key and ("in_" .. cat.key) or nil
    local row = rowKey and w.weekInCatRows[rowKey]
    if row then
      row.pct:SetText((cat.pct or 0) .. "%")
      row.bar:SetPercent(cat.pct or 0)
      row.amount:SetText(UILib:FormatMoneyWithTextures(cat.amount or 0, false))
    end
  end

  for _, cat in ipairs(weekData.outCategories) do
    local rowKey = cat.key and ("out_" .. cat.key) or nil
    local row = rowKey and w.weekOutCatRows[rowKey]
    if row then
      row.pct:SetText((cat.pct or 0) .. "%")
      row.bar:SetPercent(cat.pct or 0)
      row.amount:SetText(UILib:FormatMoneyWithTextures(cat.amount or 0, false))
    end
  end

  -- 7-Day Performance Table
  if #weekData.days == 0 then
    w.weekTableEmpty:Show()
  else
    w.weekTableEmpty:Hide()
  end

  for i, row in ipairs(w.weekTableRows) do
    local item = weekData.days[i]
    if item then
      row:Show()
      row.col1:SetText(item.date)
      row.col2:SetText(UILib:FormatMoneyWithTextures(item.inTotal, false))
      row.col3:SetText(UILib:FormatMoneyWithTextures(item.outTotal, false))
      row.col4:SetText(UILib:FormatNetMoneyWithTextures(item.net))

      local isSelected = (item.date == state.selectedDate)
      row:SetActive(isSelected)

      row:SetScript("OnClick", function()
        UI:SetDate(item.date)
        UI:SetView("day")
      end)
      row.btnAction:SetScript("OnClick", function()
        UI:SetDate(item.date)
        UI:SetView("day")
      end)
    else
      row:Hide()
    end
  end
end

function UI:RenderMonthView(currentScope)
  w.heroCard:Show()
  w.monthViewContainer:Show()

  local monthData = Engine:GetMonthData(state.selectedMonth, currentScope, nil, state.selectedZone)
  w.dateLabel:SetText(UILib:FormatMonthString(state.selectedMonth))
  w.btnToday:SetText("This Month")

  -- Hero Card
  w.heroIncomeDisplay:SetText(UILib:FormatMoneyWithTextures(monthData.inTotal, false))
  w.heroExpenseDisplay:SetText(UILib:FormatMoneyWithTextures(monthData.outTotal, false))

  local net = monthData.net
  if net > 0 then
    w.heroNetText:SetTextColor(C.COLORS.PROFIT.r, C.COLORS.PROFIT.g, C.COLORS.PROFIT.b)
    w.heroNetText:SetText("+" .. UILib:FormatMoneyWithTextures(net, false))
    w.heroNetBadge:SetTextColor(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)
    w.heroNetBadge:SetText("Surplus (Profit)")
  elseif net < 0 then
    w.heroNetText:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
    w.heroNetText:SetText("-" .. UILib:FormatMoneyWithTextures(math.abs(net), false))
    w.heroNetBadge:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
    w.heroNetBadge:SetText("Deficit (Loss)")
  else
    w.heroNetText:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
    w.heroNetText:SetText(UILib:FormatMoneyWithTextures(0, false))
    w.heroNetBadge:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
    w.heroNetBadge:SetText("Balanced")
  end

  -- Month Category Headers Badges
  w.monthInCardTitleBadge:SetText(UILib:FormatSignedMoneyWithTextures(monthData.inTotal, true))
  w.monthOutCardTitleBadge:SetText(UILib:FormatSignedMoneyWithTextures(monthData.outTotal, false))

  -- Month Category Rows
  for _, cat in ipairs(monthData.inCategories) do
    local rowKey = cat.key and ("in_" .. cat.key) or nil
    local row = rowKey and w.monthInCatRows[rowKey]
    if row then
      row.pct:SetText((cat.pct or 0) .. "%")
      row.bar:SetPercent(cat.pct or 0)
      row.amount:SetText(UILib:FormatMoneyWithTextures(cat.amount or 0, false))
    end
  end

  for _, cat in ipairs(monthData.outCategories) do
    local rowKey = cat.key and ("out_" .. cat.key) or nil
    local row = rowKey and w.monthOutCatRows[rowKey]
    if row then
      row.pct:SetText((cat.pct or 0) .. "%")
      row.bar:SetPercent(cat.pct or 0)
      row.amount:SetText(UILib:FormatMoneyWithTextures(cat.amount or 0, false))
    end
  end

  -- Month-by-Month Annual Performance Table (Descending: Newest to Oldest)
  local yearData = Engine:GetYearData(state.selectedYear, currentScope)

  if #yearData == 0 then
    w.monthTableEmpty:Show()
  else
    w.monthTableEmpty:Hide()
  end

  for i, row in ipairs(w.monthTableRows) do
    local item = yearData[i]
    if item then
      row:Show()
      row.col1:SetText(UILib:FormatMonthString(item.key))
      row.col2:SetText(UILib:FormatMoneyWithTextures(item.inTotal, false))
      row.col3:SetText(UILib:FormatMoneyWithTextures(item.outTotal, false))
      row.col4:SetText(UILib:FormatNetMoneyWithTextures(item.net))

      local isSelected = (item.key == state.selectedMonth)
      row:SetActive(isSelected)

      row:SetScript("OnClick", function()
        UI:SetMonth(item.key)
      end)
      row.btnAction:SetScript("OnClick", function()
        UI:SetMonth(item.key)
        UI:SetView("day")
      end)
    else
      row:Hide()
    end
  end
end

function UI:RenderWealthView(currentScope)
  w.heroCard:Hide()
  w.wealthViewContainer:Show()

  local goals = Engine:GetWealthGoals(currentScope)
  if #goals == 0 then
    w.wealthTableEmpty:Show()
  else
    w.wealthTableEmpty:Hide()
  end

  local activeGoal = Engine:GetActiveWealthGoal()
  local currentMoney = GetMoney()
  local goldTex = "|T" .. C.COIN_TEXTURE_GOLD .. ":12:12:0:0|t"

  for i, row in ipairs(w.wealthTableRows) do
    local goal = goals[i]
    if goal then
      row:Show()
      row.colTitle:SetText(goal.title or "Goal")
      row.colChar:SetText(string.format("%s (%s)", goal.charName or "", goal.faction or ""))

      local targetCopper = (goal.targetGold or 1) * 10000
      local pct = math.min(100, math.max(0, math.floor((currentMoney / targetCopper) * 100 + 0.5)))
      local currentGold = math.floor(currentMoney / 10000)

      local progressText = string.format("%d / %d %s (%d%%)", currentGold, goal.targetGold or 0, goldTex, pct)
      row.colProgress:SetText(progressText)

      local barW = math.floor((pct / 100) * 75)
      row.barFrame.fill:SetWidth(math.max(1, barW))
      if goal.completed then
        row.barFrame.fill:SetColorTexture(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b, 0.9)
      else
        row.barFrame.fill:SetColorTexture(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b, 0.9)
      end

      local isActive = (activeGoal and activeGoal.id == goal.id)
      if goal.completed then
        row.btnStatus:Hide()
        row.statusLabel:Show()
        row.statusLabel:SetTextColor(C.COLORS.PROFIT.r, C.COLORS.PROFIT.g, C.COLORS.PROFIT.b)
        row.statusLabel:SetText("Completed")
      elseif isActive then
        row.btnStatus:Hide()
        row.statusLabel:Show()
        row.statusLabel:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
        row.statusLabel:SetText("Active")
      else
        row.statusLabel:Hide()
        row.btnStatus:Show()
        row.btnStatus:SetText("Set Active")
        row.btnStatus:SetScript("OnClick", function()
          Engine:SetWealthGoalActive(goal.id)
          UI:Refresh()
        end)
      end

      row.btnManage:SetScript("OnClick", function()
        w.wealthActionMenu:OpenForGoal(
          goal,
          row.btnManage,
          function(g)
            w.editGoalModal:OpenForGoal(g, function(id, newTitle, newTarget)
              Engine:UpdateWealthGoal(id, newTitle, newTarget)
              UI:Refresh()
            end)
          end,
          function(g)
            Engine:ToggleWealthGoalCompleted(g.id)
            UI:Refresh()
          end,
          function(g)
            w.deleteGoalModal:ShowPrompt(
              string.format("Are you sure you want to delete '%s'?", g.title or "Goal"),
              function()
                Engine:DeleteWealthGoal(g.id)
                UI:Refresh()
              end
            )
          end
        )
      end)
    else
      row:Hide()
    end
  end
end

function UI:RefreshZoneNav()
  if state.activeView == "session" or state.activeView == "wealth" then
    w.zoneNavBar:Hide()
    return
  end

  w.zoneNavBar:Show()
  local currentScope = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  local dateOrKey
  if state.activeView == "day" then
    dateOrKey = state.selectedDate
  elseif state.activeView == "week" then
    dateOrKey = state.selectedWeekKey
  else
    dateOrKey = state.selectedMonth
  end

  local availableZones = Engine:GetAvailableZones(state.activeView, dateOrKey, currentScope)

  local found = false
  for _, z in ipairs(availableZones) do
    if z == state.selectedZone then
      found = true
      break
    end
  end
  if not found then
    state.selectedZone = "All"
  end

  for _, pill in ipairs(w.zonePills) do
    pill:Hide()
  end

  local prevPill = nil
  for idx, zName in ipairs(availableZones) do
    local pill = w.zonePills[idx]
    if not pill then
      pill = UILib:CreateTabButton(w.zoneNavBar, zName, 60, 20, function()
        state.selectedZone = pill.zoneName
        UI:Refresh()
      end)
      table.insert(w.zonePills, pill)
    end

    pill.zoneName = zName
    pill:SetText(zName)
    local textWidth = pill:GetFontString() and pill:GetFontString():GetStringWidth() or 40
    pill:SetWidth(math.max(40, math.min(130, textWidth + 14)))
    pill:SetActive(zName == state.selectedZone)
    pill:ClearAllPoints()
    if not prevPill then
      pill:SetPoint("LEFT", w.zoneNavLabel, "RIGHT", 8, 0)
    else
      pill:SetPoint("LEFT", prevPill, "RIGHT", 4, 0)
    end
    pill:Show()
    prevPill = pill
  end
end

function UI:UpdateFooterWealthGoal()
  local activeGoal = Engine:GetActiveWealthGoal()
  if not activeGoal or activeGoal.completed then
    w.wealthGoalWidget:Hide()
    return
  end

  w.wealthGoalWidget:Show()
  local currentMoney = GetMoney()
  local targetCopper = (activeGoal.targetGold or 1) * 10000
  local pct = math.min(100, math.max(0, math.floor((currentMoney / targetCopper) * 100 + 0.5)))
  local currentGold = math.floor(currentMoney / 10000)

  w.footerGoalTitle:SetText((activeGoal.title or "Goal") .. ":")
  local goldTex = "|T" .. C.COIN_TEXTURE_GOLD .. ":12:12:0:0|t"
  w.footerGoalProgress:SetText(string.format("%d / %d %s (%d%%)", currentGold, activeGoal.targetGold or 0, goldTex, pct))
  local barW = math.floor((pct / 100) * 110)
  w.footerGoalBarFill:SetWidth(math.max(1, barW))
end

function UI:Refresh()
  if w.microHUD and w.microHUD:IsShown() then
    w.microHUD:Update()
  end

  if not w.mainFrame or not w.mainFrame:IsShown() then return end

  -- Update Purse
  w.purseDisplay:SetText(UILib:FormatMoneyWithTextures(GetMoney(), false))

  -- Update Scope Buttons and Ruleset Badge
  local currentScope = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  if w.btnScopeChar then
    w.btnScopeChar:SetActive(currentScope == "character")
  end
  if w.btnScopeAlliance then
    w.btnScopeAlliance:SetActive(currentScope == "alliance")
  end
  if w.btnScopeHorde then
    w.btnScopeHorde:SetActive(currentScope == "horde")
  end

  if w.rulesetBadge then
    local currentRuleset = Engine:GetCurrentRuleset()
    w.rulesetBadge:SetText("|cFF8CA0BA[Ruleset: |r|cFFFFD100" .. currentRuleset .. "|r|cFF8CA0BA]|r")
  end

  -- Update Nav Tabs
  w.tabDay:SetActive(state.activeView == "day")
  w.tabWeek:SetActive(state.activeView == "week")
  w.tabMonth:SetActive(state.activeView == "month")
  w.tabSession:SetActive(state.activeView == "session")
  w.tabWealth:SetActive(state.activeView == "wealth")

  -- Disable Session Tab when inside an individual session detail view
  if state.activeView == "session" and state.isSessionDetailActive then
    w.tabSession:SetDisabled(true)
  else
    w.tabSession:SetDisabled(false)
  end

  if state.activeView == "session" then
    w.navDateGroup:Hide()
    w.navWealthGroup:Hide()
    w.navSessionGroup:Show()

    if Engine:IsSessionActive() then
      w.btnToggleTimer:SetText("Stop Timer")
    else
      w.btnToggleTimer:SetText("Start Timer")
    end

    if state.isSessionDetailActive then
      w.btnBack:Show()
      w.sessionNavLabel:ClearAllPoints()
      w.sessionNavLabel:SetPoint("LEFT", w.btnBack, "RIGHT", 8, 0)
      w.sessionNavLabel:SetPoint("RIGHT", w.btnToggleTimer, "LEFT", -8, 0)
      w.sessionNavLabel:SetText("Session Details")
    else
      w.btnBack:Hide()
      w.sessionNavLabel:ClearAllPoints()
      w.sessionNavLabel:SetPoint("LEFT", w.navSessionGroup, "LEFT", 0, 0)
      w.sessionNavLabel:SetPoint("RIGHT", w.btnToggleTimer, "LEFT", -8, 0)
      if Engine:IsSessionActive() then
        local elapsed = Engine:GetSessionElapsed()
        w.sessionNavLabel:SetText("|cFF00FF00Active Recording: " .. Engine:FormatElapsed(elapsed) .. "|r")
      else
        w.sessionNavLabel:SetText("Recorded Sessions")
      end
    end
  elseif state.activeView == "wealth" then
    w.navDateGroup:Hide()
    w.navSessionGroup:Hide()
    w.navWealthGroup:Show()
  else
    w.navDateGroup:Show()
    w.navSessionGroup:Hide()
    w.navWealthGroup:Hide()

    -- Boundary check: disable '>' button if currently viewing today, current week, or current month
    local canGoNext = false
    local todayDate = Engine:GetTodayDate()
    local todayMonth = Engine:GetTodayMonth()
    local currentWeekKey = Engine:GetResetWeekRange()

    if state.activeView == "day" then
      canGoNext = (state.selectedDate < todayDate)
    elseif state.activeView == "week" then
      canGoNext = (state.selectedWeekKey and state.selectedWeekKey < currentWeekKey)
    else
      canGoNext = (state.selectedMonth < todayMonth)
    end

    if canGoNext then
      w.btnNextDate:Enable()
    else
      w.btnNextDate:Disable()
    end
  end

  -- Hide all view containers before showing the active one
  w.dayViewContainer:Hide()
  w.weekViewContainer:Hide()
  w.monthViewContainer:Hide()
  w.sessionViewContainer:Hide()
  w.wealthViewContainer:Hide()

  if state.activeView == "day" then
    self:RenderDayView(currentScope)
  elseif state.activeView == "week" then
    self:RenderWeekView(currentScope)
  elseif state.activeView == "month" then
    self:RenderMonthView(currentScope)
  elseif state.activeView == "session" then
    w.sessionViewContainer:Show()
    if state.isSessionDetailActive then
      w.heroCard:Show()
      w.sessionListContainer:Hide()
      w.sessionDetailContainer:Show()
      self:UpdateSessionDetail()
    else
      w.heroCard:Hide()
      w.sessionListContainer:Show()
      w.sessionDetailContainer:Hide()
      self:UpdateSessionView()
    end
  elseif state.activeView == "wealth" then
    self:RenderWealthView(currentScope)
  end

  self:RefreshZoneNav()
  self:UpdateFooterWealthGoal()

  if w.microHUD then
    w.microHUD:Update()
  end
end

-------------------------------------------------------------------------------
-- SESSION VIEW HELPERS
-------------------------------------------------------------------------------

function UI:OnSessionCapClicked(newCap)
  local currentCap = Engine:GetSessionCap()
  if currentCap == newCap then return end

  local sessionsDB = GoblinJournalDB and GoblinJournalDB.sessions
  local maxCount = 0
  if sessionsDB then
    for _, charMap in pairs(sessionsDB) do
      for _, list in pairs(charMap) do
        if #list > maxCount then
          maxCount = #list
        end
      end
    end
  end

  if newCap > 0 and maxCount > newCap then
    local excess = maxCount - newCap
    local prompt = string.format(
      "You have character session records with up to %d sessions.\n\nSetting the cap to %d will immediately delete the %d oldest session(s) via FIFO eviction.\n\nAre you sure you want to proceed?",
      maxCount, newCap, excess
    )
    w.sessionCapModal:ShowPrompt(prompt, function()
      Engine:SetSessionCap(newCap)
    end)
  else
    Engine:SetSessionCap(newCap)
  end
end

function UI:UpdateSessionCapButtons()
  local currentCap = Engine:GetSessionCap()
  if w.capBtn50 then w.capBtn50:SetActive(currentCap == 50) end
  if w.capBtn100 then w.capBtn100:SetActive(currentCap == 100) end
  if w.capBtn200 then w.capBtn200:SetActive(currentCap == 200) end
  if w.capBtnUnlimited then w.capBtnUnlimited:SetActive(currentCap == 0) end
end

function UI:SelectSession(index)
  state.selectedSessionIndex = index
  state.isSessionDetailActive = true
  self:Refresh()
end

function UI:BackToSessionLedger()
  state.isSessionDetailActive = false
  state.selectedSessionIndex = nil
  self:Refresh()
end

function UI:ToggleSessionTimer()
  if Engine:IsSessionActive() then
    Engine:StopSession()
  else
    Engine:StartSession()
  end
  self:Refresh()
end

function UI:ToggleSessionLedger()
  if not w.mainFrame then
    self:Initialize()
  end
  if w.mainFrame:IsShown() and state.activeView == "session" and not state.isSessionDetailActive then
    self:Hide()
  else
    state.activeView = "session"
    state.isSessionDetailActive = false
    state.selectedSessionIndex = nil
    self:Show()
  end
end

function UI:UpdateSessionView()
  self:UpdateSessionCapButtons()

  local currentScope = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  local sessions = Engine:GetScopedSessions(currentScope)

  if #sessions == 0 then
    w.sessionTableEmpty:Show()
  else
    w.sessionTableEmpty:Hide()
  end

  for i, row in ipairs(w.sessionTableRows) do
    local s = sessions[i]
    if s then
      row:Show()
      row.sessionIndex = i
      local sData = Engine:GetSessionData(s)

      -- Format title: {Char}-{Date} {Start}-{End}
      local titleStr = string.format("%s - %s (%s - %s)", sData.charName, sData.date, sData.timeStart, sData.timeEnd)
      row.col1:SetText(titleStr)
      row.colZone:SetText(sData.zone or "Open World")
      row.col2:SetText(UILib:FormatMoneyWithTextures(sData.inTotal, false))
      row.col3:SetText(UILib:FormatMoneyWithTextures(sData.outTotal, false))
      row.col4:SetText(UILib:FormatNetMoneyWithTextures(sData.net))

      row:SetScript("OnClick", function()
        UI:SelectSession(i)
      end)
      row.btnAction:SetScript("OnClick", function()
        UI:SelectSession(i)
      end)
    else
      row:Hide()
    end
  end
end

function UI:UpdateSessionDetail()
  local currentScope = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  local sessions = Engine:GetScopedSessions(currentScope)
  local s = sessions[state.selectedSessionIndex or 1]
  if not s then
    self:BackToSessionLedger()
    return
  end

  local sData = Engine:GetSessionData(s)

  -- Update Hero Card
  w.heroIncomeDisplay:SetText(UILib:FormatMoneyWithTextures(sData.inTotal, false))
  w.heroExpenseDisplay:SetText(UILib:FormatMoneyWithTextures(sData.outTotal, false))

  local net = sData.net
  if net > 0 then
    w.heroNetText:SetTextColor(C.COLORS.PROFIT.r, C.COLORS.PROFIT.g, C.COLORS.PROFIT.b)
    w.heroNetText:SetText("+" .. UILib:FormatMoneyWithTextures(net, false))
    w.heroNetBadge:SetTextColor(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)
    w.heroNetBadge:SetText("Surplus (Profit)")
  elseif net < 0 then
    w.heroNetText:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
    w.heroNetText:SetText("-" .. UILib:FormatMoneyWithTextures(math.abs(net), false))
    w.heroNetBadge:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
    w.heroNetBadge:SetText("Deficit (Loss)")
  else
    w.heroNetText:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
    w.heroNetText:SetText(UILib:FormatMoneyWithTextures(0, false))
    w.heroNetBadge:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
    w.heroNetBadge:SetText("Balanced")
  end

  -- Category Card Header Badges
  w.sessionCatTotalIn:SetText(UILib:FormatSignedMoneyWithTextures(sData.inTotal, true))
  w.sessionCatTotalOut:SetText(UILib:FormatSignedMoneyWithTextures(sData.outTotal, false))

  -- Populate Category Rows
  for _, cat in ipairs(sData.inCategories) do
    local rowKey = cat.key and ("in_" .. cat.key) or nil
    local row = rowKey and w.sessionInCatRows[rowKey]
    if row then
      row.pct:SetText((cat.pct or 0) .. "%")
      row.bar:SetPercent(cat.pct or 0)
      row.amount:SetText(UILib:FormatMoneyWithTextures(cat.amount or 0, false))
    end
  end

  for _, cat in ipairs(sData.outCategories) do
    local rowKey = cat.key and ("out_" .. cat.key) or nil
    local row = rowKey and w.sessionOutCatRows[rowKey]
    if row then
      row.pct:SetText((cat.pct or 0) .. "%")
      row.bar:SetPercent(cat.pct or 0)
      row.amount:SetText(UILib:FormatMoneyWithTextures(cat.amount or 0, false))
    end
  end

  -- Metric Cards:
  w.metricDuration:SetText(Engine:FormatDuration(sData.duration))
  w.metricGPH:SetText(UILib:FormatNetMoneyRateWithTextures(sData.copperPerHour))
  local realmName = GetRealmName and GetRealmName() or ""
  w.metricChar:SetText(sData.charName .. (realmName ~= "" and ("-" .. realmName) or ""))
  w.metricTimeRange:SetText(string.format("%s  %s - %s", sData.date, sData.timeStart, sData.timeEnd))

  -- Sparkline
  if w.sessionSparkline and w.sessionSparkline.RenderSession then
    w.sessionSparkline:RenderSession(sData)
  end
end

-------------------------------------------------------------------------------
-- VIEW NAVIGATION & SCOPE
-------------------------------------------------------------------------------

function UI:SetScope(scopeType)
  if not GoblinJournalDB or not GoblinJournalDB.settings then return end
  GoblinJournalDB.settings.selectedScope = scopeType
  self:Refresh()
end

function UI:SetView(viewMode)
  if state.isSessionDetailActive and viewMode ~= "session" then
    state.isSessionDetailActive = false
  end
  state.activeView = viewMode
  if not state.selectedWeekKey then
    state.selectedWeekKey = Engine:GetResetWeekRange()
  end
  self:Refresh()
end

function UI:SetDate(dateStr)
  local today = Engine:GetTodayDate()
  if dateStr > today then
    dateStr = today
  end
  state.selectedDate = dateStr
  state.selectedMonth = string.sub(dateStr, 1, 7)
  state.selectedYear = string.sub(dateStr, 1, 4)
  self:Refresh()
end

function UI:SetMonth(monthStr)
  local todayMonth = Engine:GetTodayMonth()
  if monthStr > todayMonth then
    monthStr = todayMonth
  end
  state.selectedMonth = monthStr
  state.selectedYear = string.sub(monthStr, 1, 4)
  local currentScope = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  local mData = Engine:GetMonthData(monthStr, currentScope)
  if mData.days and #mData.days > 0 then
    state.selectedDate = mData.days[1].date
  else
    state.selectedDate = monthStr .. "-01"
  end
  local today = Engine:GetTodayDate()
  if state.selectedDate > today then
    state.selectedDate = today
  end
  self:Refresh()
end

function UI:SetToday()
  if state.activeView == "session" then
    self:BackToSessionLedger()
    return
  end
  state.selectedDate = Engine:GetTodayDate()
  state.selectedWeekKey = Engine:GetResetWeekRange()
  state.selectedMonth = Engine:GetTodayMonth()
  state.selectedYear = Engine:GetTodayYear()
  self:Refresh()
end

function UI:NavigateDate(offset)
  local todayDate = Engine:GetTodayDate()
  local todayMonth = Engine:GetTodayMonth()
  local currentWeekKey = Engine:GetResetWeekRange()

  if offset > 0 then
    if state.activeView == "day" and state.selectedDate >= todayDate then
      return
    elseif state.activeView == "week" and state.selectedWeekKey and state.selectedWeekKey >= currentWeekKey then
      return
    elseif state.activeView == "month" and state.selectedMonth >= todayMonth then
      return
    end
  end

  if state.activeView == "day" then
    local y, m, d = string.match(state.selectedDate, "(%d+)-(%d+)-(%d+)")
    if y and m and d then
      local t = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) + offset })
      local newDate = date("%Y-%m-%d", t)
      if offset > 0 and newDate > todayDate then
        newDate = todayDate
      end
      state.selectedDate = newDate
      state.selectedWeekKey = Engine:GetResetWeekRange(t)
      state.selectedMonth = string.sub(state.selectedDate, 1, 7)
      state.selectedYear = string.sub(state.selectedDate, 1, 4)
    end
  elseif state.activeView == "week" then
    local y, m, d = string.match(state.selectedWeekKey or state.selectedDate, "(%d+)-(%d+)-(%d+)")
    if y and m and d then
      local t = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) + (offset * 7), hour = 15, min = 0, sec = 0 })
      local newWeekKey = Engine:GetResetWeekRange(t)
      if offset > 0 and newWeekKey > currentWeekKey then
        newWeekKey = currentWeekKey
      end
      state.selectedWeekKey = newWeekKey
      state.selectedDate = newWeekKey
      state.selectedMonth = string.sub(newWeekKey, 1, 7)
      state.selectedYear = string.sub(newWeekKey, 1, 4)
    end
  else
    local y, m = string.match(state.selectedMonth, "(%d+)-(%d+)")
    if y and m then
      local newMonth = tonumber(m) + offset
      local newYear = tonumber(y)
      if newMonth > 12 then
        newMonth = 1
        newYear = newYear + 1
      elseif newMonth < 1 then
        newMonth = 12
        newYear = newYear - 1
      end
      local newMonthStr = string.format("%04d-%02d", newYear, newMonth)
      if offset > 0 and newMonthStr > todayMonth then
        newMonthStr = todayMonth
      end
      state.selectedMonth = newMonthStr
      state.selectedYear = string.sub(state.selectedMonth, 1, 4)
    end
  end
  self:Refresh()
end

function UI:ToggleHUDLock()
  if not GoblinJournalDB or not GoblinJournalDB.settings then return end
  local locked = not GoblinJournalDB.settings.hudLocked
  GoblinJournalDB.settings.hudLocked = locked
  if w.microHUD then
    w.microHUD:SetLocked(locked)
  end
  print(C.COLORS.GOLD.hex .. C.TITLE .. ":|r Goblin HUD " .. (locked and "|cFFFF3333Locked|r" or "|cFF00FF00Unlocked|r"))
end

function UI:Toggle()
  if not w.mainFrame then
    self:Initialize()
  end
  if w.mainFrame:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

function UI:Show()
  if not w.mainFrame then
    self:Initialize()
  end
  w.mainFrame:Show()
  self:Refresh()
end

function UI:Hide()
  if w.mainFrame and w.mainFrame:IsShown() then
    w.mainFrame:Hide()
  end
end

function UI:IsShown()
  return w.mainFrame and w.mainFrame:IsShown()
end

-------------------------------------------------------------------------------
-- SLASH COMMAND REGISTRATION
-------------------------------------------------------------------------------

SLASH_GOBLINJOURNAL1 = "/gj"
SLASH_GOBLINJOURNAL2 = "/goblin"
SlashCmdList["GOBLINJOURNAL"] = function(msg)
  local cleanMsg = msg and (strtrim and strtrim(msg) or msg:match("^%s*(.-)%s*$")) or ""
  local cmd = string.lower(cleanMsg)
  if cmd == "reset" or cmd == "resetall" then
    if not w.mainFrame then UI:Initialize() end
    UI:Show()
    UI:ShowResetConfirmModal()
  elseif cmd == "lock" or cmd == "unlock" then
    UI:ToggleHUDLock()
  elseif cmd == "hud" then
    if not GoblinJournalDB or not GoblinJournalDB.settings then return end
    local shown = not GoblinJournalDB.settings.hudShown
    GoblinJournalDB.settings.hudShown = shown
    if w.microHUD then
      if shown then w.microHUD:Show() else w.microHUD:Hide() end
    end
    print(C.COLORS.GOLD.hex .. C.TITLE .. ":|r Goblin HUD " .. (shown and "|cFF00FF00Enabled|r" or "|cFFFF3333Disabled|r"))
  elseif cmd:match("^interval") or cmd:match("^hud%s+interval") then
    local intVal = tonumber(cmd:match("(%d+)"))
    if intVal and intVal >= 1 then
      if GoblinJournalDB and GoblinJournalDB.settings then
        GoblinJournalDB.settings.hudInterval = intVal
      end
      if w.microHUD and w.microHUD.SetInterval then
        w.microHUD:SetInterval(intVal)
      end
      print(C.COLORS.GOLD.hex .. C.TITLE .. ":|r Goblin HUD interval set to " .. intVal .. "s")
    else
      local cur = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.hudInterval) or 5
      print(C.COLORS.GOLD.hex .. C.TITLE .. ":|r Goblin HUD interval is currently " .. cur .. "s (use: /gj interval <seconds>)")
    end
  elseif cmd == "session" then
    if not w.mainFrame then UI:Initialize() end
    state.activeView = "session"
    state.isSessionDetailActive = false
    UI:Show()
  elseif cmd == "wealth" then
    if not w.mainFrame then UI:Initialize() end
    state.activeView = "wealth"
    UI:Show()
  elseif cmd == "week" then
    if not w.mainFrame then UI:Initialize() end
    state.activeView = "week"
    UI:Show()
  elseif cmd == "settings" or cmd == "options" or cmd == "config" then
    if not w.mainFrame then UI:Initialize() end
    UI:Show()
    if w.settingsModal then w.settingsModal:Open() end
  elseif cmd == "export" then
    if not w.mainFrame then UI:Initialize() end
    UI:Show()
    if w.exportModal then w.exportModal:Open() end
  else
    UI:Toggle()
  end
end

-------------------------------------------------------------------------------
-- INITIALIZATION LIFECYCLE
-------------------------------------------------------------------------------

if IsLoggedIn and IsLoggedIn() then
  UI:Initialize()
else
  local loader = CreateFrame("Frame")
  loader:RegisterEvent("PLAYER_LOGIN")
  loader:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
      UI:Initialize()
    end
  end)
end
