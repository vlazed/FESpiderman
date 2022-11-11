local Vector = {}

local ZERO = 1e-6

Vector.UP_VECTOR = Vector3.new(0, 1, 0) 
Vector.XZ_VECTOR = Vector3.new(1, 0, 1)
Vector.INCREASE_VECTOR = 6*Vector.UP_VECTOR + 10*Vector.XZ_VECTOR
Vector.DECREASE_VECTOR = 30*Vector.UP_VECTOR + 30*Vector.XZ_VECTOR 
Vector.UP_CF = CFrame.new(Vector.UP_VECTOR)
Vector.DOWN_CF = CFrame.new(-Vector.UP_VECTOR)


function Vector.getVectorPairCos(v1, v2)
	if typeof(v1) == "Vector3" and typeof(v2) == "Vector3" then
		return v1:Dot(v2)/(v1.Magnitude)/(v2.Magnitude)
	end
end


-- Rodrigues' Rotation Formula
function Vector.rotateVectorAlongAxis(vector, angle, axisVector)
	local v = math.cos(angle)*vector
	local exv = math.sin(angle)*axisVector:Cross(vector)
	local e = (1 - math.cos(angle))*(vector:Dot(axisVector))*axisVector

	return v + exv + e
end


function Vector.isPosOrNeg(vector)
	if (vector.X > 0 and vector.Z > 0) or vector.Y > 0 then
		return 1
	elseif vector.Magnitude < ZERO then
		return 0
	else
		return -1
	end
end


function Vector.bool_to_number(value)
    return value and 1 or 0
end


function Vector.mapToRange(val, in_min, in_max, out_min, out_max)
	return (val - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end


return Vector
