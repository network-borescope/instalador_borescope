local server = require "resty.websocket.server"
local m = require "websocket_data"


local wb, err = server:new{
	timeout = 5000,
	max_payload_len = 65535
}

if not wb then
	ngx.log(ngx.ERR, "failed to new websocket: ", err)
	return ngx.exit(444)
end

m.set(wb)
local function call(k, s)
	return k:send_text(s)
end

while true do
	local data, typ, err = wb:recv_frame()
	
	if wb.fatal then
		ngx.log(ngx.ERR, "failed to receive frame: ", err)
		return ngx.exit(444)
	end
	
	if not data then
		local bytes, err = wb:send_ping()
		if not bytes then
			ngx.log(ngx.ERR, "failed to send ping: ", err)
			return ngx.exit(444)
		end
	elseif typ == "close" then break
	elseif typ == "ping" then
		local bytes, err = wb:send_pong()
		if not bytes then
			ngx.log(ngx.ERR, "failed to send pong: ", err)
			return ngx.exit(444)
		end
	elseif typ == "pong" then
		ngx.log(ngx.INFO, "client ponged")
	elseif typ == "text" then
		local wbs, x = m.get()

		for k, v in pairs(wbs) do
			ngx.log(ngx.ERR,"@@@@@@@@@@@@@@@@@@@@@@@@@@@@ wb> " .. tostring(k) .. " " .. tostring(#wbs) .. " " .. tostring(x) .. " @@@@@@@@@@@")
			local bytes, err = pcall(call, k, "1234" .. data:upper())
		end
		if false and not bytes then
			ngx.log(ngx.ERR, "failed to send text: ", err)
			return ngx.exit(444)
		end
	end
end

m.remove(wb)
wb:send_close()
