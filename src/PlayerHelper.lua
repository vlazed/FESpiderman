local feSpiderman = script:FindFirstAncestor("FE-Spiderman")
local Debugging = require(feSpiderman.Debugging)
local Vector = require(feSpiderman.Utils.Vector)

local PlayerHelper = {}

local characterMass = 0

PlayerHelper.Clicking = false
PlayerHelper.Holding = false
PlayerHelper.Falling = false
PlayerHelper.Dodging = false
PlayerHelper.Hanging = false
PlayerHelper.isAutomatic = false
PlayerHelper.canClimb = false
PlayerHelper.Climbing = false
PlayerHelper.Pulling = false

PlayerHelper.isLookingForward = false

PlayerHelper.climbFocus = nil
PlayerHelper.attachedPoint = nil

PlayerHelper.Mouse = game:GetService("Players").LocalPlayer:GetMouse()


function PlayerHelper:ToggleFaceForward()
    PlayerHelper.isLookingForward = not PlayerHelper.isLookingForward
end


local function isExistent()
	local exists = game:GetService("Players").LocalPlayer.Character
	-- TODO: Consider case when character model hierarchy is nonstandard
	if exists then
		--d_print("Character "..exists.Name.." exists.")
		return exists
	else
		--d_print("Character doesn't exist")
		return false
	end
end


function PlayerHelper:isAlive()
	local character = isExistent()
	if not character then return false end

	--d_print("Character "..character.Name.." exists.")

	local humanoid = character:FindFirstChild("Humanoid")

	if 
		not humanoid
		or humanoid:GetState() == Enum.HumanoidStateType.Dead 
		or humanoid.Health == 0
		or not character
	then
		Debugging:print("Not alive")
		return false 
	end
    
	--d_print("Alive")
	return character, humanoid
end


function PlayerHelper:getCharacterHumanoidRootPart()
	local character = self:isAlive()
	if not character then return nil end

	return character:FindFirstChild("HumanoidRootPart")
end


function PlayerHelper:getCharacterRootAttachment()
	local hrp = self:getCharacterHumanoidRootPart()
	if not hrp then return nil end

	return hrp:FindFirstChild("RootAttachment") or hrp:FindFirstChild("RootRigAttachment")
end


function PlayerHelper:getCharacterMass()
	local character = self:isAlive()
	if not character then return end
	local mass = characterMass
	if mass > 0 then return mass end
	for i,v in ipairs(character:GetChildren()) do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			mass = mass + v:GetMass()
		end
	end
	return mass
end


function PlayerHelper:rayCastToFloor()
	local character = PlayerHelper:isAlive()
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.IgnoreWater = true
	raycastParams.FilterDescendantsInstances = {character}

	local origin = hrp.Position
	local downVector = -Vector.UP_VECTOR

	local result = workspace:Raycast(origin, downVector*10000, raycastParams)

	return result
end


return PlayerHelper