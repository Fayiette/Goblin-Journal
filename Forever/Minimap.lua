local addonName, addonTable = ...

addonTable.Minimap = {}
local MinimapModule = addonTable.Minimap
local C = addonTable.Constants
local UILib = addonTable.UILib
local Engine = addonTable.Engine

local button

-- Standard quadrant lookup table for non-round minimap shapes (LibDBIcon-1.0 standard)
local minimapShapes = {
  ["ROUND"] = { true, true, true, true },
  ["SQUARE"] = { false, false, false, false },
  ["CORNER-TOPLEFT"] = { false, false, false, true },
  ["CORNER-TOPRIGHT"] = { false, false, true, false },
  ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
  ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
  ["SIDE-LEFT"] = { false, true, false, true },
  ["SIDE-RIGHT"] = { true, false, true, false },
  ["SIDE-TOP"] = { false, false, true, true },
  ["SIDE-BOTTOM"] = { true, true, false, false },
  ["TRICORNER-TOPLEFT"] = { false, true, true, true },
  ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
  ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
  ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

-- Update positioning matching Plater / LibDBIcon-1.0
local function UpdateButtonPosition()
  if not button or not Minimap then return end
  local angle = math.rad(GoblinJournalDB.settings.minimapAngle or C.MINIMAP_DEFAULT_ANGLE)
  local x, y, q = math.cos(angle), math.sin(angle), 1
  if x < 0 then q = q + 1 end
  if y > 0 then q = q + 2 end

  local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
  local quadTable = minimapShapes[minimapShape] or minimapShapes["ROUND"]

  local mapW = Minimap:GetWidth()
  if not mapW or mapW <= 0 then mapW = 140 end
  local mapH = Minimap:GetHeight()
  if not mapH or mapH <= 0 then mapH = 140 end

  -- Plater / LibDBIcon-1.0 standard radius offset: lib.radius = 5
  local radiusOffset = C.MINIMAP_RADIUS_OFFSET or 5
  local w = (mapW / 2) + radiusOffset
  local h = (mapH / 2) + radiusOffset

  if quadTable[q] then
    x, y = x * w, y * h
  else
    local diagRadiusW = math.sqrt(2 * (w ^ 2)) - 10
    local diagRadiusH = math.sqrt(2 * (h ^ 2)) - 10
    x = math.max(-w, math.min(x * diagRadiusW, w))
    y = math.max(-h, math.min(y * diagRadiusH, h))
  end

  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapModule:UpdatePosition()
  UpdateButtonPosition()
end

function MinimapModule:Show()
  if button then
    button:Show()
    if GoblinJournalDB and GoblinJournalDB.settings then
      GoblinJournalDB.settings.showMinimapBtn = true
    end
  end
end

function MinimapModule:Hide()
  if button then
    button:Hide()
    if GoblinJournalDB and GoblinJournalDB.settings then
      GoblinJournalDB.settings.showMinimapBtn = false
    end
  end
end

function MinimapModule:Toggle()
  if button and button:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

function MinimapModule:Initialize()
  if button then return end

  local isMainline = (WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

  -- Button Frame (matching LibDBIcon-1.0 31x31 specification in Plater)
  button = CreateFrame("Button", "GoblinJournalMinimapButton", Minimap)
  button:SetSize(C.MINIMAP_SIZE or 31, C.MINIMAP_SIZE or 31)
  button:SetFrameStrata("MEDIUM")
  if button.SetFixedFrameStrata then
    button:SetFixedFrameStrata(true)
  end
  button:SetFrameLevel(8)
  if button.SetFixedFrameLevel then
    button:SetFixedFrameLevel(true)
  end
  button:SetMovable(true)
  button:EnableMouse(true)
  button:RegisterForClicks("AnyUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  -- Background circular backing (matching Plater / LibDBIcon-1.0)
  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  if isMainline then
    background:SetSize(24, 24)
    background:SetPoint("CENTER", 0, 0)
  else
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
  end
  button.background = background

  -- Center Artwork Coin Icon (matching Plater coordinate insetting & sizing)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(C.LOGO_TEXTURE or "Interface\\Icons\\INV_Misc_Coin_02")
  if isMainline then
    icon:SetSize(18, 18)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", 0, 0)
  else
    icon:SetSize(17, 17)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", 7, -6)
  end

  local function updateCoord(self)
    local deltaX, deltaY = 0, 0
    if not self:GetParent().isMouseDown then
      deltaX = 0.05
      deltaY = 0.05
    end
    self:SetTexCoord(deltaX, 1 - deltaX, deltaY, 1 - deltaY)
  end
  icon.UpdateCoord = updateCoord
  icon:UpdateCoord()
  button.icon = icon

  -- Circular Tracking Border Overlay (matching Plater / LibDBIcon-1.0)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:ClearAllPoints()
  border:SetPoint("TOPLEFT", 0, 0)
  if isMainline then
    border:SetSize(50, 50)
  else
    border:SetSize(53, 53)
  end
  button.border = border

  -- Tactical Mouse Feedback
  button.isMouseDown = false

  button:SetScript("OnMouseDown", function(self)
    self.isMouseDown = true
    self.icon:UpdateCoord()
  end)

  button:SetScript("OnMouseUp", function(self)
    self.isMouseDown = false
    self.icon:UpdateCoord()
  end)

  -- Drag Handlers (matching LibDBIcon-1.0)
  button:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self.isMouseDown = true
    self.icon:UpdateCoord()
    self.isDragging = true
  end)

  button:SetScript("OnDragStop", function(self)
    self.isDragging = false
    self.isMouseDown = false
    self.icon:UpdateCoord()
    self:UnlockHighlight()
    self.dragJustEnded = true
    if C_Timer and C_Timer.After then
      C_Timer.After(0.05, function()
        self.dragJustEnded = false
      end)
    else
      self.dragJustEnded = false
    end
  end)

  button:SetScript("OnUpdate", function(self)
    if self.isDragging then
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      if mx and my and px and py and scale and scale > 0 then
        px, py = px / scale, py / scale
        local pos = math.deg(math.atan2(py - my, px - mx)) % 360
        GoblinJournalDB.settings.minimapAngle = pos
        UpdateButtonPosition()
      end
    end
  end)

  -- Click Handler
  button:SetScript("OnClick", function(self, btn)
    if self.dragJustEnded then
      self.dragJustEnded = false
      return
    end
    if btn == "LeftButton" then
      if addonTable.UI and addonTable.UI.Toggle then
        addonTable.UI:Toggle()
      end
    elseif btn == "RightButton" then
      if addonTable.UI and addonTable.UI.SetToday then
        addonTable.UI:SetToday()
        if not addonTable.UI:IsShown() then
          addonTable.UI:Show()
        end
      end
    end
  end)

  -- Hover Tooltip
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(C.TITLE .. " |cFF9CB3D0v" .. C.VERSION .. "|r", C.COLORS.GOLD.r, C.COLORS.GOLD.g, C.COLORS.GOLD.b)

    local today = Engine:GetTodayDate()
    local dayData = Engine:GetDayData(today)
    local net = dayData.net

    local netColor = C.COLORS.MUTED
    local netLabel = "Balanced"
    if net > 0 then
      netColor = C.COLORS.PROFIT
      netLabel = "Surplus"
    elseif net < 0 then
      netColor = C.COLORS.LOSS
      netLabel = "Deficit"
    end

    local netFormatted = UILib:FormatMoneyString(net, true)
    GameTooltip:AddDoubleLine("Today's Net (" .. netLabel .. "):", netFormatted, 1, 1, 1, netColor.r, netColor.g, netColor.b)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Income:", UILib:FormatMoneyString(dayData.inTotal, false), 0.7, 0.7, 0.7, C.COLORS.PROFIT_SOFT.r, C.COLORS.PROFIT_SOFT.g, C.COLORS.PROFIT_SOFT.b)
    GameTooltip:AddDoubleLine("Expenses:", UILib:FormatMoneyString(dayData.outTotal, false), 0.7, 0.7, 0.7, C.COLORS.ORANGE.r, C.COLORS.ORANGE.g, C.COLORS.ORANGE.b)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cFFCFA84ALeft-Click:|r Open Ledger", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cFFCFA84ARight-Click:|r Jump to Today", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cFFCFA84ADrag:|r Move Minimap Icon", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)

  button:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)

  if GoblinJournalDB and GoblinJournalDB.settings and GoblinJournalDB.settings.showMinimapBtn == false then
    button:Hide()
  else
    button:Show()
  end

  UpdateButtonPosition()
end

if IsLoggedIn and IsLoggedIn() then
  MinimapModule:Initialize()
else
  local loader = CreateFrame("Frame")
  loader:RegisterEvent("PLAYER_LOGIN")
  loader:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
      MinimapModule:Initialize()
    end
  end)
end
