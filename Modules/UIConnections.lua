local module = {}

--[[	
	makes all the button connections and returns a list of the ocnnections
--]]
function makeConnections(UIModel)
	local connections = {}
	local ui = UIModel.Scale
	local mainUI = ui.SBezier
	local helpUI = ui.SBezierHelp
	local infoPage = helpUI.InfoPage
	
	local mainButtons = mainUI.Buttons
	local helpButtons = helpUI.Buttons
	
	local saveButton = mainButtons.Save
	local helpButton = mainButtons.Help
	
	local bezierName = ui.BezierName
	local confirm = ui.Confirm
	local checkButton = ui.CheckButton
	
	local infoButton = helpButtons.PluginfoTab
	local instrucButton = helpButtons.InstructionsTab
	local docButton = helpButtons.DocumentationTab
	local buttons = {infoButton, instrucButton, docButton}
	local views = {infoPage.PluginfoPage, infoPage.InstructionsPage, infoPage.DocPage}
	
	local injectButton = views[2].ScrollingFrame.AvoidScrollbar.Step1.InjectButton
	
	--[[
		Prints the private module ID for the user to copy and paste into his/her script(s)
	--]]
	connections[#connections + 1] = injectButton.MouseButton1Click:Connect(function()
		script.Parent.Bezier2:Clone().Parent = game:GetService("ServerScriptService")
	end)
	
	local function makeInvisible(v, waitTime)
		local newSize = UDim2.new(0.01, 0, 0.01, 0)
		v.Size = newSize
		local xCenter, yCenter = -v.AbsoluteSize.X/2, -v.AbsoluteSize.Y/2
		v.Size = UDim2.new(1, 0, 1, 0)
		v:TweenSizeAndPosition(newSize, 
			UDim2.new(0.5, xCenter, 0.5, yCenter), 
			"Out", "Quad", waitTime, true)
		delay(waitTime, function() v.Visible = false end)
	end
	
	--[[
		make the help button toggle hlelp visibility
	--]]
	connections[#connections + 1] = helpButton.MouseButton1Click:Connect(function()
		helpUI.Active = not helpUI.Active
		
		if helpUI.Active then
			helpUI:TweenPosition(UDim2.new(1.05, 0, 0, 0), "Out", "Quad", 0.25, true)
		else
			helpUI:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.5, true)
			for _, v in pairs(views) do
				if v.Visible then
					makeInvisible(v, 0.5)
				end
			end
		end
	end)
		
	for i, v in pairs(buttons) do 
		connections[#connections + 1] = v.MouseButton1Click:connect(function()
			if views[i].Active then
				views[i].Active = false
				if views[i].Visible then
					makeInvisible(views[i], 0.25)
				else
					for _, w in pairs(views) do
						makeInvisible(w, 0.25)
					end
					delay(0.25, function() 
						views[i].Visible = true
						views[i]:TweenSizeAndPosition(UDim2.new(1, 0, 1, 0), 
							UDim2.new(0, 0, 0, 0), 
							"Out", "Quad", 0.25, true)
					end)
				end
				wait(0.26)
				views[i].Active = true
			end
		end)
	end
	
	connections[#connections + 1] = saveButton.MouseButton1Click:Connect(function()
		bezierName.Visible = not bezierName.Visible
		confirm.Visible = not confirm.Visible
	end)
	
	connections[#connections + 1] = checkButton.MouseButton1Click:Connect(function()
		if checkButton.Text == "" then
			checkButton.Text = "✓"
		else
			checkButton.Text = ""
		end
	end)
	
	return connections
end

module.makeConnections = makeConnections
return module