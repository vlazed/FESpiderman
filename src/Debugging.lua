local Debris = game:GetService("Debris")

local Debugging = {}

Debugging.DEBUG = false

function Debugging:print(...)
    if Debugging.DEBUG then
        self.print = print(...)
    end
end

function Debugging:makePartAt(pos, lifetime, size, color, lookVector)
	if not Debugging.DEBUG then return end

	size = size or Vector3.new(1, 1, 1)
	lookVector = lookVector or Vector3.new()
	color = color or Color3.new(1, 0, 0)
	lifetime = lifetime or 10

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Size = size
	part.CFrame = CFrame.lookAt(pos, pos+lookVector) * CFrame.new(0,0,-part.Size.Z/2)

	part.Parent = workspace

	Debris:AddItem(part, lifetime)
end


return Debugging