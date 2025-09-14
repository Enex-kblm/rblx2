-- ModuleScript untuk constants dan helper functions
-- Letakkan di ServerScriptService sebagai child dari ServerScript
-- HANYA untuk server-side, jangan letakkan di ReplicatedStorage!

local ReportConfig = {}

-- ==================== WEBHOOK CONFIGURATION ====================
-- GANTI URL WEBHOOK INI DENGAN WEBHOOK DISCORD ANDA!

-- Webhook untuk bug reports
ReportConfig.WEBHOOK_BUG = ""

-- Webhook untuk player reports  
ReportConfig.WEBHOOK_PLAYER = ""

-- Webhook untuk spam evidence (opsional, bisa sama dengan yang lain)
ReportConfig.WEBHOOK_SPAM = ""

-- ==================== SYSTEM CONSTANTS ====================

-- Rate limiting constants
ReportConfig.RATE_LIMITS = {
	NORMAL = 30,      -- 30 detik cooldown normal
	ELEVATED = 60,    -- 60 detik untuk spammer level 2
	HIGH = 90,        -- 90 detik untuk spammer level 3+
}

-- Spam detection constants
ReportConfig.SPAM_DETECTION = {
	SIMILARITY_THRESHOLD = 0.7,    -- 70% similarity untuk deteksi pattern
	EVIDENCE_THRESHOLD = 3,        -- Kirim evidence setelah 3 spam attempts
	MAX_HISTORY_SIZE = 50,         -- Maksimal 50 report disimpan per user
	PATTERN_CHECK_COUNT = 10,      -- Cek similarity dengan 10 report terakhir
}

-- Text processing constants
ReportConfig.TEXT_LIMITS = {
	MAX_LENGTH = 500,              -- Maksimal 500 karakter untuk webhook
	MAX_DESCRIPTION_LENGTH = 1000, -- Maksimal deskripsi bug/player report
	MIN_LENGTH = 3,                -- Minimal 3 karakter untuk report
}

-- Auto-moderation (opsional)
ReportConfig.AUTO_MODERATION = {
	ENABLED = false,               -- Set true untuk auto-kick
	KICK_THRESHOLD = 10,           -- Kick setelah 10 spam attempts
	WARNING_THRESHOLD = 5,         -- Warning setelah 5 spam attempts
}

-- ==================== HELPER FUNCTIONS ====================

-- Validasi input report
function ReportConfig.validateReportInput(reportType, reportInfo)
	if not reportType or type(reportType) ~= "string" then
		return false, "Invalid report type"
	end
	
	if not reportInfo or type(reportInfo) ~= "table" then
		return false, "Invalid report info"
	end
	
	if reportType == "bug" then
		local desc = reportInfo.Deskripsi or ""
		if #desc < ReportConfig.TEXT_LIMITS.MIN_LENGTH then
			return false, "Deskripsi bug terlalu pendek"
		end
		if #desc > ReportConfig.TEXT_LIMITS.MAX_DESCRIPTION_LENGTH then
			return false, "Deskripsi bug terlalu panjang"
		end
		
	elseif reportType == "player" then
		local target = reportInfo.Target or ""
		local reason = reportInfo.Reason or ""
		
		if #target < ReportConfig.TEXT_LIMITS.MIN_LENGTH then
			return false, "Nama target terlalu pendek"
		end
		if #reason < ReportConfig.TEXT_LIMITS.MIN_LENGTH then
			return false, "Alasan report terlalu pendek"
		end
		if #reason > ReportConfig.TEXT_LIMITS.MAX_DESCRIPTION_LENGTH then
			return false, "Alasan report terlalu panjang"
		end
	else
		return false, "Unknown report type"
	end
	
	return true, "Valid"
end

-- Sanitasi teks untuk Discord embed
function ReportConfig.sanitizeTextForDiscord(text)
	if not text or text == "" then
		return "_(Tidak ada teks)_"
	end
	
	-- Pangkas panjang
	if #text > ReportConfig.TEXT_LIMITS.MAX_LENGTH then
		text = string.sub(text, 1, ReportConfig.TEXT_LIMITS.MAX_LENGTH) .. "..."
	end
	
	-- Hapus karakter yang bisa merusak Discord formatting
	text = string.gsub(text, "`", "'")     -- Backtick -> single quote
	text = string.gsub(text, "@", "(at)")   -- @ mention -> (at)
	text = string.gsub(text, "#", "(hash)") -- Channel mention -> (hash)
	
	-- Hapus control characters
	text = string.gsub(text, "[\r\n\t]", " ")
	
	-- Trim whitespace
	text = string.match(text, "^%s*(.-)%s*$")
	
	return text
end

-- Generate server info untuk webhook
function ReportConfig.getServerInfo()
	local Players = game:GetService("Players")
	
	return {
		serverId = game.JobId ~= "" and game.JobId or "Private/Solo",
		serverIdShort = game.JobId ~= "" and string.sub(game.JobId, 1, 8) or "Private",
		playerCount = #Players:GetPlayers(),
		maxPlayers = Players.MaxPlayers,
		placeId = game.PlaceId,
		timestamp = os.time(),
		dateTime = os.date("%Y-%m-%d %H:%M:%S")
	}
end

-- Format player info untuk webhook
function ReportConfig.getPlayerInfo(player)
	if not player then
		return {
			name = "Unknown",
			userId = 0,
			accountAge = 0,
			membershipType = "Unknown"
		}
	end
	
	return {
		name = player.Name,
		userId = player.UserId,
		accountAge = player.AccountAge,
		membershipType = tostring(player.MembershipType),
		displayName = player.DisplayName ~= player.Name and player.DisplayName or nil
	}
end

-- Generate koordinat dari player
function ReportConfig.getPlayerCoordinates(player)
	if not player or not player.Character then
		return "Koordinat tidak tersedia"
	end
	
	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return "Koordinat tidak tersedia"
	end
	
	local pos = humanoidRootPart.Position
	return string.format("(%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z)
end

-- ==================== DATASTORE HELPERS (OPSIONAL) ====================

--[[
CATATAN: Fungsi-fungsi ini memerlukan DataStore permission di game settings.
Uncomment jika ingin menyimpan spam log ke DataStore.

local DataStoreService = game:GetService("DataStoreService")
local SpamDataStore = DataStoreService:GetDataStore("SpamLogs_v1")

function ReportConfig.saveSpamLogToDataStore(userId, spamData)
	local success, result = pcall(function()
		local key = "spam_" .. tostring(userId)
		return SpamDataStore:SetAsync(key, spamData)
	end)
	
	if not success then
		warn("[Report System] Failed to save spam log for user", userId, ":", result)
	end
	
	return success
end

function ReportConfig.loadSpamLogFromDataStore(userId)
	local success, result = pcall(function()
		local key = "spam_" .. tostring(userId)
		return SpamDataStore:GetAsync(key)
	end)
	
	if success then
		return result
	else
		warn("[Report System] Failed to load spam log for user", userId, ":", result)
		return nil
	end
end
--]]

-- ==================== REMOTE EVENTS (akan di-set dari ServerScript) ====================
ReportConfig.ReportEvent = nil
ReportConfig.AntiSpamEvent = nil

return ReportConfig