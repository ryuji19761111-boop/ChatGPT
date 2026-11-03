# AetherUI v1.0.0

Roblox Studio向けのクライアント専用UIライブラリです。通常のRoblox Luau APIだけを使用し、executor専用APIや`loadstring`には依存しません。

## 導入

1. Roblox Studioの`ReplicatedStorage`に`ModuleScript`を作成し、名前を`AetherUI`にします。
2. `AetherUI.lua`の内容を、そのModuleScriptに貼り付けます。
3. `StarterPlayer > StarterPlayerScripts`に`LocalScript`を作成します。
4. `Example.client.lua`の内容をLocalScriptに貼り付けて実行します。

## 基本API

```lua
local AetherUI = require(game:GetService("ReplicatedStorage"):WaitForChild("AetherUI"))

local Window = AetherUI.CreateWindow({
    Title = "My Panel",
    Subtitle = "Client UI",
    ToggleKey = Enum.KeyCode.RightControl,
})

local Tab = Window:CreateTab("Main")
local Section = Tab:CreateSection("Controls")

Section:CreateButton("Click", function()
    print("Clicked")
end)

local toggle = Section:CreateToggle("Enabled", false, function(value)
    print(value)
end)

toggle:SetValue(true)
```

## Components

- `CreateButton(text, callback, description?)`
- `CreateToggle(text, default, callback)` → `SetValue`, `GetValue`
- `CreateSlider(text, min, max, default, callback, step?)` → `SetValue`, `GetValue`
- `CreateDropdown(text, options, default, callback)` → `SetValue`, `GetValue`, `SetOptions`
- `CreateInput(text, placeholder, callback)` → `SetValue`, `GetValue`
- `CreateKeybind(text, defaultKeyCode, callback)` → `SetKey`, `GetKey`
- `CreateLabel(text)` → `SetText`
- `CreateParagraph(title, body)` → `SetTitle`, `SetText`
- `CreateDivider()`

各コンポーネントには短縮名もあります（例：`Section:Button(...)`、`Section:Toggle(...)`）。

## Window controls

- `Window:CreateTab(name)` / `Window:Tab(name)`
- `Window:SelectTab(tabOrName)`
- `Window:Notify(title, message, duration?)`
- `Window:SetVisible(boolean)` / `Window:Toggle()`
- `Window:SetMinimized(boolean)`
- `Window:SetToggleKey(Enum.KeyCode or nil)`
- `Window:SetTitle(title, subtitle?)`
- `Window:Destroy()`

デスクトップではサイドバー、幅の狭い画面では横スクロール式タブバーに切り替わります。ドラッグ移動はヘッダーから行えます。
