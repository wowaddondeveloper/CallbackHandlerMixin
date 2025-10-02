# CallbackHandlerMixin

![Version](https://img.shields.io/badge/Version-1.0.0-blue)
![WoW](https://img.shields.io/badge/World%20of%20Warcraft-10.1.5+-green)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

> Industrial-strength callback management system for World of Warcraft addon development

🚀 Features

🔒 Combat-Aware Execution
- **Smart Queue System**: Automatically queues UI events during combat
- **Priority-Based Processing**: Normal, Priority, and Secure queue levels
- **Combat-Safe Execution**: Prevents taint while maintaining functionality

🛡️ Enterprise-Grade Safety
- **Self-Healing Callbacks**: Automatic error detection and recovery
- **Auto-Disable Protection**: Disables faulty callbacks after configurable error thresholds
- **Secure Execution Modes**: SAFE, UNSAFE, AUTO, and SECURE_ONLY modes
- **Taint Debugging**: Comprehensive logging and diagnostics

📊 Advanced Monitoring
- **Real-time Health Tracking**: Monitor callback performance and error rates
- **Diagnostic Reports**: Detailed system status and performance metrics
- **Queue Statistics**: Monitor combat queue size and composition
- **Error Analytics**: Identify worst-performing callbacks

🔄 Seamless Integration
- **Native WoW Mixin**: Optimized performance with seamless API integration
- **CallbackHandler-1.0 Compatibility**: Drop-in replacement for existing systems
- **Flexible Registration**: Multiple callback registration methods
- **Event Prioritization**: Intelligent event classification and handling

📥 Installation

1. **Download** the latest release from [CurseForge](https://www.curseforge.com)
2. **Extract** to your WoW Addons folder: `World of Warcraft/_retail_/Interface/AddOns/`
3. **Enable** "CallbackHandlerMixin" in your addon list
4. **Require** in your addon's TOC file: `## RequiredDeps: CallbackHandlerMixin`

## 🎯 Quick Start

Basic Usage
```lua
-- Create a callback handler
local MyHandler = CreateCallbackHandler()

-- Register events
MyHandler:RegisterEvent("DataUpdated", function(event, data)
    print("Data received:", data)
end)

-- Trigger events
MyHandler:TriggerEvent("DataUpdated", "Hello World!")
