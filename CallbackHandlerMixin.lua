-- ===========================================================================
-- CallbackHandlerMixin - Native Professional Callback System  
-- Version: 1.0.0
-- Description: Industrial-strength callback management mixin combining
--              proven design patterns with innovative multi-layered safety
--              systems and smart combat-aware execution architecture.
--              Engineered as a native WoW mixin for peak performance,
--              seamless integration, and enterprise-grade reliability
--              in the most demanding addon environments.
-- ===========================================================================

local CallbackHandlerMixin = {}

-- Execution modes
local EXECUTION_MODES = {
    SAFE = "SAFE",           -- Always use secure execution (default)
    UNSAFE = "UNSAFE",       -- Never use secure execution (developer responsibility)  
    AUTO = "AUTO",           -- Automatic combat detection
    SECURE_ONLY = "SECURE_ONLY" -- Only execute in combat (queued otherwise)
}

-- Event priorities for combat queue
local QUEUE_PRIORITIES = {
    NORMAL = "normal",
    PRIORITY = "priority", 
    SECURE = "secure"
}

-- ===========================================================================
-- Initialization and Core Setup
-- ===========================================================================

function CallbackHandlerMixin:OnLoad()
    -- Set up event handler for system events
    if not self.OnEvent then
        self.OnEvent = function(_, event, ...)
            self:HandleSystemEvent(event, ...)
        end
        self:SetScript("OnEvent", self.OnEvent)
    end
    
    -- Initialize our callback system
    self._callbacks = {}
    self._events = {}
    
    -- Combat queue system
    self.combatQueue = {
        [QUEUE_PRIORITIES.NORMAL] = {},
        [QUEUE_PRIORITIES.PRIORITY] = {},
        [QUEUE_PRIORITIES.SECURE] = {}
    }
    
    -- Security configuration
    self.executionMode = EXECUTION_MODES.AUTO
    self.eventSecurity = {} -- Event-specific security overrides
    self.secureCallbacks = {} -- Callbacks that only run in combat
    
    -- Diagnostics and monitoring
    self.taintLog = {}
    self.callbackHealth = {}
    self.disabledCallbacks = {}
    
    -- Combat state tracking
    self.isInCombat = InCombatLockdown()
    
    -- Register combat events using native frame events
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    self:LogTaintEvent("SYSTEM_INIT", "CallbackHandlerMixin initialized")
end

-- ===========================================================================
-- Core Event Registration and Triggering
-- ===========================================================================

function CallbackHandlerMixin:RegisterEvent(event, handler, security)
    -- If no handler provided, this is a system event registration
    if not handler then
        -- Use native frame event registration
        if self.RegisterEvent then
            getmetatable(self).__index.RegisterEvent(self, event)
        end
        return
    end
    
    security = security or self.executionMode
    
    -- Store callback in our own system
    self._callbacks[event] = self._callbacks[event] or {}
    table.insert(self._callbacks[event], handler)
    
    -- Store security setting for this event
    if security ~= self.executionMode then
        self.eventSecurity[event] = security
    end
    
    self:LogTaintEvent("EVENT_REGISTERED", event, security)
end

function CallbackHandlerMixin:RegisterCallback(event, handler)
    return self:RegisterEvent(event, handler, EXECUTION_MODES.SAFE)
end

function CallbackHandlerMixin:RegisterCallbackUnsafe(event, handler)
    return self:RegisterEvent(event, handler, EXECUTION_MODES.UNSAFE)
end

function CallbackHandlerMixin:RegisterSecureCallback(event, handler)
    self.secureCallbacks[event] = true
    return self:RegisterEvent(event, handler, EXECUTION_MODES.SECURE_ONLY)
end

function CallbackHandlerMixin:TriggerEvent(event, ...)
    local shouldQueue, queuePriority = self:ShouldQueueEvent(event, ...)
    
    if shouldQueue then
        return self:QueueEvent(event, queuePriority, ...)
    end
    
    local executionSafe = self:ShouldUseSecureExecution(event)
    
    if executionSafe then
        return securecall(self.ExecuteEvent, self, event, ...)
    else
        return self:ExecuteEvent(event, ...)
    end
end

-- ===========================================================================
-- Combat Queue System
-- ===========================================================================

function CallbackHandlerMixin:ShouldQueueEvent(event, ...)
    if not self.isInCombat then 
        -- Not in combat, only queue SECURE_ONLY events
        return self.secureCallbacks[event], QUEUE_PRIORITIES.SECURE
    end
    
    local mode = self:GetEffectiveExecutionMode(event)
    
    if mode == EXECUTION_MODES.UNSAFE then 
        return false 
    end
    
    if mode == EXECUTION_MODES.SECURE_ONLY then 
        return true, QUEUE_PRIORITIES.SECURE
    end
    
    -- AUTO mode: intelligent queue decisions
    local eventType = self:ClassifyEventType(event, ...)
    if eventType == "UI_UPDATE" then 
        return true, QUEUE_PRIORITIES.NORMAL 
    end
    if eventType == "COMBAT_CRITICAL" then 
        return true, QUEUE_PRIORITIES.PRIORITY 
    end
    
    -- FIXED: SAFE mode should queue in combat, AUTO mode should queue UI events
    return true, QUEUE_PRIORITIES.NORMAL
end

function CallbackHandlerMixin:QueueEvent(event, priority, ...)
    local queueItem = {
        event = event,
        args = { ... },
        timestamp = GetTime(),
        priority = priority or QUEUE_PRIORITIES.NORMAL
    }
    
    table.insert(self.combatQueue[queueItem.priority], queueItem)
    self:LogTaintEvent("EVENT_QUEUED", event, priority)
    
    return "queued"
end

function CallbackHandlerMixin:ProcessQueue(priority)
    local queuesToProcess = {}
    
    if priority then
        queuesToProcess[priority] = self.combatQueue[priority]
    else
        queuesToProcess = self.combatQueue
    end
    
    for queuePriority, queue in pairs(queuesToProcess) do
        local itemsToProcess = {}
        
        -- Collect items that can be processed
        for i = #queue, 1, -1 do
            local item = queue[i]
            -- FIXED: Only process if not in combat OR if it's a secure-only event
            if not self.isInCombat or self.secureCallbacks[item.event] then
                table.insert(itemsToProcess, 1, item)
                table.remove(queue, i)
            end
        end
        
        -- Process collected items
        for _, item in ipairs(itemsToProcess) do
            self:ExecuteEvent(item.event, unpack(item.args))
        end
    end
end

function CallbackHandlerMixin:GetAllQueuedItems()
    local allItems = {}
    for priority, queue in pairs(self.combatQueue) do
        for _, item in ipairs(queue) do
            table.insert(allItems, item)
        end
    end
    
    -- Sort by priority: secure > priority > normal
    table.sort(allItems, function(a, b)
        local priorityOrder = { secure = 3, priority = 2, normal = 1 }
        return priorityOrder[a.priority] > priorityOrder[b.priority]
    end)
    
    return allItems
end

-- ===========================================================================
-- Self-Healing Callback System
-- ===========================================================================

function CallbackHandlerMixin:ExecuteEvent(event, ...)
    if self.disabledCallbacks[event] then
        self:LogTaintEvent("CALLBACK_SKIPPED", event, "disabled due to errors")
        return false, "callback_disabled"
    end
    
    -- Initialize health tracking
    if not self.callbackHealth[event] then
        self.callbackHealth[event] = { 
            totalCalls = 0, 
            errors = 0, 
            lastError = nil,
            lastSuccess = nil
        }
    end
    
    local health = self.callbackHealth[event]
    health.totalCalls = health.totalCalls + 1
    
    local callbacks = self:GetCallbacksForEvent(event)
    if not callbacks or #callbacks == 0 then
        return false, "no_handlers"
    end
    
    local allSuccess = true
    local errors = {}
    
    for i, handler in ipairs(callbacks) do
        local success, result = self:ExecuteSingleCallback(handler, event, ...)
        
        if not success then
            allSuccess = false
            table.insert(errors, result)
            health.errors = health.errors + 1
            health.lastError = result
            
            -- Auto-disable if too many errors
            if health.errors >= 5 then
                self.disabledCallbacks[event] = true
                self:LogTaintEvent("CALLBACK_AUTO_DISABLED", event, 
                    string.format("%d errors in %d calls", health.errors, health.totalCalls))
                break
            end
        else
            health.lastSuccess = GetTime()
        end
    end
    
    return allSuccess, #errors > 0 and errors or nil
end

function CallbackHandlerMixin:ExecuteSingleCallback(handler, event, ...)
    local success, result = pcall(handler, event, ...)
    
    if not success then
        self:LogTaintEvent("CALLBACK_ERROR", event, result)
        return false, result
    end
    
    return true, result
end

function CallbackHandlerMixin:GetCallbacksForEvent(event)
    return self._callbacks and self._callbacks[event] or {}
end

-- ===========================================================================
-- Execution Mode Management
-- ===========================================================================

function CallbackHandlerMixin:SetExecutionMode(mode)
    assert(EXECUTION_MODES[mode], "Invalid execution mode: " .. tostring(mode))
    self.executionMode = mode
    self:LogTaintEvent("MODE_CHANGED", mode)
end

function CallbackHandlerMixin:SetEventSecurity(event, security)
    assert(EXECUTION_MODES[security], "Invalid security mode: " .. tostring(security))
    self.eventSecurity[event] = security
    self:LogTaintEvent("EVENT_SECURITY_SET", event, security)
end

function CallbackHandlerMixin:GetEffectiveExecutionMode(event)
    return self.eventSecurity[event] or self.executionMode
end

function CallbackHandlerMixin:ShouldUseSecureExecution(event)
    local mode = self:GetEffectiveExecutionMode(event)
    
    if mode == EXECUTION_MODES.UNSAFE then return false end
    if mode == EXECUTION_MODES.SECURE_ONLY then return true end
    if mode == EXECUTION_MODES.SAFE then return true end
    
    -- AUTO mode: use secure execution in combat
    return self.isInCombat
end

-- ===========================================================================
-- Diagnostic and Monitoring System
-- ===========================================================================

function CallbackHandlerMixin:EnableTaintDebug()
    self.debugTaint = true
    self.taintLog = {}
    self:LogTaintEvent("DEBUG_ENABLED", "Taint debugging enabled")
end

function CallbackHandlerMixin:LogTaintEvent(type, event, details)
    if not self.debugTaint and type ~= "CALLBACK_ERROR" and type ~= "CALLBACK_AUTO_DISABLED" then
        return
    end
    
    local logEntry = {
        type = type,
        event = event,
        details = details,
        timestamp = GetTime(),
        combat = self.isInCombat,
        stack = debugstack(2)
    }
    
    table.insert(self.taintLog, logEntry)
    
    -- Keep only last 100 entries
    if #self.taintLog > 100 then
        table.remove(self.taintLog, 1)
    end
end

function CallbackHandlerMixin:GetDiagnosticReport()
    local queueStats = self:GetCombatQueueStats()
    
    return {
        system = {
            executionMode = self.executionMode,
            isInCombat = self.isInCombat,
            debugEnabled = self.debugTaint or false
        },
        queue = queueStats,
        callbacks = {
            totalEvents = self:GetRegisteredEventCount(),
            disabledCallbacks = self:GetDisabledCallbacks(),
            healthSummary = self:GetCallbackHealthSummary()
        },
        taint = {
            totalEvents = #self.taintLog,
            recentEvents = { unpack(self.taintLog, math.max(1, #self.taintLog - 9), #self.taintLog) }
        }
    }
end

function CallbackHandlerMixin:GetCombatQueueStats()
    local stats = { 
        total = 0,
        byPriority = {},
        byEvent = {}
    }
    
    for priority, queue in pairs(self.combatQueue) do
        stats.byPriority[priority] = #queue
        stats.total = stats.total + #queue
        
        for _, item in ipairs(queue) do
            stats.byEvent[item.event] = (stats.byEvent[item.event] or 0) + 1
        end
    end
    
    return stats
end

function CallbackHandlerMixin:GetTaintReport()
    local errorCount = 0
    local recentErrors = {}
    
    for i = math.max(1, #self.taintLog - 19), #self.taintLog do
        local entry = self.taintLog[i]
        if entry and (entry.type == "CALLBACK_ERROR" or entry.type == "CALLBACK_AUTO_DISABLED") then
            errorCount = errorCount + 1
            table.insert(recentErrors, entry)
        end
    end
    
    return {
        totalTaintEvents = #self.taintLog,
        recentErrorCount = errorCount,
        recentErrors = recentErrors,
        errorRate = self:CalculateErrorRate(),
        worstPerformers = self:GetWorstPerformingCallbacks(5)
    }
end

function CallbackHandlerMixin:CalculateErrorRate()
    local totalCalls = 0
    local totalErrors = 0
    
    for event, health in pairs(self.callbackHealth) do
        totalCalls = totalCalls + health.totalCalls
        totalErrors = totalErrors + health.errors
    end
    
    return totalCalls > 0 and (totalErrors / totalCalls) or 0
end

function CallbackHandlerMixin:GetWorstPerformingCallbacks(limit)
    local performers = {}
    
    for event, health in pairs(self.callbackHealth) do
        if health.totalCalls > 0 then
            local errorRate = health.errors / health.totalCalls
            table.insert(performers, {
                event = event,
                errorRate = errorRate,
                totalCalls = health.totalCalls,
                errors = health.errors
            })
        end
    end
    
    table.sort(performers, function(a, b) 
        return a.errorRate > b.errorRate 
    end)
    
    return limit and { unpack(performers, 1, math.min(limit, #performers)) } or performers
end

function CallbackHandlerMixin:GetCallbackHealth(event)
    if event then
        return self.callbackHealth[event]
    else
        return self.callbackHealth
    end
end

function CallbackHandlerMixin:GetDisabledCallbacks()
    local disabled = {}
    for event, _ in pairs(self.disabledCallbacks) do
        table.insert(disabled, event)
    end
    return disabled
end

function CallbackHandlerMixin:GetRegisteredEventCount()
    local count = 0
    for _ in pairs(self._callbacks) do
        count = count + 1
    end
    return count
end

function CallbackHandlerMixin:GetCallbackHealthSummary()
    local summary = { total = 0, healthy = 0, warning = 0, critical = 0 }
    
    for event, health in pairs(self.callbackHealth) do
        summary.total = summary.total + 1
        
        if health.totalCalls == 0 then
            summary.healthy = summary.healthy + 1
        elseif health.errors == 0 then
            summary.healthy = summary.healthy + 1
        elseif health.errors / health.totalCalls < 0.1 then
            summary.warning = summary.warning + 1
        else
            summary.critical = summary.critical + 1
        end
    end
    
    return summary
end

-- ===========================================================================
-- Utility Methods
-- ===========================================================================

function CallbackHandlerMixin:HasQueuedEvents()
    for _, queue in pairs(self.combatQueue) do
        if #queue > 0 then
            return true
        end
    end
    return false
end

function CallbackHandlerMixin:GetQueueSize()
    local total = 0
    for _, queue in pairs(self.combatQueue) do
        total = total + #queue
    end
    return total
end

function CallbackHandlerMixin:IsInSafeMode()
    return self.executionMode == EXECUTION_MODES.SAFE or 
           (self.executionMode == EXECUTION_MODES.AUTO and self.isInCombat)
end

function CallbackHandlerMixin:ClassifyEventType(event, ...)
    local eventLower = event:lower()
    
    if eventLower:find("ui") or eventLower:find("frame") or eventLower:find("button") then
        return "UI_UPDATE"
    elseif eventLower:find("combat") or eventLower:find("attack") or eventLower:find("spell") then
        return "COMBAT_CRITICAL"
    elseif eventLower:find("data") or eventLower:find("update") then
        return "DATA_UPDATE"
    else
        return "GENERAL"
    end
end

-- ===========================================================================
-- Combat Event Handling
-- ===========================================================================

function CallbackHandlerMixin:HandleSystemEvent(event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        self.isInCombat = true
        self:LogTaintEvent("COMBAT_START")
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        self.isInCombat = false
        self:LogTaintEvent("COMBAT_END")
        
        -- Process queued events when combat ends
        if self:HasQueuedEvents() then
            self:ProcessQueue()
        end
        
    else
        -- Forward other events through the callback system
        self:TriggerEvent(event, ...)
    end
end

-- ===========================================================================
-- CallbackHandler-1.0 Compatibility Layer
-- ===========================================================================

function CallbackHandlerMixin:Fire(event, ...)
    return self:TriggerEvent(event, ...)
end

function CallbackHandlerMixin:Register(name, handler)
    return self:RegisterEvent(name, handler)
end

-- Factory function for easy creation
function CreateCallbackHandler(target)
    if not target then
        target = CreateFrame("Frame")
    end
    
    Mixin(target, CallbackHandlerMixin)
    target:OnLoad()
    
    -- Create CallbackHandler-1.0 compatible .callbacks property
    if not target.callbacks then
        target.callbacks = target
    end
    
    return target
end

-- Global registration for mixin system
if not _G.CallbackHandlerMixin then
    _G.CallbackHandlerMixin = CallbackHandlerMixin
end

-- ===========================================================================
-- Legacy Support for non-Mixin systems
-- ===========================================================================

local CallbackHandler = {
    version = "1.0.0",
    Create = CreateCallbackHandler
}

_G.CallbackHandler = CallbackHandler