-- LocalScript untuk Report System GUI
-- Letakkan di StarterPlayer > StarterPlayerScripts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- Wait for RemoteEvents
local ReportEvent = ReplicatedStorage:WaitForChild("ReportEvent")
local AntiSpamEvent = ReplicatedStorage:WaitForChild("AntiSpamEvent")

-- ==================== GUI CONFIGURATION ====================
local GUI_CONFIG = {
	COLORS = {
		PRIMARY = Color3.fromRGB(64, 128, 255),     -- Blue
		SUCCESS = Color3.fromRGB(76, 175, 80),      -- Green  
		WARNING = Color3.fromRGB(255, 193, 7),      -- Yellow
		DANGER = Color3.fromRGB(244, 67, 54),       -- Red
		DARK = Color3.fromRGB(33, 37, 41),          -- Dark Gray
		LIGHT = Color3.fromRGB(248, 249, 250),      -- Light Gray
		TEXT = Color3.fromRGB(255, 255, 255),       -- White
		TEXT_SECONDARY = Color3.fromRGB(173, 181, 189), -- Light Gray
	},
	
	ANIMATIONS = {
		DURATION = 0.3,
		EASING = Enum.EasingStyle.Quart,
		DIRECTION = Enum.EasingDirection.Out,
	}
}

-- ==================== NOTIFICATION SYSTEM ====================

local notificationContainer = Instance.new("ScreenGui")
notificationContainer.Name = "ReportNotifications"
notificationContainer.Parent = PlayerGui
notificationContainer.ResetOnSpawn = false
notificationContainer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local notificationQueue = {}
local isShowingNotification = false

-- Create notification
local function createNotification(message, notificationType, duration)
	duration = duration or 3
	
	local notification = Instance.new("Frame")
	notification.Size = UDim2.new(0, 350, 0, 80)
	notification.Position = UDim2.new(1, 20, 0, 100) -- Start off-screen
	notification.BackgroundColor3 = GUI_CONFIG.COLORS[notificationType] or GUI_CONFIG.COLORS.PRIMARY
	notification.BorderSizePixel = 0
	notification.Parent = notificationContainer
	
	-- Corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = notification
	
	-- Drop shadow
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 20, 1, 20)
	shadow.Position = UDim2.new(0, -10, 0, -10)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxasset://textures/ui/InGameMenu/Shadow.png"
	shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	shadow.ImageTransparency = 0.5
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 118, 118)
	shadow.ZIndex = notification.ZIndex - 1
	shadow.Parent = notification
	
	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 30, 0, 30)
	icon.Position = UDim2.new(0, 15, 0, 25)
	icon.BackgroundTransparency = 1
	icon.Text = notificationType == "SUCCESS" and "✓" or notificationType == "DANGER" and "⚠" or "ℹ"
	icon.TextColor3 = GUI_CONFIG.COLORS.TEXT
	icon.TextSize = 18
	icon.Font = Enum.Font.GothamBold
	icon.Parent = notification
	
	-- Message text
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -60, 1, -20)
	textLabel.Position = UDim2.new(0, 55, 0, 10)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = message
	textLabel.TextColor3 = GUI_CONFIG.COLORS.TEXT
	textLabel.TextSize = 14
	textLabel.Font = Enum.Font.Gotham
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.Parent = notification
	
	-- Animate in
	local tweenIn = TweenService:Create(notification, 
		TweenInfo.new(GUI_CONFIG.ANIMATIONS.DURATION, GUI_CONFIG.ANIMATIONS.EASING, GUI_CONFIG.ANIMATIONS.DIRECTION),
		{Position = UDim2.new(1, -370, 0, 100)}
	)
	
	-- Animate out function
	local function animateOut()
		local tweenOut = TweenService:Create(notification,
			TweenInfo.new(GUI_CONFIG.ANIMATIONS.DURATION, GUI_CONFIG.ANIMATIONS.EASING, Enum.EasingDirection.In),
			{Position = UDim2.new(1, 20, 0, 100)}
		)
		
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			notification:Destroy()
			isShowingNotification = false
			
			-- Show next notification in queue
			if #notificationQueue > 0 then
				local next = table.remove(notificationQueue, 1)
				task.spawn(function()
					createNotification(next.message, next.type, next.duration)
				end)
			end
		end)
	end
	
	tweenIn:Play()
	isShowingNotification = true
	
	-- Auto-hide after duration
	task.spawn(function()
		task.wait(duration)
		if notification.Parent then
			animateOut()
		end
	end)
end

-- Show notification with queue system
local function showNotification(message, notificationType, duration)
	if isShowingNotification then
		table.insert(notificationQueue, {
			message = message,
			type = notificationType,
			duration = duration
		})
	else
		createNotification(message, notificationType, duration)
	end
end

-- ==================== COOLDOWN DISPLAY ====================

local cooldownGui = Instance.new("ScreenGui")
cooldownGui.Name = "ReportCooldown"
cooldownGui.Parent = PlayerGui
cooldownGui.ResetOnSpawn = false

local cooldownFrame = Instance.new("Frame")
cooldownFrame.Size = UDim2.new(0, 200, 0, 50)
cooldownFrame.Position = UDim2.new(0.5, -100, 0, 120)
cooldownFrame.BackgroundColor3 = GUI_CONFIG.COLORS.WARNING
cooldownFrame.Visible = false
cooldownFrame.Parent = cooldownGui

-- Style cooldown frame
local cooldownCorner = Instance.new("UICorner")
cooldownCorner.CornerRadius = UDim.new(0, 8)
cooldownCorner.Parent = cooldownFrame

local cooldownLabel = Instance.new("TextLabel")
cooldownLabel.Size = UDim2.new(1, -20, 1, -10)
cooldownLabel.Position = UDim2.new(0, 10, 0, 5)
cooldownLabel.BackgroundTransparency = 1
cooldownLabel.TextColor3 = GUI_CONFIG.COLORS.TEXT
cooldownLabel.Font = Enum.Font.GothamBold
cooldownLabel.TextScaled = true
cooldownLabel.TextWrapped = true
cooldownLabel.Text = ""
cooldownLabel.Parent = cooldownFrame

local cooldownConnection = nil

local function showCooldownTimer(remainingTime, message)
	if cooldownConnection then
		cooldownConnection:Disconnect()
		cooldownConnection = nil
	end
	
	cooldownFrame.Visible = true
	
	cooldownConnection = RunService.Heartbeat:Connect(function(dt)
		remainingTime = remainingTime - dt
		
		if remainingTime <= 0 then
			cooldownFrame.Visible = false
			if cooldownConnection then
				cooldownConnection:Disconnect()
				cooldownConnection = nil
			end
		else
			cooldownLabel.Text = string.format("%s\n⏱️ %d detik", message, math.ceil(remainingTime))
		end
	end)
end

-- ==================== MAIN REPORT GUI ====================

local reportGui = Instance.new("ScreenGui")
reportGui.Name = "ReportSystem"
reportGui.Parent = PlayerGui
reportGui.ResetOnSpawn = false

-- Main report button
local reportButton = Instance.new("TextButton")
reportButton.Size = UDim2.new(0, 120, 0, 40)
reportButton.Position = UDim2.new(0, 20, 0, 150)
reportButton.Text = "📢 Report"
reportButton.TextSize = 16
reportButton.Font = Enum.Font.GothamBold
reportButton.BackgroundColor3 = GUI_CONFIG.COLORS.PRIMARY
reportButton.TextColor3 = GUI_CONFIG.COLORS.TEXT
reportButton.BorderSizePixel = 0
reportButton.Parent = reportGui

-- Style main button
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = reportButton

-- Button hover effect
reportButton.MouseEnter:Connect(function()
	local tween = TweenService:Create(reportButton,
		TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{BackgroundColor3 = GUI_CONFIG.COLORS.PRIMARY:lerp(Color3.new(1, 1, 1), 0.1)}
	)
	tween:Play()
end)

reportButton.MouseLeave:Connect(function()
	local tween = TweenService:Create(reportButton,
		TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{BackgroundColor3 = GUI_CONFIG.COLORS.PRIMARY}
	)
	tween:Play()
end)

-- ==================== REPORT TYPE SELECTION ====================

local selectionFrame = Instance.new("Frame")
selectionFrame.Size = UDim2.new(0, 280, 0, 160)
selectionFrame.Position = UDim2.new(0.5, -140, 0.5, -80)
selectionFrame.BackgroundColor3 = GUI_CONFIG.COLORS.DARK
selectionFrame.BorderSizePixel = 0
selectionFrame.Visible = false
selectionFrame.Parent = reportGui

-- Style selection frame
local selectionCorner = Instance.new("UICorner")
selectionCorner.CornerRadius = UDim.new(0, 12)
selectionCorner.Parent = selectionFrame

local selectionStroke = Instance.new("UIStroke")
selectionStroke.Thickness = 2
selectionStroke.Color = GUI_CONFIG.COLORS.PRIMARY
selectionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
selectionStroke.Parent = selectionFrame

-- Title
local selectionTitle = Instance.new("TextLabel")
selectionTitle.Size = UDim2.new(1, -50, 0, 35)
selectionTitle.Position = UDim2.new(0, 10, 0, 10)
selectionTitle.BackgroundTransparency = 1
selectionTitle.Text = "📢 Pilih Jenis Report"
selectionTitle.TextColor3 = GUI_CONFIG.COLORS.TEXT
selectionTitle.TextSize = 18
selectionTitle.Font = Enum.Font.GothamBold
selectionTitle.TextXAlignment = Enum.TextXAlignment.Left
selectionTitle.Parent = selectionFrame

-- Close button
local selectionClose = Instance.new("TextButton")
selectionClose.Size = UDim2.new(0, 30, 0, 30)
selectionClose.Position = UDim2.new(1, -40, 0, 10)
selectionClose.Text = "×"
selectionClose.TextSize = 20
selectionClose.Font = Enum.Font.GothamBold
selectionClose.BackgroundColor3 = GUI_CONFIG.COLORS.DANGER
selectionClose.TextColor3 = GUI_CONFIG.COLORS.TEXT
selectionClose.BorderSizePixel = 0
selectionClose.Parent = selectionFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = selectionClose

-- Bug report button
local bugButton = Instance.new("TextButton")
bugButton.Size = UDim2.new(1, -20, 0, 45)
bugButton.Position = UDim2.new(0, 10, 0, 55)
bugButton.Text = "🐛 Report Bug/Map Issue"
bugButton.TextSize = 16
bugButton.Font = Enum.Font.Gotham
bugButton.BackgroundColor3 = GUI_CONFIG.COLORS.WARNING
bugButton.TextColor3 = Color3.fromRGB(0, 0, 0)
bugButton.BorderSizePixel = 0
bugButton.Parent = selectionFrame

local bugCorner = Instance.new("UICorner")
bugCorner.CornerRadius = UDim.new(0, 8)
bugCorner.Parent = bugButton

-- Player report button
local playerButton = Instance.new("TextButton")
playerButton.Size = UDim2.new(1, -20, 0, 45)
playerButton.Position = UDim2.new(0, 10, 0, 105)
playerButton.Text = "⚠️ Report Player"
playerButton.TextSize = 16
playerButton.Font = Enum.Font.Gotham
playerButton.BackgroundColor3 = GUI_CONFIG.COLORS.DANGER
playerButton.TextColor3 = GUI_CONFIG.COLORS.TEXT
playerButton.BorderSizePixel = 0
playerButton.Parent = selectionFrame

local playerCorner = Instance.new("UICorner")
playerCorner.CornerRadius = UDim.new(0, 8)
playerCorner.Parent = playerButton

-- ==================== BUG REPORT FRAME ====================

local bugFrame = Instance.new("Frame")
bugFrame.Size = UDim2.new(0, 400, 0, 280)
bugFrame.Position = UDim2.new(0.5, -200, 0.5, -140)
bugFrame.BackgroundColor3 = GUI_CONFIG.COLORS.DARK
bugFrame.BorderSizePixel = 0
bugFrame.Visible = false
bugFrame.Parent = reportGui

-- Style bug frame
local bugFrameCorner = Instance.new("UICorner")
bugFrameCorner.CornerRadius = UDim.new(0, 12)
bugFrameCorner.Parent = bugFrame

local bugFrameStroke = Instance.new("UIStroke")
bugFrameStroke.Thickness = 2
bugFrameStroke.Color = GUI_CONFIG.COLORS.WARNING
bugFrameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bugFrameStroke.Parent = bugFrame

-- Bug report components
local bugTitle = Instance.new("TextLabel")
bugTitle.Size = UDim2.new(1, -50, 0, 35)
bugTitle.Position = UDim2.new(0, 10, 0, 10)
bugTitle.BackgroundTransparency = 1
bugTitle.Text = "🐛 Report Bug/Map Issue"
bugTitle.TextColor3 = GUI_CONFIG.COLORS.TEXT
bugTitle.TextSize = 18
bugTitle.Font = Enum.Font.GothamBold
bugTitle.TextXAlignment = Enum.TextXAlignment.Left
bugTitle.Parent = bugFrame

local bugClose = Instance.new("TextButton")
bugClose.Size = UDim2.new(0, 30, 0, 30)
bugClose.Position = UDim2.new(1, -40, 0, 10)
bugClose.Text = "×"
bugClose.TextSize = 20
bugClose.Font = Enum.Font.GothamBold
bugClose.BackgroundColor3 = GUI_CONFIG.COLORS.DANGER
bugClose.TextColor3 = GUI_CONFIG.COLORS.TEXT
bugClose.BorderSizePixel = 0
bugClose.Parent = bugFrame

local bugCloseCorner = Instance.new("UICorner")
bugCloseCorner.CornerRadius = UDim.new(0, 6)
bugCloseCorner.Parent = bugClose

-- Bug description input
local bugInput = Instance.new("TextBox")
bugInput.Size = UDim2.new(1, -20, 0, 120)
bugInput.Position = UDim2.new(0, 10, 0, 60)
bugInput.PlaceholderText = "Jelaskan bug yang Anda temukan secara detail...\n\nContoh: Player bisa tembus tembok di area spawn"
bugInput.Text = ""
bugInput.TextSize = 14
bugInput.Font = Enum.Font.Gotham
bugInput.BackgroundColor3 = GUI_CONFIG.COLORS.LIGHT:lerp(GUI_CONFIG.COLORS.DARK, 0.8)
bugInput.TextColor3 = GUI_CONFIG.COLORS.TEXT
bugInput.BorderSizePixel = 0
bugInput.TextWrapped = true
bugInput.TextXAlignment = Enum.TextXAlignment.Left
bugInput.TextYAlignment = Enum.TextYAlignment.Top
bugInput.ClearTextOnFocus = false
bugInput.MultiLine = true
bugInput.Parent = bugFrame

local bugInputCorner = Instance.new("UICorner")
bugInputCorner.CornerRadius = UDim.new(0, 8)
bugInputCorner.Parent = bugInput

-- Character counter for bug input
local bugCounter = Instance.new("TextLabel")
bugCounter.Size = UDim2.new(0, 80, 0, 20)
bugCounter.Position = UDim2.new(1, -90, 0, 185)
bugCounter.BackgroundTransparency = 1
bugCounter.Text = "0/1000"
bugCounter.TextColor3 = GUI_CONFIG.COLORS.TEXT_SECONDARY
bugCounter.TextSize = 12
bugCounter.Font = Enum.Font.Gotham
bugCounter.TextXAlignment = Enum.TextXAlignment.Right
bugCounter.Parent = bugFrame

-- Bug send button
local bugSend = Instance.new("TextButton")
bugSend.Size = UDim2.new(1, -20, 0, 45)
bugSend.Position = UDim2.new(0, 10, 0, 220)
bugSend.Text = "📤 Kirim Bug Report"
bugSend.TextSize = 16
bugSend.Font = Enum.Font.GothamBold
bugSend.BackgroundColor3 = GUI_CONFIG.COLORS.SUCCESS
bugSend.TextColor3 = GUI_CONFIG.COLORS.TEXT
bugSend.BorderSizePixel = 0
bugSend.Parent = bugFrame

local bugSendCorner = Instance.new("UICorner")
bugSendCorner.CornerRadius = UDim.new(0, 8)
bugSendCorner.Parent = bugSend

-- ==================== PLAYER REPORT FRAME ====================

local playerFrame = Instance.new("Frame")
playerFrame.Size = UDim2.new(0, 400, 0, 350)
playerFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
playerFrame.BackgroundColor3 = GUI_CONFIG.COLORS.DARK
playerFrame.BorderSizePixel = 0
playerFrame.Visible = false
playerFrame.Parent = reportGui

-- Style player frame  
local playerFrameCorner = Instance.new("UICorner")
playerFrameCorner.CornerRadius = UDim.new(0, 12)
playerFrameCorner.Parent = playerFrame

local playerFrameStroke = Instance.new("UIStroke")
playerFrameStroke.Thickness = 2
playerFrameStroke.Color = GUI_CONFIG.COLORS.DANGER
playerFrameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
playerFrameStroke.Parent = playerFrame

-- Player report components
local playerTitle = Instance.new("TextLabel")
playerTitle.Size = UDim2.new(1, -50, 0, 35)
playerTitle.Position = UDim2.new(0, 10, 0, 10)
playerTitle.BackgroundTransparency = 1
playerTitle.Text = "⚠️ Report Player"
playerTitle.TextColor3 = GUI_CONFIG.COLORS.TEXT
playerTitle.TextSize = 18
playerTitle.Font = Enum.Font.GothamBold
playerTitle.TextXAlignment = Enum.TextXAlignment.Left
playerTitle.Parent = playerFrame

local playerClose = Instance.new("TextButton")
playerClose.Size = UDim2.new(0, 30, 0, 30)
playerClose.Position = UDim2.new(1, -40, 0, 10)
playerClose.Text = "×"
playerClose.TextSize = 20
playerClose.Font = Enum.Font.GothamBold
playerClose.BackgroundColor3 = GUI_CONFIG.COLORS.DANGER
playerClose.TextColor3 = GUI_CONFIG.COLORS.TEXT
playerClose.BorderSizePixel = 0
playerClose.Parent = playerFrame

local playerCloseCorner = Instance.new("UICorner")
playerCloseCorner.CornerRadius = UDim.new(0, 6)
playerCloseCorner.Parent = playerClose

-- Target player input
local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(1, -20, 0, 20)
targetLabel.Position = UDim2.new(0, 10, 0, 55)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "👤 Nama Player yang Dilaporkan:"
targetLabel.TextColor3 = GUI_CONFIG.COLORS.TEXT
targetLabel.TextSize = 14
targetLabel.Font = Enum.Font.GothamBold
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.Parent = playerFrame

local targetInput = Instance.new("TextBox")
targetInput.Size = UDim2.new(1, -20, 0, 35)
targetInput.Position = UDim2.new(0, 10, 0, 80)
targetInput.PlaceholderText = "Masukkan username player..."
targetInput.Text = ""
targetInput.TextSize = 14
targetInput.Font = Enum.Font.Gotham
targetInput.BackgroundColor3 = GUI_CONFIG.COLORS.LIGHT:lerp(GUI_CONFIG.COLORS.DARK, 0.8)
targetInput.TextColor3 = GUI_CONFIG.COLORS.TEXT
targetInput.BorderSizePixel = 0
targetInput.Parent = playerFrame

local targetInputCorner = Instance.new("UICorner")
targetInputCorner.CornerRadius = UDim.new(0, 8)
targetInputCorner.Parent = targetInput

-- Reason input
local reasonLabel = Instance.new("TextLabel")
reasonLabel.Size = UDim2.new(1, -20, 0, 20)
reasonLabel.Position = UDim2.new(0, 10, 0, 125)
reasonLabel.BackgroundTransparency = 1
reasonLabel.Text = "📝 Alasan Report:"
reasonLabel.TextColor3 = GUI_CONFIG.COLORS.TEXT
reasonLabel.TextSize = 14
reasonLabel.Font = Enum.Font.GothamBold
reasonLabel.TextXAlignment = Enum.TextXAlignment.Left
reasonLabel.Parent = playerFrame

local reasonInput = Instance.new("TextBox")
reasonInput.Size = UDim2.new(1, -20, 0, 100)
reasonInput.Position = UDim2.new(0, 10, 0, 150)
reasonInput.PlaceholderText = "Jelaskan alasan report...\n\nContoh: Player menggunakan exploit/hack, toxic behavior, dll."
reasonInput.Text = ""
reasonInput.TextSize = 14
reasonInput.Font = Enum.Font.Gotham
reasonInput.BackgroundColor3 = GUI_CONFIG.COLORS.LIGHT:lerp(GUI_CONFIG.COLORS.DARK, 0.8)
reasonInput.TextColor3 = GUI_CONFIG.COLORS.TEXT
reasonInput.BorderSizePixel = 0
reasonInput.TextWrapped = true
reasonInput.TextXAlignment = Enum.TextXAlignment.Left
reasonInput.TextYAlignment = Enum.TextYAlignment.Top
reasonInput.ClearTextOnFocus = false
reasonInput.MultiLine = true
reasonInput.Parent = playerFrame

local reasonInputCorner = Instance.new("UICorner")
reasonInputCorner.CornerRadius = UDim.new(0, 8)
reasonInputCorner.Parent = reasonInput

-- Character counter for reason
local reasonCounter = Instance.new("TextLabel")
reasonCounter.Size = UDim2.new(0, 80, 0, 20)
reasonCounter.Position = UDim2.new(1, -90, 0, 255)
reasonCounter.BackgroundTransparency = 1
reasonCounter.Text = "0/1000"
reasonCounter.TextColor3 = GUI_CONFIG.COLORS.TEXT_SECONDARY
reasonCounter.TextSize = 12
reasonCounter.Font = Enum.Font.Gotham
reasonCounter.TextXAlignment = Enum.TextXAlignment.Right
reasonCounter.Parent = playerFrame

-- Player send button
local playerSend = Instance.new("TextButton")
playerSend.Size = UDim2.new(1, -20, 0, 45)
playerSend.Position = UDim2.new(0, 10, 0, 290)
playerSend.Text = "📤 Kirim Player Report"
playerSend.TextSize = 16
playerSend.Font = Enum.Font.GothamBold
playerSend.BackgroundColor3 = GUI_CONFIG.COLORS.SUCCESS
playerSend.TextColor3 = GUI_CONFIG.COLORS.TEXT
playerSend.BorderSizePixel = 0
playerSend.Parent = playerFrame

local playerSendCorner = Instance.new("UICorner")
playerSendCorner.CornerRadius = UDim.new(0, 8)
playerSendCorner.Parent = playerSend

-- ==================== EVENT HANDLERS ====================

-- Character counter updates
bugInput.Changed:Connect(function(property)
	if property == "Text" then
		local length = #bugInput.Text
		bugCounter.Text = string.format("%d/1000", length)
		
		if length > 1000 then
			bugCounter.TextColor3 = GUI_CONFIG.COLORS.DANGER
		else
			bugCounter.TextColor3 = GUI_CONFIG.COLORS.TEXT_SECONDARY
		end
	end
end)

reasonInput.Changed:Connect(function(property)
	if property == "Text" then
		local length = #reasonInput.Text
		reasonCounter.Text = string.format("%d/1000", length)
		
		if length > 1000 then
			reasonCounter.TextColor3 = GUI_CONFIG.COLORS.DANGER
		else
			reasonCounter.TextColor3 = GUI_CONFIG.COLORS.TEXT_SECONDARY
		end
	end
end)

-- Button click handlers
reportButton.MouseButton1Click:Connect(function()
	selectionFrame.Visible = not selectionFrame.Visible
end)

selectionClose.MouseButton1Click:Connect(function()
	selectionFrame.Visible = false
end)

bugButton.MouseButton1Click:Connect(function()
	selectionFrame.Visible = false
	bugFrame.Visible = true
end)

playerButton.MouseButton1Click:Connect(function()
	selectionFrame.Visible = false
	playerFrame.Visible = true
end)

bugClose.MouseButton1Click:Connect(function()
	bugFrame.Visible = false
	bugInput.Text = ""
end)

playerClose.MouseButton1Click:Connect(function()
	playerFrame.Visible = false
	targetInput.Text = ""
	reasonInput.Text = ""
end)

-- Report submission handlers
bugSend.MouseButton1Click:Connect(function()
	local description = bugInput.Text
	
	if #description < 10 then
		showNotification("Deskripsi bug terlalu pendek! (minimal 10 karakter)", "DANGER", 4)
		return
	end
	
	if #description > 1000 then
		showNotification("Deskripsi bug terlalu panjang! (maksimal 1000 karakter)", "DANGER", 4)
		return
	end
	
	-- Get player coordinates
	local coords = "Tidak diketahui"
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local pos = player.Character.HumanoidRootPart.Position
		coords = string.format("(%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z)
	end
	
	-- Get server info
	local serverId = game.JobId ~= "" and game.JobId or "Private/Solo"
	
	-- Send report
	ReportEvent:FireServer("bug", {
		Reporter = player.Name,
		ServerId = serverId,
		Coords = coords,
		Deskripsi = description
	})
	
	-- Close frame and clear input
	bugFrame.Visible = false
	bugInput.Text = ""
	
	showNotification("Bug report sedang diproses...", "PRIMARY", 3)
end)

playerSend.MouseButton1Click:Connect(function()
	local target = targetInput.Text
	local reason = reasonInput.Text
	
	if #target < 3 then
		showNotification("Nama player terlalu pendek! (minimal 3 karakter)", "DANGER", 4)
		return
	end
	
	if #reason < 10 then
		showNotification("Alasan report terlalu pendek! (minimal 10 karakter)", "DANGER", 4)
		return
	end
	
	if #reason > 1000 then
		showNotification("Alasan report terlalu panjang! (maksimal 1000 karakter)", "DANGER", 4)
		return
	end
	
	-- Get server info
	local serverId = game.JobId ~= "" and game.JobId or "Private/Solo"
	
	-- Send report
	ReportEvent:FireServer("player", {
		Reporter = player.Name,
		Target = target,
		Reason = reason,
		ServerId = serverId
	})
	
	-- Close frame and clear inputs
	playerFrame.Visible = false
	targetInput.Text = ""
	reasonInput.Text = ""
	
	showNotification("Player report sedang diproses...", "PRIMARY", 3)
end)

-- ==================== ANTI-SPAM RESPONSE HANDLER ====================

AntiSpamEvent.OnClientEvent:Connect(function(responseData)
	if not responseData or type(responseData) ~= "table" then
		return
	end
	
	local status = responseData.status
	local remaining = responseData.remaining or 0
	local message = responseData.message or "Unknown response"
	local spamCount = responseData.spamCount or 0
	local patternDetected = responseData.patternDetected or false
	
	if status == "throttled" then
		-- Show spam notification
		local spamMessage = string.format("⏱️ Cooldown aktif: %d detik", remaining)
		if patternDetected then
			spamMessage = spamMessage .. "\n🔄 Pattern spam terdeteksi!"
		end
		if spamCount >= 3 then
			spamMessage = spamMessage .. "\n⚠️ Aktivitas mencurigakan dicatat"
		end
		
		showNotification(spamMessage, "DANGER", 5)
		showCooldownTimer(remaining, "🚫 Tidak dapat mengirim report")
		
	elseif status == "success" then
		-- Show success notification
		showNotification("✅ Report berhasil dikirim ke Discord!", "SUCCESS", 4)
		
	elseif status == "error" then
		-- Show error notification
		showNotification("❌ Gagal mengirim report: " .. message, "DANGER", 5)
	end
end)

-- ==================== STARTUP ====================
print("[Report System Client] GUI loaded successfully!")