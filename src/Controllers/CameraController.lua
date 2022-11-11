local feSpiderman = script:FindFirstAncestor("FE-Spiderman")
local PlayerHelper = require(feSpiderman.PlayerHelper)
local Spring = require(feSpiderman.Spring)

local ControllerConstants = require(feSpiderman.Controllers.ControllerConstants)

local CameraController = {}

CameraController.isCameraToggled = false

local pointLookVector = Vector3.new()
local cameraOffset = Vector3.new()

local Settings = ControllerConstants:GetSettings()

local velSpring = Spring.new(Settings.CAM_RESPONSIVENESS*1.5, Vector3.new())
local panSpring = Spring.new(Settings.CAM_RESPONSIVENESS, Vector3.new())
local zoomSpring = Spring.new(1, Vector3.new())

local fastTween = require(feSpiderman.Utils.FastTween)


CameraController.mouseVector = Vector3.new()
CameraController.distance = nil

function CameraController:UpdateDistance(scrollDelta)
    local Settings = ControllerConstants:GetSettings()

	CameraController.distance -= scrollDelta * Settings.DOLLY_SPEED * 330 
	CameraController.distance = math.clamp(CameraController.distance, Settings.CAM_MIN_DISTANCE, Settings.CAM_MAX_DISTANCE)
end


function CameraController:TweenFOV(targetFOV, tweenLength)
	tweenLength = tweenLength or 0.2
	local tweenInfo = { tweenLength, Enum.EasingStyle.Quad, Enum.EasingDirection.In }
	local camera = workspace.Camera

	local tween = fastTween(camera, tweenInfo, {FieldOfView = targetFOV})

	tween:Play()
	tween.Completed:Connect(function()
		tween:Destroy()
	end)
end


function CameraController:ToggleCamera()
    CameraController.isCameraToggled = not CameraController.isCameraToggled
end


function CameraController.Update(dt)
	local character = PlayerHelper:isAlive()
	if not character then return end
	local hrp = PlayerHelper:getCharacterHumanoidRootPart()
	local camera = workspace.CurrentCamera

    local Settings = ControllerConstants:GetSettings()

	local newCFrame = nil
	local newFocus = nil
    local displacement = camera.CFrame.Position - hrp.Position
	local focusedPoint = Vector3.new()
	local orientation = hrp:FindFirstChild("FaceForward")

	if PlayerHelper.Holding then
		focusedPoint = PlayerHelper.attachedPoint.WorldPosition
		focusedPoint = focusedPoint - hrp.CFrame.Position
		velSpring.f = Settings.CAM_RESPONSIVENESS*2
		panSpring.f = Settings.CAM_RESPONSIVENESS*6
		if orientation then
			orientation.Enabled = false	
		end
	elseif PlayerHelper.Falling then
		velSpring.f = Settings.CAM_RESPONSIVENESS*2
		panSpring.f = Settings.CAM_RESPONSIVENESS*3
	else
		velSpring.f = Settings.CAM_RESPONSIVENESS
		panSpring.f = Settings.CAM_RESPONSIVENESS*2
		if orientation then
			orientation.Enabled = PlayerHelper.isLookingForward	
		end
	end

	if PlayerHelper.Climbing then
		focusedPoint = PlayerHelper.ClimbFocus
		focusedPoint = focusedPoint - hrp.CFrame.Position
		velSpring.f = Settings.CAM_RESPONSIVENESS*3
		panSpring.f = Settings.CAM_RESPONSIVENESS*4
	end

	if camera.CameraType == Enum.CameraType.Custom then
		local distance = displacement.Magnitude
		distance = math.clamp(distance, Settings.CAM_MIN_DISTANCE, Settings.CAM_MAX_DISTANCE)
		zoomSpring:Reset(distance)
		panSpring:Reset(hrp.CFrame.Position)
		pointLookVector = hrp.CFrame.Position + Vector3.new(0,5,0)
		cameraOffset = Vector3.new(0, 5, CameraController.distance)
		CameraController.distance = distance
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local transformedMouseVector = camera.CFrame:VectorToWorldSpace(CameraController.mouseVector)

	local newDistance = zoomSpring:Update(dt, CameraController.distance)
	local newDisplacement = displacement.Unit*newDistance 
	- (transformedMouseVector 
		* Vector3.new(0.8, 1.5, 0.8))

	local newPos = hrp.CFrame.Position + Vector3.new(0,2,0) + newDisplacement--CFrame.new(hrp.CFrame.Position):PointToWorldSpace(newDisplacement)
	local newPointLook = hrp.CFrame.Position 
		+ Vector3.new(0,5,0) 
		+ focusedPoint * Settings.FOCUS_POINT_BIAS
		+ hrp.AssemblyLinearVelocity/50

	pointLookVector = panSpring:Update(dt, newPointLook)
	cameraOffset = velSpring:Update(dt, newPos)

	newCFrame = CFrame.lookAt(cameraOffset, pointLookVector)

	if PlayerHelper.isLookingForward and orientation then
		--d_print("Facing forward")
		orientation.CFrame = CFrame.lookAt(hrp.Position, hrp.Position+camera.CFrame.LookVector)
		--print(orientation.PrimaryAxis)
	end

	camera.CFrame = newCFrame
	--camera.Focus = newFocus
end


return CameraController