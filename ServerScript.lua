-- ServerScript para Report + Anti-Spam System
-- Letakkan di ServerScriptService
-- Memerlukan ReportEvent dan AntiSpamEvent di ReplicatedStorage

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Import ModuleScript untuk constants dan helper functions
local ReportConfig = require(script.ReportConfig)

-- ==================== KONFIGURASI SISTEM ====================
local CONFIG = {
	-- Cooldown dasar dalam detik
	COOLDOWN = 30,
	
	-- Threshold untuk pattern detection (0.0 - 1.0)
	SIMILARITY_THRESHOLD = 0.7,
	
	-- Jumlah spam untuk mengirim evidence ke WEBHOOK_SPAM
	EVIDENCE_THRESHOLD = 3,
	
	-- Maksimal history report yang disimpan per user
	MAX_HISTORY = 50,
	
	-- Progressive cooldown multipliers
	PROGRESSIVE_MULTIPLIER = {
		[1] = 1,    -- Normal cooldown
		[2] = 2,    -- 2x cooldown
		[3] = 3,    -- 3x cooldown (dan kirim evidence)
	},
	
	-- Maksimal panjang teks untuk sanitasi
	MAX_TEXT_LENGTH = 500,
	
	-- Auto-kick (set false untuk tidak kick otomatis)
	AUTO_KICK_ENABLED = false,
	KICK_THRESHOLD = 10,
}

-- ==================== STATE TRACKING ====================
local playerState = {
	lastReportTime = {},
	spamCounter = {},
	reportHistory = {},
	spamLog = {},
}

-- ==================== UTILITY FUNCTIONS ====================

-- Sanitasi teks untuk webhook
local function sanitizeText(text)
	if not text or text == "" then
		return "_(Kosong)_"
	end
	
	-- Pangkas panjang teks
	if #text > CONFIG.MAX_TEXT_LENGTH then
		text = string.sub(text, 1, CONFIG.MAX_TEXT_LENGTH) .. "..."
	end
	
	-- Hapus karakter khusus yang bisa merusak Discord embed
	text = string.gsub(text, "[`@]", "")
	
	return text
end

-- Pattern Detection dengan similarity calculation
local function calculateSimilarity(str1, str2)
	if not str1 or not str2 then return 0 end
	
	-- Normalize strings
	str1 = string.lower(str1)
	str2 = string.lower(str2)
	
	-- Exact match
	if str1 == str2 then return 1.0 end
	
	-- Substring detection
	if string.find(str1, str2, 1, true) or string.find(str2, str1, 1, true) then
		return 0.8
	end
	
	-- Word-based Jaccard similarity
	local words1, words2 = {}, {}
	for word in string.gmatch(str1, "%w+") do
		words1[word] = true
	end
	for word in string.gmatch(str2, "%w+") do
		words2[word] = true
	end
	
	local intersection = 0
	local union = 0
	
	-- Count intersection
	for word in pairs(words1) do
		if words2[word] then
			intersection = intersection + 1
		end
	end
	
	-- Count union
	for word in pairs(words1) do
		union = union + 1
	end
	for word in pairs(words2) do
		if not words1[word] then
			union = union + 1
		end
	end
	
	return union > 0 and (intersection / union) or 0
end

-- Advanced Pattern Detection
local function detectRepeatedPattern(player, reportType, content)
	local userId = player.UserId
	
	if not playerState.reportHistory[userId] then
		playerState.reportHistory[userId] = {}
	end
	
	local history = playerState.reportHistory[userId]
	local maxSimilarity = 0
	local matchedReport = nil
	
	-- Periksa similarity dengan 10 report terakhir
	local checkCount = math.min(#history, 10)
	for i = #history - checkCount + 1, #history do
		if i > 0 then
			local oldReport = history[i]
			if oldReport.type == reportType then
				local similarity = calculateSimilarity(content, oldReport.content)
				if similarity > maxSimilarity then
					maxSimilarity = similarity
					matchedReport = oldReport
				end
			end
		end
	end
	
	-- Tambahkan report baru ke history
	table.insert(history, {
		timestamp = os.time(),
		type = reportType,
		content = content or ""
	})
	
	-- Bersihkan history jika terlalu panjang
	if #history > CONFIG.MAX_HISTORY then
		table.remove(history, 1)
	end
	
	return {
		isRepeated = maxSimilarity >= CONFIG.SIMILARITY_THRESHOLD,
		similarity = maxSimilarity,
		matchedContent = matchedReport and matchedReport.content or nil
	}
end

-- Spam logging
local function logSpamAttempt(player, actionType, data)
	local userId = player.UserId
	local timestamp = os.time()
	
	if not playerState.spamLog[userId] then
		playerState.spamLog[userId] = {
			playerName = player.Name,
			totalSpamAttempts = 0,
			firstSpamTime = timestamp,
			lastSpamTime = timestamp,
			spamHistory = {},
			patternDetections = 0,
			evidenceSent = 0
		}
	end
	
	local log = playerState.spamLog[userId]
	log.totalSpamAttempts = log.totalSpamAttempts + 1
	log.lastSpamTime = timestamp
	log.playerName = player.Name -- Update name jika berubah
	
	local entry = {
		timestamp = timestamp,
		dateTime = os.date("%Y-%m-%d %H:%M:%S", timestamp),
		actionType = actionType,
		data = data
	}
	
	table.insert(log.spamHistory, entry)
	
	-- Bersihkan history lama
	if #log.spamHistory > 20 then
		table.remove(log.spamHistory, 1)
	end
	
	-- Debug print (opsional, hapus di production)
	print(string.format("[SPAM LOG] %s (%d): %s", player.Name, userId, actionType))
end

-- Progressive Rate Limiting
local function applyProgressiveRateLimit(player)
	local userId = player.UserId
	local spamCount = playerState.spamCounter[userId] or 0
	
	local multiplier = CONFIG.PROGRESSIVE_MULTIPLIER[spamCount] or CONFIG.PROGRESSIVE_MULTIPLIER[3]
	local newCooldown = CONFIG.COOLDOWN * multiplier
	
	playerState.lastReportTime[userId] = os.time() + newCooldown
	
	return newCooldown
end

-- Send Discord Webhook
local function sendDiscordWebhook(url, data)
	if not url or url == "" then
		warn("[Report System] Webhook URL kosong!")
		return false
	end
	
	local success, result = pcall(function()
		return HttpService:PostAsync(url, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson)
	end)
	
	if not success then
		warn("[Report System] Gagal kirim webhook:", result)
		return false
	end
	
	return true
end

-- Send Spam Evidence
local function sendSpamEvidence(player)
	local userId = player.UserId
	local log = playerState.spamLog[userId]
	
	if not log then return end
	
	-- Update counter evidence yang dikirim
	log.evidenceSent = log.evidenceSent + 1
	
	local recentHistory = {}
	local historyCount = math.min(#log.spamHistory, 5)
	for i = #log.spamHistory - historyCount + 1, #log.spamHistory do
		if i > 0 then
			local entry = log.spamHistory[i]
			table.insert(recentHistory, string.format("• %s: %s", 
				entry.dateTime, 
				entry.actionType
			))
		end
	end
	
	local evidenceData = {
		["username"] = "🚫 Anti-Spam Evidence",
		["embeds"] = {{
			["title"] = "🚨 Spam Evidence Detected",
			["description"] = string.format("Player **%s** (%d) menunjukkan pola spam yang mencurigakan.", 
				sanitizeText(player.Name), userId),
			["color"] = 15158332, -- Red
			["fields"] = {
				{
					["name"] = "📊 Statistik Spam", 
					["value"] = string.format(
						"Total Spam: **%d**\nPattern Detections: **%d**\nEvidence Sent: **%d**", 
						log.totalSpamAttempts, 
						log.patternDetections, 
						log.evidenceSent
					), 
					["inline"] = true
				},
				{
					["name"] = "⏰ Timeline", 
					["value"] = string.format(
						"First Spam: %s\nLast Spam: %s", 
						os.date("%Y-%m-%d %H:%M:%S", log.firstSpamTime),
						os.date("%Y-%m-%d %H:%M:%S", log.lastSpamTime)
					), 
					["inline"] = true
				},
				{
					["name"] = "📝 Recent Activity", 
					["value"] = #recentHistory > 0 and table.concat(recentHistory, "\n") or "_(No recent activity)_",
					["inline"] = false
				}
			},
			["footer"] = {
				["text"] = string.format("Evidence Report • %s • Server: %s", 
					os.date("%Y-%m-%d %H:%M:%S"), 
					game.JobId ~= "" and string.sub(game.JobId, 1, 8) or "Private"
				)
			}
		}}
	}
	
	sendDiscordWebhook(ReportConfig.WEBHOOK_SPAM, evidenceData)
end

-- ==================== MAIN REPORT HANDLER ====================

local function handleReport(player, reportType, reportInfo)
	-- Validate inputs
	if not player or not Players:GetPlayerByUserId(player.UserId) then
		return -- Player no longer exists
	end
	
	if not reportType or type(reportType) ~= "string" then
		return -- Invalid report type
	end
	
	if not reportInfo or type(reportInfo) ~= "table" then
		return -- Invalid report info
	end
	
	local userId = player.UserId
	local now = os.time()
	
	-- Initialize player state jika belum ada
	playerState.lastReportTime[userId] = playerState.lastReportTime[userId] or 0
	playerState.spamCounter[userId] = playerState.spamCounter[userId] or 0
	
	-- Hitung remaining cooldown
	local timeDiff = now - playerState.lastReportTime[userId]
	local remainingCooldown = math.max(0, CONFIG.COOLDOWN - timeDiff)
	
	-- Ekstrak content untuk pattern detection
	local reportContent = ""
	if reportType == "bug" then
		reportContent = sanitizeText(reportInfo.Deskripsi or "")
	elseif reportType == "player" then
		reportContent = sanitizeText((reportInfo.Target or "") .. " " .. (reportInfo.Reason or ""))
	end
	
	-- Pattern detection
	local patternResult = detectRepeatedPattern(player, reportType, reportContent)
	
	-- Jika masih dalam cooldown -> SPAM DETECTED
	if timeDiff < CONFIG.COOLDOWN then
		playerState.spamCounter[userId] = playerState.spamCounter[userId] + 1
		
		-- Log spam attempt
		logSpamAttempt(player, "spam_attempt", {
			reportType = reportType,
			spamCount = playerState.spamCounter[userId],
			remainingTime = remainingCooldown,
			patternDetected = patternResult.isRepeated,
			similarity = patternResult.similarity,
			content = string.sub(reportContent, 1, 100) -- Ringkas untuk log
		})
		
		-- Jika pattern terdeteksi
		if patternResult.isRepeated then
			if playerState.spamLog[userId] then
				playerState.spamLog[userId].patternDetections = playerState.spamLog[userId].patternDetections + 1
			end
			logSpamAttempt(player, "pattern_detected", {
				similarity = patternResult.similarity,
				matchedSnippet = string.sub(patternResult.matchedContent or "", 1, 50)
			})
		end
		
		-- Apply progressive rate limiting
		local newCooldown = applyProgressiveRateLimit(player)
		local newRemaining = newCooldown
		
		-- Kirim spam evidence jika threshold tercapai
		if playerState.spamCounter[userId] >= CONFIG.EVIDENCE_THRESHOLD then
			sendSpamEvidence(player)
		end
		
		-- Kirim response ke client
		pcall(function()
			if ReportConfig.AntiSpamEvent then
				ReportConfig.AntiSpamEvent:FireClient(player, {
					status = "throttled",
					remaining = newRemaining,
					message = string.format("Spam terdeteksi! Cooldown: %ds", newRemaining),
					spamCount = playerState.spamCounter[userId],
					patternDetected = patternResult.isRepeated
				})
			end
		end)
		
		-- Auto-kick jika diaktifkan (opsional)
		if CONFIG.AUTO_KICK_ENABLED and playerState.spamCounter[userId] >= CONFIG.KICK_THRESHOLD then
			logSpamAttempt(player, "auto_kicked", {spamCount = playerState.spamCounter[userId]})
			player:Kick("Spam berlebihan terdeteksi. Silakan coba lagi nanti.")
		end
		
		return -- Jangan proses report
	end
	
	-- ==================== VALID REPORT - FORWARD KE DISCORD ====================
	
	-- Reset spam counter karena report valid
	playerState.spamCounter[userId] = 0
	playerState.lastReportTime[userId] = now
	
	-- Process report berdasarkan type
	if reportType == "bug" then
		local webhookData = {
			["username"] = "🐛 Bug Report System",
			["embeds"] = {{
				["title"] = "🐛 Bug Report Diterima",
				["description"] = "Bug baru dilaporkan di server!",
				["color"] = 16776960, -- Yellow
				["fields"] = {
					{["name"] = "👤 Reporter", ["value"] = sanitizeText(player.Name), ["inline"] = true},
					{["name"] = "📍 Koordinat", ["value"] = sanitizeText(reportInfo.Coords or "Unknown"), ["inline"] = true},
					{["name"] = "🔍 Deskripsi Bug", ["value"] = sanitizeText(reportInfo.Deskripsi), ["inline"] = false},
					{["name"] = "🌐 Server ID", ["value"] = sanitizeText(reportInfo.ServerId), ["inline"] = true},
					{["name"] = "👥 Players Online", ["value"] = tostring(#Players:GetPlayers()), ["inline"] = true}
				},
				["footer"] = {["text"] = "Bug Report • " .. os.date("%Y-%m-%d %H:%M:%S")}
			}}
		}
		
		sendDiscordWebhook(ReportConfig.WEBHOOK_BUG, webhookData)
		
	elseif reportType == "player" then
		local webhookData = {
			["username"] = "⚠️ Player Report System",
			["embeds"] = {{
				["title"] = "⚠️ Player Report Diterima",
				["description"] = "Player dilaporkan karena pelanggaran!",
				["color"] = 15158332, -- Red
				["fields"] = {
					{["name"] = "👤 Reporter", ["value"] = sanitizeText(player.Name), ["inline"] = true},
					{["name"] = "🎯 Target Player", ["value"] = sanitizeText(reportInfo.Target), ["inline"] = true},
					{["name"] = "📝 Alasan Report", ["value"] = sanitizeText(reportInfo.Reason), ["inline"] = false},
					{["name"] = "🌐 Server ID", ["value"] = sanitizeText(reportInfo.ServerId), ["inline"] = true},
					{["name"] = "👥 Players Online", ["value"] = tostring(#Players:GetPlayers()), ["inline"] = true}
				},
				["footer"] = {["text"] = "Player Report • " .. os.date("%Y-%m-%d %H:%M:%S")}
			}}
		}
		
		sendDiscordWebhook(ReportConfig.WEBHOOK_PLAYER, webhookData)
	end
	
	-- Kirim konfirmasi ke client
	pcall(function()
		if ReportConfig.AntiSpamEvent then
			ReportConfig.AntiSpamEvent:FireClient(player, {
				status = "success",
				remaining = 0,
				message = "Report berhasil dikirim!",
				reportType = reportType
			})
		end
	end)
	
	print(string.format("[Report System] %s mengirim %s report", player.Name, reportType))
end

-- ==================== ADMIN HELPER FUNCTIONS ====================

-- Fungsi untuk admin melihat spam statistics
function ReportConfig.getSpamStats(userId)
	return playerState.spamLog[userId]
end

function ReportConfig.clearSpamHistory(userId)
	playerState.spamLog[userId] = nil
	playerState.spamCounter[userId] = nil
	playerState.lastReportTime[userId] = nil
	playerState.reportHistory[userId] = nil
	print(string.format("[Report System] Cleared spam history for user %d", userId))
end

function ReportConfig.getAllSpamStats()
	local stats = {}
	for userId, log in pairs(playerState.spamLog) do
		stats[userId] = {
			playerName = log.playerName,
			totalSpamAttempts = log.totalSpamAttempts,
			patternDetections = log.patternDetections,
			evidenceSent = log.evidenceSent,
			lastSpamTime = log.lastSpamTime
		}
	end
	return stats
end

-- ==================== EVENT CONNECTIONS ====================

-- Setup RemoteEvents
if not ReplicatedStorage:FindFirstChild("ReportEvent") then
	local reportEvent = Instance.new("RemoteEvent")
	reportEvent.Name = "ReportEvent"
	reportEvent.Parent = ReplicatedStorage
end

if not ReplicatedStorage:FindFirstChild("AntiSpamEvent") then
	local antiSpamEvent = Instance.new("RemoteEvent")
	antiSpamEvent.Name = "AntiSpamEvent"
	antiSpamEvent.Parent = ReplicatedStorage
end

-- Update references
ReportConfig.ReportEvent = ReplicatedStorage:WaitForChild("ReportEvent")
ReportConfig.AntiSpamEvent = ReplicatedStorage:WaitForChild("AntiSpamEvent")

-- Main report handler
ReportConfig.ReportEvent.OnServerEvent:Connect(handleReport)

-- Cleanup saat player disconnect untuk mencegah memory leak
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	
	-- Simpan log spam sebelum cleanup (opsional)
	if playerState.spamLog[userId] then
		-- Log untuk debugging
		print(string.format("[Report System] Player %s disconnected. Spam stats: %d attempts", 
			player.Name, 
			playerState.spamLog[userId].totalSpamAttempts
		))
	end
	
	-- Bersihkan state (kecuali spamLog untuk persistent tracking)
	playerState.lastReportTime[userId] = nil
	playerState.spamCounter[userId] = nil
	playerState.reportHistory[userId] = nil
	-- spamLog tetap disimpan untuk tracking jangka panjang
end)

-- ==================== SYSTEM STARTUP ====================
print("[Report System] Started successfully!")
print(string.format("[Report System] Config: Cooldown=%ds, Similarity=%.1f, Evidence=%d", 
	CONFIG.COOLDOWN, 
	CONFIG.SIMILARITY_THRESHOLD, 
	CONFIG.EVIDENCE_THRESHOLD
))