local addonName, addonTable = ...

addonTable.Constants = {}
local C = addonTable.Constants

-- Addon Metadata
C.ADDON_NAME = addonName or "Goblin-Journal"
C.VERSION = "1.1.2"
C.TITLE = "Goblin Journal"

-- Reset Week Constants (Tuesday 15:00 UTC)
C.WOW_RESET_EPOCH_OFFSET = 486000
C.WOW_RESET_CYCLE_SECONDS = 604800

-- Session Timer & History Retention
C.DEFAULT_SESSION_CAP = 50
C.SESSION_CAP_OPTIONS = { 50, 100, 200, 0 } -- 0 denotes Unlimited

-- Frame Dimensions
C.FRAME_WIDTH = 720
C.FRAME_HEIGHT = 615
C.CARD_CAT_WIDTH = 345
C.CARD_CAT_HEIGHT = 204
C.CARD_BOTTOM_WIDTH = 700
C.CARD_BOTTOM_HEIGHT = 180
C.HERO_BANNER_HEIGHT = 82

-- Bottom Zone Navigation Dimensions
C.ZONE_ROW_HEIGHT = 20
C.ZONE_ROW_STEP = 24
C.ZONE_BASE_HEIGHT = 24
C.ZONE_MAX_WIDTH = 700
C.ZONE_MORE_BTN_WIDTH = 58

-- Minimap Button Defaults (matching Plater / LibDBIcon-1.0)
C.MINIMAP_SIZE = 31
C.MINIMAP_DEFAULT_ANGLE = 225
C.MINIMAP_RADIUS_OFFSET = 5

-- Fonts
C.FONT_PRIMARY = "Fonts\\FRIZQT__.TTF"
C.FONT_SIZE_TITLE = 17
C.FONT_SIZE_VERSION = 9
C.FONT_SIZE_HERO_NET = 20
C.FONT_SIZE_HERO_LABEL = 11
C.FONT_SIZE_NORMAL = 12
C.FONT_SIZE_SMALL = 11
C.FONT_SIZE_TINY = 10

-- Theme Palette
C.COLORS = {
  GOLD = { r = 1.0, g = 0.82, b = 0.0, hex = "|cFFFFD100" },
  GOLD_DIM = { r = 0.81, g = 0.66, b = 0.29, hex = "|cFFCFA84A" },
  PROFIT = { r = 0.0, g = 1.0, b = 0.0, hex = "|cFF00FF00" },
  PROFIT_SOFT = { r = 0.27, g = 0.87, b = 0.27, hex = "|cFF44DD44" },
  LOSS = { r = 1.0, g = 0.2, b = 0.2, hex = "|cFFFF3333" },
  ORANGE = { r = 1.0, g = 0.6, b = 0.0, hex = "|cFFFF9900" },
  MUTED = { r = 0.55, g = 0.63, b = 0.73, hex = "|cFF8CA0BA" },
  WHITE = { r = 1.0, g = 1.0, b = 1.0, hex = "|cFFFFFFFF" },
  VERSION = { r = 0.61, g = 0.70, b = 0.82, hex = "|cFF9CB3D0" },
  CARD_BG = { r = 0.06, g = 0.08, b = 0.11, a = 0.92 },
  CARD_BORDER = { r = 0.16, g = 0.20, b = 0.28, a = 0.85 },
  GOLD_BORDER = { r = 0.70, g = 0.53, b = 0.16, a = 1.0 },
  ROW_HOVER = { r = 0.09, g = 0.13, b = 0.18, a = 0.7 },
  ROW_ACTIVE = { r = 0.11, g = 0.15, b = 0.23, a = 0.9 },
  ALLIANCE = { r = 0.25, g = 0.50, b = 1.0, hex = "|cFF4080FF" },
  HORDE = { r = 0.90, g = 0.20, b = 0.20, hex = "|cFFE63333" },
  CHARACTER = { r = 1.0, g = 0.82, b = 0.0, hex = "|cFFFFD100" }
}

-- Backdrops
C.MAIN_BACKDROP = {
  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

C.CARD_BACKDROP = {
  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 12,
  insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

-- Currency & Logo Textures
C.LOGO_TEXTURE = "Interface\\AddOns\\Goblin-Journal\\Media\\coin"
C.COIN_TEXTURE_GOLD = "Interface\\MoneyFrame\\UI-GoldIcon"
C.COIN_TEXTURE_SILVER = "Interface\\MoneyFrame\\UI-SilverIcon"
C.COIN_TEXTURE_COPPER = "Interface\\MoneyFrame\\UI-CopperIcon"
C.COIN_SIZE = 12

-- Category Definitions (100% Flat Integer keys)
C.INCOME_CATEGORIES = {
  { key = "ah", name = "Auction House", id = "in_ah" },
  { key = "loot", name = "Monsters & Loot", id = "in_loot" },
  { key = "quest", name = "Quest Rewards", id = "in_quest" },
  { key = "vendor", name = "Vendor Sales", id = "in_vendor" },
  { key = "trade", name = "Trade & Mail", id = "in_trade" },
  { key = "misc", name = "Other / Misc", id = "in_misc" }
}

C.EXPENSE_CATEGORIES = {
  { key = "repair", name = "Equipment Repairs", id = "out_repair" },
  { key = "ah", name = "Auction House (Deposits/Bids)", id = "out_ah" },
  { key = "vendor", name = "Vendor Purchases", id = "out_vendor" },
  { key = "taxi", name = "Flight & Travel", id = "out_taxi" },
  { key = "trainer", name = "Class & Profession Training", id = "out_trainer" },
  { key = "trade", name = "Trade & Mail", id = "out_trade" },
  { key = "misc", name = "Other / Misc", id = "out_misc" }
}

-- Default Configuration
C.DEFAULT_SETTINGS = {
  showMinimapBtn = true,
  minimapAngle = 225,
  selectedView = "day",
  selectedScope = "character",
  sessionCap = 50,
  pos = { "CENTER", 0, 0 },
  hudShown = true,
  hudLocked = false,
  hudPos = { "TOPLEFT", 200, -200 },
  hudInterval = 5,
  exportFormat = "csv",
  audioEnabled = true
}
