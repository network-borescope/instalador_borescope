-- ngx.say("Hello")
 
local http = require "resty.http"
local cjson = require "cjson"

-----------------------------------------------------------------

--local capture = ngx.location.capture
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait
local say = ngx.say

local function fetch(uri)
	local httpc = http.new() 
	say("call: ", uri)
	
	local res, err = httpc:request_uri(uri)
	
	-- ngx.log(ngx.ERR,"@@@@@@@@@@@@@@ : "..res) 

	-- say("res: ", res or "-")
	
	if not res then	
		return err
	end
	return res
end

local threads = {
	spawn(fetch, "http://www.midiacom.uff.br/"),
	spawn(fetch, "http://www.midiacom.uff.br/"),
}

for i = 1, #threads do
	 local ok, res = wait(threads[i])
	say("-----")
	say(i,ok)
	say(i,type(res)~="table" or res.body)
	 
	 if not ok then
		 -- say(i, ": failed to run: ", res)
	 else
		 --say(i, ": status: ", res.status)
		 --say(i, ": body: ", res.body)
	 end
end