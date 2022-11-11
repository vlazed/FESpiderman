local feSpiderman = script:FindFirstAncestor("FE-Spiderman")
local Debugging = require(feSpiderman.Debugging)

local AnimationController =  require(feSpiderman.Controllers.AnimationController)
local ActionHandler = require(feSpiderman.Controllers.ActionHandler)
local AudioController = require(feSpiderman.Controllers.AudioController)
local ControllerConstants = require(feSpiderman.Controllers.ControllerConstants)
local CameraController = require(feSpiderman.Controllers.CameraController)
local PlayerHelper = require(feSpiderman.PlayerHelper)

local Vector = require(feSpiderman.Vector)

local Debris = game:GetService("Debris")

local PlayerController = {}

PlayerController.dragStrength = 1
PlayerController.grip = nil
PlayerController.climbable = nil

local dodgeDebounce = false
local connected = false

local DT = 0.01
local ZERO = 1e-6

local ClickBeganEvent, ClickEndedEvent

local rightHand = {"Right Arm", "RightHand"}
local leftHand = {"Left Arm", "LeftHand"}
local gripAttachments = {
	["Right Arm"] = "RightGripAttachment", 
	["RightHand"] = "RightGripAttachment", 
	["Left Arm"] = "LeftGripAttachment",
	["LeftHand"] = "LeftGripAttachment"
}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.IgnoreWater = true


local function disableClimbForDuration(t, t_delay)
    local Settings = ControllerConstants:GetSettings()

	if t_delay then
		task.wait(t_delay)
	end
	Debugging:print("climb disabled : ", PlayerHelper.canClimb)
	PlayerHelper.canClimb = false
	task.wait(t)
	PlayerHelper.canClimb = ActionHandler:isKeyDownBool(Settings.ClimbingButton)
	PlayerController:ControlClimbing()
	Debugging:print("climb enabled : ", PlayerHelper.canClimb)
end

local function sit()
	local c, humanoid = PlayerHelper:isAlive()

	humanoid.Sit = true
end


local function stand()
	local c, humanoid = PlayerHelper:isAlive()

	humanoid.Sit = false
end


local function getDistanceFromFloor()
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()

	local P0 = hrp.Position

	local result = PlayerHelper:rayCastToFloor()

	if result then
		local P1 = result.Position
		return (P1 - P0).Magnitude
	else
		return math.huge
	end
end


local function rollPct(n)
	return math.random(0, 100) < n 
end


local function attachToPart(climbable, climbingPosition)
	local c, humanoid = PlayerHelper:isAlive()
    local Settings = ControllerConstants:GetSettings()
	local camera = workspace.CurrentCamera
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()
	--d_print("Attachment0")

	local climbingPosition = hrp.ClimbAlignPos
	local climbingOrientationA = hrp.ClimbAlignWall
	local climbingOrientationB = hrp.ClimbAlignRot

	local climbingAttachment1 = climbable.Instance:FindFirstChild("Climb1") or Instance.new("Attachment")
	if climbingAttachment1.Name ~= "Climb1" then
		climbingAttachment1.Name = "Climb1"
		climbingAttachment1.Visible = Debugging.DEBUG
		climbingAttachment1.Parent = climbable.Instance
	end

	local angle = math.acos(Vector.getVectorPairCos(climbable.Normal, Vector.UP_VECTOR))
	local wallMoveDirection = Vector.rotateVectorAlongAxis(humanoid.MoveDirection, angle, hrp.CFrame.RightVector)

	-- Control climbingAttachment1 to moves
	-- Attempt to rotate humanoid move direction to the wall normal by component
	local wallUpAndDownDirection = -humanoid.MoveDirection:Cross(Vector.UP_VECTOR):Cross(climbable.Normal)
	local wallLeftAndRightDirection = climbable.Normal:Cross(humanoid.MoveDirection):Cross(climbable.Normal)

	--local wallMoveDirection = wallUpAndDownDirection + wallLeftAndRightDirection*XZ_VECTOR

	if not PlayerHelper.Climbing then
		climbingAttachment1.WorldPosition = climbable.Position		
	end

	climbingPosition.Attachment1 = climbingAttachment1
	climbingPosition.Enabled = true

	local xVector
	if wallMoveDirection.Magnitude > 0 then
		xVector = wallMoveDirection:Cross(climbable.Normal)
	else
		xVector = hrp.CFrame.RightVector
	end

	Debugging:makePartAt(hrp.Position, 0.1, Vector3.new(0.1,0.1,12), Color3.new(0, 1, 0), xVector.Unit)
	Debugging:makePartAt(hrp.Position, 0.1, Vector3.new(0.1,0.1,12), Color3.new(1, 0, 0), wallMoveDirection.Unit)

	local angleCFrame = CFrame.fromMatrix(hrp.Position, xVector.Unit, wallMoveDirection.Unit)

	climbingOrientationA.CFrame = CFrame.lookAt(angleCFrame.Position, hrp.Position-climbable.Normal*5)
	climbingOrientationA.Enabled = true

	--hrp.CFrame = CFrame.fromMatrix(hrp.Position, xVector, wallMoveDirection*16)
	climbingOrientationB.Enabled = true

	climbingAttachment1.WorldPosition += wallMoveDirection*humanoid.WalkSpeed / Settings.initialWalkspeed * Settings.CLIMB_SPEED
	PlayerHelper.ClimbFocus = climbingAttachment1.WorldPosition + wallMoveDirection*4

    AnimationController.climbTrack:AdjustSpeed(Vector.isPosOrNeg(wallMoveDirection) * humanoid.WalkSpeed / Settings.initialWalkspeed * 1.5)
end


local function distanceFromTorso(character, hitCFrame)
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")

	return torso.Position - hitCFrame.Position
end


local function chooseHand(character, disp)
	local hand 

	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	local rightVector = torso.CFrame.RightVector

	-- lookvector is just the negative of the torso z-component, rightvector negative here
	if -rightVector:Dot(disp) > ZERO then
		hand = rightHand
	else
		hand = leftHand
	end

	return hand
end


local function destroyWebs(endPoint, rope)
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()

    local TweenService = game:GetService("TweenService")

	local residueAttachment = Instance.new("Attachment")
	residueAttachment.Name = "ResidueAttachment"
	residueAttachment.Parent = endPoint.Parent
	residueAttachment.WorldPosition = PlayerController.grip.WorldPosition

	local residueInfo = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)
	local propTab = {WorldPosition = PlayerController.grip.WorldPosition + hrp.AssemblyLinearVelocity}
	local residueMovement = TweenService:Create(residueAttachment, residueInfo, propTab)

	if rope then
		hrp[rope]:Destroy()
		local web = hrp:FindFirstChild("RightWeb") or hrp:FindFirstChild("LeftWeb")
		if web then 
            web:Destroy() 
        end
		return
	end
	--d_print("Deleting everything else")
	for i,v in ipairs(hrp:GetChildren()) do
		if v.Name == "RightRope" or v.Name == "LeftRope" or v.Name == "Web" or v.Name == "LeftWeb" or v.Name == "RightWeb" then
			v.Attachment0 = residueAttachment
			residueMovement:Play()
			Debris:AddItem(v, 1)
			Debris:AddItem(residueMovement, 1)
		end
	end
end



-- Pull towards a position 
-- Sit, then apply vectorforce
local function pullTowardsWeb(endPoint, grip)
	local character = PlayerHelper:isAlive()
	if not character then return end

    local Settings = ControllerConstants:GetSettings()

    --d_print("Pulling towards web")
	local characterVelocity

	local hrp = PlayerHelper:getCharacterHumanoidRootPart()

	local webVector = endPoint.WorldPosition - grip.WorldPosition


	local ropeLength = webVector.magnitude/0.5



	sit()
	task.spawn(disableClimbForDuration, Settings.PULL_TIME / 4, 0.1)
	task.wait(Settings.PULL_TIME / 4)
	hrp:ApplyImpulse(webVector.Unit*ropeLength * Settings.WEB_STRENGTH / 11000)
	PlayerController.dragStrength = Settings.HOLDING_DRAG_STRENGTH
	PlayerHelper.Pulling = false

	task.wait(1/2)
	destroyWebs(endPoint)
	Debris:AddItem(endPoint.Parent, 1)
	PlayerHelper.dragStrength = Settings.FALLING_DRAG_STRENGTH
end


local function setGravity(gravity)
	if gravity then 
        workspace.Gravity = gravity 
        return 
    end
	local character = PlayerHelper:isAlive()
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()
	if not hrp then return end
end


local function resetGravity()
    local Settings = ControllerConstants:GetSettings()
	workspace.Gravity = 196.2 / Settings.ANTIGRAV_MAGNITUDE
end



-- WEB FUNCTIONS --------------------------------------
local function setWebProperties(web)
	local beam = web

	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), -- red
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)), -- green
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)), -- blue
	}
	)
	beam.LightEmission = 1 -- use additive blending
	beam.LightInfluence = 0.5 -- beam not influenced by light
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds" -- a built in sparkle texture
	beam.TextureMode = Enum.TextureMode.Wrap -- wrap so length can be set by TextureLength
	beam.TextureLength = 0.05 -- repeating texture is 1 stud long 
	beam.TextureSpeed = 0 -- slow texture speed
	beam.Transparency = NumberSequence.new({ -- beam fades out at the end
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 0)
	}
	)
	beam.ZOffset = 0 -- render at the position of the beam without offset 

	-- shape properties
	beam.CurveSize0 = -4 -- create a curved beam
	beam.CurveSize1 = 1 -- create a curved beam
	beam.FaceCamera = true -- beam is visible from every angle 
	beam.Segments = 10 -- default curve resolution  
	beam.Width0 = 0.1 -- starts small
	beam.Width1 = 2 -- ends big

	beam.Enabled = true

	--d_print("Beam properties set")
	return beam
end


local function createWebRope(cf, handPart, grip)
	local limitDistance -- Account for animation delay
	local web

	--d_print(handPart)
	a0 = grip

	local a1 = Instance.new("Attachment")
	local a1Anchor = Instance.new("Part")

	a1Anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	a1Anchor.Anchored = true
	a1Anchor.CFrame = cf
	a1Anchor.Transparency = 0
	a1Anchor.CanCollide = false
	a1Anchor.Parent = workspace
	a1Anchor.Name = "anchorPart"

	local soundId = AudioController:GrabRandomFromTable(AudioController.WEB_IMPACT_AUDIO_TABLE)
	AudioController:PlaySoundAtPart(soundId, a1Anchor)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = {a1Anchor}
	overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
	local touchingPart = workspace:GetPartBoundsInBox(cf, Vector3.new(0.1, 0.1, 0.1), overlapParams)
	if #touchingPart > 0 then
		local weld = Instance.new("WeldConstraint")
		a1Anchor.Anchored = false
		touchingPart = touchingPart[1]
		Debugging:print(touchingPart.Name)
		weld.Part0 = a1Anchor
		weld.Part1 = touchingPart
		weld.Enabled = true
		weld.Parent = a1Anchor
	else
		a1Anchor.Anchored = true
	end
	for i, part in ipairs(a1Anchor:GetTouchingParts()) do
		Debugging:print(part.Name)
	end
	--d_print(a1Anchor.CFrame.LookVector)

	--a1.WorldPosition = cf.Position
	a1.Parent = a1Anchor

	web = Instance.new("Beam")
	web.Name = "Web"
	web.Attachment0 = a0
	web.Attachment1 = a1
	--d_print("attempting web properties")
	web = setWebProperties(web)

	if string.find(grip.Name, "Right") then
		web.Name = "RightWeb"
	elseif string.find(grip.Name, "Left") then
		web.Name = "LeftWeb"
	end

	--d_print("Web located at "..tostring(cf.Position))

	limitDistance = (a1.WorldPosition - a0.WorldPosition).magnitude
	--d_print(a0.WorldPosition)
	--d_print(a1.WorldPosition)
	--d_print(limitDistance)

	return web, limitDistance, a1
end


local function iterDetermineOffset(locale, offset, result, camera)
    local Settings = ControllerConstants:GetSettings()

	if math.abs(camera.CFrame.Position.Y - (locale).Y) < Settings.AUTO_DISTANCE and n <= 100 then
		local result0 = workspace:Raycast(locale, -result.Normal, raycastParams)	
		if result0 then
			Debugging:print("Increase distance: ", locale)
			n = n + 1
			Debugging:makePartAt(locale, 60)
			locale = iterDetermineOffset(locale+offset, offset*Vector.INCREASE_VECTOR, result0, camera)
		else
			Debugging:print("Decrease distance: ", locale)
			n = n + 1
			Debugging:makePartAt(locale, 60)
			locale = iterDetermineOffset(locale-offset, offset*Vector.DECREASE_VECTOR, result, camera)
		end			
	else
		return locale
	end
end


local function determineWebLocale(result, camera)
	local webLocale

	local instance = result.Instance
	--d_print(result.Normal)
	local y_max = instance.Position.Y + (instance.Size.Y / 10)
	local y_offset = 0.8*y_max
	local offset

	local forwardVector = result.Normal:Cross(Vector.UP_VECTOR)
	local offset = (forwardVector.Unit * camera.CFrame.LookVector:Dot(forwardVector)) * 100

	n = 0
	webLocale = Vector3.new(result.Position.x, y_offset, result.Position.z) + offset
	Debugging:print("Old Locale: ", webLocale)
	local newLocale = iterDetermineOffset(webLocale, offset, result, camera)

	Debugging:print("Final Locale: ", webLocale)

	webLocale = CFrame.new(webLocale)

	return webLocale
end


local function closestResultFromOrigin(r1, r2, origin)
	if r1 and not r2 then
		return r1
	elseif r2 and not r1 then
		return r2
	end

	if (r1.Position - origin).Magnitude < (r2.Position - origin).Magnitude then
		return r1
	elseif (r2.Position - origin).Magnitude < (r1.Position - origin).Magnitude then
		return r2
	else
		return 0
	end
end


local function rayCastLocale(character, camera)
	local webLocale

    local Settings = ControllerConstants:GetSettings()

	local hrp = character:FindFirstChild("HumanoidRootPart")
	local origin = hrp.Position + (8 * Vector.UP_VECTOR)
	local rightVector = camera.CFrame.RightVector
	local leftVector = -rightVector
	local lookVector = camera.CFrame.LookVector

	local rightBias = Settings.WEB_MAX_DISTANCE*(rightVector+0.2*lookVector).Unit
	local leftBias = Settings.WEB_MAX_DISTANCE*(leftVector+0.2*lookVector).Unit

	raycastParams.FilterDescendantsInstances = {character}

	local rightResult = workspace:Raycast(origin, rightBias, raycastParams)
	local leftResult = workspace:Raycast(origin, leftBias, raycastParams)

	Debugging:makePartAt(origin, 3, Vector3.new(1, 1, Settings.WEB_MAX_DISTANCE), Color3.new(1, 1, 0), rightBias.Unit)
	Debugging:makePartAt(origin, 3, Vector3.new(1, 1, Settings.WEB_MAX_DISTANCE), Color3.new(0, 1, 1), leftBias.Unit)

	Debugging:print(rightResult)
	Debugging:print(leftResult)

	if not (leftResult and rightResult) then 
        return PlayerHelper.Mouse.Hit 
    end

	local result = closestResultFromOrigin(rightResult, leftResult, origin)

	webLocale = determineWebLocale(result, camera)

	return webLocale
end


--[[
The method below uses the rope swinging physics pioneered by Jamie Fristrom
https://gamedevelopment.tutsplus.com/tutorials/swinging-physics-for-player-movement-as-seen-in-spider-man-2-and-energy-hook--gamedev-8782
]]
local function holdRope3(endPoint, grip)
	local character = PlayerHelper:isAlive()
	if not character then 
        PlayerHelper.Holding = false 
        return 
    end
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()

    local Settings = ControllerConstants:GetSettings()

	PlayerHelper.attachedPoint = endPoint

	PlayerHelper.Holding = true
	PlayerHelper.Pulling = false
	PlayerHelper.Falling = false
	PlayerHelper.dragStrength = Settings.HOLDING_DRAG_STRENGTH

	local mass = PlayerHelper:getCharacterMass()

	local distanceFromFloor = getDistanceFromFloor()
	local ropeVector = hrp.CFrame.Position - endPoint.WorldCFrame.Position
	local ropeLength = ropeVector.Magnitude
	local desiredLength = ropeLength / Settings.TAUT_MAGNITUDE - 128/distanceFromFloor
	desiredLength = math.clamp(desiredLength, ropeLength/Settings.TAUT_MAGNITUDE, math.huge)
	local tautTime = Settings.TAUT_TIME - 4/distanceFromFloor^2
	--print(128/distanceFromFloor)
	local t = 0
	local dt = 0
	local alpha = dt

	local currentPos
	local oldPos
	local oldVel
	local newPos
	local setPos
	local newVel
	local in_min = 0
	local in_max = 0

	setGravity()
	local gravityForce = hrp:FindFirstChild("Gravity")
	setGravity(0)
	sit()

	local tensionForce = hrp.Tension
	local adjustmentVelocity = hrp.Adjustment
	local upsideDown = hrp.UpsideDown

	tensionForce.Enabled = false
	AnimationController:Swing(grip)
	--d_print("Start hold")
	while PlayerHelper.Holding do
		oldPos = hrp.CFrame
		oldVel = hrp.AssemblyLinearVelocity
		dt = task.wait(DT)
		currentPos =  hrp.CFrame - endPoint.WorldCFrame.Position
		--d_print(ropeLength)
		--d_print(currentPos.Position.Magnitude)
		alpha = alpha + dt
		ropeLength += (desiredLength - ropeLength)*dt/tautTime
		
		local dispToEndpoint = (currentPos.Position * Vector.XZ_VECTOR).Magnitude 
			* hrp.CFrame.LookVector:Dot(currentPos.Position.Unit * Vector.XZ_VECTOR)
		if in_min == 0 or in_max == 0 then
			in_min = dispToEndpoint
			in_max = -in_min
		end
		AnimationController.swingTrack.TimePosition = Vector.mapToRange(
			dispToEndpoint,
			in_min,
			in_max,
			1/3,
			1/2
		)

        if ActionHandler:isKeyDownBool(Settings.HangButton) then
			AnimationController.hangTrack:Play(0.1, 500, 0)
			PlayerHelper.Hanging = not PlayerHelper.Hanging
			upsideDown.Enabled = true
		end
		
		if PlayerHelper.Hanging then
			upsideDown.CFrame = CFrame.fromOrientation(hrp.Orientation.X, hrp.Orientation.Y, 180)
			desiredLength += Vector.bool_to_number(PlayerHelper.Hanging)
		else
			desiredLength = math.clamp(desiredLength, ropeLength / Settings.TAUT_MAGNITUDE, math.huge)
		end
		
		if currentPos.Position.Magnitude > ropeLength then
			newPos = hrp.CFrame - endPoint.WorldCFrame.Position
			currentPos = newPos.Position.Unit * ropeLength
			--d_print("new current position")
			setPos = CFrame.new(currentPos):ToWorldSpace(endPoint.WorldCFrame)
			--hrp.CFrame = CFrame.fromMatrix(setPos.Position, hrp.CFrame.XVector, -currentPos.Unit)
			--d_print("Setting Velocity")
			if upsideDown.Enabled then
				hrp.CFrame = CFrame.fromMatrix(setPos.Position, setPos.XVector, currentPos.Unit)
			else
				hrp.CFrame = CFrame.fromMatrix(setPos.Position, setPos.XVector, -currentPos.Unit)
					* CFrame.fromOrientation(0,0,-math.asin(Vector.getVectorPairCos(setPos.XVector, -currentPos.Unit)))
			end
			newVel = (oldPos.Position - setPos.Position)/dt

			tensionForce.Force = -currentPos.Unit * (mass*newVel.Magnitude^2/desiredLength + gravityForce.Force.Magnitude)*1.2

			if Debugging.DEBUG then
				Debugging:makePartAt(hrp.Position, 0.1, Vector3.new(0.01,0.01,Vector.WEB_MAX_DISTANCE), Color3.new(1, 1, 0), tensionForce.Force.Unit)
			end

			adjustmentVelocity.VectorVelocity = newVel
			--d_print(hrp.AssemblyLinearVelocity.Magnitude)
			tensionForce.Enabled = true
			gravityForce.Enabled = true
			adjustmentVelocity.Enabled = false
		else
			hrp.CFrame = hrp.CFrame
			tensionForce.Enabled = false
			gravityForce.Enabled = true
			adjustmentVelocity.Enabled = false
		end 
	end

	task.wait()
	AnimationController.swingTrack:Stop(0.3)
	AnimationController.swingLegsTrack:Stop(0.3)
	AnimationController.hangTrack:Stop(0.1)
	--d_print("End hold")
	tensionForce.Enabled = false
	adjustmentVelocity.Enabled = false
	upsideDown.Enabled = false
	gravityForce.Enabled = false
	PlayerHelper.Hanging = false
	resetGravity()
	Debris:AddItem(endPoint.Parent, 3)
end


local function webAction(endPoint, grip)
	task.wait(1/9)
	if PlayerHelper.Clicking then
		--holdWeb(endPoint, grip)
		-- The coroutine exists to allow web-swinging with two hands
		-- Might figure this one later.
		local f = coroutine.wrap(holdRope3)
		local result = f(endPoint, grip)
	else
		pullTowardsWeb(endPoint, grip)
	end
end



function PlayerController:WebShoot(hand)
	PlayerHelper.Clicking = true
	local character = PlayerHelper.isAlive()
	if not PlayerHelper.websEnabled or not character then return end
	local webSpot
	local camera = workspace.Camera

    local Settings = ControllerConstants:GetSettings()

	if PlayerHelper.isAutomatic then
		webSpot = rayCastLocale(character, camera)
	else
		webSpot = PlayerHelper.Mouse.Hit
	end

	local web
	local limitDist
	local endPoint

	local torsoDistance = distanceFromTorso(character, webSpot)

	--d_print("Distance from torso: " .. tostring(torsoDistance.magnitude))

	if torsoDistance.magnitude <= Settings.WEB_MAX_DISTANCE then
		local hand = hand or chooseHand(character, torsoDistance)
		local handPart = character:FindFirstChild(hand[1]) or character:FindFirstChild(hand[2])
		local grip = handPart[gripAttachments[handPart.Name]]
		PlayerController.grip = grip
		--d_print(grip)
		PlayerHelper.Pulling = true

		local soundId = AudioController:GrabRandomFromTable(AudioController.WEB_SHOOT_AUDIO_TABLE)

		AudioController:PlaySoundAtPart(soundId, handPart, 0.1)
		AnimationController:ShootWeb(grip)
		web, limitDist, endPoint = createWebRope(webSpot, handPart, grip)
		web.Parent = PlayerHelper:getCharacterHumanoidRootPart()
		if limitDist <= Settings.WEB_MAX_DISTANCE then --For animation delay
            PlayerHelper.Pulling = false
			--d_print("Webs")
			webAction(endPoint, grip)
		else
			web:Destroy()
		end
	end
end


-- stop holding onto web
function PlayerController:ReleaseWeb(rope)
	PlayerHelper.Holding = false
	PlayerHelper.Clicking = false
	--print(Pulling)
	local character = PlayerHelper:isAlive()
	if not character then return end
	if PlayerHelper.Pulling then return end
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()

	local Settings = ControllerConstants:GetSettings()

	local willFlip = rollPct(Settings.FLIP_CHANCE)

	--print(hrp.AssemblyLinearVelocity.Magnitude)
	if hrp.AssemblyLinearVelocity.Magnitude > 250 then
		AnimationController.emoteTrackC:Play(0.02, 5, 0)
		AnimationController.emoteTrackC.TimePosition = AnimationController.pullPosition
		AnimationController.releaseTrack:AdjustSpeed(0.05)
	else
		AnimationController.releaseTrack:Play(0.3, 1, 0)
		AnimationController.releaseTrack.TimePosition = 0.333
		AnimationController.releaseTrack:AdjustSpeed(0.05)
	end

	local soundId = AudioController:GrabRandomFromTable(AudioController.WEB_WHIP_AUDIO_TABLE)

	AudioController:PlaySoundAtPart(soundId, hrp, 0.01)

	if willFlip and AnimationController.releaseTrack.IsPlaying then
		AnimationController:LateralFlip(-1)
	elseif not willFlip and AnimationController.releaseTrack.IsPlaying then
		AnimationController:LateralFlip(-0.5)	
	else
		AnimationController:LateralFlip(0.3)
	end

	task.wait()

	destroyWebs(PlayerHelper.attachedPoint, rope)

	task.wait(0.3)
	AnimationController.releaseTrack:Stop(0.5)
	AnimationController.emoteTrackC:Stop(0.5)
end


function PlayerController:Dodge()
    dodgeDebounce = true
    sit()
    AnimationController:Slide()
    AnimationController:ChooseFlip()
    AnimationController:Dodge()
    Debugging:print("FLIP")
    stand()
    dodgeDebounce = false
    PlayerHelper.Dodging = false
end


function PlayerController:AutoRotate()
	local c, humanoid = PlayerHelper:isAlive()

	humanoid.AutoRotate = not PlayerHelper.isLookingForward
	local orientation = PlayerHelper:getCharacterHumanoidRootPart():FindFirstChild("FaceForward")
    orientation.Enabled = PlayerHelper.isLookingForward
end


local function rayCastToPart(part, length)
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
	raycastParams.IgnoreWater = true
	raycastParams.FilterDescendantsInstances = {part}

	local origin = hrp.Position
	local lookVector = hrp.CFrame.LookVector

	local result = workspace:Raycast(origin, lookVector * length, raycastParams) or 
		workspace:Raycast(origin, Vector.UP_VECTOR * length, raycastParams)

	return result
end


local function collectNearbyParts()
	local character = PlayerHelper:isAlive()
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()

    local Settings = ControllerConstants:GetSettings()

	local filter = {character}

	local floorFilter = RaycastParams.new()
	floorFilter.FilterDescendantsInstances = filter
	floorFilter.FilterType = Enum.RaycastFilterType.Blacklist
	local floor = workspace:Raycast(hrp.Position, -Vector.UP_VECTOR * 3, floorFilter)
	if floor then 
        table.insert(filter, floor.Instance) 
    end


	local characterFilter = OverlapParams.new()
	characterFilter.FilterDescendantsInstances = filter
	characterFilter.FilterType = Enum.RaycastFilterType.Blacklist
	local nearbyParts = workspace:GetPartBoundsInRadius(hrp.Position, Settings.CLIMB_DIST_THRESHOLD, characterFilter)
	if #nearbyParts > 0 then
		Debugging:print(nearbyParts[1].Name)
		return nearbyParts[1]			
	else
		return nil
	end
end


function PlayerController:ControlClimbing()
	local character = PlayerHelper:isAlive()
	if not character then return end
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()

    local Settings = ControllerConstants:GetSettings()

	local climbInstance = nil
	local charCoordinates
	local climbingAttachment0 = hrp.Climb0

	local climbingPosition = hrp.ClimbAlignPos
	local climbingOrientationA = hrp.ClimbAlignWall
	local climbingOrientationB = hrp.ClimbAlignRot

	while PlayerHelper.canClimb do
		task.wait(DT)

		PlayerController.climbable = collectNearbyParts()		
		if not PlayerHelper.Climbing then
			if PlayerController.climbable then
				climbInstance = rayCastToPart(PlayerController.climbable, Settings.CLIMB_DIST_THRESHOLD*4)
			end
		end

		--print(climbInstance)
		if climbInstance and PlayerController.climbable then
			attachToPart(climbInstance, climbingPosition)
			PlayerHelper.Climbing = true						
		else
			PlayerHelper.Climbing = false
			climbingPosition.Enabled = false
			climbingOrientationA.Enabled = false
			climbingOrientationB.Enabled = false
            if AnimationController.climbTrack then
                AnimationController.climbTrack:Stop()		
            end
		end
	end

	if AnimationController.climbTrack then
		AnimationController.climbTrack:Stop()		
	end
	climbingPosition.Enabled = false
	climbingOrientationA.Enabled = false
	climbingOrientationB.Enabled = false

	PlayerHelper.Climbing = false
	--d_print("End climbing")
end


local function leap()
	local c, humanoid = PlayerHelper:isAlive()
	humanoid:ChangeState(3)
	task.wait(DT)
	humanoid:ChangeState(5)
	Debugging:print("JUMPED")		
end


local function jump(actionName, inputState, inputObj)
    local character, humanoid = PlayerHelper:isAlive()
	if not character then return end

    local Settings = ControllerConstants:GetSettings()

	local willFlip = rollPct(Settings.FLIP_CHANCE)
	AnimationController:StopEmotes()

	if inputState == Enum.UserInputState.Begin then
		Debugging:print("Jumping")
		local dt = 0
		humanoid.UseJumpPower = true
		humanoid.JumpPower = Settings.MIN_JUMPPOWER

		while humanoid.JumpPower <= Settings.MAX_JUMPPOWER-1 do
			humanoid.JumpPower = humanoid.JumpPower + (Settings.MAX_JUMPPOWER - humanoid.JumpPower)*dt / Settings.JUMP_TIME
			--d_print("Humanoid Jump Power: ", humanoid.JumpPower)
			dt = dt + task.wait(DT)
		end		
	elseif inputState == Enum.UserInputState.End then
		task.spawn(disableClimbForDuration, 0.55)
		if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
			leap()
			if willFlip then
				sit()
				AnimationController:ChooseFlip()
			else
				sit()
			end
			task.wait(0.55)
			humanoid.Sit = false
		end
		humanoid.JumpPower = Settings.MIN_JUMPPOWER
	end
end


local function sprint(actionName, inputState, inputObj)
    local character, humanoid = PlayerHelper:isAlive()
	if not character then return end

    local TweenService = game:GetService("TweenService")

    local Settings = ControllerConstants:GetSettings()

	local newFOV = Settings.originalFOV + Settings.originalFOV * Settings.finalWalkspeed / Settings.initialWalkspeed / 25

    local accelerateInfo = TweenInfo.new(3)
    local decelerateInfo = TweenInfo.new(1)

	local tween1 = TweenService:Create(humanoid, accelerateInfo, {WalkSpeed = Settings.finalWalkspeed})
	local tween2 = TweenService:Create(humanoid, decelerateInfo, {WalkSpeed = Settings.initialWalkspeed})

	if inputState == Enum.UserInputState.Begin then
		tween1:Play()
		CameraController:TweenFOV(newFOV, 3)
		tween1.Completed:Connect(function()
			tween1:Destroy()
		end)
	elseif inputState == Enum.UserInputState.End then
		tween2:Play()
		CameraController:TweenFOV(Settings.originalFOV, 1)
		tween2.Completed:Connect(function()
			tween2:Destroy()
		end)
	end
end


local function calculateDrag(characterVelocity, dragStrength)
	local S = 2*(2*2) + (2*1*4)*6 + (1*1*2)*5
	local C_D = 1.3

	local conversion = 9.8 / 196.2
	local dynamicPressure = 1/2 * 1.225 * characterVelocity.Magnitude^2 * characterVelocity.Unit * conversion^2.3

	return -dynamicPressure * S * C_D * dragStrength
end


local function applyDrag()
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()
	if not hrp then return end

	local dragForce = hrp.Drag

	dragForce.Force = calculateDrag(hrp.AssemblyLinearVelocity, PlayerController.dragStrength)
	dragForce.Enabled = true
end


function PlayerController:Fall()
    local c, humanoid = PlayerHelper:isAlive()
	if not c then return end
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()
	
    local Settings = ControllerConstants:GetSettings()

	local controlForce = hrp:FindFirstChild("Control") or Instance.new("VectorForce")
	if 
		not PlayerHelper.Holding and 
		not PlayerHelper.Climbing and 
		controlForce.Enabled and
		not AnimationController.fallTrack.IsPlaying 
	then
		AnimationController.fallTrack:Play(0.8, 3, 0.8)
		PlayerHelper.Falling = true
		PlayerHelper.dragStrength = Settings.FALLING_DRAG_STRENGTH
		AnimationController:StopEmotes()
	elseif
		PlayerHelper.Holding or 
		PlayerHelper.Climbing or
		humanoid:GetState() == Enum.HumanoidStateType.Running or
		humanoid:GetState() == Enum.HumanoidStateType.Jumping
	then
		AnimationController.fallTrack:Stop()
		AnimationController.skydiveMainTrack:Stop()
		AnimationController.skydiveLayerTrack:Stop()
		PlayerHelper.Falling = false
	end
end


local function connectWebShootingFunctions()
    if PlayerHelper.websEnabled and not connected then
        print("Connecting")
        connected = true
        ClickBeganEvent = PlayerHelper.Mouse.Button1Down:Connect(PlayerController.WebShoot)
        ClickEndedEvent = PlayerHelper.Mouse.Button1Up:Connect(PlayerController.ReleaseWeb)
    elseif not PlayerHelper.websEnabled and connected then
        print("Disconnecting")
        connected = false
        ClickBeganEvent:Disconnect()
        ClickEndedEvent:Disconnect()
    end
end


--[[
	This function allows one to control their swinging and provides 
	the pendulum motion required by holdRope3
--]]
function PlayerController:Update()
	local character, humanoid = PlayerHelper:isAlive()
	if not character then return end
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()

    local Settings = ControllerConstants:GetSettings()

	local lookVector
	
	local projectXZ = Vector3.new(1,0,1)

	local camera = workspace.Camera
	local camCF = camera.CFrame

	local forwardVector = camCF:VectorToWorldSpace(Vector3.new(0, 0, -1))

	if not humanoid.Sit and PlayerHelper.Holding then
		sit()
	end
	
	local controlForce = hrp.Control
	local directionControl = hrp.Direction

	if PlayerHelper.Pulling or PlayerHelper.Holding or humanoid.Sit == true then
		controlForce.Force = humanoid.MoveDirection * Settings.CONTROL_STRENGTH
		lookVector = forwardVector*projectXZ + humanoid.MoveDirection
		
		directionControl.CFrame = CFrame.lookAt(hrp.Position, hrp.Position+lookVector.Unit)
		controlForce.Enabled = true
		directionControl.D = 1000
		directionControl.P = 10000
		directionControl.MaxTorque = Vector3.new(400000, 400000, 400000)
	else
		controlForce.Enabled = false
		directionControl.P = 0
		directionControl.D = 0
		directionControl.MaxTorque = Vector3.new()
	end

	if hrp.AssemblyLinearVelocity.Y < -Settings.SKYDIVE_SPEED then
		directionControl.CFrame = CFrame.lookAt(hrp.Position, hrp.Position+forwardVector-2 * Vector.UP_VECTOR)
	end
    
    if PlayerHelper.Dodging and not dodgeDebounce then
        PlayerController:Dodge()
    end 

    connectWebShootingFunctions()
    PlayerController:ControlClimbing()
    PlayerController:AutoRotate()
    ActionHandler:Update(sprint, jump)
    AudioController:Update()
    AnimationController:Update()
end


function PlayerController:Init()
    local Settings = ControllerConstants:GetSettings()

	PlayerHelper.Clicking = false
	PlayerHelper.Holding = false
	PlayerHelper.isAutomatic = false
	PlayerHelper.canClimb = false
	PlayerHelper.Climbing = false
	PlayerHelper.isCameraToggled = false
	PlayerHelper.attachedPoint = nil
	PlayerHelper.isLookingForward = false
	local max_force = 50000

	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom

	local hrp = PlayerHelper:getCharacterHumanoidRootPart()
	local character, humanoid = PlayerHelper:isAlive()
    local mass = PlayerHelper:getCharacterMass()

	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	local gravityForce = hrp:FindFirstChild("Gravity") or Instance.new("VectorForce")
	if 
		gravityForce.Name ~= "Gravity" 
		or gravityForce.Force.Magnitude ~= 196.2/Settings.ANTIGRAV_MAGNITUDE * mass
	then
		--d_print(gravityForce.Name)
		gravityForce.Name = "Gravity"
		gravityForce.RelativeTo = 2
		gravityForce.ApplyAtCenterOfMass = true
		gravityForce.Attachment0 = PlayerHelper:getCharacterRootAttachment()
		gravityForce.Force = -Vector.UP_VECTOR*196.2/Settings.ANTIGRAV_MAGNITUDE * mass
		gravityForce.Parent = hrp
		gravityForce.Enabled = false
	end

	local adjustmentVelocity = hrp:FindFirstChild("Adjustment") or Instance.new("LinearVelocity")
	if adjustmentVelocity.Name ~= "Adjustment" or adjustmentVelocity.MaxForce ~= max_force then
		adjustmentVelocity.Name = "Adjustment"
		adjustmentVelocity.RelativeTo = 0
		adjustmentVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		adjustmentVelocity.MaxForce = max_force
		adjustmentVelocity.VectorVelocity = Vector3.new()
		adjustmentVelocity.Attachment0 = PlayerHelper:getCharacterRootAttachment()
		adjustmentVelocity.Parent = hrp
		adjustmentVelocity.Enabled = false
	end

	local tensionForce = hrp:FindFirstChild("Tension") or Instance.new("VectorForce")
	if tensionForce.Name ~= "Tension" then
		tensionForce.Name = "Tension"
		tensionForce.RelativeTo = 2
		tensionForce.Attachment0 = PlayerHelper:getCharacterRootAttachment()
		tensionForce.Force = Vector3.new()
		tensionForce.ApplyAtCenterOfMass = true
		tensionForce.Parent = hrp
		tensionForce.Enabled = false
	end

	local dragForce = hrp:FindFirstChild("Drag") or Instance.new("VectorForce")
	if dragForce.Name ~= "Drag" then 
		dragForce.Name = "Drag" 
		dragForce.Attachment0 = PlayerHelper:getCharacterRootAttachment()
		dragForce.ApplyAtCenterOfMass = true
		dragForce.RelativeTo = 2
		dragForce.Parent = hrp
		dragForce.Enabled = true
	end

	local directionControl = hrp:FindFirstChild("Direction") or Instance.new("BodyGyro")
	if directionControl.Name ~= "Direction" or not hrp:FindFirstChild("Direction") then
		directionControl.Name = "Direction"
		directionControl.D = 0
		directionControl.MaxTorque = Vector3.new(400000,400000,400000)
		directionControl.P = 0
		directionControl.Parent = hrp
	end

	local controlForce = hrp:FindFirstChild("Control") or Instance.new("VectorForce")
	if controlForce.Name ~= "Control" then 
		controlForce.Name = "Control"
		controlForce.Attachment0 = PlayerHelper:getCharacterRootAttachment()
		controlForce.RelativeTo = 2
		controlForce.ApplyAtCenterOfMass = true
		controlForce.Enabled = false
		controlForce.Parent = hrp
	end


	local climbingAttachment0 = hrp:FindFirstChild("Climb0") or Instance.new("Attachment")
	if climbingAttachment0.Name ~= "Climb0" then
		climbingAttachment0.Name = "Climb0"
		climbingAttachment0.Visible = Debugging.DEBUG

		climbingAttachment0.Position = Vector3.new(0,0,-1.5)

		climbingAttachment0.Parent = hrp
	end

	local climbingPosition = hrp:FindFirstChild("ClimbAlignPos") or Instance.new("AlignPosition")
	if climbingPosition.Name ~= "ClimbAlignPos" then
		climbingPosition.Name = "ClimbAlignPos"

		climbingPosition.Mode = Enum.PositionAlignmentMode.TwoAttachment
		climbingPosition.RigidityEnabled = true
		climbingPosition.ApplyAtCenterOfMass = false
		climbingPosition.ReactionForceEnabled = false

		climbingPosition.Attachment0 = climbingAttachment0
		climbingPosition.Enabled = false
		climbingPosition.Parent = hrp
	end

	local climbingOrientationA = hrp:FindFirstChild("ClimbAlignWall") or Instance.new("AlignOrientation")
	if climbingOrientationA.Name ~= "ClimbAlignWall" then
		climbingOrientationA.Name = "ClimbAlignWall"

		climbingOrientationA.Mode = Enum.OrientationAlignmentMode.OneAttachment
		climbingOrientationA.RigidityEnabled = true
		climbingOrientationA.ReactionTorqueEnabled = false
		climbingOrientationA.PrimaryAxisOnly = false

		climbingOrientationA.Attachment0 = climbingAttachment0
		climbingOrientationA.Enabled = false
		climbingOrientationA.Parent = hrp
	end

	local climbingOrientationB = hrp:FindFirstChild("ClimbAlignRot") or Instance.new("AlignOrientation")
	if climbingOrientationB.Name ~= "ClimbAlignRot" then
		climbingOrientationB.Name = "ClimbAlignRot"

		climbingOrientationB.Mode = Enum.OrientationAlignmentMode.OneAttachment
		climbingOrientationB.RigidityEnabled = true
		climbingOrientationB.ReactionTorqueEnabled = false
		climbingOrientationB.PrimaryAxisOnly = false

		climbingOrientationB.Attachment0 = climbingAttachment0
		climbingOrientationB.Enabled = false
		climbingOrientationB.Parent = hrp
	end

	local orientation = hrp:FindFirstChild("FaceForward") or Instance.new("AlignOrientation")
	if orientation.Name ~= "FaceForward" then
		orientation.Name = "FaceForward"
		orientation.Attachment0 = PlayerHelper:getCharacterRootAttachment()
		orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		orientation.PrimaryAxisOnly = false
		orientation.AlignType = Enum.AlignType.Perpendicular
		orientation.Responsiveness = 100
		orientation.MaxTorque = 50000
		orientation.Parent = hrp
		orientation.Enabled = false
	end
	local upsideDown = hrp:FindFirstChild("UpsideDown") or Instance.new("AlignOrientation")
	if upsideDown.Name ~= "UpsideDown" then
		upsideDown.Name = "UpsideDown"
		upsideDown.Attachment0 = PlayerHelper:getCharacterRootAttachment()
		upsideDown.Mode = Enum.OrientationAlignmentMode.OneAttachment
		upsideDown.PrimaryAxisOnly = false
		upsideDown.AlignType = Enum.AlignType.Perpendicular
		upsideDown.Responsiveness = 100
		upsideDown.MaxTorque = 50000
		upsideDown.Parent = hrp
		upsideDown.Enabled = false
	end

    print(self)
    ActionHandler:Update(sprint, jump)
    ActionHandler:HookRenderStepFunctions(applyDrag, self.Update, self.Fall)

	print("Controls set")
end

return PlayerController