local feSpiderman = script:FindFirstAncestor("FE-Spiderman")
local Tabs = require(feSpiderman.Components.Tabs)
local Window = require(feSpiderman.Components.Window)

local App = {}

function App:Init()
    Tabs:Init()
    Window:Init()
end

return App