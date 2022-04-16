--print("Loading SBezier")

--distance from the camera
local NEW_COMPOSITE_DISTANCE = Vector3.new(0,-5, 0)

--how many things to indicate the shape of the curve, per curve
local DOTS_PER_CURVE = 30

local pluginFolder = script.Parent
local arrowSample = pluginFolder.ArrowSample
local sphereSample = pluginFolder.SphereSample
local connectorSample = pluginFolder.ConnectorSample

local pluginOn = false --whether to turn on plugin

local mouse = nil

local toolbar = plugin:CreateToolbar("SBezier")
local bezButton = toolbar:CreateButton("Bezier Editor", "Click to Toggle Bezier editing mode", "rbxassetid://2547722877")

local handles = script.Parent:WaitForChild("BezierHandles")

local bezUI = pluginFolder.SBezUI
local uiClone = bezUI:Clone()
local uiButtons = uiClone.Scale.SBezier.Buttons

local bezierName = uiClone.Scale.BezierName
local confirmButton = uiClone.Scale.Confirm

-- Buttons
local newButton = uiButtons.New
local extendButton = uiButtons.Extend
local shortenButton = uiButtons.Shorten
local saveButton = uiButtons.Save
local loadButton = uiButtons.Load
local allowContinuity = uiClone.Scale.CheckButton

local bezierModule = require(pluginFolder.Modules.Bezier2)
local uiConnector = require(pluginFolder.Modules.UIConnections)

local selectedBezier = nil 		--the seleected bezier
local bezRender = nil 			--the model of the selected bezier
local startingPosition = nil	-- the starting position of a selected control point
local selectedPoint = nil --the cpMarker that is currently selected

local activeHandle = -1

--getting the selection service
local selectionService = game:GetService("Selection")

------------------------------------------------------------------------------------------------
--[[
	Helper math funcs
--]]

--[[
	Floors toFloor to the greatest multiple of mult less than toFloor
	Params:
		toFloor - The number to floor
		mult - The factor to floor to
--]]
local function floorMultiple(toFloor, mult)
	return toFloor - (toFloor % mult)
end

local function cielMultiple(toCiel, mult)
	return floorMultiple(toCiel, mult) + mult
end
------------------------------------------------------------------------------------------------

--[[
	Clears the current render
--]]
local function clearRender()
	if bezRender then
		bezRender:Destroy()
		bezRender = nil
		collectgarbage("count")
	end
end

--[[
	deletes the previous bezier selection
--]]
local function clearSelection ()
	selectedBezier = nil
	clearRender()
end

--[[
	Determines whether a selected part is a control point marker
--]]
local function isControlPoint(part)
	--TODO: improve on this
	return (part.Parent.Name == "Control Points")
end

--[[
	creates the indicators for the bezier curve
--]]
local function createIndicators(bez, starting, ending, parent)
	local num = DOTS_PER_CURVE*starting
	for i = starting, ending, 1/DOTS_PER_CURVE do
		local curveDot = arrowSample:Clone()

		local pos, dir = bez:Calculate(i)			
			
		curveDot.CFrame = CFrame.new(pos, pos + dir * 1)
		curveDot.Name = num
		if parent:FindFirstChild(num) then
			parent:FindFirstChild(num):Destroy() 
		end
		curveDot.Parent = parent
		num = num + 1
	end
end

--[[
	updates the size and position a connector
--]]
local function updateConnector(connector, bezier)
	local cVal = connector:FindFirstChild("Control")
	local tVal = connector:FindFirstChild("Tangent")
	
	if (cVal and tVal) then
		local p1 = bezier.Points[cVal.Value]
		local p2 = bezier.Points[tVal.Value]
		
		local dist = p2-p1
		
		connector.Size = Vector3.new((p1-p2).magnitude, .5, .5)
		
		local pPreRotate = CFrame.new(p1, p2) * CFrame.new(Vector3.new(0,0,-dist.magnitude/2))
		connector.CFrame = pPreRotate * CFrame.fromAxisAngle(Vector3.new(0,1,0), math.pi/2)
	else
		error("Argument to updateConnector is not a valid parameter")
	end
	
end

--[[
	Updates all connectors in a folder
	Params:
		connectorFolder - The folder that holds connectors
--]]
local function updateConnectors(connectorFolder, bezier)
	for i,v in pairs(connectorFolder:GetChildren()) do
		local cPoint = v.Control.Value
		
		local point = bezier.Points[cPoint]
		if point then 
			updateConnector(v, bezier)
		end
	end
end

--[[
	creates an initial render of the composite
--]]
local function createBezRender(bez)
	local curveRenderModel = Instance.new("Model")
	curveRenderModel.Name = "Bezier Render"
	
	--making the curve indicators
	local arrowFolder = Instance.new("Folder")
	arrowFolder.Name = "Curve Indicators"
	createIndicators(bez, 0, bez:UpdateLength(), arrowFolder)
	
	--making control point markers
	local cpFolder = Instance.new("Folder")
	cpFolder.Name = "Control Points"	
	for i, v in ipairs(bez.Points) do
		local cpMarker = sphereSample:Clone()
		cpMarker.Name = i
		cpMarker.CFrame = CFrame.new(v)
		--if cp is a tangent point
		if ((i-1)%3 == 0) then
			cpMarker.Color = Color3.new(1, 1, 1)
		end
		cpMarker.Parent = cpFolder
		--[[
		local clicker = Instance.new("ClickDetector")
		clicker.Parent = cpMarker
		clicker.MouseClick:connect(function()
			for _, v in pairs(cpFolder:GetChildren()) do
				v:WaitForChild("ClickDetector").MaxActivationDistance = 32
			end
			clicker.MaxActivationDistance = 0
			handles.Adornee = cpMarker
			activeHandle = tonumber(cpMarker.Name)
		end)
		]]--
	end
	
	--folder for connecting tangent points with CPS
	local connectorFolder = Instance.new("Folder")
	connectorFolder.Name = "Connectors"
	for i, v in pairs(selectedBezier.Points) do
		if ((i-1)%3 ~= 0) then 
			--make a connector if it's a non-tangential CP
			local connector = connectorSample:Clone()						
			local cVal = connector.Control
			local tVal = connector.Tangent			
			--print(i)
			cVal.Value = i				
				
			--if it's a left tangent
			if ((i-1)%3 == 1) then
				tVal.Value = i-1
			else
				tVal.Value = i+1	
			end
			
			updateConnector(connector, bez)
			
			connector.Parent = connectorFolder
		end
	end
	
	arrowFolder.Parent = curveRenderModel
	cpFolder.Parent = curveRenderModel
	connectorFolder.Parent = curveRenderModel
	
	bezRender = curveRenderModel
	curveRenderModel.Archivable = false
	curveRenderModel.Parent = game.Workspace
	return curveRenderModel
end

--[[
	Displays a user error
	Params:
		errorMessage - A string that describes the error
--]]
local function displayError(errorMessage)
	print(errorMessage)
	--TODO: implement the UI for this
end

--[[
	changes the currently selected bezier
--]]
local function setSelectedBez (newSelect)
	clearSelection()
	selectedBezier = newSelect
	bezRender =  createBezRender(newSelect)
	bezRender.Parent = game.Workspace
end

--[[
	makes a new composite
--]]
local function newBez ()
	local lookVector = workspace.CurrentCamera.CFrame.lookVector
	setSelectedBez(bezierModule.BezierComposite.New(
		(workspace.CurrentCamera.CFrame * NEW_COMPOSITE_DISTANCE), 
		Vector3.new(lookVector.X, 0, lookVector.Z).unit))
	handles.Adornee = nil
end

local function reassignHandles()
	if bezRender and bezRender:FindFirstChild("Control Points") 
		and bezRender["Control Points"]:FindFirstChild(activeHandle) then
		handles.Adornee = bezRender["Control Points"]:FindFirstChild(activeHandle)
	else
		handles.Adornee = nil
		activeHandle = -1
	end
end

local function extendBez ()
	if (selectedBezier) then
		selectedBezier:Extend()
		clearRender()
		createBezRender(selectedBezier)
		reassignHandles()
	end
end

local function shortenBez ()
	if (selectedBezier) then
		selectedBezier:Shorten()
		clearRender()
		createBezRender(selectedBezier)
		reassignHandles()
	end
end

--[[
	Creates a StringValue that saves the string form of the selected Bezier
--]]
local function saveBez ()
	if not selectedBezier then return end
	if bezierName.Text == "" then return end
	-- Folder to organize all the bezier paths
	local bezFolder = workspace:FindFirstChild("Bezier Paths")
	if not bezFolder then
		bezFolder = Instance.new("Folder")
		bezFolder.Name = "Bezier Paths"
		bezFolder.Parent = workspace
	end
	local dataObj = bezFolder:FindFirstChild(bezierName.Text)
	if not dataObj then
		dataObj = Instance.new("StringValue")
		dataObj.Name = bezierName.Text
		dataObj.Parent = bezFolder
	end
	dataObj.Value = selectedBezier:ToString()
	selectionService:Set({dataObj})
	
	bezierName.Visible = false
	confirmButton.Visible = false
end

--[[
	Attempts to load the currently selected object as a Bezier Composite
	The current selection must be a single StringValue
--]]
local function loadBez ()
	--First make sure there is only one selected object and make sure it's a StringValue
	local selectedObjects = selectionService:Get()
	if (#selectedObjects == 1) then 
		local selection = selectedObjects[1]
		--make sure the selection is a StringValue
		if (selection:IsA("StringValue")) then
			--make a pcall to load, in case there was an error parsing the string
			local success, arg1 = pcall(function() return bezierModule.BezierComposite.LoadFromString(selection.Value) end)
			--if the pcall to load was successful
			if success then
				setSelectedBez(arg1)
			else
				displayError(arg1)
			end
		else
			displayError("Loading error: You must load from a StringValue object.")
		end
	else
		displayError("Loading error: Only one object can be selected when loading.")
	end
end



-------------------------------------------------------------------------------------
local onHandle = false
local function onMouseButton1Down()
	if not onHandle and handles.Adornee then
		if handles.Adornee:FindFirstChild("ClickDetector") then
			handles.Adornee.ClickDetector.MaxActivationDistance = 32
		end
		handles.Adornee = nil
	end
end

local function onHandleEnter(face)
	onHandle = true
end

local function onHandleLeave(face)
	onHandle = false
end

local function onHandleButton1Down(face)
	if not handles.Adornee then return end
	startingPosition = handles.Adornee.CFrame.p
end

local function onHandleButton1Up(face)
	startingPosition = nil
end

--[[
	updates the position of control point markers
--]]
local function updateControlPointMarkers(render, bez, from, to)
	local cpFolder = render["Control Points"]
	for j = from, to, 1 do
		local currentCp = cpFolder:FindFirstChild(tostring(j))
		currentCp.CFrame = CFrame.new(bez.Points[j])
	end
end


local function onHandleDrag(face, distance)
	local cp = handles.Adornee
	if not cp then return end
	local cpNum = tonumber(cp.Name)
	cp.CFrame = CFrame.new(startingPosition + Vector3.FromNormalId(face) * distance)
	
	selectedBezier:MovePoint(cpNum, cp.CFrame.p, allowContinuity.Text ~= "")
	
	local starting = math.max(1, floorMultiple(cpNum-3, 3)+1)
	local ending = math.min(selectedBezier:UpdateLength()*3+1, cielMultiple(cpNum + 1, 3)+1)
	
	--print(starting.." "..ending)
	
	--updating the position of affected control points
	if allowContinuity.Text ~= "" then
		updateControlPointMarkers(bezRender, selectedBezier, starting, ending)
	end
	starting = (starting - 1)/3
	ending = (ending - 1)/3
	createIndicators(selectedBezier, starting, ending, bezRender["Curve Indicators"])
	
	local connectorFolder = bezRender:FindFirstChild("Connectors")
	if connectorFolder then
		updateConnectors(connectorFolder, selectedBezier)
	end
end
-------------------------------------------------------------------------------------

local uiConnections = nil
local function activate ()
	if uiClone.Parent ~= game.CoreGui then
		uiClone.Parent = game.CoreGui
	else
		uiClone.Enabled = true	
	end
	if handles.Parent ~= game.CoreGui then
		handles.Parent = game.CoreGui
	end
	uiConnections = uiConnector.makeConnections(uiClone)
	uiConnections[#uiConnections + 1] = newButton.MouseButton1Click:Connect(newBez)
	uiConnections[#uiConnections + 1] = extendButton.MouseButton1Click:Connect(extendBez)
	uiConnections[#uiConnections + 1] = shortenButton.MouseButton1Click:Connect(shortenBez)
	uiConnections[#uiConnections + 1] = confirmButton.MouseButton1Click:Connect(saveBez)
	uiConnections[#uiConnections + 1] = loadButton.MouseButton1Click:Connect(loadBez)
	uiConnections[#uiConnections + 1] = mouse.Button1Down:Connect(onMouseButton1Down)
end

handles.MouseEnter:Connect(onHandleEnter)
handles.MouseLeave:Connect(onHandleLeave)
handles.MouseButton1Down:Connect(onHandleButton1Down)
handles.MouseButton1Up:Connect(onHandleButton1Up)
handles.MouseDrag:Connect(onHandleDrag)

--Turning plugin off
local function deactivate ()
	if uiClone.Parent == game.CoreGui then
		uiClone.Enabled = false
		handles.Adornee = nil
	end
	if handles.Parent == game.CoreGui then
		handles.Parent = script.Parent
	end
	if uiConnections then
		for i, v in pairs(uiConnections) do
			v:Disconnect()
		end	
	end
	clearSelection()
	uiConnections = nil
end
plugin.Deactivation:Connect(deactivate)

--[[
	When the plugin button is clicked
--]]
bezButton.Click:Connect(function()
	--print("Button clicked")
	if (not pluginOn) then
		--print("on")
		plugin:Activate(true)
		
		mouse = plugin:GetMouse()
		
		-- Determines whether the part is a clickable control point
		local function isValidControlPoint(part)
			return part and part.Parent:IsA("Folder") 
						and part.Parent.Name == "Control Points"
						and handles.Adornee ~= part 
		end
		
		-- Control point clickers
		mouse.Button1Up:connect(function()
			local mTarget = mouse.Target
			if isValidControlPoint(mTarget) then
				activeHandle = tonumber(mTarget.Name)
				handles.Adornee = mTarget
				mTarget.Transparency = 0
			end
		end)
		
		-- Hover effect over control points
		local mTarget = nil
		mouse.Move:connect(function()
			local mTargetNew = mouse.Target
			if mTarget and mTarget ~= mTargetNew then
				mTarget.Transparency = 0
			end
			if isValidControlPoint(mTargetNew) then
				mTarget = mTargetNew
				mTarget.Transparency = 0.75
			end	
		end)
		
		activate()
		pluginOn = true
	else
		--print("noff")
		deactivate()
		pluginOn = false
	end
end)

--print("Load complete")
