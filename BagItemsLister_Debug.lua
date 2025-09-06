local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Конфигурация
local BagItemsListerDB = {
    debugMode = false,
    filters = {
        quality = {},
        itemType = {},
        searchText = ""
    },
    windowSettings = {
        width = 400,
        height = 500,
        scale = 1.0
    }
}

-- Переменные для отладки
local debugWindow = nil
local debugData = {}
local debugHooks = {}

frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "BagItemsLister" then
        --CreateMainWindow()
        CreateDebugButton() -- Создаем кнопку отладки
        SLASH_BAGITEMS1 = "/bagdebug"
        SLASH_BAGITEMS2 = "/bid"
        
        
        SlashCmdList["BAGITEMS"] = function(msg)
            HandleCommand(msg)
        end

        print("Bag Items Lister loaded. Use /bagdebug or /bid help for debug tools")
    end
end)

-- Создание отладочной кнопки
function CreateDebugButton()
    -- Кнопка отладки (скрытая по умолчанию)
    local mainWin = _G.BIL_mainWindow or BagItemsLister.mainWindow
    if not mainWin then return end

    local debugBtn = CreateFrame("Button", nil, mainWin, "UIPanelButtonTemplate")
    debugBtn:SetSize(80, 20)
    debugBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    debugBtn:SetText("Debug")
    debugBtn:SetAlpha(0.3) -- Полупрозрачная
    debugBtn:Hide()
    debugBtn:SetShown()
    
    -- Показывать при Alt+клике на заголовок
    --mainWin.title:SetScript("OnMouseDown", function(self, button)
    --    if button == "LeftButton" and IsAltKeyDown() then
    --        debugBtn:SetShown(not debugBtn:IsShown())
    --    end
    --end)
    
    debugBtn:SetScript("OnClick", function()
        ToggleDebugWindow()
    end)
    
    mainWin.debugButton = debugBtn
end

-- Окно отладки
function ToggleDebugWindow()
    if not debugWindow then
        CreateDebugWindow()
    else
        if debugWindow:IsShown() then
            debugWindow:Hide()
        else
            debugWindow:Show()
            UpdateDebugWindow()
        end
    end
end

function CreateDebugWindow()
    debugWindow = CreateFrame("Frame", "BIL_DebugWindow", UIParent, "BasicFrameTemplate")
    debugWindow:SetSize(350, 400)
    debugWindow:SetPoint("CENTER", 150, 0)
    debugWindow:SetMovable(true)
    debugWindow:SetClampedToScreen(true)
    debugWindow:Hide()
    
    debugWindow.title = debugWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    debugWindow.title:SetPoint("TOP", 0, -5)
    debugWindow.title:SetText("Debug Tools")
    
    debugWindow.closeButton = CreateFrame("Button", nil, debugWindow, "UIPanelCloseButton")
    debugWindow.closeButton:SetPoint("TOPRIGHT", -3, -3)
    debugWindow.closeButton:SetScript("OnClick", function() debugWindow:Hide() end)
    
    -- Кнопки отладки
    local buttons = {
        {text = "Dump Items", func = function() DumpAllItems() end},
        {text = "Check Layout", func = function() CheckLayout() end},
        {text = "Show Events", func = function() ToggleEventDebug() end},
        {text = "Memory Info", func = function() ShowMemoryUsage() end},
        {text = "Reload UI", func = function() ReloadUI() end},
        {text = "Clear Filters", func = function() ClearFilters(); UpdateWindowContent() end},
    }
    
    for i, btnInfo in ipairs(buttons) do
        local btn = CreateFrame("Button", nil, debugWindow, "UIPanelButtonTemplate")
        btn:SetSize(120, 25)
        btn:SetPoint("TOPLEFT", 20, -30 - (i-1)*35)
        btn:SetText(btnInfo.text)
        btn:SetScript("OnClick", btnInfo.func)
    end
    
    -- Консоль вывода
    debugWindow.console = CreateFrame("ScrollFrame", nil, debugWindow, "UIPanelScrollFrameTemplate")
    debugWindow.console:SetPoint("BOTTOMLEFT", 10, 40)
    debugWindow.console:SetPoint("BOTTOMRIGHT", -30, 40)
    debugWindow.console:SetHeight(150)
    
    debugWindow.consoleContent = CreateFrame("Frame")
    debugWindow.consoleContent:SetSize(debugWindow.console:GetWidth() - 20, 100)
    debugWindow.console:SetScrollChild(debugWindow.consoleContent)
    
    debugWindow.consoleText = debugWindow.consoleContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    debugWindow.consoleText:SetPoint("TOPLEFT", 5, -5)
    debugWindow.consoleText:SetJustifyH("LEFT")
    debugWindow.consoleText:SetText("Debug console ready...")
end

function UpdateDebugWindow()
    if not debugWindow then return end
    
    local text = "=== DEBUG INFO ===\n"
    text = text .. "Items in bags: " .. #GetFilteredBagItemsList() .. "\n"
    text = text .. "Debug mode: " .. tostring(BagItemsListerDB.debugMode) .. "\n"
    text = text .. "Active filters: " .. GetActiveFiltersString() .. "\n"
    
    debugWindow.consoleText:SetText(text)
    debugWindow.consoleText:SetHeight(debugWindow.consoleText:GetStringHeight() + 20)
    debugWindow.consoleContent:SetHeight(debugWindow.consoleText:GetStringHeight() + 30)
end

-- Инструменты отладки
function DumpAllItems()
    local items = GetFilteredBagItemsList()
    DebugLog("=== DUMP ALL ITEMS ===")
    for i, item in ipairs(items) do
        DebugLog(string.format("[%d:%d] %s x%d (ID: %d)", 
            item.bag, item.slot, item.name, item.count, item.itemID))
    end
    UpdateDebugWindow()
end

function CheckLayout()
    if mainWin then
        DebugLog("=== LAYOUT CHECK ===")
        DebugLog("MainWindow: " .. mainWin:GetWidth() .. "x" .. mainWin:GetHeight())
        DebugLog("ScrollFrame: " .. scrollFrame:GetWidth() .. "x" .. scrollFrame:GetHeight())
        DebugLog("ContentFrame: " .. contentFrame:GetWidth() .. "x" .. contentFrame:GetHeight())
        
        if contentFrame[1] then
            DebugLog("First item top: " .. contentFrame[1]:GetTop())
            DebugLog("Button bottom: " .. mainWin.refreshButton:GetTop())
        end
    end
    UpdateDebugWindow()
end

function ToggleEventDebug()
    if not debugHooks.events then
        -- Хук для отслеживания событий
        debugHooks.events = true
        local oldOnEvent = frame:GetScript("OnEvent")
        frame:SetScript("OnEvent", function(self, event, ...)
            DebugLog("EVENT: " .. event)
            if oldOnEvent then
                oldOnEvent(self, event, ...)
            end
        end)
        DebugLog("Event debugging ENABLED")
    else
        -- Выключаем хук
        debugHooks.events = false
        frame:SetScript("OnEvent", nil)
        frame:RegisterEvent("ADDON_LOADED")
        DebugLog("Event debugging DISABLED")
    end
    UpdateDebugWindow()
end

function ShowMemoryUsage()
    UpdateAddOnMemoryUsage()
    local mem = GetAddOnMemoryUsage("BagItemsLister")
    DebugLog("Memory usage: " .. string.format("%.2f", mem) .. " KB")
    UpdateDebugWindow()
end

-- Улучшенная функция отладки
function DebugLog(message)
    if BagItemsListerDB.debugMode then
        local timestamp = date("%H:%M:%S")
        local debugMsg = "|cFF00FF00[" .. timestamp .. "]|r " .. message
        
        -- Вывод в чат
        print(debugMsg)
        
        -- Вывод в консоль отладки
        if debugWindow and debugWindow.consoleText then
            local currentText = debugWindow.consoleText:GetText() or ""
            debugWindow.consoleText:SetText(currentText .. "\n" .. message)
            
            -- Автопрокрутка
            local height = debugWindow.consoleText:GetStringHeight() + 30
            debugWindow.consoleContent:SetHeight(height)
            debugWindow.console:SetVerticalScroll(height)
        end
    end
end

-- Добавляем команды отладки
function HandleCommand(msg)
    local command, param = string.match(msg, "^(%S*)%s*(.-)$")
    
    if command == "debug" then
        ToggleDebugMode()
        ToggleDebugWindow()
    elseif command == "dump" then
        DumpAllItems()
    elseif command == "layout" then
        CheckLayout()
    elseif command == "memory" then
        ShowMemoryUsage()
    elseif command == "events" then
        ToggleEventDebug()
    else
        -- остальные команды...
    end
end

function ToggleDebugMode()
    BagItemsListerDB.debugMode = not BagItemsListerDB.debugMode
    local status = BagItemsListerDB.debugMode and "|cFF00FF00ENABLED|r" or "|cFFFF0000DISABLED|r"
    print("Debug mode: " .. status)
    
    -- Показываем/скрываем кнопку отладки
    if mainWin.debugButton then
        if BagItemsListerDB.debugMode then
            mainWin.debugButton:Show()
        else
            mainWin.debugButton:Hide()
        end
    end
end

BagItemsLister_Debug = {
    CreateDebugButton = CreateDebugButton,
    ToggleDebugWindow = ToggleDebugWindow,
    DebugLog = DebugLog
}
_G.BIL_Debug = BagItemsLister_Debug