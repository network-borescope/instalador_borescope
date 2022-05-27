---------------------------------------------------------
--
-- Preparation
--
--------------------------------------------------------

-- reject non POST connections 
if ngx.req.get_method() ~= 'POST' then return end

-- load body to transfer area
ngx.req.read_body()

-- store the request body into variable
local post_body_str = ngx.req.get_body_data()

---------------------------------------------------------
--
-- Compile the tsql source
--
--------------------------------------------------------

local tcql = require "lib_tcql"

-- call the compiler
local ok, instructions = pcall(tcql.compile_tsql, post_body_str)

-- check for a major error
if not ok then
	-- in case of error, json_queries has the error string
	ngx.say(instructions)
	return
end

---------------------------------------------------------
--
-- Execute the compiled instructions
-- 
--------------------------------------------------------
local base = require "lib_nx_base"
local tc = require "lib_tc_functions"
local cjson = require "cjson"
--local pylink = require "pylink" -- Arthur

local variables = {}

-- process all compiled json_queries
local responses = {}
local last_response_str

-- ngx.log(ngx.ERR,"--------------------------------------")
for k,v in ipairs(instructions) do
	--ngx.log(ngx.ERR,"++++++++++++++++++ into>" .. tostring(v._into) .. " +++++++")
	if v.err then 
		table.insert(responses, v.err) -- v[1] has the compiler error
		
	elseif v._list then -- Arthur
		table.insert(responses, v._list)

	elseif v._return then 
		for _, varname in ipairs(v._return) do
			local response = variables[varname]
			if not response then
				table.insert(responses, tc.buildError('Unknonwn variable '.. v._return))
			else
				table.insert(responses, response)
			end
		end
		
	elseif v._call then 
		-- ngx.log(ngx.ERR,"======== CALL:" .. tostring(1) .. " +++++++")
		local c = v._call

		local function bind_args_variables(args, vars)
			-- binds free variables
			for i, var in ipairs(vars) do
				local name = var.name
				local content = variables[name]
				if not content then 
					return "Undefined variable: "..name
				else 
					local js = cjson.decode(content)
					if not js or not js.result then 
						return "Invalid variable content : "..name
					end
					c.args[var.position] = js.result
				end
			end
		end

		local err = bind_args_variables(c.args, c.vars) 
		if err then
			table.insert(responses, tc.buildError(res))
		else
			-- chama a proc
			last_response_str = c.proc(c.args)
			
			if v._into then 
				-- ngx.log(ngx.ERR,"++++++++++++++++++ saving CALL var:" .. tostring(v._into) .. " +++++++")
				variables[v._into] = last_response_str
			else
				table.insert(responses, last_response_str)
			end
		end
		
		
	else
		local tc_cache = ngx.shared.tc_cache
		local query_str = v.js
		
		if v._fresh then 
			last_response_str = nil
		else
			last_response_str  = tc_cache:get(query_str)
		end
		
		if not last_response_str  then 
			last_response_str = base.body_request(query_str, v.url)
			--local last_response_str2 = pylink.connect(last_response_str) -- Arthur
			--if last_response_str2 then -- Arthur
				--last_response_str = last_response_str2 -- Arthur
			--end -- Arthur
			if not last_response_str:find('"err":') then 
				local c = last_response_str:sub(1, #last_response_str-1) .. ', "cached": 1}'
				tc_cache:set(query_str, c, 60)
			end
		end

		if v._into then 
			-- ngx.log(ngx.ERR,"++++++++++++++++++ saving Q var:" .. tostring(v._into) .. " +++++++")
			variables[v._into] = last_response_str
		else
			table.insert(responses, last_response_str)
		end
	end
end

---------------------------------------------------------
--
-- Prepare the final result
-- 
--------------------------------------------------------


local final_result
if #responses == 1 then
	final_result = responses[1]
else 
	-- combine all queries responses into a single array
	final_result = "[" .. table.concat(responses, ",") .. "]"
end

-- send back the final_result
ngx.header.content_type = "application/json; charset=utf-8"
ngx.say(final_result)
ngx.eof()

