local ControllerConstants = require(script.Controllers.ControllerConstants)

local Settings = {
    HOLD_DELAY = 0.3,
    WEB_STRENGTH = 2.5 * 10^5,
    DRAG_STRENGTH = 1,
    FALLING_DRAG_STRENGTH = 0.8,
    HOLDING_DRAG_STRENGTH = 1,
    CONTROL_STRENGTH = 1000,
    TAUT_TIME = 1.5,
    PULL_TIME = 0.75,
    TAUT_MAGNITUDE = 3,
    ANTIGRAV_MAGNITUDE = 1,
    WEB_MAX_DISTANCE = 1000,
    AUTO_DISTANCE = 500,
    CLIMB_DIST_THRESHOLD = 2,
    CLIMB_ANGLE_THRESHOLD = 1,
    MIN_JUMPPOWER = 50,
    MAX_JUMPPOWER = 125,
    JUMP_TIME = 1,
    FLIP_CHANCE = 50, -- Percent
    initialWalkspeed = 20,
    finalWalkspeed = 60,
    CLIMB_SPEED = 0.5,
    SKYDIVE_SPEED = 220,

-- CAMERA CONTROLS
    CAM_RESPONSIVENESS = 2,
    CAM_SPEED = 1,
    CAM_MIN_DISTANCE = 16,
    CAM_MAX_DISTANCE = 64,
    DOLLY_SPEED = 0.01,
    PAN_SPEED = 0.01,
    FOCUS_POINT_BIAS = 0.02,

    originalFOV = 70,

    EnableButton = Enum.KeyCode.F,
    ClimbingButton = Enum.KeyCode.Q,
    AutomaticButton = Enum.KeyCode.E,
    EmoteButton = Enum.KeyCode.M,
    HangButton = Enum.KeyCode.Z,
    ControlButton = Enum.KeyCode.LeftAlt,
    DodgeButton = Enum.KeyCode.LeftShift,
    RunButton = Enum.KeyCode.LeftControl,
    JumpButton = Enum.KeyCode.Space,
    CameraButton = Enum.KeyCode.Semicolon,
    FaceForwardButton = Enum.KeyCode.Quote,
}

ControllerConstants:SetSettings(Settings)

local AnimationController = require(script.Controllers.AnimationController)
local AudioController = require(script.Controllers.AudioController)
local PlayerController = require(script.Controllers.PlayerController)

local App = require(script.Components.App)

AudioController:Init()
AnimationController:Init()
PlayerController:Init()

App:Init()

local function scriptLoaded()
	local notifSound = Instance.new("Sound")
	notifSound.PlaybackSpeed = 1
	notifSound.Volume = 0.4
	notifSound.SoundId = "rbxassetid://4066197235"
	notifSound.PlayOnRemove = true
    notifSound.Parent = workspace
	notifSound:Destroy()
	game.StarterGui:SetCore(
		"SendNotification", 
		{
			Title = "Pizza Time", 
			Text = "Rope Sim loaded; Press F to enable", 
			Icon = "rbxassetid://4688867958", 
			Duration = 5, Button1 = "Close"
		}
	)
end

scriptLoaded()