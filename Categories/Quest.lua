local _, ns = ...
local Rummage = ns.core

-- Quest items: the usable item attached to a quest in your log (the same
-- item the objective tracker shows a button for), plus bag items that start
-- a quest. Ranked by how relevant the quest is right now:
--   1. the super-tracked quest (the one the map is pointing you to)
--   2. quests on the current map
--   3. quests you are tracking
--   4. every other quest in the log
--   5. items that begin a quest
-- Items for quests that are already complete rank below all of those unless
-- the quest still needs the item to turn in.

local QUEST_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12

local questItems = {}   -- itemID -> { questID, title, rank, logIndex }

local function ItemIDFromLink(link)
    if not link then
        return nil
    end
    local getter = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if getter then
        local ok, itemID = pcall(getter, link)
        if ok and itemID then
            return itemID
        end
    end
    return tonumber(link:match("item:(%d+)"))
end

local function SuperTrackedQuest()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        return C_SuperTrack.GetSuperTrackedQuestID()
    end
    if GetSuperTrackedQuestID then
        return GetSuperTrackedQuestID()
    end
    return nil
end

local function IsOnMap(questID, logIndex)
    if C_QuestLog and C_QuestLog.IsOnMap then
        local ok, onMap = pcall(C_QuestLog.IsOnMap, questID)
        if ok then
            return onMap
        end
    end
    if GetQuestLogTitle and logIndex then
        local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, isOnMap = GetQuestLogTitle(logIndex)
        return isOnMap
    end
    return false
end

local function IsWatched(questID, logIndex)
    if C_QuestLog and C_QuestLog.GetQuestWatchType then
        return C_QuestLog.GetQuestWatchType(questID) ~= nil
    end
    if IsQuestWatched and logIndex then
        return IsQuestWatched(logIndex)
    end
    return false
end

local function IsComplete(questID, logIndex)
    if C_QuestLog and C_QuestLog.IsComplete then
        return C_QuestLog.IsComplete(questID)
    end
    if GetQuestLogTitle and logIndex then
        local _, _, _, _, _, isComplete = GetQuestLogTitle(logIndex)
        return isComplete == 1 or isComplete == true
    end
    return false
end

-- Iterates the quest log as (logIndex, questID, title) for real quests only.
local function QuestLogEntries()
    local entries = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local count = C_QuestLog.GetNumQuestLogEntries()
        for index = 1, count do
            local info = C_QuestLog.GetInfo(index)
            if info and not info.isHeader and not info.isHidden and info.questID then
                entries[#entries + 1] = { index = index, questID = info.questID, title = info.title }
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        local count = GetNumQuestLogEntries()
        for index = 1, count do
            local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
            if title and not isHeader then
                entries[#entries + 1] = { index = index, questID = questID, title = title }
            end
        end
    end
    return entries
end

local function Prepare()
    wipe(questItems)
    if not GetQuestLogSpecialItemInfo then
        return
    end
    local superTracked = SuperTrackedQuest()
    for _, entry in ipairs(QuestLogEntries()) do
        local ok, link, _, _, showWhenComplete = pcall(GetQuestLogSpecialItemInfo, entry.index)
        local itemID = ok and ItemIDFromLink(link) or nil
        if itemID then
            local rank
            if entry.questID == superTracked then
                rank = 1
            elseif IsOnMap(entry.questID, entry.index) then
                rank = 2
            elseif IsWatched(entry.questID, entry.index) then
                rank = 3
            else
                rank = 4
            end
            if IsComplete(entry.questID, entry.index) and not showWhenComplete then
                rank = rank + 10
            end
            local existing = questItems[itemID]
            if not existing or rank < existing.rank then
                questItems[itemID] = {
                    questID = entry.questID,
                    title = entry.title,
                    rank = rank,
                    logIndex = entry.index,
                }
            end
        end
    end
end

local function Classify(itemID, lines)
    local fromLog = questItems[itemID]
    if fromLog then
        return {
            name = lines[1],
            rank = fromLog.rank,
            order = fromLog.logIndex,
            questTitle = fromLog.title,
        }
    end

    local text = table.concat(lines, "\n"):lower()
    local usable = text:find("use:", 1, true) ~= nil
    if not usable then
        return nil
    end
    if text:find("begins a quest", 1, true) or text:find("starts a quest", 1, true) then
        return {
            name = lines[1],
            rank = 5,
            order = 0,
            questTitle = "starts a quest",
        }
    end
    return nil
end

local function Rank(candidates)
    table.sort(candidates, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.order ~= b.order then return a.order < b.order end
        return a.itemID < b.itemID
    end)
end

local RANK_LABELS = {
    [1] = "super-tracked",
    [2] = "on this map",
    [3] = "tracked",
    [4] = "in log",
    [5] = "starts a quest",
}

local function Describe(candidate)
    local label = RANK_LABELS[candidate.rank] or "complete"
    if candidate.rank > 10 then
        label = "complete, " .. (RANK_LABELS[candidate.rank - 10] or "in log")
    end
    return string.format("%s for \"%s\" (%s)", candidate.link or candidate.name or ("item:" .. candidate.itemID), candidate.questTitle or "?", label)
end

Rummage.RegisterCategory({
    key = "quest",
    label = "Quest item",
    macroName = "SmartQuestItem",
    Prepare = Prepare,
    Prefilter = function(itemID, classID)
        return questItems[itemID] ~= nil or classID == nil or classID == QUEST_CLASS
    end,
    Classify = Classify,
    Rank = Rank,
    Describe = Describe,
    events = {
        "QUEST_LOG_UPDATE",
        "QUEST_ACCEPTED",
        "QUEST_REMOVED",
        "QUEST_TURNED_IN",
        "QUEST_WATCH_LIST_CHANGED",
        "SUPER_TRACKING_CHANGED",
        "ZONE_CHANGED_NEW_AREA",
        "ZONE_CHANGED",
    },
})
