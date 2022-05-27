local shell = require "resty.shell"

if ngx.worker.id() ~= 0 then return end

local script = "/home/ubuntu/tc_test/scripts/nginx_cron_test.sh"
local cmd = "sudo -u ubuntu ./" .. script
--local cmd = script

-- When the stdin argument is nil or "", the stdin device will immediately be closed.
local stdin = nil

-- The timeout argument specifies the timeout 
-- threshold (in ms) for stderr/stdout
-- reading timeout, stdin writing timeout,
-- and process waiting timeout.
local timeout = 1000

-- The max_size argument specifies the maximum size
-- allowed for each output data stream of stdout and stderr.
local max_size = 4096

function run_script()
	local ok, stdout, stderr, reason, status = shell.run(cmd, stdin, timeout, max_size)
	
	if not ok then
		ngx.log(ngx.ERR,"@@@@@@@@@@@@@@@@@@@@@@@ XXXXXXXXXXXXXShell Run Error(stderr):" .. stderr .. " +++++++")
		return
	end
end

ngx.timer.every(60, run_script)
