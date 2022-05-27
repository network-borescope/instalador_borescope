local hosts = require "lib_tc_hosts"

ngx.time.at(0, hosts.load_all_hosts())

--[[
local hosts = ngx.shared.hosts
hosts = {
	false,
	rnp_ttls = { url = "http://127.0.0.1:9001/tc/query" }
}
--]]