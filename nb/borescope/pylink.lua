local _M = {}

local HOST = "127.0.0.1"
local PORT = 8080
local sock = ngx.socket.tcp()


---------------------------------------------------------
--
-- Send "data" to be processed by server(python) using tcp socket
--
--------------------------------------------------------
function _M.connect(data)
	sock:settimeout(1000) -- Timeout for the connect/send/receive operations
	
	local ok, err = sock:connect(HOST, PORT)
	if not ok then
		ngx.log(ngx.ERR,"||||||||||||||||||||||||||| Pylink Connect Error:" .. err .. " +++++++")
		return
	end
	
	-- send data to be processed by python tcp server
	local bytes, err = sock:send(data .. "\r\n\r\n") -- returns the total number of bytes that have been sent.
	if not bytes then
		ngx.log(ngx.ERR,"||||||||||||||||||||||||||| Pylink Send Error:" .. err .. " +++++++")
		return
	end
	
	-- receive data processed by python tcp server
	local processed_data, err, partial = sock:receive('*a') -- reads from the socket until the connection is closed.
	if not processed_data then
		ngx.log(ngx.ERR,"||||||||||||||||||||||||||| Pylink Receive Error:" .. err .. " +++++++")
		return
	end
	
	sock:close() -- close connection
	return processed_data
end


return _M
