------------------------------------------------------------------------------ 
--
-- POST PROXY
--
------------------------------------------------------------------------------ 
local http = require "resty.http"
local cjson = require "cjson"

local start_time = os.clock()
-- ngx.log(ngx.ERR,"++++++++++++++++++" .. start_time .. "+++++++")

if ngx.req.get_method() ~= 'POST' then
	return
end

ngx.req.read_body()
local req_body = ngx.req.get_body_data()

local req_json = cjson.decode(req_body) or ""
local process_time = false

local group_by = req_json["group-by"]
if group_by ~= nil then
	if type(group_by) == "table" then
		group_by = group_by.field
	end
	if type(group_by) == "string" then
		if group_by == "time" then
			process_time = true
			-- ngx.log(ngx.ERR,"++++++++++++++++++" .. "time" .. "+++++++")
		end
	end
	
end


local url 
url = req_json.from or req_json.src or req_json.url or ""
-- ngx.log(ngx.ERR,"<<<<<<<<<<<<< " .. url .. " >>>>>>>>>>")

if url == "" then
	url = "http://127.0.0.1:8001/tc/query"
elseif url:sub(1,7) ~= "http://" then
	if url == "covid" or url == "COVID" then
		url = "http://127.0.0.1:8002/tc/query"
	elseif url=="antenas" then
		url = "http://127.0.0.1:8001/tc/query"
	elseif url=="rnp" then
		url = "http://127.0.0.1:8006/tc/query"
	else
		url = "http://127.0.0.1:8001/tc/query"
	end
end

local h = ngx.req.get_headers()
local origin = "*" -- h["Origin"] 

-- ngx.header["Access-Control-Allow-Origin"] = origin

local httpc = http.new() 
httpc:set_timeout(60000)

--
-- Faz o request
--
local res, err = httpc:request_uri(
	url, {
	method = "POST",
	body = req_body,
--	headers = {
--		--        	["Content-Type"] = "application/x-www-form-urlencoded",
--	},
	keepalive_timeout = 60000,
	keepalive_pool = 10
}) 

--
-- Verifica a ocorrencia de algum erro
--
if not res then
	ngx.log(ngx.ERR,"@@@@@@@@@@@@@@ failed to request: "..err) 
	ngx.say("failed to request: ", err)
	return
end 

local end_time = os.clock()
local ms = math.floor((end_time - start_time) * 1000)
-- ngx.log(ngx.ERR,"++++++++++++++++++" .. ms .. "+++++++")


if false and process_time then 
	local jres = cjson.decode(res.body)
	local result = jres.result
	
	
	local n = #result
	local tmp
	local n2 =  math.floor(n / 2)

	for i = 1, n2 do
		tmp = result[i][2]
		result[i][2] = result[n-i+1][2] 
		result[n-i+1][2] = tmp
	end
	
	
	jres.ms0 = jres.ms
	jres.ms = ms + jres.ms0
	res.body = cjson.encode(jres)
end

--
-- envia o resultado
--
-- ngx.header.content_type = 'text/plain';
ngx.header.content_type = "application/json; charset=utf-8" 
ngx.say(res.body)
ngx.eof()

