local feSpiderman = script:FindFirstAncestor("FE-Spiderman")

local ControllerConstants = require(feSpiderman.Controllers.ControllerConstants)
local Debugging = require(feSpiderman.Debugging)
local PlayerHelper = require(feSpiderman.PlayerHelper)
local Vector = require(feSpiderman.Utils.Vector)

local AnimationController = {}

AnimationController.climbTrack = nil
AnimationController.fallTrack = nil
AnimationController.swingTrack = nil
AnimationController.swingLegsTrack = nil
AnimationController.shootTrack = nil
AnimationController.releaseTrack = nil
AnimationController.dodgeTrack = nil
AnimationController.emoteTrackA = nil
AnimationController.emoteTrackB = nil
AnimationController.emoteTrackC = nil
AnimationController.skydiveMainTrack = nil
AnimationController.skydiveLayerTrack = nil
AnimationController.hangTrack = nil
AnimationController.lookTrackA = nil
AnimationController.lookTrackB = nil

AnimationController.swingLegsPosition = 0.51
AnimationController.pullPosition = 1.16

local character, humanoid, hrp
local ZERO = 1e-6

local EMOTE_R15_TABLE = {
	"http://www.roblox.com/asset/?id=3695333486",
	"http://www.roblox.com/asset/?id=4049551434",
	"http://www.roblox.com/asset/?id=5104344710",
}

local EMOTE_R06_TABLE = {
	"http://www.roblox.com/asset/?id=75354915",
	"http://www.roblox.com/asset/?id=87986341",
	"http://www.roblox.com/asset/?id=33796059"
}


function AnimationController:Init()
    character, humanoid = PlayerHelper:isAlive()
    hrp = PlayerHelper:getCharacterHumanoidRootPart()

    local climbAnimation = character:FindFirstChild("ClimbAnim", true)
	if climbAnimation then
		Debugging:print("Found climbing anim")
		self.climbTrack = humanoid.Animator:LoadAnimation(climbAnimation)
	end

	local fallAnimation = Instance.new("Animation")
	local swingAnimation = Instance.new("Animation")
	local swingLegsAnimation = Instance.new("Animation")
	local shootAnimation = Instance.new("Animation")
	local releaseAnimation = Instance.new("Animation")
	local dodgeAnimation = Instance.new("Animation")
	local emoteAnimationA = Instance.new("Animation")
	local emoteAnimationB = Instance.new("Animation")
	local emoteAnimationC = Instance.new("Animation")
	local skydiveMainAnimation = Instance.new("Animation")
	local skydiveLayerAnimation = Instance.new("Animation")
	local hangAnimation = Instance.new("Animation")
	local lookAnimation = Instance.new("Animation")

	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		fallAnimation.AnimationId = "http://www.roblox.com/asset/?id=2510195892"
		swingAnimation.AnimationId = "http://www.roblox.com/asset/?id=5918726674"
		swingLegsAnimation.AnimationId = "http://www.roblox.com/asset/?id=5895324424"
		shootAnimation.AnimationId = "http://www.roblox.com/asset/?id=7202863182"
		releaseAnimation.AnimationId = "http://www.roblox.com/asset/?id=5918726674"
		dodgeAnimation.AnimationId = "http://www.roblox.com/asset/?id=5915648917"
		emoteAnimationA.AnimationId = EMOTE_R15_TABLE[1]
		emoteAnimationB.AnimationId = EMOTE_R15_TABLE[2]
		emoteAnimationC.AnimationId = EMOTE_R15_TABLE[3]
		skydiveMainAnimation.AnimationId = "http://www.roblox.com/asset/?id=1083464683"
		skydiveLayerAnimation.AnimationId = "http://www.roblox.com/asset/?id=742639220"
		hangAnimation.AnimationId = "http://www.roblox.com/asset/?id=5915712534"
		lookAnimation.AnimationId = "http://www.roblox.com/asset/?id=10714066964"
	else
		fallAnimation.AnimationId = "http://www.roblox.com/asset/?id=180436148"
		swingAnimation.AnimationId = "http://www.roblox.com/asset/?id=32659699"
		swingLegsAnimation.AnimationId = "http://www.roblox.com/asset/?id=32659699"
		shootAnimation.AnimationId = "http://www.roblox.com/asset/?id=128853357"
		releaseAnimation.AnimationId = "http://www.roblox.com/asset/?id=163209885"	
		dodgeAnimation.AnimationId = "http://www.roblox.com/asset/?id=178130996"
		emoteAnimationA.AnimationId = EMOTE_R06_TABLE[1]
		emoteAnimationB.AnimationId = EMOTE_R06_TABLE[2]
		emoteAnimationC.AnimationId = EMOTE_R06_TABLE[3]
		skydiveMainAnimation.AnimationId = "http://www.roblox.com/asset/?id=182749109"
		skydiveLayerAnimation.AnimationId = "http://www.roblox.com/asset/?id=182749109"
		hangAnimation.AnimationId = "http://www.roblox.com/asset/?id=5915712534"
		lookAnimation.AnimationId = "http://www.roblox.com/asset/?id=10714066964"
		self.swingLegsPosition = 0.4
	end

	self.fallTrack = humanoid.Animator:LoadAnimation(fallAnimation)
	self.swingTrack = humanoid.Animator:LoadAnimation(swingAnimation)
	self.swingLegsTrack = humanoid.Animator:LoadAnimation(swingLegsAnimation)
	self.shootTrack = humanoid.Animator:LoadAnimation(shootAnimation)
	self.releaseTrack = humanoid.Animator:LoadAnimation(releaseAnimation)
	self.dodgeTrack = humanoid.Animator:LoadAnimation(dodgeAnimation)
	self.emoteTrackA = humanoid.Animator:LoadAnimation(emoteAnimationA)
	self.emoteTrackB = humanoid.Animator:LoadAnimation(emoteAnimationB)
	self.emoteTrackC = humanoid.Animator:LoadAnimation(emoteAnimationC)
	self.skydiveMainTrack = humanoid:LoadAnimation(skydiveMainAnimation)
	self.skydiveLayerTrack = humanoid:LoadAnimation(skydiveLayerAnimation)
	self.hangTrack = humanoid:LoadAnimation(hangAnimation)
	self.lookTrackA = humanoid:LoadAnimation(lookAnimation)
	self.lookTrackB = humanoid:LoadAnimation(lookAnimation)
end


-- feFlip
function AnimationController:LongitudinalFlip(signDirection)
	for i = 1,360 do 
		task.delay(i/720,function()
			hrp.CFrame = hrp.CFrame * CFrame.Angles(0,0,signDirection*1/math.deg(1))
		end)
	end
end


function AnimationController:LateralFlip(signDirection)
	for i = 1,360 do 
		task.delay(i/720,function()
			hrp.CFrame = hrp.CFrame * CFrame.Angles(-signDirection*1/math.deg(1),0,0)
		end)
	end
end


function AnimationController:ChooseFlip()
    local c, humanoid = PlayerHelper:isAlive()
	local camera = workspace.CurrentCamera

	local lookVector = camera.CFrame.LookVector
	--int("Move Direction:", humanoid.MoveDirection)
	--print(lookVector:Dot(humanoid.MoveDirection))

	local direction = lookVector:Dot(humanoid.MoveDirection)
	local directionVector = lookVector:Cross(humanoid.MoveDirection)

	local roundedScalarDirection = math.round(direction)
	local roundedYDirection = math.round(directionVector.Y)
	Debugging:print("Flip Direction :", direction)
	Debugging:print("Rounded Direction :", roundedScalarDirection)
	Debugging:print("directionVector: ", directionVector)

	if PlayerHelper.isLookingForward then
		if math.abs(directionVector.Y) < ZERO then
			self:LateralFlip(roundedScalarDirection)
			Debugging:print("FORWARD OR BACK FLIP")
		else
			self:LongitudinalFlip(roundedYDirection)
			Debugging:print("SIDE FLIP")
		end
	else
		self:LateralFlip(1)
	end
end


function AnimationController:Slide()
	for i = 1,360 do 
		task.delay(i/720,function()
			hrp.CFrame = hrp.CFrame + humanoid.MoveDirection/30
		end)
	end
end


function AnimationController:StopEmotes()
    self.emoteTrackA:Stop()
	self.emoteTrackB:Stop()
	self.emoteTrackC:Stop()
end


function AnimationController:Emote()
	local animIndex = math.random(1,3)
	AnimationController:StopEmotes()
	if animIndex == 1 then
		print("EMOTEA")
		self.emoteTrackA:Play(0.2, 100, 2)
	elseif animIndex == 2 then
		print("EMOTEB")
		self.emoteTrackB:Play(0.2, 100, 1)
	elseif animIndex == 3 then 
		print("EMOTEC")
		self.emoteTrackC:Play(0.2, 100, 1)
	end
end


function AnimationController:Dodge()
	self:StopEmotes()
	
	local rollPosition = 0.29
	self.dodgeTrack:Play(0.8, 2, 0)
	self.dodgeTrack.TimePosition = rollPosition
	task.wait(0.55)
	self.dodgeTrack:Stop(0.3)
end


function AnimationController:Swing(grip)
    self.swingTrack:Play(0.2, 0.5, 0)
	self.swingLegsTrack:Play(0.8, 1.5, 0)
	--swingTrack:AdjustSpeed(0)
	self.swingLegsTrack:AdjustSpeed(0)

	self.swingLegsTrack.TimePosition = self.swingLegsPosition
	
	local rightPosition = 3
	local leftPosition = 1
	
	if string.match(grip.Name, "Left") then
		self.swingTrack.TimePosition = leftPosition
	else
		self.swingTrack.TimePosition = rightPosition
	end
end


function AnimationController:ShootWeb(grip)
	self:StopEmotes()

	local t = 0
	local rightShootStart = 1.933
	local rightShootEnd = 2.133
	local leftShootStart = 2.167
	local leftshootEnd = 2.4
	
	self.shootTrack:Play()
	self.shootTrack:AdjustSpeed(0)
	if string.match(grip.Name, "Left") then
		self.shootTrack.TimePosition = leftShootStart
		t = leftshootEnd - leftShootStart
	else
		self.shootTrack.TimePosition = rightShootStart
		t = rightShootEnd - rightShootStart
	end

	self.shootTrack:AdjustSpeed(0.5)
	task.wait(t)
	self.shootTrack:Stop(0.8)
end


function AnimationController:Update()
    local c, humanoid = PlayerHelper:isAlive()
    local Settings = ControllerConstants:GetSettings()


    if PlayerHelper.Pulling or PlayerHelper.Holding or humanoid.Sit then
        self.lookTrackA:AdjustWeight(0.1)
		self.lookTrackB:AdjustWeight(0.1*0.5)
    end
    
	if hrp.AssemblyLinearVelocity.Y < -Settings.SKYDIVE_SPEED then
		--print(hrp.AssemblyLinearVelocity.Y)
		if not self.skydiveLayerTrack.IsPlaying then
			self.skydiveLayerTrack:Play(3, 4, 1)
			self.skydiveMainTrack:Play(4, 4, 0.1)
            humanoid.Sit = true
		end
    end
    if not self.lookTrackA.IsPlaying then
		self.lookTrackA:Play(0.2, 1, 0)
		self.lookTrackB:Play(0.2, 0.5, 0)
	end
	self.lookTrackA.TimePosition = Vector.mapToRange(
		(PlayerHelper.Mouse.UnitRay.Direction * Vector.XZ_VECTOR).Unit:Dot(hrp.CFrame.RightVector),
		-1,
		1,
		18/24,
		22/24
	)

    local floorPosition = PlayerHelper:rayCastToFloor()
    if floorPosition then
        if (floorPosition.Position - hrp.Position).Magnitude < humanoid.HipHeight and 
		not PlayerHelper.Dodging and 
		not PlayerHelper.Pulling and
		not PlayerHelper.Clicking
	then
		humanoid.Sit = false
		self.emoteTrackC.Looped = false
		self.emoteTrackC:Play(0.1, 5, 1)
		self.emoteTrackC.TimePosition = 1 + 1/30
	end
	if humanoid.MoveDirection.Magnitude > 0 then
		self.lookTrackA:AdjustWeight(0.1)
		self.lookTrackB:AdjustWeight(0.1*0.5)
		self:StopEmotes()
	else
		self.lookTrackA:AdjustWeight(1)
		self.lookTrackB:AdjustWeight(0.5)
	end
    
	self.lookTrackB.TimePosition = Vector.mapToRange(
		(PlayerHelper.Mouse.UnitRay.Direction).Unit:Dot(-Vector.UP_VECTOR),
		-1,
		1,
		3+16/24,
		4+1/24
	)
    end

    if PlayerHelper.Climbing then
		if not AnimationController.climbTrack.IsPlaying then
			AnimationController.climbTrack:Play(0.1, 5)
			Debugging:print("Play climb")
		end
    else
        AnimationController.climbTrack:Stop()
	end
end


return AnimationController