local DEFAULT_LENGTH = 50
--default direction of a new composite
local DEFAULT_DIRECTION  = Vector3.new(1, 0, 0)

local module = {}

local BezierComposite = {}

BezierComposite.mt = {
	__index = BezierComposite
}

BezierComposite.Points = {}
BezierComposite.Length = 0

--[[
	Calculates the point, derivative, and second derivative along the Bezier Composite
	based on the input time value
	
	t domain: 0 <= t <= Length	
--]]
BezierComposite.Calculate = function(self, t)
	local length = self:UpdateLength()
	--Clamp that
	t = math.clamp(t, 0, length)	
	
	--First find the Curve that the point calculated by t will be found in	
	local p1Index = 3*math.floor(t)+1
	if t == length then
		p1Index = p1Index - 3
	end
	local p1 = self.Points[p1Index]
	local p2 = self.Points[p1Index+1]
	local p3 = self.Points[p1Index+2]
	local p4 = self.Points[p1Index+3]
	
	--time relative to the current curve
	local t2 = 	t % 1
	if t == length then t2 = t2 + 1 end
	local u2 = 1-t2
	--[[
	----do them calculations
	local pos = math.pow(u2,3)*p1 + 3*math.pow(u2,2)*t2*p2 + 3*u2*math.pow(t2,2)*p3 + math.pow(t2,3)*p4
	local deriv = 3*math.pow(u2,2)*(p2-p1) + 6*u2*t2*(p3-p2) + 3*math.pow(t2,2)*(p4-p3)
	local deriv2 = 6*u2*(p3-2*p2+p1) + 6*t2*(p4-2*p3+p2)
	return pos, deriv.unit, deriv2.unit
	--]]
	----[[
	local a, b = p1:lerp(p2, t2):lerp(p2:lerp(p3, t2), t2), p2:lerp(p3, t2):lerp(p3:lerp(p4, t2), t2)
	return a:lerp(b, t2), (b - a).unit
	--]]
end

--[[
	Calculates the point and derivative along the Bezier Composite
	based on the input time value. Assures that it is uniform.
	
	t domain: 0 <= t <= 1	
--]]
BezierComposite.CalculateUniform = function(self, t)
	t = math.clamp(t, 0, 1)
	local T, near = t * self.length, 0;
	for _, n in next, self.sums do
		if (T - n) < 0 then break end
		near = n
	end
	local set = self.ranges[near]
	local percent = (T - near)/set[1]
	return set[2]:lerp(set[3], percent), (set[3] - set[2]).unit
end

--[[
	Calculates and returns the distances and sum of distances of each 
	adjacent pair of points within the bezier passed as an argument
--]]
function length(bez)
	local sum, ranges, sums = 0, {}, {}
	local n = #bez.Points
	for i = 0, n-1 do
		-- Calculate the current point and the next point
		local p1 = bez:Calculate((i/n)*bez.Length)
		local p2 = bez:Calculate(((i+1)/n)*bez.Length)
		-- Get the distance between them
		local dist = (p2 - p1).magnitude
		-- Store the information we gathered in a table that's indexed by the current distance
		ranges[sum] = {dist, p1, p2}
		-- Store the current sum so we can easily sort through it later
		sums[#sums + 1] = sum
		-- Update the sum
		sum = sum + dist
	end
	return sum, ranges, sums
end

--[[
	Updates the BezierComposite's sum, ranges, and sums values
--]]
BezierComposite.UpdateSums = function(self)
	local sum, ranges, sums = length(self)
	self.length = sum
	self.ranges = ranges
	self.sums = sums
end

--[[
	Calculates the length of the Composite by the number of curves in it
	Throws an error if there's in invalid nmber of points in the line
--]]
BezierComposite.UpdateLength = function(self)
	self.Length = (#self.Points - 1)/3
	if (self.Length % 1 ~= 0) then
		error("Invalid number of points in Bezier Composite: "..#(self.Points))
	end
	return self.Length
end

--[[
	Adds a new curve to the end of the composite
--]]
BezierComposite.Extend = function(self)
	local prevLast = #self.Points --the index of the previously last point
	local lastPos, lastDeriv = self:Calculate(self:UpdateLength())
	lastPos = self.Points[prevLast]
	--self.Points[prevLast+1] = 2*self.Points[prevLast-1] - lastPos
	self.Points[prevLast+1] = 2*lastPos - self.Points[prevLast-1]
	self.Points[prevLast+2] = self.Points[prevLast+1] + (1/3)*lastDeriv*DEFAULT_LENGTH
	
	self.Points[prevLast+3] = self.Points[prevLast+1] + (2/3)*lastDeriv*DEFAULT_LENGTH
	self:UpdateLength()
	self:UpdateSums()
end

--[[
	Removes the last curve from the composite
--]]
BezierComposite.Shorten = function(self)
	--don't shorten if you can't shorten
	if self:UpdateLength() <= 1 then return end
	
	local prevLast = #self.Points
	
	self.Points[prevLast] = nil
	self.Points[prevLast-1] = nil
	self.Points[prevLast-2] = nil
	collectgarbage("count")
	
	self:UpdateLength()
	self:UpdateSums()
end

--[[
	Moves a point in the composite and updates any dependent adjacent points
	
	Params:
		pointNo	- The index of the point to be repositioned
		newPos - The new position of the point
--]]
BezierComposite.MovePoint = function(self, pointNo, newPos, allowContinuity)
	
	local oldPos = self.Points[pointNo]
		
	self.Points[pointNo] = newPos	
	
	--Figure out what kind of point it was
	if ((pointNo-1)%3 == 0) then --if it's a tangent point
		--change the pos of the left and right cps
		local lPoint = self.Points[pointNo-1]
		local rPoint = self.Points[pointNo+1]		
		
		if lPoint then --Move left point, if there is one
			self.Points[pointNo-1] = newPos + (lPoint - oldPos)
		end
		
		if rPoint then --move right point, if there is one
			self.Points[pointNo+1] = newPos + (rPoint - oldPos)
		end
	elseif (((pointNo-1)%3 == 1) and (self.Points[pointNo-2])) and allowContinuity then --if it's a left tangent point and there exists a previous right tangent point
		self.Points[pointNo-2] = 2*self.Points[pointNo-1] - newPos
	elseif (((pointNo-1)%3 == 2) and (self.Points[pointNo+2])) and allowContinuity then --if it's a right tangent point and there exists a next left tangent point
		self.Points[pointNo+2] = 2*self.Points[pointNo+1] - newPos
	end
	
	self:UpdateSums()
end

--[[
	Returns the string form of a composite to be loaded elsewhere
--]]
BezierComposite.ToString = function(self)
	local toReturn = ""
	for _, v in ipairs(self.Points) do
		toReturn = toReturn.."("..v.X..","..v.Y..","..v.Z..") "
	end
	return toReturn
end

--[[
	Parses the input string and tries to convert it into a composite
	Params:
		str - The String form of a composite
		
	NOTE: This function can throw an error, so make sure you make a pcall when handling this
--]]
BezierComposite.LoadFromString = function(str)
	local bez, i = BezierComposite.New(), 1
	for v in str:gmatch("%S+") do
		local components = {}
		for w in v:gmatch("(%-?%d*%.?%d+)") do
			components[#components + 1] = tonumber(w)
		end
		bez.Points[i] = Vector3.new(components[1], components[2], components[3])
		i = i + 1
	end
	bez:UpdateLength()
	bez:UpdateSums()
	return bez
end

--[[
	Creates a new composite
	Params:
		newPos - The new position of the first control point
--]]
BezierComposite.New = function(newPos, dir)
	local o = {}
	newPos = newPos or Vector3.new()
	dir = dir or DEFAULT_DIRECTION
	setmetatable(o, BezierComposite.mt)
	local compositeVector = dir * DEFAULT_LENGTH
	o.Points = {newPos,
		(1/3) * compositeVector + newPos,
		(2/3) * compositeVector + newPos,
	compositeVector + newPos}
	o:UpdateSums()
	return o
end

module.DEFAULT_LENGTH = DEFAULT_LENGTH
module.DEFAULT_DIRECTION = DEFAULT_DIRECTION
module.BezierComposite = BezierComposite

return module
