-- mydata.lua
local _M = {}

local data = {}
local x = 0

function _M.get()
	return data, x
end

function _M.set(wb)
	data[wb] = wb
	x = x + 1
	--table.insert(data, wb)
end

function _M.remove(wb)
	data[wb] = nil
end

return _M