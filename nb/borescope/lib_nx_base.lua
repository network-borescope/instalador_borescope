local _m = {}

-- local ngx = ngx or nil
    
------------------------------------------------------------------------------ 
--
-- MAP URL
--
------------------------------------------------------------------------------ 

--[[
local default_url = "http://127.0.0.1:9001/tc/query"

local from_to_url = {
    
    rnp_ttls = "http://127.0.0.1:9001/tc/quer",
    rnp_serv = "http://127.0.0.1:9002/tc/query",
    rnp_dns = "http://127.0.0.1:9003/tc/query",

    perfsonar = "http://127.0.0.1:9105/tc/query",
}
--]]



-------------------------------------
--
--
--
--
function _m.map_from_to_url(from)
    if not from or from == '' then return default_url end
    return  from_to_url[from] or default_url
end


------------------------------------------------------------------------------ 
--
-- post_request
--
------------------------------------------------------------------------------ 
local http = require "resty.http"
local httpc = http.new() 
httpc:set_timeout(60000)

-------------------------------------
--
-- Faz o request
--
function _m.post_request(url, body, options)
    local res, err = httpc:request_uri(
    	url, {
    	method = "POST",
    	body = body,
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
        ngx.log(ngx.ERR,"failed to request: "..err) 
        -- ngx.say("failed to request: ", err)
		error(err)
        return
	elseif res.body:sub(1,1) ~= "{" then
		error(res.body)
	end 
   
    return res
end


------------------------------------------------------------------------------ 
--
-- 
--
------------------------------------------------------------------------------ 
local cjson = require "cjson"



-------------------------------------
--
--
--
--
local function body_request(body_str, url)

    -- convert request body to json
    local body_json = cjson.decode(body_str) or ""

    -- map url
    --url = url or _m.map_from_to_url(body_json.from)
	url = url or nil
	
	-- ngx.log(ngx.ERR,"++++++++++++++++++" .. url .. "+++++++")

    -- fix 'group by' array call
    local group_by = body_json["group-by"]
    if group_by and type(group_by) == "table" then body_json["group-by"] = group_by.field end
    
    local h = ngx.req.get_headers()
    local origin = "*" -- h["Origin"] 
    -- ngx.header["Access-Control-Allow-Origin"] = origin
    
	--ngx.log(ngx.ERR,"++++++++++++++++++" .. url .. "+++++++")
    local res_table = _m.post_request(url, body_str)
	--ngx.log(ngx.ERR,"++++++++++++++++++" .. tostring(res_table.body) .. "+++++++")
    
    return res_table.body
--[[

    local end_time = os.clock()
    local us = math.floor(end_time - start_time)

    --
    -- envia o resultado
    --
    -- ngx.header.content_type = 'text/plain';
    ngx.header.content_type = "application/json; charset=utf-8" 
    ngx.say(res_table.body)
    ngx.eof()
--]]
end

-------------------------------------
--
--
--
--
function _m.body_request(body_str, url)
	local ok, res = pcall(body_request, body_str, url)
	if ok then return res end
	return string.format('{ "tp":0, "id":%d, "err": "%s"}', 0, res)
end

-------------------------------------
--
--
--
--
function _m.full_request()

    -- refuse non POST request
    if ngx.req.get_method() ~= 'POST' then return end

    -- statistics
    local start_time = os.clock()

    -- preprare access to request body
    ngx.req.read_body()

    -- retrieve the request body as a string    
    local body_str = ngx.req.get_body_data()

    return _m.body_request(body_str)
end


return _m