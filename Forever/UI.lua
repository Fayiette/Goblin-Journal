local addonName, addonTable = ...

addonTable.UI = {}
local UI = addonTable.UI
local C = addonTable.Constants
local UILib = addonTable.UILib
local Engine = addonTable.Engine

-- Main Frame Reference & State
local mainFrame
local activeView = "day" -- "day" or "month"
local selectedDate
local selectedMonth
local selectedYear

-- UI Widget References
local dateLabel, btnPrevDate, btnNextDate, btnToday
local tabDay, tabMonth
local btnScopeChar, btnScopeAlliance, btnScopeHorde, rulesetBadge
local heroIncomeDisplay, heroExpenseDisplay, heroNetText, heroNetBadge
local dayViewContainer, monthViewContainer
local inCatRows, outCatRows = {}, {}
local monthInCatRows, monthOutCatRows = {}, {}
local dayTableRows = {}
local monthTableRows = {}
local dayTableEmpty, monthTableEmpty
local purseDisplay

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

-------------------------------------------------------------------------------
-- MAIN FRAME INITIALIZATION
-------------------------------------------------------------------------------

local function BuildUI()
  if mainFrame then return end

  selectedDate = Engine:GetTodayDate()
  selectedMonth = Engine:GetTodayMonth()
  selectedYear = Engine:GetTodayYear()

  -- 1. Outer Frame (Fixed Height: 615px)
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  mainFrame = CreateFrame("Frame", "GoblinJournalFrame", UIParent, template)
  mainFrame:Hide()
  mainFrame:SetSize(C.FRAME_WIDTH, C.FRAME_HEIGHT)
  mainFrame:SetPoint("CENTER")
  mainFrame:SetFrameStrata("MEDIUM")
  mainFrame:SetMovable(true)
  mainFrame:EnableMouse(true)
  mainFrame:SetClampedToScreen(true)
  mainFrame:RegisterForDrag("LeftButton")
  mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
  mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
  mainFrame:SetBackdrop(C.MAIN_BACKDROP)

  local bg = C.COLORS.CARD_BG
  mainFrame:SetBackdropColor(bg.r, bg.g, bg.b, 0.96)
  local gb = C.COLORS.GOLD_BORDER
  mainFrame:SetBackdropBorderColor(gb.r, gb.g, gb.b, 1.0)

  table.insert(UISpecialFrames, "GoblinJournalFrame")

  -- 2. Header
  local header = CreateFrame("Frame", nil, mainFrame)
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
  closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

  -- Active ruleset badge next to close button
  rulesetBadge = header:CreateFontString(nil, "OVERLAY")
  rulesetBadge:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  rulesetBadge:SetTextColor(C.COLORS.VERSION.r, C.COLORS.VERSION.g, C.COLORS.VERSION.b)
  rulesetBadge:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)

  -- Scope Filter Buttons directly under X (WCAG 2 AAA Contrast & Legibility)
  btnScopeHorde = UILib:CreateScopeButton(header, "Horde", 52, 20, "horde", function()
    UI:SetScope("horde")
  end)
  btnScopeHorde:SetPoint("TOPRIGHT", header, "TOPRIGHT", -8, -25)

  btnScopeAlliance = UILib:CreateScopeButton(header, "Alliance", 62, 20, "alliance", function()
    UI:SetScope("alliance")
  end)
  btnScopeAlliance:SetPoint("RIGHT", btnScopeHorde, "LEFT", -4, 0)

  btnScopeChar = UILib:CreateScopeButton(header, "Current Character", 116, 20, "character", function()
    UI:SetScope("character")
  end)
  btnScopeChar:SetPoint("RIGHT", btnScopeAlliance, "LEFT", -4, 0)

  -- 3. Navigation Bar (Tabs + Date Navigator)
  local navBar = CreateFrame("Frame", nil, mainFrame)
  navBar:SetSize(C.FRAME_WIDTH - 20, 36)
  navBar:SetPoint("TOPLEFT", 10, -48)

  tabDay = UILib:CreateTabButton(navBar, "Day View", 90, 26, function()
    UI:SetView("day")
  end)
  tabDay:SetPoint("LEFT", 0, 0)

  tabMonth = UILib:CreateTabButton(navBar, "Month View", 90, 26, function()
    UI:SetView("month")
  end)
  tabMonth:SetPoint("LEFT", tabDay, "RIGHT", 4, 0)

  btnToday = UILib:CreateButton(navBar, "Today", 85, 22, function()
    UI:SetToday()
  end)
  btnToday:SetPoint("RIGHT", navBar, "RIGHT", 0, 0)

  btnNextDate = UILib:CreateButton(navBar, ">", 24, 22, function()
    UI:NavigateDate(1)
  end)
  btnNextDate:SetPoint("RIGHT", btnToday, "LEFT", -6, 0)

  dateLabel = navBar:CreateFontString(nil, "OVERLAY")
  dateLabel:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  dateLabel:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  dateLabel:SetPoint("RIGHT", btnNextDate, "LEFT", -4, 0)
  dateLabel:SetWidth(140)
  dateLabel:SetJustifyH("CENTER")

  btnPrevDate = UILib:CreateButton(navBar, "<", 24, 22, function()
    UI:NavigateDate(-1)
  end)
  btnPrevDate:SetPoint("RIGHT", dateLabel, "LEFT", -4, 0)

  -- 4. Hero Summary Card (Center: Net Result (+/- in Green/Red))
  local heroCard = UILib:CreateCard(mainFrame, "", C.FRAME_WIDTH - 20, C.HERO_BANNER_HEIGHT, false)
  heroCard:SetPoint("TOPLEFT", 10, -84)

  -- Income Column
  local lblIn = heroCard:CreateFontString(nil, "OVERLAY")
  lblIn:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  lblIn:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  lblIn:SetPoint("TOPLEFT", 14, -10)
  lblIn:SetText("TOTAL INCOMING")

  heroIncomeDisplay = heroCard:CreateFontString(nil, "OVERLAY")
  heroIncomeDisplay:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  heroIncomeDisplay:SetPoint("TOPLEFT", lblIn, "BOTTOMLEFT", 0, -4)
  heroIncomeDisplay:SetTextColor(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)

  -- Outgoing Column
  local lblOut = heroCard:CreateFontString(nil, "OVERLAY")
  lblOut:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  lblOut:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  lblOut:SetPoint("TOPRIGHT", -14, -10)
  lblOut:SetText("TOTAL OUTGOING")

  heroExpenseDisplay = heroCard:CreateFontString(nil, "OVERLAY")
  heroExpenseDisplay:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "OUTLINE")
  heroExpenseDisplay:SetPoint("TOPRIGHT", lblOut, "BOTTOMRIGHT", 0, -4)
  heroExpenseDisplay:SetTextColor(C.COLORS.ORANGE.r, C.COLORS.ORANGE.g, C.COLORS.ORANGE.b)

  -- Net Center Display
  local lblNet = heroCard:CreateFontString(nil, "OVERLAY")
  lblNet:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  lblNet:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  lblNet:SetPoint("TOP", 0, -8)
  lblNet:SetText("NET RESULT")

  heroNetText = heroCard:CreateFontString(nil, "OVERLAY")
  heroNetText:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_HERO_NET, "OUTLINE")
  heroNetText:SetPoint("TOP", lblNet, "BOTTOM", 0, -3)

  heroNetBadge = heroCard:CreateFontString(nil, "OVERLAY")
  heroNetBadge:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_TINY, "")
  heroNetBadge:SetPoint("TOP", heroNetText, "BOTTOM", 0, -2)

  -----------------------------------------------------------------------------
  -- DAY VIEW CONTAINER
  -----------------------------------------------------------------------------
  dayViewContainer = CreateFrame("Frame", nil, mainFrame)
  dayViewContainer:SetSize(C.FRAME_WIDTH - 20, 400)
  dayViewContainer:SetPoint("TOPLEFT", 10, -170)

  -- Top-Left Card: Day Incoming Categories
  local inCard = UILib:CreateCard(dayViewContainer, "Incoming by Source", C.CARD_CAT_WIDTH, C.CARD_CAT_HEIGHT, false)
  inCard:SetPoint("TOPLEFT", 0, 0)
  for idx, cat in ipairs(C.INCOME_CATEGORIES) do
    local row = CreateCategoryRow(inCard, -26 - (idx - 1) * 26, true)
    row.name:SetText(cat.name)
    inCatRows[cat.id] = row
  end

  -- Top-Right Card: Day Outgoing Categories
  local outCard = UILib:CreateCard(dayViewContainer, "Outgoing by Expense", C.CARD_CAT_WIDTH, C.CARD_CAT_HEIGHT, false)
  outCard:SetPoint("TOPRIGHT", 0, 0)
  for idx, cat in ipairs(C.EXPENSE_CATEGORIES) do
    local row = CreateCategoryRow(outCard, -24 - (idx - 1) * 24, false)
    row.name:SetText(cat.name)
    outCatRows[cat.id] = row
  end

  -- Bottom Card: Day-by-Day Monthly Performance Table
  local dayTableCard = UILib:CreateCard(dayViewContainer, "Day-by-Day Monthly Performance", C.CARD_BOTTOM_WIDTH, C.CARD_BOTTOM_HEIGHT, false)
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
    table.insert(dayTableRows, r)
  end

  dayTableEmpty = dayTableCard:CreateFontString(nil, "OVERLAY")
  dayTableEmpty:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "")
  dayTableEmpty:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  dayTableEmpty:SetPoint("CENTER", 0, -10)
  dayTableEmpty:SetText("No daily transactions recorded for this month.")
  dayTableEmpty:Hide()

  -----------------------------------------------------------------------------
  -- MONTH VIEW CONTAINER
  -----------------------------------------------------------------------------
  monthViewContainer = CreateFrame("Frame", nil, mainFrame)
  monthViewContainer:SetSize(C.FRAME_WIDTH - 20, 400)
  monthViewContainer:SetPoint("TOPLEFT", 10, -170)
  monthViewContainer:Hide()

  -- Top-Left Card: Monthly Aggregated Revenue
  local monthInCard = UILib:CreateCard(monthViewContainer, "Monthly Top Revenue", C.CARD_CAT_WIDTH, C.CARD_CAT_HEIGHT, false)
  monthInCard:SetPoint("TOPLEFT", 0, 0)
  for idx, cat in ipairs(C.INCOME_CATEGORIES) do
    local row = CreateCategoryRow(monthInCard, -26 - (idx - 1) * 26, true)
    row.name:SetText(cat.name)
    monthInCatRows[cat.id] = row
  end

  -- Top-Right Card: Monthly Aggregated Expenses
  local monthOutCard = UILib:CreateCard(monthViewContainer, "Monthly Top Expenses", C.CARD_CAT_WIDTH, C.CARD_CAT_HEIGHT, false)
  monthOutCard:SetPoint("TOPRIGHT", 0, 0)
  for idx, cat in ipairs(C.EXPENSE_CATEGORIES) do
    local row = CreateCategoryRow(monthOutCard, -24 - (idx - 1) * 24, false)
    row.name:SetText(cat.name)
    monthOutCatRows[cat.id] = row
  end

  -- Bottom Card: Month-by-Month Annual Performance Table
  local monthTableCard = UILib:CreateCard(monthViewContainer, "Month-by-Month Annual Performance", C.CARD_BOTTOM_WIDTH, C.CARD_BOTTOM_HEIGHT, false)
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
    table.insert(monthTableRows, r)
  end

  monthTableEmpty = monthTableCard:CreateFontString(nil, "OVERLAY")
  monthTableEmpty:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "")
  monthTableEmpty:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  monthTableEmpty:SetPoint("CENTER", 0, -10)
  monthTableEmpty:SetText("No monthly transactions recorded for this year.")
  monthTableEmpty:Hide()

  -- 5. Footer
  local footer = CreateFrame("Frame", nil, mainFrame)
  footer:SetSize(C.FRAME_WIDTH - 20, 30)
  footer:SetPoint("BOTTOMLEFT", 10, 8)

  local purseLabel = footer:CreateFontString(nil, "OVERLAY")
  purseLabel:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "")
  purseLabel:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
  purseLabel:SetPoint("LEFT", 0, 0)
  purseLabel:SetText("Backpack Wealth:")

  purseDisplay = footer:CreateFontString(nil, "OVERLAY")
  purseDisplay:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_SMALL, "OUTLINE")
  purseDisplay:SetPoint("LEFT", purseLabel, "RIGHT", 6, 0)

  local btnReset = UILib:CreateButton(footer, "Reset All", 80, 20, function()
    UI:ShowResetConfirmModal()
  end)
  btnReset:SetPoint("RIGHT", 0, 0)

  -- 6. Confirmation Popup Modal
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local modalOverlay = CreateFrame("Frame", nil, mainFrame)
  modalOverlay:SetAllPoints(mainFrame)
  modalOverlay:SetFrameStrata("DIALOG")
  modalOverlay:EnableMouse(true)
  modalOverlay:Hide()

  local modalDimmer = modalOverlay:CreateTexture(nil, "BACKGROUND")
  modalDimmer:SetAllPoints()
  modalDimmer:SetColorTexture(0, 0, 0, 0.75)

  local modalBox = CreateFrame("Frame", nil, modalOverlay, template)
  modalBox:SetSize(360, 150)
  modalBox:SetPoint("CENTER", modalOverlay, "CENTER", 0, 10)
  modalBox:SetBackdrop(C.MAIN_BACKDROP)
  modalBox:SetBackdropColor(C.COLORS.CARD_BG.r, C.COLORS.CARD_BG.g, C.COLORS.CARD_BG.b, 0.98)
  modalBox:SetBackdropBorderColor(C.COLORS.GOLD_BORDER.r, C.COLORS.GOLD_BORDER.g, C.COLORS.GOLD_BORDER.b, 1.0)
  modalBox:EnableMouse(true)

  local modalTitle = modalBox:CreateFontString(nil, "OVERLAY")
  modalTitle:SetFont(C.FONT_PRIMARY, 14, "OUTLINE")
  modalTitle:SetTextColor(C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)
  modalTitle:SetPoint("TOPLEFT", 16, -14)
  modalTitle:SetText("Reset All Records")

  local modalDivider = modalBox:CreateTexture(nil, "ARTWORK")
  modalDivider:SetPoint("TOPLEFT", 14, -34)
  modalDivider:SetPoint("TOPRIGHT", -14, -34)
  modalDivider:SetHeight(1)
  modalDivider:SetColorTexture(C.COLORS.CARD_BORDER.r, C.COLORS.CARD_BORDER.g, C.COLORS.CARD_BORDER.b, 1.0)

  local modalBody = modalBox:CreateFontString(nil, "OVERLAY")
  modalBody:SetFont(C.FONT_PRIMARY, C.FONT_SIZE_NORMAL, "")
  modalBody:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
  modalBody:SetPoint("TOPLEFT", 16, -44)
  modalBody:SetPoint("TOPRIGHT", -16, -44)
  modalBody:SetJustifyH("LEFT")
  modalBody:SetText("Are you sure you want to reset all financial records?\n\n|cFFFF3333This will permanently delete all daily and monthly records.|r")

  local btnCancel = UILib:CreateButton(modalBox, "Cancel", 75, 22, function()
    modalOverlay:Hide()
  end)
  btnCancel:SetPoint("BOTTOMRIGHT", modalBox, "BOTTOMRIGHT", -95, 14)

  local btnConfirm = UILib:CreateButton(modalBox, "Confirm", 75, 22, function()
    modalOverlay:Hide()
    Engine:ResetAll()
    print(C.COLORS.GOLD.hex .. C.TITLE .. ":|r All financial records have been reset.")
  end)
  btnConfirm:SetPoint("BOTTOMRIGHT", modalBox, "BOTTOMRIGHT", -14, 14)

  function UI:ShowResetConfirmModal()
    modalOverlay:Show()
  end

  mainFrame:Hide()
end

function UI:Initialize()
  if mainFrame then return end
  BuildUI()
end

-------------------------------------------------------------------------------
-- REFRESH & RENDER
-------------------------------------------------------------------------------

function UI:Refresh()
  if not mainFrame or not mainFrame:IsShown() then return end

  -- Update Purse
  purseDisplay:SetText(UILib:FormatMoneyWithTextures(GetMoney(), false))

  -- Update Scope Buttons and Ruleset Badge
  local currentScope = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  if btnScopeChar then
    btnScopeChar:SetActive(currentScope == "character")
  end
  if btnScopeAlliance then
    btnScopeAlliance:SetActive(currentScope == "alliance")
  end
  if btnScopeHorde then
    btnScopeHorde:SetActive(currentScope == "horde")
  end

  if rulesetBadge then
    local currentRuleset = Engine:GetCurrentRuleset()
    rulesetBadge:SetText("|cFF8CA0BA[Ruleset: |r|cFFFFD100" .. currentRuleset .. "|r|cFF8CA0BA]|r")
  end

  local isDay = (activeView == "day")
  tabDay:SetActive(isDay)
  tabMonth:SetActive(not isDay)

  -- Boundary check: disable '>' button if currently viewing today or current month
  local canGoNext = false
  if isDay then
    canGoNext = (selectedDate < Engine:GetTodayDate())
  else
    canGoNext = (selectedMonth < Engine:GetTodayMonth())
  end

  if canGoNext then
    btnNextDate:Enable()
  else
    btnNextDate:Disable()
  end

  if isDay then
    dayViewContainer:Show()
    monthViewContainer:Hide()

    local dayData = Engine:GetDayData(selectedDate, currentScope)
    dateLabel:SetText(selectedDate)
    btnToday:SetText("Today")

    -- Hero Card
    heroIncomeDisplay:SetText(UILib:FormatMoneyWithTextures(dayData.inTotal, false))
    heroExpenseDisplay:SetText(UILib:FormatMoneyWithTextures(dayData.outTotal, false))

    local net = dayData.net
    if net > 0 then
      heroNetText:SetTextColor(C.COLORS.PROFIT.r, C.COLORS.PROFIT.g, C.COLORS.PROFIT.b)
      heroNetText:SetText("+" .. UILib:FormatMoneyWithTextures(net, false))
      heroNetBadge:SetTextColor(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)
      heroNetBadge:SetText("Surplus (Profit)")
    elseif net < 0 then
      heroNetText:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
      heroNetText:SetText("-" .. UILib:FormatMoneyWithTextures(math.abs(net), false))
      heroNetBadge:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
      heroNetBadge:SetText("Deficit (Loss)")
    else
      heroNetText:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
      heroNetText:SetText(UILib:FormatMoneyWithTextures(0, false))
      heroNetBadge:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
      heroNetBadge:SetText("Balanced")
    end

    -- Day Category Rows
    for _, cat in ipairs(dayData.inCategories) do
      local rowKey = cat.key and ("in_" .. cat.key) or nil
      local row = rowKey and inCatRows[rowKey]
      if row then
        row.pct:SetText((cat.pct or 0) .. "%")
        row.bar:SetPercent(cat.pct or 0)
        row.amount:SetText(UILib:FormatMoneyWithTextures(cat.amount or 0, false))
      end
    end

    for _, cat in ipairs(dayData.outCategories) do
      local rowKey = cat.key and ("out_" .. cat.key) or nil
      local row = rowKey and outCatRows[rowKey]
      if row then
        row.pct:SetText((cat.pct or 0) .. "%")
        row.bar:SetPercent(cat.pct or 0)
        row.amount:SetText(UILib:FormatMoneyWithTextures(cat.amount or 0, false))
      end
    end

    -- Day-by-Day Monthly Performance Table for selected month (Descending)
    local currentMonthKey = string.sub(selectedDate, 1, 7)
    local monthData = Engine:GetMonthData(currentMonthKey, currentScope)

    if #monthData.days == 0 then
      dayTableEmpty:Show()
    else
      dayTableEmpty:Hide()
    end

    for i, row in ipairs(dayTableRows) do
      local item = monthData.days[i]
      if item then
        row:Show()
        row.col1:SetText(item.date)
        row.col2:SetText(UILib:FormatMoneyWithTextures(item.inTotal, false))
        row.col3:SetText(UILib:FormatMoneyWithTextures(item.outTotal, false))

        if item.net > 0 then
          row.col4:SetTextColor(C.COLORS.PROFIT.r, C.COLORS.PROFIT.g, C.COLORS.PROFIT.b)
          row.col4:SetText("+" .. UILib:FormatMoneyString(item.net, false))
        elseif item.net < 0 then
          row.col4:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
          row.col4:SetText("-" .. UILib:FormatMoneyString(math.abs(item.net), false))
        else
          row.col4:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
          row.col4:SetText("0g 0s 0c")
        end

        local isSelected = (item.date == selectedDate)
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

  else
    dayViewContainer:Hide()
    monthViewContainer:Show()

    local monthData = Engine:GetMonthData(selectedMonth, currentScope)
    dateLabel:SetText(UILib:FormatMonthString(selectedMonth))
    btnToday:SetText("This Month")

    -- Hero Card
    heroIncomeDisplay:SetText(UILib:FormatMoneyWithTextures(monthData.inTotal, false))
    heroExpenseDisplay:SetText(UILib:FormatMoneyWithTextures(monthData.outTotal, false))

    local net = monthData.net
    if net > 0 then
      heroNetText:SetTextColor(C.COLORS.PROFIT.r, C.COLORS.PROFIT.g, C.COLORS.PROFIT.b)
      heroNetText:SetText("+" .. UILib:FormatMoneyWithTextures(net, false))
      heroNetBadge:SetTextColor(C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)
      heroNetBadge:SetText("Surplus (Profit)")
    elseif net < 0 then
      heroNetText:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
      heroNetText:SetText("-" .. UILib:FormatMoneyWithTextures(math.abs(net), false))
      heroNetBadge:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
      heroNetBadge:SetText("Deficit (Loss)")
    else
      heroNetText:SetTextColor(C.COLORS.WHITE.r, C.COLORS.WHITE.g, C.COLORS.WHITE.b)
      heroNetText:SetText(UILib:FormatMoneyWithTextures(0, false))
      heroNetBadge:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
      heroNetBadge:SetText("Balanced")
    end

    -- Month Category Rows
    for _, cat in ipairs(monthData.inCategories) do
      local rowKey = cat.key and ("in_" .. cat.key) or nil
      local row = rowKey and monthInCatRows[rowKey]
      if row then
        row.pct:SetText((cat.pct or 0) .. "%")
        row.bar:SetPercent(cat.pct or 0)
        row.amount:SetText(UILib:FormatMoneyWithTextures(cat.amount or 0, false))
      end
    end

    for _, cat in ipairs(monthData.outCategories) do
      local rowKey = cat.key and ("out_" .. cat.key) or nil
      local row = rowKey and monthOutCatRows[rowKey]
      if row then
        row.pct:SetText((cat.pct or 0) .. "%")
        row.bar:SetPercent(cat.pct or 0)
        row.amount:SetText(UILib:FormatMoneyWithTextures(cat.amount or 0, false))
      end
    end

    -- Month-by-Month Annual Performance Table (Descending: Newest to Oldest)
    local yearData = Engine:GetYearData(selectedYear, currentScope)

    if #yearData == 0 then
      monthTableEmpty:Show()
    else
      monthTableEmpty:Hide()
    end

    for i, row in ipairs(monthTableRows) do
      local item = yearData[i]
      if item then
        row:Show()
        row.col1:SetText(UILib:FormatMonthString(item.key))
        row.col2:SetText(UILib:FormatMoneyWithTextures(item.inTotal, false))
        row.col3:SetText(UILib:FormatMoneyWithTextures(item.outTotal, false))

        if item.net > 0 then
          row.col4:SetTextColor(C.COLORS.PROFIT.r, C.COLORS.PROFIT.g, C.COLORS.PROFIT.b)
          row.col4:SetText("+" .. UILib:FormatMoneyString(item.net, false))
        elseif item.net < 0 then
          row.col4:SetTextColor(C.COLORS.LOSS.r, C.COLORS.LOSS.g, C.COLORS.LOSS.b)
          row.col4:SetText("-" .. UILib:FormatMoneyString(math.abs(item.net), false))
        else
          row.col4:SetTextColor(C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b)
          row.col4:SetText("0g 0s 0c")
        end

        local isSelected = (item.key == selectedMonth)
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
  activeView = viewMode
  self:Refresh()
end

function UI:SetDate(dateStr)
  local today = Engine:GetTodayDate()
  if dateStr > today then
    dateStr = today
  end
  selectedDate = dateStr
  selectedMonth = string.sub(dateStr, 1, 7)
  selectedYear = string.sub(dateStr, 1, 4)
  self:Refresh()
end

function UI:SetMonth(monthStr)
  local todayMonth = Engine:GetTodayMonth()
  if monthStr > todayMonth then
    monthStr = todayMonth
  end
  selectedMonth = monthStr
  selectedYear = string.sub(monthStr, 1, 4)
  local currentScope = (GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.selectedScope) or "character"
  local mData = Engine:GetMonthData(monthStr, currentScope)
  if mData.days and #mData.days > 0 then
    selectedDate = mData.days[1].date
  else
    selectedDate = monthStr .. "-01"
  end
  local today = Engine:GetTodayDate()
  if selectedDate > today then
    selectedDate = today
  end
  self:Refresh()
end

function UI:SetToday()
  selectedDate = Engine:GetTodayDate()
  selectedMonth = Engine:GetTodayMonth()
  selectedYear = Engine:GetTodayYear()
  self:Refresh()
end

function UI:NavigateDate(offset)
  local todayDate = Engine:GetTodayDate()
  local todayMonth = Engine:GetTodayMonth()

  if offset > 0 then
    if activeView == "day" and selectedDate >= todayDate then
      return
    elseif activeView == "month" and selectedMonth >= todayMonth then
      return
    end
  end

  if activeView == "day" then
    -- Parse current selectedDate
    local y, m, d = string.match(selectedDate, "(%d+)-(%d+)-(%d+)")
    if y and m and d then
      local t = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) + offset })
      local newDate = date("%Y-%m-%d", t)
      if offset > 0 and newDate > todayDate then
        newDate = todayDate
      end
      selectedDate = newDate
      selectedMonth = string.sub(selectedDate, 1, 7)
      selectedYear = string.sub(selectedDate, 1, 4)
    end
  else
    -- Parse current selectedMonth
    local y, m = string.match(selectedMonth, "(%d+)-(%d+)")
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
      selectedMonth = newMonthStr
      selectedYear = string.sub(selectedMonth, 1, 4)
    end
  end
  self:Refresh()
end

function UI:Toggle()
  if not mainFrame then
    self:Initialize()
  end
  if mainFrame:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

function UI:Show()
  if not mainFrame then
    self:Initialize()
  end
  mainFrame:Show()
  self:Refresh()
end

function UI:Hide()
  if mainFrame and mainFrame:IsShown() then
    mainFrame:Hide()
  end
end

function UI:IsShown()
  return mainFrame and mainFrame:IsShown()
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
    if not mainFrame then
      UI:Initialize()
    end
    UI:Show()
    UI:ShowResetConfirmModal()
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
