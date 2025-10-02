-- ===========================================================================
-- CallbackHandlerMixin Examples
-- Version: 1.0.0
-- Description: Practical usage examples for CallbackHandlerMixin
-- ===========================================================================

local Examples = CreateFrame("Frame")
Examples:RegisterEvent("ADDON_LOADED")

function Examples:OnEvent(event, addonName)
    if addonName == "CallbackHandlerMixin" then
        self:RunExamples()
    end
end
Examples:SetScript("OnEvent", Examples.OnEvent)

function Examples:RunExamples()
    print("=== CALLBACKHANDLERMIXIN EXAMPLES ===")
    
    self:BasicExample()
    self:CombatQueueExample()
    self:SecureCallbackExample()
    self:ErrorHandlingExample()
    self:DiagnosticExample()
end

-- ===========================================================================
-- Example 1: Basic Event Registration and Triggering
-- ===========================================================================

function Examples:BasicExample()
    print("\n📘 EXAMPLE 1: Basic Event System")
    
    local handler = CreateCallbackHandler()
    
    -- Register multiple callbacks for the same event
    handler:RegisterEvent("DataUpdated", function(event, data)
        print("  Callback 1: Data updated - " .. data)
    end)
    
    handler:RegisterEvent("DataUpdated", function(event, data)
        print("  Callback 2: Processing data - " .. data)
    end)
    
    -- Trigger the event
    handler:TriggerEvent("DataUpdated", "sample_data_123")
    
    -- Register and trigger a different event
    handler:RegisterEvent("UserAction", function(event, action, target)
        print("  User performed: " .. action .. " on " .. target)
    end)
    
    handler:TriggerEvent("UserAction", "click", "button_ok")
end

-- ===========================================================================
-- Example 2: Combat Queue System
-- ===========================================================================

function Examples:CombatQueueExample()
    print("\n⚔️ EXAMPLE 2: Combat Queue System")
    
    local handler = CreateCallbackHandler()
    handler:EnableTaintDebug()
    
    -- Register UI update events that should queue in combat
    handler:RegisterEvent("UI_Refresh", function(event, element)
        print("  UI Refreshed: " .. element)
    end)
    
    handler:RegisterEvent("Frame_Update", function(event, frameName)
        print("  Frame Updated: " .. frameName)
    end)
    
    -- Simulate combat state
    handler.isInCombat = true
    print("  Combat state: IN COMBAT")
    
    -- These should be queued
    local result1 = handler:TriggerEvent("UI_Refresh", "ActionBar")
    local result2 = handler:TriggerEvent("Frame_Update", "PlayerFrame")
    
    print("  UI_Refresh result: " .. tostring(result1))
    print("  Frame_Update result: " .. tostring(result2))
    print("  Queue size: " .. handler:GetQueueSize())
    
    -- Process queue (simulate combat end)
    handler.isInCombat = false
    handler:ProcessQueue()
    print("  Queue size after process: " .. handler:GetQueueSize())
end

-- ===========================================================================
-- Example 3: Secure Callbacks (Combat-Only Execution)
-- ===========================================================================

function Examples:SecureCallbackExample()
    print("\n🛡️ EXAMPLE 3: Secure Callbacks (Combat-Only)")
    
    local handler = CreateCallbackHandler()
    
    -- Register a secure callback that only executes in combat
    handler:RegisterSecureCallback("Combat_Alert", function(event, message)
        print("  COMBAT ALERT: " .. message)
    end)
    
    -- Out of combat - should queue
    handler.isInCombat = false
    local result1 = handler:TriggerEvent("Combat_Alert", "Enemy spotted!")
    print("  Out of combat result: " .. tostring(result1))
    
    -- In combat - should execute immediately
    handler.isInCombat = true
    local result2 = handler:TriggerEvent("Combat_Alert", "Under attack!")
    print("  In combat result: " .. tostring(result2))
    
    handler.isInCombat = false
end

-- ===========================================================================
-- Example 4: Error Handling and Auto-Disable
-- ===========================================================================

function Examples:ErrorHandlingExample()
    print("\n🚨 EXAMPLE 4: Error Handling & Auto-Disable")
    
    local handler = CreateCallbackHandler()
    handler:EnableTaintDebug()
    
    local errorCount = 0
    handler:RegisterEvent("Error_Test", function(event, data)
        errorCount = errorCount + 1
        error("Simulated error #" .. errorCount .. " with data: " .. data)
    end)
    
    -- Trigger multiple errors
    for i = 1, 7 do
        local success, errors = handler:TriggerEvent("Error_Test", "test_data_" .. i)
        print(string.format("  Call %d: success=%s", i, tostring(success)))
        
        if not success and errors then
            if type(errors) == "table" then
                print("    Errors: " .. #errors)
            else
                print("    Error: " .. tostring(errors))
            end
        end
        
        -- Check health after each call
        local health = handler:GetCallbackHealth("Error_Test")
        if health then
            print(string.format("    Health: calls=%d, errors=%d, disabled=%s", 
                health.totalCalls, health.errors, 
                tostring(handler.disabledCallbacks["Error_Test"])))
        end
    end
    
    print("  Final disabled state: " .. tostring(handler.disabledCallbacks["Error_Test"]))
end

-- ===========================================================================
-- Example 5: Diagnostic and Monitoring
-- ===========================================================================

function Examples:DiagnosticExample()
    print("\n📊 EXAMPLE 5: Diagnostic System")
    
    local handler = CreateCallbackHandler()
    handler:EnableTaintDebug()
    
    -- Register some events
    handler:RegisterEvent("System_Start", function(event) 
        print("  System started successfully") 
    end)
    
    handler:RegisterEvent("Data_Load", function(event, dataType)
        print("  Data loaded: " .. dataType)
    end)
    
    handler:RegisterEvent("UI_Ready", function(event)
        print("  UI is ready")
    end)
    
    -- Trigger events to generate data
    handler:TriggerEvent("System_Start")
    handler:TriggerEvent("Data_Load", "player_info")
    handler:TriggerEvent("Data_Load", "spell_data")
    handler:TriggerEvent("UI_Ready")
    
    -- Generate an error for diagnostics
    handler:RegisterEvent("Faulty_Event", function(event)
        error("This event is faulty by design")
    end)
    
    handler:TriggerEvent("Faulty_Event")
    
    -- Get diagnostic report
    local report = handler:GetDiagnosticReport()
    
    print("  System Mode: " .. report.system.executionMode)
    print("  In Combat: " .. tostring(report.system.isInCombat))
    print("  Total Events: " .. report.callbacks.totalEvents)
    print("  Queue Size: " .. report.queue.total)
    print("  Taint Events: " .. report.taint.totalEvents)
    
    -- Get health summary
    local healthSummary = handler:GetCallbackHealthSummary()
    print("  Callback Health:")
    print("    Total: " .. healthSummary.total)
    print("    Healthy: " .. healthSummary.healthy)
    print("    Warning: " .. healthSummary.warning)
    print("    Critical: " .. healthSummary.critical)
    
    -- Get worst performers
    local worst = handler:GetWorstPerformingCallbacks(3)
    if #worst > 0 then
        print("  Worst Performers:")
        for i, performer in ipairs(worst) do
            print(string.format("    %d. %s: %.1f%% error rate (%d/%d)", 
                i, performer.event, performer.errorRate * 100, 
                performer.errors, performer.totalCalls))
        end
    end
end

-- ===========================================================================
-- Example 6: Execution Mode Configuration
-- ===========================================================================

function Examples:ExecutionModeExample()
    print("\n⚙️ EXAMPLE 6: Execution Mode Configuration")
    
    local handler = CreateCallbackHandler()
    
    -- Test different execution modes
    local modes = {"SAFE", "UNSAFE", "AUTO", "SECURE_ONLY"}
    
    for _, mode in ipairs(modes) do
        handler:SetExecutionMode(mode)
        
        handler:RegisterEvent("Mode_Test_" .. mode, function(event, data)
            print("  " .. mode .. " mode executed: " .. data)
        end)
        
        -- Test in different combat states
        handler.isInCombat = true
        local combatResult = handler:TriggerEvent("Mode_Test_" .. mode, "in_combat")
        
        handler.isInCombat = false
        local peaceResult = handler:TriggerEvent("Mode_Test_" .. mode, "out_of_combat")
        
        print("  " .. mode .. " mode:")
        print("    Combat result: " .. tostring(combatResult))
        print("    Peace result: " .. tostring(peaceResult))
    end
    
    handler.isInCombat = false
end

-- ===========================================================================
-- Example 7: Real-World Addon Usage Pattern
-- ===========================================================================

function Examples:RealWorldExample()
    print("\n🎯 EXAMPLE 7: Real-World Addon Pattern")
    
    -- Create a typical addon structure using CallbackHandlerMixin
    local MyAddon = CreateFrame("Frame", "MyAddonFrame")
    Mixin(MyAddon, CallbackHandlerMixin)
    MyAddon:OnLoad()
    
    -- Addon initialization
    function MyAddon:Initialize()
        print("  MyAddon initializing...")
        
        -- Register addon-specific events
        self:RegisterEvent("MYADDON_DATA_READY", function(event, data)
            self:OnDataReady(data)
        end)
        
        self:RegisterEvent("MYADDON_UI_UPDATE", function(event, element)
            self:UpdateUI(element)
        end)
        
        self:RegisterSecureCallback("MYADDON_COMBAT_EVENT", function(event, action)
            self:HandleCombatAction(action)
        end)
        
        -- Simulate data loading
        self:TriggerEvent("MYADDON_DATA_READY", {player = "TestPlayer", level = 60})
    end
    
    function MyAddon:OnDataReady(data)
        print("  Data ready - Player: " .. data.player .. ", Level: " .. data.level)
        self:TriggerEvent("MYADDON_UI_UPDATE", "player_frame")
    end
    
    function MyAddon:UpdateUI(element)
        print("  Updating UI element: " .. element)
    end
    
    function MyAddon:HandleCombatAction(action)
        print("  Combat action handled: " .. action)
    end
    
    -- Initialize the addon
    MyAddon:Initialize()
    
    -- Test combat queueing
    MyAddon.isInCombat = true
    MyAddon:TriggerEvent("MYADDON_UI_UPDATE", "action_bar") -- Should queue
    print("  UI update queued in combat: " .. tostring(MyAddon:GetQueueSize()))
    
    MyAddon.isInCombat = false
    MyAddon:ProcessQueue() -- Should process queued event
end

-- ===========================================================================
-- Example 8: CallbackHandler-1.0 Compatibility
-- ===========================================================================

function Examples:CompatibilityExample()
    print("\n🔄 EXAMPLE 8: CallbackHandler-1.0 Compatibility")
    
    local handler = CreateCallbackHandler()
    
    -- Use CallbackHandler-1.0 style API
    handler.callbacks:Register("LegacyEvent", function(event, data)
        print("  Legacy event fired: " .. data)
    end)
    
    -- Fire using both old and new style
    handler.callbacks:Fire("LegacyEvent", "old_style_data")
    handler:Fire("LegacyEvent", "new_style_data")
    
    -- Mixed usage
    handler:Register("MixedEvent", function(event, data)
        print("  Mixed event: " .. data)
    end)
    
    handler:TriggerEvent("MixedEvent", "triggered_data")
end

-- Register example command
SLASH_CALLBACKEXAMPLES1 = "/callbackexamples"
SlashCmdList["CALLBACKEXAMPLES"] = function()
    Examples:RunExamples()
end

print("CallbackHandlerExamples loaded. Use /callbackexamples to run examples.")
