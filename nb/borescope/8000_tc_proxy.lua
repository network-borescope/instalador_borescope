------------------------------------------------------------------------------ 
--
-- POST PROXY
--
------------------------------------------------------------------------------ 
local http = require "resty.http"
local cjson = require "cjson"

-- registra o inicio dos tempos
local start_time = os.clock()
ngx.log(ngx.ERR,"++++++++++++++++++ " .. start_time .. " +++++++")

-- sรณ POST
if ngx.req.get_method() ~= 'POST' then
	return
end

-- prepara o http request
local httpc = http.new() 
httpc:set_timeout(60000)


ngx.req.read_body()
local req_body = ngx.req.get_body_data()
local req_json = cjson.decode(req_body) or ""

local process_elapsed_time = false


--[[ 
*************************************************************************
	URL
*************************************************************************
--]]
local url 
url = req_json.from or ""
ngx.log(ngx.ERR,"<<<<<<<<<<<<< " .. url .. " >>>>>>>>>>")

url = ""

if url == "" then
	url = "http://127.0.0.1:9001/tc/query"
elseif url:sub(1,7) ~= "http://" then
	if url == "ttl" or url=="ttls" then
		url = "http://127.0.0.1:9105/tc/query"
	elseif url=="serv" then
		url = "http://127.0.0.1:9005/tc/query"
	elseif url=="dns" then
		url = "http://127.0.0.1:9005/tc/query"
	else
		url = "http://127.0.0.1:9105/tc/query"
	end
end

--url = "http://127.0.0.1:9105/tc/query"

--ngx.log(ngx.ERR,"<<<<<<<<<<<<< " .. url .. " >>>>>>>>>>")


--[[ 
*************************************************************************
	http request
*************************************************************************
--]]

---------------------------------------------
--
---------------------------------------------
local function raw_perform_http_request(httpc, url, req_body) 
	ngx.log(ngx.ERR,"++++++++++++++++++ URL: " .. url .. " +++++++")
	local res, err = httpc:request_uri(
		url, {
		method = "POST",
		body = req_body,
	--	headers = {
	--		--        	["Content-Type"] = "application/x-www-form-urlencoded",
	--	},
		keepalive_timeout = 60000,
		keepalive_pool = 100
	}) 

	--
	-- Verifica a ocorrencia de algum erro
	--
	if not res then
		ngx.log(ngx.ERR,"@@@@@@@@@@@@@@ failed to request: "..err) 
		ngx.say("failed to request: ", err)
		return 
	end 
	
	return res
end


---------------------------------------------
-- Do request
---------------------------------------------

local res = raw_perform_http_request(httpc, url, req_body)
ngx.header.content_type = "application/json; charset=utf-8"
if res then 
	ngx.say(res.body)
else
	ngx.say('{"tp":0, "err":"2909923" }')
end
ngx.eof()