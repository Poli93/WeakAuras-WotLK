local ipairs = ipairs
local pairs = pairs
local select = select
local ceil, floor = math.ceil, math.floor

local GetInstanceInfo = GetInstanceInfo
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers

function tInvert(tbl)
	local inverted = {};
	for k, v in pairs(tbl) do
		inverted[v] = k;
	end
	return inverted;
end

local function Mixin(object, ...)
	for i = 1, select("#", ...) do
		local mixin = select(i, ...);
		for k, v in pairs(mixin) do
			object[k] = v;
		end
	end

	return object;
end

function CreateFromMixins(...)
	return Mixin({}, ...)
end

function Lerp(startValue, endValue, amount)
	return (1 - amount) * startValue + amount * endValue
end

function Clamp(value, min, max)
	if value > max then
		return max
	elseif value < min then
		return min
	end
	return value
end

function Saturate(value)
	return Clamp(value, 0.0, 1.0)
end

local TARGET_FRAME_PER_SEC = 60.0;
function DeltaLerp(startValue, endValue, amount, timeSec)
	return Lerp(startValue, endValue, Saturate(amount * timeSec * TARGET_FRAME_PER_SEC));
end

function FrameDeltaLerp(startValue, endValue, amount, tickTime)
	return DeltaLerp(startValue, endValue, amount, tickTime)
end

function Round(value)
	if value < 0 then
		return ceil(value - .5);
	end
	return floor(value + .5);
end

function tIndexOf(tbl, item)
	for i, v in ipairs(tbl) do
		if item == v then
			return i;
		end
	end
end

local g_updatingBars = {};

local function IsCloseEnough(bar, newValue, targetValue)
	local min, max = bar:GetMinMaxValues();
	local range = max - min
	if range > 0.0 then
		return math.abs((newValue - targetValue) / range) < .00001
	end

	return true;
end

do
	local f = CreateFrame("Frame")
	f:Show()
	f:SetScript("OnUpdate", function(_, elapsed)
		for bar, targetValue in pairs(g_updatingBars) do
			local effectiveTargetValue = Clamp(targetValue, bar:GetMinMaxValues())
			local newValue = FrameDeltaLerp(bar:GetValue(), effectiveTargetValue, .25, elapsed)

			if IsCloseEnough(bar, newValue, effectiveTargetValue) then
				g_updatingBars[bar] = nil
				bar:SetValue(effectiveTargetValue)
			else
				bar:SetValue(newValue)
			end
		end
	end)
end

SmoothStatusBarMixin = {}

function SmoothStatusBarMixin:ResetSmoothedValue(value)
	local targetValue = g_updatingBars[self]
	if targetValue then
		g_updatingBars[self] = nil
		self:SetValue(value or targetValue)
	elseif value then
		self:SetValue(value)
	end
end

function SmoothStatusBarMixin:SetSmoothedValue(value)
	g_updatingBars[self] = value
end

function SmoothStatusBarMixin:SetMinMaxSmoothedValue(min, max)
	self:SetMinMaxValues(min, max)

	local targetValue = g_updatingBars[self]
	if targetValue then
		local ratio = 1
		if max ~= 0 and self.lastSmoothedMax and self.lastSmoothedMax ~= 0 then
			ratio = max / self.lastSmoothedMax
		end

		g_updatingBars[self] = targetValue * ratio
	end

	self.lastSmoothedMin = min
	self.lastSmoothedMax = max
end

local oldGetInstanceDifficulty = GetInstanceDifficulty
function GetInstanceDifficulty()
	local diff = oldGetInstanceDifficulty()
	if diff == 1 then
		local _, _, difficulty, _, maxPlayers = GetInstanceInfo()
		if difficulty == 1 and maxPlayers == 25 then
			diff = 2
		end
	end
	return diff
end

function IsInGroup()
	return (GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0)
end

function IsInRaid()
	return GetNumRaidMembers() > 0
end

function GetNumSubgroupMembers()
	return GetNumPartyMembers()
end

function GetNumGroupMembers()
	return GetNumRaidMembers()
end

if not C_Timer or C_Timer._version ~= 2 then
	local setmetatable = setmetatable
	local type = type
	local tinsert = table.insert
	local tremove = table.remove

	C_Timer = C_Timer or {}
	C_Timer._version = 2

	local TickerPrototype = {}
	local TickerMetatable = {
		__index = TickerPrototype,
		__metatable = true
	}

	local waitTable = {}
	local waitFrame = TimerFrame or CreateFrame("Frame", "TimerFrame", UIParent)
	waitFrame:SetScript("OnUpdate", function(self, elapsed)
		local total = #waitTable
		local i = 1

		while i <= total do
			local ticker = waitTable[i]

			if ticker._cancelled then
				tremove(waitTable, i)
				total = total - 1
			elseif ticker._delay > elapsed then
				ticker._delay = ticker._delay - elapsed
				i = i + 1
			else
				ticker._callback(ticker)

				if ticker._remainingIterations == -1 then
					ticker._delay = ticker._duration
					i = i + 1
				elseif ticker._remainingIterations > 1 then
					ticker._remainingIterations = ticker._remainingIterations - 1
					ticker._delay = ticker._duration
					i = i + 1
				elseif ticker._remainingIterations == 1 then
					tremove(waitTable, i)
					total = total - 1
				end
			end
		end

		if #waitTable == 0 then
			self:Hide()
		end
	end)

	local function AddDelayedCall(ticker, oldTicker)
		if oldTicker and type(oldTicker) == "table" then
			ticker = oldTicker
		end

		tinsert(waitTable, ticker)
		waitFrame:Show()
	end

	_G.AddDelayedCall = AddDelayedCall

	local function CreateTicker(duration, callback, iterations)
		local ticker = setmetatable({}, TickerMetatable)
		ticker._remainingIterations = iterations or -1
		ticker._duration = duration
		ticker._delay = duration
		ticker._callback = callback

		AddDelayedCall(ticker)

		return ticker
	end

	function C_Timer.After(duration, callback)
		return CreateTicker(duration, callback, 1)
	end

	function C_Timer.NewTimer(duration, callback)
		return CreateTicker(duration, callback, 1)
	end

	function C_Timer.NewTicker(duration, callback, iterations)
		return CreateTicker(duration, callback, iterations)
	end

	function TickerPrototype:Cancel()
		self._cancelled = true
	end
end

RAID_CLASS_COLORS.HUNTER.colorStr = "ffabd473"
RAID_CLASS_COLORS.WARLOCK.colorStr = "ff8788ee"
RAID_CLASS_COLORS.PRIEST.colorStr = "ffffffff"
RAID_CLASS_COLORS.PALADIN.colorStr = "fff58cba"
RAID_CLASS_COLORS.MAGE.colorStr = "ff3fc7eb"
RAID_CLASS_COLORS.ROGUE.colorStr = "fffff569"
RAID_CLASS_COLORS.DRUID.colorStr = "ffff7d0a"
RAID_CLASS_COLORS.SHAMAN.colorStr = "ff0070de"
RAID_CLASS_COLORS.WARRIOR.colorStr = "ffc79c6e"
RAID_CLASS_COLORS.DEATHKNIGHT.colorStr = "ffc41f3b"