local feSpiderman = script:FindFirstAncestor("FE-Spiderman")
local ControllerConstants = require(feSpiderman.Controllers.ControllerConstants)
local AnimationController = require(feSpiderman.Controllers.AnimationController)
local CameraController = require(feSpiderman.Controllers.CameraController)
local PlayerHelper = require(feSpiderman.PlayerHelper)
local Debugging = require(feSpiderman.Debugging)

local Vector = require(feSpiderman.Vector)

local sendNotification = require(feSpiderman.SendNotification)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local ActionHandler = {}

local prevSettings = {}

local MouseMovement = Enum.UserInputType.MouseMovement
local MouseWheel = Enum.UserInputType.MouseWheel

function table_eq(table1, table2)
    local avoid_loops = {}
    local function recurse(t1, t2)
       -- compare value types
       if type(t1) ~= type(t2) then return false end
       -- Base case: compare simple values
       if type(t1) ~= "table" then return t1 == t2 end
       -- Now, on to tables.
       -- First, let's avoid looping forever.
       if avoid_loops[t1] then return avoid_loops[t1] == t2 end
       avoid_loops[t1] = t2
       -- Copy keys from t2
       local t2keys = {}
       local t2tablekeys = {}
       for k, _ in pairs(t2) do
          if type(k) == "table" then table.insert(t2tablekeys, k) end
          t2keys[k] = true
       end
       -- Let's iterate keys from t1
       for k1, v1 in pairs(t1) do
          local v2 = t2[k1]
          if type(k1) == "table" then
             -- if key is a table, we need to find an equivalent one.
             local ok = false
             for i, tk in ipairs(t2tablekeys) do
                if table_eq(k1, tk) and recurse(v1, t2[tk]) then
                   table.remove(t2tablekeys, i)
                   t2keys[tk] = nil
                   ok = true
                   break
                end
             end
             if not ok then return false end
          else
             -- t1 has a key which t2 doesn't have, fail.
             if v2 == nil then return false end
             t2keys[k1] = nil
             if not recurse(v1, v2) then return false end
          end
       end
       -- if t2 has a key which t1 doesn't have, fail.
       if next(t2keys) then return false end
       return true
    end
    return recurse(table1, table2)
end


local function mouseMovementAction(actionName, inputState, inputObj)
	local camera = workspace.Camera
	if inputState == Enum.UserInputState.Change then
		if inputObj.UserInputType == MouseMovement then
			CameraController.mouseVector = inputObj.Position - Vector3.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2, 0)
			CameraController.mouseVector = Vector3.new(CameraController.mouseVector.X, -CameraController.mouseVector.Y, 0) / 100	
		elseif inputObj.UserInputType == MouseWheel then
			CameraController:UpdateDistance(inputObj.Position.Z)
		end
	end
end


local function cameraAction(actionName, inputState, inputObj)
	local Settings = ControllerConstants:GetSettings()

    if inputState == Enum.UserInputState.Begin then
		if inputObj.KeyCode == Settings.CameraButton then
			CameraController:ToggleCamera()
            if CameraController.isCameraToggled then
                RunService:BindToRenderStep("CameraControl", 1, CameraController.Update)
                ContextActionService:BindAction('MouseMovement', mouseMovementAction, false, MouseMovement, MouseWheel)
            else
                RunService:UnbindFromRenderStep("CameraControl")
                ContextActionService:UnbindAction('MouseMovement')
                workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            end
		elseif inputObj.KeyCode == Settings.FaceForwardButton then
			PlayerHelper:ToggleFaceForward()
		end		
	end
end


function ActionHandler:isKeyDown(keyCode)
	return Vector.bool_to_number(UserInputService:IsKeyDown(keyCode))
end


function ActionHandler:isKeyDownBool(keyCode)
	return UserInputService:IsKeyDown(keyCode)
end


function ActionHandler:Update(sprintFunc, jumpFunc)
    local Settings = ControllerConstants:GetSettings()

    if table_eq(Settings, prevSettings) then 
        --print("Tables equal") 
        return 
    end
    
    print("Binding actions")
    print("Listen Function bound")
    ContextActionService:UnbindAction("EnableWebSwinging")
	ContextActionService:BindAction(
        "EnableWebSwinging",
        self.Listen,
        false,
        Settings.EnableButton, 
        Settings.AutomaticButton, 
        Settings.ClimbingButton, 
        Settings.DodgeButton, 
        Settings.EmoteButton
    )

	ContextActionService:UnbindAction('SPEED')
	ContextActionService:BindAction(
        'SPEED', 
        sprintFunc, 
        false, 
        Settings.RunButton
    )
    print("Sprint Function bound")

	ContextActionService:UnbindAction('MouseMovement')
	ContextActionService:BindAction(
        "ControlHandler", 
        self.CameraListen, 
        false, 
        Settings.ControlButton
    )
    print("Camera Function bound")

	ContextActionService:UnbindAction('JUMP')
	ContextActionService:BindAction(
        'JUMP', 
        jumpFunc, 
        false, 
        Settings.JumpButton
    )
    print("Jump Function bound")

    prevSettings = Settings
	Debugging:print("Jump and Speed controls")
end


function ActionHandler:HookRenderStepFunctions(dragFunc, controlSwingingFunc, fallingFunc)
    local success, message = pcall(function() 
        RunService:UnbindFromRenderStep("ImposeDrag") 
    end)
	if success then
		Debugging:print("Success: Drag force unbound!")
	else 
		Debugging:print("An error occurred with unbinding drag force: " .. message)
	end
	RunService:BindToRenderStep("ImposeDrag", 1, dragFunc)
	Debugging:print("Drag Force rebound")

	success, message = pcall(function() 
        RunService:UnbindFromRenderStep("ControlSwinging") 
    end)
	if success then
		Debugging:print("Success: Swing control unbound!")
	else 
		Debugging:print("An error occurred with unbinding swing control: " .. message)
	end
	RunService:BindToRenderStep("ControlSwinging", 1, controlSwingingFunc)
	Debugging:print("Swing control rebound")
	success, message = pcall(function() 
        RunService:UnbindFromRenderStep("FallingAnimation") 
    end)
	if success then
		Debugging:print("Success: Falling animation unbound!")
	else 
		Debugging:print("An error occurred with unbinding falling animation: " .. message)
	end
	RunService:BindToRenderStep("FallingAnimation", 1, fallingFunc)
	Debugging:print("Falling animation rebound")
end


function ActionHandler.CameraListen(actionName, inputState, inputObj)
    local Settings = ControllerConstants:GetSettings()

    print(Settings)
	if inputState == Enum.UserInputState.Begin then
		if inputObj.KeyCode == Settings.ControlButton then
            ContextActionService:BindAction('ToggleCamera', cameraAction, false, Settings.CameraButton, Settings.FaceForwardButton)
        end
    elseif inputState == Enum.UserInputState.End then
        ContextActionService:UnbindAction('ToggleCamera')
	end
end


function ActionHandler.Listen(actionName, inputState, inputObj)
    local Settings = ControllerConstants:GetSettings()

    --print(Settings)
	if inputState == Enum.UserInputState.Begin then
		if inputObj.KeyCode == Settings.EnableButton then
			PlayerHelper.websEnabled = not PlayerHelper.websEnabled
            if PlayerHelper.websEnabled then
                sendNotification("Webs Enabled", "Left Click to Shoot; Press E for Auto Mode", "Close", 1)
            else
                sendNotification("Webs Disabled", "Press F to re-enable", "Close", 1)
            end
		elseif inputObj.KeyCode == Settings.AutomaticButton then
			PlayerHelper.isAutomatic = not PlayerHelper.isAutomatic
			if PlayerHelper.isAutomatic then
				sendNotification("Automatic Mode", "", "Close", 1)
			else
				sendNotification("Manual Mode", "", "Close", 1)
			end
		elseif inputObj.KeyCode == Settings.ClimbingButton then
			PlayerHelper.canClimb = true
		elseif inputObj.KeyCode == Settings.DodgeButton then
            PlayerHelper.Dodging = true
		elseif inputObj.KeyCode == Settings.EmoteButton then
			AnimationController:Emote()
		end
	elseif inputState == Enum.UserInputState.End then
		if inputObj.KeyCode == Settings.ClimbingButton then
			PlayerHelper.canClimb = false
		end
	end
end


return ActionHandler