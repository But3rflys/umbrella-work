--[[
     Draft Helper -> Build Brain
     author: watah3ll
]]

local script = {}

local K = {
	VERSION = "2.0.0",
	TARGET = "build_brain.lua",
	SELF = "draft_helper.lua",
	URLS = {
		"https://github.com/BraVoEw/Scripts-Umbrella/releases/download/build-brain-v2.0.0/build_brain.lua",
		"https://raw.githubusercontent.com/BraVoEw/Scripts-Umbrella/build-brain-v2.0.0/build_brain/build_brain.lua",
	},
	MIN_SIZE = 100000,
	TIMEOUT = 30,
	START_DELAY = 1,
	RETRY = 30,
	RELOAD_DELAY = 1.2,
}

local state = { phase = "wait", at = os.clock() + K.START_DELAY, url = 1, error = nil }

local dir = Engine.GetCheatDirectory()
if not dir:match("[\\/]$") then dir = dir .. "\\" end
local target = dir .. "scripts\\" .. K.TARGET
local self_path = dir .. "scripts\\" .. K.SELF

local function log(text)
	Log.Write("[Draft Helper -> Build Brain] " .. text)
end

local function exists(path)
	local f = io.open(path, "rb")
	if not f then return false end
	f:close()
	return true
end

local function valid(body)
	return type(body) == "string"
		and #body >= K.MIN_SIZE
		and body:find("^%-%-%[%[") ~= nil
		and body:match('\n\tVERSION = "([%d%.]+)",') ~= nil
		and body:find("return script%s*$") ~= nil
end

local function write(path, body)
	local tmp = path .. ".tmp"
	local f = io.open(tmp, "wb")
	if not f then return false end
	f:write(body)
	f:close()
	os.remove(path)
	if not os.rename(tmp, path) then
		f = io.open(path, "wb")
		if not f then return false end
		f:write(body)
		f:close()
		os.remove(tmp)
	end
	f = io.open(path, "rb")
	if not f then return false end
	local size = f:seek("end")
	f:close()
	return size == #body
end

local function finish()
	os.remove(self_path)
	os.remove(self_path .. ".tmp")
	log("done, reloading scripts")
	state.phase = "reload"
	state.at = os.clock() + K.RELOAD_DELAY
end

local function fail(reason)
	if state.error ~= reason then log("failed: " .. reason) end
	state.error = reason
	state.url = 1
	state.phase = "wait"
	state.at = os.clock() + K.RETRY
end

local function download()
	local url = K.URLS[state.url]
	state.phase = "loading"
	local sent = HTTP.Request("GET", url, { timeout = K.TIMEOUT }, function(r)
		local code = tonumber(r.code) or 0
		local body = code == 200 and r.response or nil
		if not valid(body) then
			if K.URLS[state.url + 1] then
				state.url = state.url + 1
				return download()
			end
			return fail(code == 200 and "bad file" or ("HTTP " .. code .. " " .. tostring(r.error_message)))
		end
		if not write(target, body) then return fail("cannot write " .. target) end
		log("installed " .. K.TARGET .. " " .. body:match('\n\tVERSION = "([%d%.]+)",'))
		finish()
	end, "dh_to_bb")
	if not sent then fail("request not sent") end
end

function script.OnUpdateEx()
	if os.clock() < state.at then return end
	if state.phase == "reload" then
		state.phase = "done"
		Engine.ReloadScriptSystem()
	elseif state.phase == "wait" then
		if exists(target) then
			log(K.TARGET .. " already installed")
			finish()
		else
			download()
		end
	end
end

return script
