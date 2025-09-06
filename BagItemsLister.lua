local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Конфигурация окна
local BagItemsListerDB = {
    debugMode = true,
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

-- Основное окно аддона
local mainWindow = nil
local scrollFrame = nil
local contentFrame = nil

-- Переменные для отладки
local debugWindow = nil

--Базовая функция отладки
function DebugLog(message)
    if BagItemsListerDB.debugMode then
        print("DEBUG:", message)
    end
end

frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "BagItemsLister" then
        CreateMainWindow()
        
        SLASH_BAGITEMS1 = "/bagitems"
        SLASH_BAGITEMS2 = "/bi"
        
        SlashCmdList["BAGITEMS"] = function(msg)
            HandleCommand(msg)
        end
        
        print("Bag Items Lister loaded. Use /bagitems help for commands")
    end
end)

-- Создание главного окна
function CreateMainWindow()
    -- Основное окно
    mainWindow = CreateFrame("Frame", "BagItemsListerWindow", UIParent, "BasicFrameTemplate")
    mainWindow:SetSize(BagItemsListerDB.windowSettings.width, BagItemsListerDB.windowSettings.height)
    mainWindow:SetPoint("CENTER")
    mainWindow:SetMovable(true)
    mainWindow:SetClampedToScreen(true)
    mainWindow:SetScale(BagItemsListerDB.windowSettings.scale)
    mainWindow:EnableMouse(true)
    mainWindow:RegisterForDrag("LeftButton")
    mainWindow:Hide()
    
    -- Заголовок окна
    mainWindow.title = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainWindow.title:SetPoint("TOP", 0, -5)
    mainWindow.title:SetText("Bag Items Lister")
    
    -- Область для контента с прокруткой
    scrollFrame = CreateFrame("ScrollFrame", nil, mainWindow, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40) -- Место для кнопки
    
    -- Область с основной информацией
    contentFrame = CreateFrame("Frame")
    contentFrame:SetSize(scrollFrame:GetWidth() - 20, 100)
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Кнопка обновления
    local refreshButton = CreateFrame("Button", nil, mainWindow, "UIPanelButtonTemplate")
    refreshButton:SetSize(100, 25)
    refreshButton:SetPoint("BOTTOM", 0, 10)
    refreshButton:SetText("Обновить")
    refreshButton:SetScript("OnClick", function() UpdateWindowContent() end)

    -- Кнопка отладки (простая версия)
    CreateDebugButton()
    
    -- Создаем невидимый фрейм для перетаскивания в области заголовка
    local dragFrame = CreateFrame("Frame", nil, mainWindow)
    dragFrame:SetPoint("TOPLEFT", 5, -5)
    dragFrame:SetPoint("TOPRIGHT", -25, -5)
    dragFrame:SetHeight(20)
    dragFrame:EnableMouse(true)
    dragFrame:RegisterForDrag("LeftButton")
    dragFrame:SetScript("OnDragStart", function() 
        mainWindow:StartMoving() 
    end)
    dragFrame:SetScript("OnDragStop", function() 
        mainWindow:StopMovingOrSizing() 
    end)
    
    -- Делаем заголовок дочерним элементом dragFrame, чтобы он отображался поверх
    mainWindow.title:SetParent(dragFrame)
    mainWindow.title:SetPoint("CENTER")
    
    -- Обработчики для самого окна
    mainWindow:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    mainWindow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    
    -- Подсветка при наведении на область перетаскивания
    dragFrame:SetScript("OnEnter", function(self)
        mainWindow.title:SetTextColor(1, 0.8, 0) -- Желтый цвет при наведении
    end)
    
    dragFrame:SetScript("OnLeave", function(self)
        mainWindow.title:SetTextColor(1, 1, 1) -- Белый цвет обычно
    end)
end

-- Простая кнопка отладки
function CreateDebugButton()
    local btn = CreateFrame("Button", nil, mainWindow, "UIPanelButtonTemplate")
    btn:SetSize(70, 20)
    btn:SetPoint("BOTTOMRIGHT", -80, 10)
    btn:SetText("Debug")
    btn:SetAlpha(0.4)
    
    btn:SetScript("OnClick", function()
        if BagItemsListerDB.debugMode then
            DebugEvent()
        end
    end)
    
    -- Показывать кнопку при Alt+клике на заголовок
    --mainWindow.title:SetScript("OnMouseDown", function(self, button)
    --    if button == "LeftButton" and IsAltKeyDown() then
    --        btn:SetShown(not btn:IsShown())
    --    end
    --end)
end

-- Обновление содержимого окна
function UpdateWindowContent()
    if not mainWindow or not contentFrame then return end
    
    -- Очищаем предыдущее содержимое
    for i = 1, #contentFrame do
        if contentFrame[i] then
            contentFrame[i]:Hide()
            contentFrame[i] = nil
        end
    end
    
    local items = GetFilteredBagItemsList()
    local totalHeight = 0
    local availableWidth = scrollFrame:GetWidth() - 50
    local scrollHeight = scrollFrame:GetHeight()

    if #items == 0 then
        -- Сообщение если предметов нет
        local noItemsText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noItemsText:SetPoint("TOP", 0, -20)
        noItemsText:SetText("Не найдено предметов по текущим фильтрам!")
        noItemsText:SetTextColor(1, 0.5, 0.5)
        totalHeight = 40
    else
        -- Заголовок
        local headerText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        headerText:SetPoint("TOP", 0, -10)
        headerText:SetText(string.format("Найдено предметов: %d", #items))
        
        -- Активные фильтры
        if next(BagItemsListerDB.filters.quality) or next(BagItemsListerDB.filters.itemType) or BagItemsListerDB.filters.searchText ~= "" then
            local filtersText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            filtersText:SetPoint("TOP", 0, -30)
            filtersText:SetText("Фильтры: " .. GetActiveFiltersString())
            filtersText:SetTextColor(0.8, 0.8, 0.8)
            totalHeight = 50
        else
            totalHeight = 30
        end
        
        -- Создаем элементы для каждого предмета
        for i, item in ipairs(items) do
            local itemFrame = CreateFrame("Frame", nil, contentFrame)
            itemFrame:SetSize(availableWidth, 20)
            itemFrame:SetPoint("TOPLEFT", 10, -totalHeight - (i-1)*25)
            
            -- Иконка предмета
            local icon = itemFrame:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18)
            icon:SetPoint("LEFT")
            icon:SetTexture(GetItemIcon(item.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
            
            -- Название предмета
            local nameText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameText:SetPoint("LEFT", 25, 0)
            nameText:SetText(item.name)
            nameText:SetTextColor(GetQualityColorRGB(item.quality))
            
            -- Количество
            if item.count > 1 then
                local countText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                countText:SetPoint("RIGHT")
                countText:SetText("x" .. item.count)
                countText:SetTextColor(1, 1, 1)
            end
            
            -- Позиция в сумке
            local positionText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            positionText:SetPoint("RIGHT", -30, 0)
            positionText:SetText(string.format("[%d:%d]", item.bag, item.slot))
            positionText:SetTextColor(0.7, 0.7, 0.7)
            
            contentFrame[i] = itemFrame
            totalHeight = totalHeight + 25
        end
    end
    
    -- Обновляем размер contentFrame для прокрутки
    --contentFrame:SetHeight(totalHeight + 10)
    contentFrame:SetSize(availableWidth, math.max(scrollHeight, totalHeight))
end

-- Функция для получения RGB цвета качества
function GetQualityColorRGB(quality)
    local colors = {
        [0] = {0.61, 0.61, 0.61}, -- серый
        [1] = {1.00, 1.00, 1.00}, -- белый
        [2] = {0.12, 1.00, 0.00}, -- зеленый
        [3] = {0.00, 0.44, 0.87}, -- синий
        [4] = {0.64, 0.21, 0.93}, -- фиолетовый
        [5] = {1.00, 0.50, 0.00}, -- оранжевый
    }
    return unpack(colors[quality] or {1, 1, 1})
end

-- Обработчик команд
function HandleCommand(msg)
    local command, param = string.match(msg, "^(%S*)%s*(.-)$")
    
    if command == "help" then
        PrintHelp()
    elseif command == "debug" then
        ToggleDebugMode()
    elseif command == "filter" then
        SetFilter(param)
    elseif command == "search" then
        SearchItems(param)
    elseif command == "clear" then
        ClearFilters()
    elseif command == "stats" then
        ShowStatistics()
    elseif command == "show" then
        ToggleWindow()
    else
        ToggleWindow()
    end
end

function ToggleDebugMode()
    BagItemsListerDB.debugMode = not BagItemsListerDB.debugMode
    local status = BagItemsListerDB.debugMode and "|cFF00FF00ENABLED|r" or "|cFFFF0000DISABLED|r"
    print("Debug mode: " .. status)
    UpdateWindowContent()
end

function PrintHelp()
    print("=== Bag Items Lister - Команды ===")
    print("/bi - показать/скрыть окно")
    print("/bi show - показать окно")
    print("/bi help - эта справка")
    print("/bi debug - режим отладки")
    print("/bi filter [quality|type] - фильтр по качеству/типу")
    print("/bi search [текст] - поиск по названию")
    print("/bi clear - очистить фильтры")
    print("/bi stats - статистика предметов")
end

function ToggleWindow()
    if mainWindow:IsShown() then
        mainWindow:Hide()
    else
        mainWindow:Show()
        UpdateWindowContent()
    end
end

function GetFilteredBagItemsList()
    local items = {}
    local totalCount = 0
    
    for bag = 0, 4 do
        local numberOfSlots = GetContainerNumSlots(bag)
        if numberOfSlots > 0 then
            for slot = 1, numberOfSlots do
                local itemTexture, itemCount, locked, quality, readable, lootable, 
                      itemLink, isFiltered, noValue, itemID = GetContainerItemInfo(bag, slot)
                
                if itemLink then
                    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType,
                          itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemLink)
                    
                    if itemName then
                        totalCount = totalCount + 1
                        
                        -- Проверка фильтров
                        local shouldInclude = true
                        
                        -- Фильтр по качеству
                        if next(BagItemsListerDB.filters.quality) then
                            local qualityName = GetQualityName(itemRarity)
                            shouldInclude = shouldInclude and BagItemsListerDB.filters.quality[qualityName]
                        end
                        
                        -- Фильтр по типу
                        if next(BagItemsListerDB.filters.itemType) then
                            shouldInclude = shouldInclude and BagItemsListerDB.filters.itemType[itemType:lower()]
                        end
                        
                        -- Поиск по тексту
                        if BagItemsListerDB.filters.searchText ~= "" then
                            shouldInclude = shouldInclude and string.find(itemName:lower(), BagItemsListerDB.filters.searchText)
                        end
                        
                        if shouldInclude then
                            table.insert(items, {
                                bag = bag,
                                slot = slot,
                                name = itemName,
                                count = itemCount,
                                quality = itemRarity,
                                itemLink = itemLink,
                                itemID = itemID,
                                type = itemType,
                                subType = itemSubType
                            })
                        end
                    end
                end
            end
        end
    end
    
    DebugLog(string.format("Отфильтровано %d из %d предметов", #items, totalCount))
    return items
end

function GetQualityName(quality)
    local qualities = {
        [0] = "poor",
        [1] = "common",
        [2] = "uncommon",
        [3] = "rare",
        [4] = "epic",
        [5] = "legendary"
    }
    return qualities[quality] or "unknown"
end

function GetActiveFiltersString()
    local filters = {}
    
    for quality in pairs(BagItemsListerDB.filters.quality) do
        table.insert(filters, "качество:" .. quality)
    end
    
    for itemType in pairs(BagItemsListerDB.filters.itemType) do
        table.insert(filters, "тип:" .. itemType)
    end
    
    if BagItemsListerDB.filters.searchText ~= "" then
        table.insert(filters, "поиск:" .. BagItemsListerDB.filters.searchText)
    end
    
    return table.concat(filters, ", ")
end

function ShowStatistics()
    local items = GetFilteredBagItemsList()
    local stats = {
        total = 0,
        byQuality = {},
        byType = {}
    }
    
    for _, item in ipairs(items) do
        stats.total = stats.total + item.count
        
        -- Статистика по качеству
        local qualityName = GetQualityName(item.quality)
        stats.byQuality[qualityName] = (stats.byQuality[qualityName] or 0) + item.count
        
        -- Статистика по типам
        stats.byType[item.type] = (stats.byType[item.type] or 0) + item.count
    end
    
    -- Создаем отдельное окно для статистики
    local statsWindow = CreateFrame("Frame", "StatsWindow", UIParent, "BasicFrameTemplate")
    statsWindow:SetSize(300, 400)
    statsWindow:SetPoint("CENTER")
    statsWindow:SetMovable(true)
    statsWindow:SetClampedToScreen(true)
    
    statsWindow.title = statsWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statsWindow.title:SetPoint("TOP", 0, -5)
    statsWindow.title:SetText("Статистика предметов")
    
    statsWindow.closeButton = CreateFrame("Button", nil, statsWindow, "UIPanelCloseButton")
    statsWindow.closeButton:SetPoint("TOPRIGHT", -3, -3)
    statsWindow.closeButton:SetScript("OnClick", function() statsWindow:Hide() end)
    
    local content = CreateFrame("Frame", nil, statsWindow)
    content:SetPoint("TOPLEFT", 10, -30)
    content:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 10, -10)
    
    local statsText = string.format("Всего предметов: %d\n\nПо качеству:\n", stats.total)
    for quality, count in pairs(stats.byQuality) do
        statsText = statsText .. string.format("  %s: %d\n", quality, count)
    end
    
    statsText = statsText .. "\nПо типам:\n"
    for itemType, count in pairs(stats.byType) do
        statsText = statsText .. string.format("  %s: %d\n", itemType, count)
    end
    
    text:SetText(statsText)
    statsWindow:Show()
end

function DumpUnknownTable(t, tableName, maxDepth)
    tableName = tableName or "unknown"
    maxDepth = maxDepth or 3
    local visited = {}
    
    local function dumpRecursive(t, indent, depth, path)
        indent = indent or 0
        depth = depth or 0
        path = path or tableName
        
        if depth > maxDepth then
            return string.rep("  ", indent) .. "... (max depth reached)\n"
        end
        
        if visited[t] then
            return string.rep("  ", indent) .. path .. ": [[circular reference]]\n"
        end
        visited[t] = true
        
        local result = ""
        for k, v in pairs(t) do
            local keyStr = tostring(k)
            local fullPath = path .. "." .. keyStr
            local formatting = string.rep("  ", indent) .. keyStr .. ": "
            
            if type(v) == "table" then
                result = result .. formatting .. "{\n"
                result = result .. dumpRecursive(v, indent + 1, depth + 1, fullPath)
                result = result .. string.rep("  ", indent) .. "}\n"
            else
                local valueStr = tostring(v)
                if type(v) == "string" then
                    valueStr = "\"" .. valueStr .. "\""
                elseif type(v) == "boolean" then
                    valueStr = valueStr and "true" or "false"
                end
                result = result .. formatting .. valueStr .. "\n"
            end
        end
        
        visited[t] = nil
        return result
    end
    
    print("=== " .. tableName .. " ===")
    if type(t) == "table" then
        print(dumpRecursive(t, 0, 0, tableName))
    else
        print(tostring(t))
    end
    print("==================")
end
-- Функция отладки 
function DebugEvent()    
    DebugLog("=== DEBUG ===")
    
    -- Блок кода

    DebugLog("=== DUMP ALL ITEMS ===")
    local items = {}
    local totalCount = 0
    
    for bag = 0, 4 do
        local numberOfSlots = GetContainerNumSlots(bag)
        if numberOfSlots > 0 then
            for slot = 1, numberOfSlots do
                local texture, itemCount, locked, quality, readable, lootable, 
                      itemLink, isFiltered, noValue, itemID = GetContainerItemInfo(bag, slot)
                
                if itemLink then
                    -- Получаем ВСЮ доступную информацию
                    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType,
                          itemSubType, itemStackCount, itemEquipLoc, itemTexture, 
                          itemSellPrice = GetItemInfo(itemLink)
                    
                    local itemStats = GetItemStats(itemLink)
                    local isQuestItem, questID, isActive = GetContainerItemQuestInfo(bag, slot)
                    
                    if itemName then
                        totalCount = totalCount + 1
                        
                        -- Проверка фильтров
                        local shouldInclude = true
                        -- ... ваша логика фильтрации ...
                        
                        if shouldInclude then
                            table.insert(items, {
                                -- Основная информация
                                bag = bag,
                                slot = slot,
                                name = itemName,
                                count = itemCount,
                                quality = itemRarity,
                                itemLink = itemLink,
                                itemID = itemID,
                                
                                -- Дополнительная информация
                                type = itemType,
                                subType = itemSubType,
                                equipLoc = itemEquipLoc,
                                itemLevel = itemLevel,
                                minLevel = itemMinLevelb,
                                texture = itemTexture,
                                sellPrice = itemSellPrice,
                                
                                -- Специальные флаги
                                isQuest = isQuestItem,
                                questID = questID,
                                isReadable = readable,
                                isLocked = locked,
                                isLootable = lootable,
                                
                                -- Статистика
                                stats = itemStats,
                                
                                -- Сокеты (если есть)
                                gem1 = GetItemGem(itemLink, 1),
                                gem2 = GetItemGem(itemLink, 2),
                                gem3 = GetItemGem(itemLink, 3),
                                
                                -- Заклинание (если есть)
                                spell = GetItemSpell(itemLink)
                            })
                        end
                    end
                end
            end
        end
        for k,v in pairs(items) do
            DumpUnknownTable(v,k)
        end
    end
end

