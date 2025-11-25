local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", function()
	
		---------------------------------------------------
		-- SavedVariables Initialization
		---------------------------------------------------

		-- Ensure tables exist
		simpleAuras = simpleAuras or {}
		simpleAuras.auras   = simpleAuras.auras   or {}
		simpleAuras.refresh = simpleAuras.refresh or 5
		if sA.SuperWoW then
		  simpleAuras.auradurations = simpleAuras.auradurations or {}
		  simpleAuras.updating      = simpleAuras.updating or 0
		  simpleAuras.showlearning  = simpleAuras.showlearning or 0
		  simpleAuras.learnall      = simpleAuras.learnall or 0
		end
		
		sA.SettingsLoaded = 1
		
		-- Login message about DLL support
		local msg = sA.PREFIX .. "Loaded. DLL Support: "
		if sA.hasNampowerSupport then
			msg = msg .. "|cff00ff00nampower|r "
		end
		if sA.SuperWoW then
			msg = msg .. "|cff00ff00SuperWoW|r "
		end
		if sA.hasUnitXPSupport then
			msg = msg .. "|cff00ff00UnitXP|r"
		end
		if not (sA.hasNampowerSupport or sA.SuperWoW or sA.hasUnitXPSupport) then
			msg = msg .. "|cffff0000None|r (limited functionality)"
		end
		DEFAULT_CHAT_FRAME:AddMessage(msg)
		
		sA:CreateTestAuras()

		table.insert(UISpecialFrames, "sATest")
		table.insert(UISpecialFrames, "sATestDual")

end)

-- runtime only
sA = sA or { auraTimers = {}, learnCastTimers = {}, learnNew = {}, frames = {}, dualframes = {}, draggers = {}, raidTargets = {}, spellIDCache = {} }
sA.SuperWoW = SetAutoloot and true or false

-- message helper (must be defined before VARIABLES_LOADED event uses it)
sA.PREFIX = "|c194b7dccsimple|cffffffffAuras: "
function sA:Msg(msg)
  DEFAULT_CHAT_FRAME:AddMessage(self.PREFIX .. msg)
end

-- DLL detection
sA.hasNampowerSupport = GetSpellIdForName and true or false
sA.hasUnitXPSupport = UnitGUID and true or false

-- GUID Helper (defined here because init.lua loads before core.lua)
function sA:GetUnitGUID(unit)
  if not unit then return nil end
  
  local guid
  
  -- Use UnitXP if available (more reliable)
  if sA.hasUnitXPSupport then
    guid = UnitGUID(unit)
  end
  
  -- Fallback to UnitExists
  if not guid then
    local exists
    exists, guid = UnitExists(unit)
    if not exists then return nil end
  end
  
  -- Ensure guid is a string and remove 0x prefix
  if guid then
    guid = tostring(guid)
    guid = string.gsub(guid, "^0x", "")
    return guid
  end
  
  return nil
end

-- Initialize player GUID now that GetUnitGUID is defined
sA.playerGUID = sA:GetUnitGUID("player")
sA.SettingsLoaded = nil
sA.debugMode = false

-- perf: cache globals we use a lot (Lua 5.0-safe)
local gsub   = string.gsub
local find   = string.find
local lower  = string.lower
local floor  = math.floor
local tinsert = table.insert
local getn   = table.getn
local GetTime = GetTime

---------------------------------------------------
-- Helper Functions
---------------------------------------------------

local function GetAuraDurationBySpellID(spellID, casterGUID)
  if not spellID or not casterGUID then return nil end
  if type(simpleAuras.auradurations[spellID]) ~= "table" then
	simpleAuras.auradurations[spellID] = nil
	return nil
  end
  return simpleAuras.auradurations[spellID][casterGUID]
end

local function getAuraID(spellName)
    local auraFound = {}
    for auraID, aura in ipairs(simpleAuras.auras) do
        if aura and aura.name == spellName then
            table.insert(auraFound, auraID)
        end
    end
    if getn(auraFound) > 0 then
        return auraFound
    else
        return {}
    end
end

-- SuperWoW: learn and track aura durations
if sA.SuperWoW then
  local sADuration = CreateFrame("Frame")
  sADuration:RegisterEvent("RAW_COMBATLOG")
  sADuration:RegisterEvent("UNIT_CASTEVENT")
  sADuration:SetScript("OnEvent", function()
    local timestamp = GetTime()

    if event == "RAW_COMBATLOG" and simpleAuras.auradurations then
      local raw = arg2
      if not raw or not find(raw, "fades from") then return end

      local _, _, spellName  = string.find(raw, "^(.-) fades from ")
      local _, _, targetGUID = string.find(raw, "from (.-).$")

      -- targetGUID from combat log is a string, but ensure we handle it properly
      if targetGUID and lower(targetGUID) == "you" then 
        targetGUID = sA:GetUnitGUID("player")
      elseif targetGUID and targetGUID ~= "" then 
        targetGUID = gsub(tostring(targetGUID), "^0x", "")
      else
        targetGUID = nil
      end
      
      if not spellName or not targetGUID then return end
      if not sA.auraTimers[targetGUID] then return end

      for spellID in pairs(sA.auraTimers[targetGUID]) do
        local n = SpellInfo(spellID)
        if n then
          n = gsub(n, "%s*%(%s*Rank%s+%d+%s*%)", "")
          if n == spellName then
            -- if we were learning this duration, compute actual
			
            if sA.learnCastTimers[targetGUID] and sA.learnCastTimers[targetGUID][spellID] and sA.learnCastTimers[targetGUID][spellID].duration then
              local castTime = sA.learnCastTimers[targetGUID][spellID].duration
              local actual   = timestamp - castTime
			  local casterGUID = sA.learnCastTimers[targetGUID][spellID].castby
			  simpleAuras.auradurations[spellID] = simpleAuras.auradurations[spellID] or {}
              simpleAuras.auradurations[spellID][casterGUID] = floor(actual + 0.5)
			  sA.learnNew[spellID] = nil
              if simpleAuras.updating == 1 then
                sA:Msg("Updated " .. spellName .. " (ID:"..spellID..") to: " .. floor(actual + 0.5) .. "s")
              elseif simpleAuras.showlearning == 1 then
				sA:Msg("Learned " .. spellName .. " (ID:"..spellID..") duration: " .. floor(actual + 0.5) .. "s")
			  end
              sA.learnCastTimers[targetGUID][spellID].duration = nil
              sA.learnCastTimers[targetGUID][spellID].castby = nil
            end
			
			if sA.auraTimers[targetGUID][spellID].duration <= timestamp then
				sA.auraTimers[targetGUID][spellID] = nil
			end
			
            if not next(sA.auraTimers[targetGUID]) then
              sA.auraTimers[targetGUID] = nil
            end
            break
          end
        end
      end

    elseif event == "UNIT_CASTEVENT" and simpleAuras.auradurations then
      local casterGUID, targetGUID, evType, spellID = arg1, arg2, arg3, arg4
      if evType ~= "CAST" or not spellID then return end
	  
      local spellName = SpellInfo(spellID)
	  local auraIDs = getAuraID(spellName)

	  if ((auraIDs and getn(auraIDs) > 0) or simpleAuras.learnall == 1) and spellID then

		  if sA.playerGUID then
			sA.playerGUID = tostring(sA.playerGUID)
			sA.playerGUID = gsub(sA.playerGUID, "^0x", "")
		  else
			sA.playerGUID = sA:GetUnitGUID("player")
		  end
		  
		  -- arg1 and arg2 from UNIT_CASTEVENT are hex numbers, convert to string
		  casterGUID = gsub(tostring(casterGUID or ""), "^0x", "")
		  if targetGUID then 
		    targetGUID = gsub(tostring(targetGUID), "^0x", "")
		  end

		  -- Store raid target information for auras that might need it
		  if casterGUID and casterGUID == sA.playerGUID and targetGUID and targetGUID ~= "" then
		    -- Find which raid member this target corresponds to
		    for i = 1, 40 do
		      local raidUnit = "raid" .. i
		      local raidGUID = sA:GetUnitGUID(raidUnit)
		      if raidGUID and raidGUID == targetGUID then
		        sA.raidTargets[spellID] = raidUnit
		        break
		      end
		    end
		  end

		  -- Ensure we have a valid casterGUID for comparisons
		  if not casterGUID then return end
		  
		  local dur = GetAuraDurationBySpellID(spellID,casterGUID)
	  
		  if dur and dur > 0 and simpleAuras.updating == 0 and casterGUID == sA.playerGUID then
		    -- Ensure targetGUID is valid
		    if not targetGUID or targetGUID == "" then targetGUID = sA.playerGUID end
		    
			sA.auraTimers[targetGUID] = sA.auraTimers[targetGUID] or {}
			sA.auraTimers[targetGUID][spellID] = sA.auraTimers[targetGUID][spellID] or {}
			if not sA.auraTimers[targetGUID][spellID].duration or (dur + timestamp) > sA.auraTimers[targetGUID][spellID].duration then
				sA.auraTimers[targetGUID][spellID].duration = timestamp + dur
				sA.auraTimers[targetGUID][spellID].castby = casterGUID
			end
			sA.learnNew[spellID] = nil
		  elseif casterGUID == sA.playerGUID then

			local showLearn = nil
						
			if not targetGUID or targetGUID == "" then targetGUID = sA.playerGUID end
			
			sA.learnCastTimers[targetGUID] = sA.learnCastTimers[targetGUID] or {}
			sA.learnCastTimers[targetGUID][spellID] = sA.learnCastTimers[targetGUID][spellID] or {}
			sA.learnCastTimers[targetGUID][spellID].duration = timestamp
			sA.learnCastTimers[targetGUID][spellID].castby = casterGUID
			
			sA.auraTimers[targetGUID] = sA.auraTimers[targetGUID] or {}
			sA.auraTimers[targetGUID][spellID] = sA.auraTimers[targetGUID][spellID] or {}
			sA.auraTimers[targetGUID][spellID].duration = 0
			sA.auraTimers[targetGUID][spellID].castby = casterGUID
									
			for _, auraID in ipairs(auraIDs) do
				if simpleAuras.auras[auraID].unit ~= "Player" and simpleAuras.auras[auraID].type ~= "Cooldown" then
					showLearn = true
					break
				end
			end
						
			if showLearn and casterGUID == sA.playerGUID and targetGUID ~= sA.playerGUID then
				sA.learnNew[spellID] = 1
			end
			
			if simpleAuras.updating == 1 then
			  sA:Msg("Updating " .. (spellName or spellID) .. " (ID:"..spellID..")...")
			elseif simpleAuras.showlearning == 1 then
			  sA:Msg("Learning " .. (spellName or spellID) .. " (ID:"..spellID..")...")
			end
			
		  end
		  
	  end
	  
    end
  end)
end

-- Timed updates
local sAEvent = CreateFrame("Frame", "sAEvent", UIParent)
sAEvent:SetScript("OnUpdate", function()

	local time = GetTime()
	local refreshRate = 1 / (simpleAuras.refresh or 5)
	if (time - (sAEvent.lastUpdate or 0)) < refreshRate then return end
		
  -- Cache the UI scale in a safe context
  sA.uiScale = UIParent:GetEffectiveScale()

  -- Handle Move Mode with Ctrl Key
  local mainFrame = _G["sAGUI"]
  if mainFrame and mainFrame:IsVisible() and IsControlKeyDown() and IsAltKeyDown() and IsShiftKeyDown() then

	if sA.moveAuras ~= 1 then
			
		-- TestAura
		if sA.TestAura and sA.TestAura:IsVisible() then
			
			sA.draggers[0]:Show()
			gui:SetAlpha(0)
			gui.editor:SetAlpha(0)
			
		else
	  
			-- Continuously show draggers for any visible frames while in move mode
			for id, frame in pairs(sA.frames) do
			  if frame:IsVisible() and sA.draggers[id] then
				sA.draggers[id]:Show()
				gui:SetAlpha(0)
				if gui.editor then
				  gui.editor:SetAlpha(0)
				end
			  end
			end
			
		end

		sA.moveAuras = 1

	end
	
  else

	if sA.moveAuras == 1 then
				
		-- Hide all draggers when not in move mode
	    for id, dragger in pairs(sA.draggers) do
	      if dragger then
			dragger:Hide()
	        gui:SetAlpha(1)
			if gui.editor then
	          gui.editor:SetAlpha(1)
			end
		  end
	    end
		
		-- Reload data if in editor
		if gui.editor and gui.auraEdit and sA.draggers[0] and sA.draggers[0]:IsVisible() then
			
			sA:SaveAura(gui.auraEdit)
			
		end

		sA.moveAuras = 0

	end
	
  end
		
  sAEvent.lastUpdate = time
  sA:UpdateAuras()
		
end)

-- Combat state
local sACombat = CreateFrame("Frame")
sACombat:RegisterEvent("PLAYER_REGEN_DISABLED")
sACombat:RegisterEvent("PLAYER_REGEN_ENABLED")
sACombat:SetScript("OnEvent", function()
  if event == "PLAYER_REGEN_DISABLED" then
    sAinCombat = true
  elseif event == "PLAYER_REGEN_ENABLED" then
    sAinCombat = nil
  end
end)

---------------------------------------------------
-- Slash Commands
---------------------------------------------------
SLASH_sA1 = "/sa"
SLASH_sA2 = "/simpleauras"
SlashCmdList["sA"] = function(msg)

	-- Get Command
	if type(msg) ~= "string" then
		msg = ""
	end

	-- Get Command Arguments
	local cmd, val
	local s, e, a, b, c = string.find(msg, "^(%S+)%s*(%S*)%s*(%S*)$")
	if a then cmd = a else cmd = "" end
	if b then val = b else val = "" end
	if c then fad = c else fad = "" end
	
	-- hide / show or no command
	if cmd == "" or cmd == "show" or cmd == "hide" then
		if gui.auraEdit then gui.auraEdit = nil end
		if cmd == "show" then
			if not gui:IsVisible() then gui:Show() end
		elseif cmd == "hide" then
			if gui:IsVisible() then gui:Hide() sA.TestAura:Hide() sA.TestAuraDual:Hide() end
		else 
			if gui:IsVisible() then gui:Hide() sA.TestAura:Hide() sA.TestAuraDual:Hide() else gui:Show() end
		end
		sA:RefreshAuraList()
		return
	end
	
	-- debug command
	if cmd == "debug" then
		sA.debugMode = not sA.debugMode
		sA:Msg("Debug mode " .. (sA.debugMode and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"))
		return
	end
	
	-- refresh command
	if cmd == "refresh" then
		local num = tonumber(val)
		if num and num >= 1 and num <= 10 then
			simpleAuras.refresh = num
			sA:Msg("Refresh set to " .. num .. " times per second")
		else
			sA:Msg("Usage: /sa refresh X - set refresh rate. (1 to 10 updates per second. Default: 5).")
			sA:Msg("Current refresh = " .. simpleAuras.refresh .. " times per second.")
		end
		return
	end
	
	-- learnall command
	if cmd == "learnall" then
		if sA.SuperWoW then
			local num = tonumber(val)
			if num and (num == 0 or num == 1) then
				simpleAuras.learnall = num
				sA:Msg("LearnAll set to " .. num)
			else
				sA:Msg("Usage: /sa learnall X - learn all AuraDurations, even if no Aura is set up. (1 = Active. Default: 0).")
				sA:Msg("Current LearnAll status = " .. simpleAuras.learnall)
			end
		else
			sA:Msg("/sa showlearning needs SuperWoW to be installed!")
		end
		return
	end
	
	-- refresh command
	if cmd == "update" or cmd == "relearn" then
		local num = tonumber(val)
		if num and (num == 0 or num == 1) then
			simpleAuras.updating = num
			sA:Msg("Aura durations update status set to " .. num)
		else
			sA:Msg("Usage: /sa update X - force aura durations updates (1 = re-learn aura durations. Default: 0).")
			sA:Msg("Current update status = " .. simpleAuras.updating)
		end
		return
	end
	
	-- manual learning of durations
	if cmd == "learn" then
		if sA.SuperWoW then
			local spell = tonumber(val)
			local fade = tonumber(fad)
			if spell and fade then
				local playerGUID = sA:GetUnitGUID("player")
				if playerGUID then
					simpleAuras.auradurations[spell] = simpleAuras.auradurations[spell] or {}
					simpleAuras.auradurations[spell][playerGUID] = fade
				end
				sA:Msg("Set Duration of "..SpellInfo(spell).."("..spell..") to " .. fade .. " seconds.")
			else
				sA:Msg("Usage: /sa learn X Y - manually set duration Y of spellID X.")
			end
		else
			sA:Msg("/sa learn needs SuperWoW to be installed!")
		end
		return
	end
	
	-- track others
	if cmd == "showlearning" then
		if sA.SuperWoW then
			local num = tonumber(val)
			if num and (num == 0 or num == 1) then
				simpleAuras.showlearning = num
				sA:Msg("ShowLearning status set to " .. num)
			else
				sA:Msg("Usage: /sa showlearning X - shows learning of new AuraDurations in chat (1 = show. Default: 0).")
				sA:Msg("Current ShowLearning status = " .. simpleAuras.showlearning)
			end
			return
		else
			sA:Msg("/sa showlearning needs SuperWoW to be installed!")
		end
		return
	end
	
	-- delete
	if cmd == "forget" or cmd == "unlearn" or cmd == "delete" then
		if sA.SuperWoW then
			local arg = val
			if val and val == "all" then
				simpleAuras.auradurations = {}
				sA:Msg("Forgot all learned AuraDurations.")
			elseif val then
				local val = tonumber(val)
				if simpleAuras.auradurations[val] and type(simpleAuras.auradurations[val]) == "table" then
					simpleAuras.auradurations[val] = nil
					sA:Msg("Forgot learned AuraDuration for " .. SpellInfo(val) .. " (ID:"..val..").")
				else
					sA:Msg("No learned AuraDuration for SpellID " .. val.. ".")
				end
				
				-- local _, playerGUID = UnitExists("player")
				-- playerGUID = gsub(playerGUID, "^0x", "")
				-- for spellID, units in pairs(simpleAuras.auradurations) do
					-- if type(units) == "table" and units[playerGUID] then
						-- units[playerGUID] = nil
						-- if next(units) == nil then
							-- simpleAuras.auradurations[spellID] = nil
						-- end
					-- elseif type(units) ~= "table" and simpleAuras.auradurations[spellID] then
						-- simpleAuras.auradurations[spellID] = nil
					-- end
				-- end
				-- sA:Msg("All learned AuraDurations casted by unitGUID "..unitGUID.." deleted.")
			else
				sA:Msg("Usage: /sa forget X - forget AuraDuration of SpellID X (or use 'all' instead to delete all durations).")
			end
		else
			sA:Msg("/sa forget needs SuperWoW to be installed!")
		end
		return
	end
	

	-- clearraid command
	if cmd == "clearraid" then
		sA.raidTargets = {}
		sA:Msg("Cleared all stored raid targets.")
		return
	end
	
	-- showraid command
	if cmd == "showraid" or cmd == "raid" then
		if not next(sA.raidTargets) then
			sA:Msg("No raid targets currently stored.")
		else
			sA:Msg("Currently tracked raid targets:")
			for spellID, raidUnit in pairs(sA.raidTargets) do
				local spellName = SpellInfo(spellID)
				local unitName = UnitName(raidUnit)
				if unitName then
					sA:Msg("  " .. (spellName or "Unknown") .. " (" .. spellID .. ") -> " .. unitName .. " (" .. raidUnit .. ")")
				else
					sA:Msg("  " .. (spellName or "Unknown") .. " (" .. spellID .. ") -> " .. raidUnit .. " (offline/not found)")
				end
			end
		end
		return
	end
	

	-- help or unknown command fallback
	sA:Msg("Usage:")
	sA:Msg("/sa or /sa show or /sa hide - show/hide simpleAuras Settings.")
	sA:Msg("/sa debug - toggle debug mode for troubleshooting aura detection.")
	sA:Msg("/sa refresh X - set refresh rate. (1 to 10 updates per second. Default: 5).")
	sA:Msg("/sa raid or /sa showraid - show currently tracked raid targets.")
	sA:Msg("/sa clearraid - clear all stored raid targets.")
	if sA.SuperWoW then
		sA:Msg("/sa learn X Y - manually set duration Y of spellID X.")
		sA:Msg("/sa forget X - forget AuraDuration of SpellID X (or use 'all' instead to delete all durations).")
		sA:Msg("/sa update X - force AuraDurations updates (1 = re-learn aura durations. Default: 0).")
		sA:Msg("/sa showlearning X - shows learning of new AuraDurations in chat (1 = show. Default: 0).")
		sA:Msg("/sa learnall X - learn all AuraDurations, even if no Aura is set up. (1 = Active. Default: 0).")
	end

end


