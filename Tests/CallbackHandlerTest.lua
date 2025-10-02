-- ===========================================================================
-- CallbackHandlerMixin Debug Test Suite
-- Version: 1.0.0
-- Description: Detailed debugging for failed tests
-- ===========================================================================

local DebugSuite = CreateFrame("Frame")

function DebugSuite:RunDebugTests()
    print("=== CALLBACKHANDLERMIXIN DEBUG TESTS ===")
    self:DebugCombatQueue()
    self:DebugAutoDisable()
    self:DebugQueueSize()
end

function DebugSuite:DebugCombatQueue()
    print("\n🔍 DEBUG COMBAT QUEUE:")
    
    local testObj = CreateCallbackHandler()
    testObj:EnableTaintDebug()
    
    -- Set combat state manually
    testObj.isInCombat = true
    print("Combat state set to:", testObj.isInCombat)
    
    local callbackFired = false
    testObj:RegisterEvent("DebugQueueTest", function(event, data)
        callbackFired = true
        print("Callback fired with data:", data)
    end)
    
    -- Check execution mode and security
    local mode = testObj:GetEffectiveExecutionMode("DebugQueueTest")
    local shouldQueue, queuePriority = testObj:ShouldQueueEvent("DebugQueueTest")
    
    print("Execution mode:", mode)
    print("Should queue:", shouldQueue, "Priority:", queuePriority)
    
    -- Trigger event
    local success, result = testObj:TriggerEvent("DebugQueueTest", "debug_data")
    print("Trigger success:", success, "Result:", result)
    
    -- Check queue status
    print("Queue size:", testObj:GetQueueSize())
    print("Has queued events:", testObj:HasQueuedEvents())
    
    -- Print queue contents
    for priority, queue in pairs(testObj.combatQueue) do
        print("Queue", priority, "size:", #queue)
        for i, item in ipairs(queue) do
            print("  Item", i, "event:", item.event, "priority:", item.priority)
        end
    end
    
    -- Process queue
    testObj.isInCombat = false
    print("Combat state changed to:", testObj.isInCombat)
    testObj:ProcessQueue()
    
    print("Callback fired after process:", callbackFired)
    print("Queue size after process:", testObj:GetQueueSize())
end

function DebugSuite:DebugAutoDisable()
    print("\n🔍 DEBUG AUTO DISABLE:")
    
    local testObj = CreateCallbackHandler()
    testObj:EnableTaintDebug()
    
    local errorCount = 0
    testObj:RegisterEvent("DebugErrorTest", function()
        errorCount = errorCount + 1
        error("Deliberate error #" .. errorCount)
    end)
    
    -- Trigger multiple errors
    for i = 1, 7 do
        local success, errors = testObj:TriggerEvent("DebugErrorTest")
        print(string.format("Call %d: success=%s", i, tostring(success)))
        if errors then
            if type(errors) == "table" then
                print("  Errors:", #errors, "errors")
            else
                print("  Error:", errors)
            end
        end
        
        local health = testObj:GetCallbackHealth("DebugErrorTest")
        if health then
            print(string.format("  Health: calls=%d, errors=%d, disabled=%s", 
                health.totalCalls, health.errors, tostring(testObj.disabledCallbacks["DebugErrorTest"])))
        end
    end
    
    print("Final disabled state:", testObj.disabledCallbacks["DebugErrorTest"])
    print("Auto-disable test result:", testObj.disabledCallbacks["DebugErrorTest"] == true)
end

function DebugSuite:DebugQueueSize()
    print("\n🔍 DEBUG QUEUE SIZE:")
    
    local testObj = CreateCallbackHandler()
    testObj:EnableTaintDebug()
    testObj.isInCombat = true
    
    -- Register multiple events that should be queued
    for i = 1, 3 do
        testObj:RegisterEvent("QueueSizeTest" .. i, function(event, data)
            print("Processing:", event, data)
        end)
    end
    
    -- Trigger events that should be queued
    for i = 1, 3 do
        local success, result = testObj:TriggerEvent("QueueSizeTest" .. i, "data_" .. i)
        print(string.format("Event %d: success=%s, result=%s", i, tostring(success), tostring(result)))
    end
    
    -- Check queue size calculation
    local calculatedSize = 0
    for priority, queue in pairs(testObj.combatQueue) do
        calculatedSize = calculatedSize + #queue
        print(string.format("Queue %s: %d items", priority, #queue))
    end
    
    local methodSize = testObj:GetQueueSize()
    print("Calculated size:", calculatedSize)
    print("Method size:", methodSize)
    print("Queue size test result:", calculatedSize == methodSize and methodSize == 3)
end

-- Register debug command
SLASH_CALLBACKDEBUG1 = "/callbackdebug"
SlashCmdList["CALLBACKDEBUG"] = function()
    DebugSuite:RunDebugTests()
end

-- Run debug tests automatically
DebugSuite:RunDebugTests()
