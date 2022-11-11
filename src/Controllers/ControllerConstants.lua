local ControllerConstants = {}

local Settings = {}

function ControllerConstants:SetSettings(settings)
    Settings = settings
end

function ControllerConstants:GetSettings()
    return Settings
end    

return ControllerConstants