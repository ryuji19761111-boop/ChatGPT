-- Place this LocalScript in StarterPlayerScripts.
-- Put AetherUI.lua in ReplicatedStorage as a ModuleScript named "AetherUI".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AetherUI = require(ReplicatedStorage:WaitForChild("AetherUI"))

local Window = AetherUI.CreateWindow({
    Title = "Aether Panel",
    Subtitle = "Client Control Center",
    ToggleKey = Enum.KeyCode.RightControl,
    Theme = {
        Accent = Color3.fromRGB(91, 166, 255),
        AccentDark = Color3.fromRGB(54, 112, 190),
    },
})

local Main = Window:CreateTab("Main")
local Settings = Window:CreateTab("Settings")

local Actions = Main:CreateSection("Actions")
Actions:CreateParagraph("Welcome", "A clean client-side interface built with standard Roblox Studio APIs.")
Actions:CreateButton("Show notification", function()
    Window:Notify("AetherUI", "The notification system is working.", 3)
end, "Test the built-in notification card")

local enabled = Actions:CreateToggle("Example toggle", false, function(value)
    print("Toggle:", value)
end)

Actions:CreateSlider("Volume", 0, 100, 65, function(value)
    print("Volume:", value)
end, 5)

Actions:CreateDropdown("Quality", { "Low", "Medium", "High" }, "Medium", function(value)
    print("Quality:", value)
end)

local Preferences = Settings:CreateSection("Preferences")
Preferences:CreateInput("Player title", "Enter a title...", function(value, enterPressed)
    if enterPressed then
        print("Submitted:", value)
    end
end)

Preferences:CreateKeybind("Print test", Enum.KeyCode.G, function(key)
    print("Key pressed:", key.Name)
end)

Preferences:CreateButton("Reset toggle", function()
    enabled:SetValue(false)
end)

Preferences:CreateDivider()
Preferences:CreateLabel("AetherUI v" .. AetherUI.Version)

Window:Notify("Ready", "Press RightControl to hide or show the panel.", 4)
