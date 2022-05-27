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

-- só POST
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
url = req_json.from or req_json.src or req_json.url or ""
-- ngx.log(ngx.ERR,"<<<<<<<<<<<<< " .. url .. " >>>>>>>>>>")

if url == "" then
	url = "http://127.0.0.1:9105/tc/query"
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

url = "http://127.0.0.1:9105/tc/query"

ngx.log(ngx.ERR,"<<<<<<<<<<<<< " .. url .. " >>>>>>>>>>")


--[[ 
*************************************************************************
	http request
*************************************************************************
--]]

---------------------------------------------
--
---------------------------------------------
local function raw_perform_http_request(httpc, url, req_body) 
	-- ngx.log(ngx.ERR,"++++++++++++++++++ URL: " .. url .. " +++++++")
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
--
---------------------------------------------
local function perform_http_request(httpc, url, req_body) 

	local res = raw_perform_http_request(httpc, url, req_body) 

	if res then 
		local json = cjson.decode(res.body)
		return res, json
	end
end

--[[ 
*************************************************************************
	what queries

	{ "what": "matrix", "metric": "throughtput", "start": epoch0, "end": epoch1 }
	
	{ "result": [ 1, 2, val ], .... [ 27, 26, val ] }

*************************************************************************
--]]

local what = req_json["what"] or ""
local dt_start = req_json["start"] or "1"
local dt_end = req_json["end"] or "2000000000"
local metric = req_json["metric"] or ""
local field = req_json["field"] or ""

local idpop = req_json["idpop"] or 1
local ncols = req_json["ncols"] or 7
local colsize = req_json["colsize"] or 86400

local use_multi_query = not (req_json["single"] or false)
-- ngx.log(ngx.ERR,"++++++++++++++++++ UseMultipleQuery: " .. tostring(use_multi_query) .. "+++++++")

local min_matrix_time = 0
local max_matrix_time = 0

---------------------------------------------
--
---------------------------------------------
local function build_matrix_query_string(src, dst, field, metric, dt0, dt1, id)
	id = tostring(id or 0)
	local query = '{"id": '..id..', "select": "' .. field.. 
	              '", "where": [["metric","eq",' .. metric ..
				  '], ["time", "between",' .. dt0 ..','.. dt1 ..
				  '],["src","eq",'.. src ..'],["dst","eq",'.. dst ..'] ] }'
					-- performs
	return query
end


---------------------------------------------
--
---------------------------------------------
local function perform_matrix_query(src, dst, field, metric, dt0, dt1, id)
	
	id = id or 0
	local query = build_matrix_query_string(src, dst, field, metric, dt0, dt1)

	--[=[
	local query = '{"select": "' .. field.. 
	              '", "where": [["metric","eq",' .. metric ..
				  '], ["time", "between",' .. dt0 ..','.. dt1 ..
				  '],["src","eq",'.. src ..'],["dst","eq",'.. dst ..'] ] }'
					-- performs
	--]=]
					
	local res, json = perform_http_request(httpc, url, query)
	
	local body = ""
	if res then 
		body = res.body 
		if json.tp == 0 then return -1 end
		return json.result[1]
	end
	
	ngx.log(ngx.ERR,"++++++++++++++++++ FAILURE Body: " .. query .. " -> " .. body .. "+++++++")
	return -1
end

---------------------------------------------
--
---------------------------------------------
local function perform_coltime_query(src, dst, field, metric, dt0, colsize, id)
	local dt1 = dt0 + colsize - 1
	
	id = tostring(id or 0)
	local query = '{"id": '..id..', "select": "' .. field.. 
	              '", "where": [["metric","eq",' .. metric ..
				  '], ["time", "between",' .. dt0 ..','.. dt1 ..
				  '],["src","eq",'.. src ..'],["dst","eq",'.. dst ..'] ] }'
					-- performs
					
	local res, json = perform_http_request(httpc, url, query)
	
	local body = ""
	-- ngx.log(ngx.ERR,"++++++++++++++++++ FAILURE Body: " .. query .. " -> " .. body .. "+++++++")
	if res then 
		body = res.body 
		if json.tp == 0 then return -1 end
		return json.result[1]
	end
	
	ngx.log(ngx.ERR,"++++++++++++++++++ FAILURE Body: " .. query .. " -> " .. body .. "+++++++")
	return -1
end

---------------------------------------------
--
---------------------------------------------
local function forge_matrix_result(matrix,n_cols, suffix) 
	local s = '{"result": ['
	local sep = ''
	for i = 1, 27 do
		for j = 1, n_cols do
			s = s .. sep .. '[' .. i .. ',' .. j .. ',' .. matrix[i][j] .. ']'
			sep = ','
		end
	end
	suffix = suffix or ""
	s = s .. ']' .. suffix .. '}'
	return s
end

---------------------------------------------
--
---------------------------------------------
local function forge_timecol_result(matrix, n_cols, start, colsize) 
	local s = '{"result": ['
	local sep = ''
	for i = 1, 27 do
		local tm = start
		for j = 1, n_cols do
			s = s .. sep .. '[' .. i .. ',' .. tm .. ',' .. matrix[i][j] .. ']'
			sep = ','
			tm = tm + colsize
		end
	end
	s = s .. ']}'
	return s
end

---------------------------------------------
--
---------------------------------------------
local function perform_simple_matrix_query()
	local matrix = { }
	for i = 1, 27 do
		local row = {}
		for j = 1, 27 do
			local value = 0
			if i ~= j then 
				value = perform_matrix_query(i, j, field, metric, dt_start, dt_end)
			end
			table.insert(row, value)
		end
		table.insert(matrix, row)
	end
	-- envia a matrix como resultado
	local result_str = forge_matrix_result(matrix,27)
	return result_str
end

---------------------------------------------
--
---------------------------------------------
local function perform_multiple_matrix_query()

	-- init result matrix with zeros
	local matrix = {}
	for i = 1, 27 do
		local row = {}
		for j = 1, 27 do table.insert(row, 0) end
		table.insert(matrix, row)
	end

	local multi = {}
	table.insert(multi,"#multiple ")
	for i = 1, 27 do
		for j = 1, 27 do
			local value = 0
			if i ~= j then 
				query = build_matrix_query_string(i, j, field, metric, dt_start, dt_end)
				table.insert(multi,query)
			end
		end
	end
	
	-- query bounds
	local query_bounds = '{"bounds":"time", "id":23}'
	-- table.insert(multi,query_bounds)
    	
	local multi_query = table.concat(multi,"\r\n#query\r\n")

	-- debug
	-- if true then return end
	-- ngx.log(ngx.ERR,"++++++++++++++++++ Multi: " .. multi_query .. "+++++++")
	-- if true then return end

	local res = raw_perform_http_request(httpc, url, multi_query) 
	-- ngx.log(ngx.ERR,"++++++++++++++++++ Answer: " .. res.body .. "+++++++")
	
	local suffix
	
	if res then
		local body = res.body
		local p0 = 1
		local pa, ea, pe, ee
		for i = 1, 27 do
			for j = 1, 27 do
				if i ~= j then 
					pa, ea = body:find('#answer\r\n', p0)
					if pa then 
						pe, ee = body:find('#end\r\n', pa+1)
						local qstr = body:sub(ea+1, pe-1)
						local json = cjson.decode(qstr)
						matrix[i][j] = json.result[1]
						p0 = ee + 1
					end
				end
			end
		end
		-- retira a query de bounds
		--[[
		pa, ea = body:find('#answer\r\n', p0)
		if pa then 
			pe, ee = body:find('#end\r\n', pa+1)
			local qstr = body:sub(ea+1, pe-1)
			ngx.log(ngx.ERR,"++++++++++++++++++ QSTR: " .. qstr .. "+++++++")
			local json = cjson.decode(qstr)
			local bounds_1 = json.result.vs[1][1]
			local bounds_2 = json.result.vs[1][2]
			suffix = ', "min_matrix_epoch": '..tostring(bounds_1)..', "max_matrix_epoch": '..tostring(bounds_2)..' '
			p0 = ee + 1
		end
		--]]
	end
	-- envia a matrix como resultado
	local result_str = forge_matrix_result(matrix,27, suffix)
	return result_str
end

--[[ 
*************************************************************************
	What processing
*************************************************************************
--]]

if what ~= "" then
	if what == "matrix" then

		if field == '' or metric == '' then 
			ngx.header.content_type = "application/json; charset=utf-8" 
			ngx.say('Error')
			ngx.eof()
			return
		end

		--[[
		local matrix = { }
		for i = 1, 27 do
			local row = {}
			for j = 1, 27 do
				local value = 0
				if i ~= j then 
					value = perform_matrix_query(i, j, field, metric, dt_start, dt_end)
				end
				table.insert(row, value)
			end
			table.insert(matrix, row)
		end
		-- envia a matrix como resultado
		local result_str = forge_matrix_result(matrix,27)
		--]]

		local result_str
		if use_multi_query then
			result_str = perform_multiple_matrix_query()
		else 
			result_str = perform_simple_matrix_query()
		end
		
		body = cjson.encode(result_str)
		--body.min_matrix_epoch = 1
		--body.max_matrix_epoch = 2000000000
		
		ngx.header.content_type = "application/json; charset=utf-8" 
		ngx.say(body)
		ngx.eof()
		return
		
	elseif what == "timecolumns" then

		if field == '' or metric == '' then 
			ngx.header.content_type = "application/json; charset=utf-8" 
			ngx.say('Error')
			ngx.eof()
			return
		end
		
		local fuso_segundos = 0 ---3 * 3600
		-- dt_start = math.floor(dt_start/86400) * 86400 + fuso_segundos
		
		local matrix = { }
		for dst = 1, 27 do
			local row = {}
			local value = 0
			local dt = dt_start
			for i = 1, ncols do
				value = perform_coltime_query(idpop, dst, field, metric, dt, colsize)
				if value ~= 0 then
					ngx.log(ngx.ERR,"++++++++++++++++++ Value: " .. value .. " +++++++")
				end
				table.insert(row, value)
				dt = dt + colsize
			end
			table.insert(matrix, row)
		end
		
		-- envia a matrix como resultado
		local result_str = forge_timecol_result(matrix, ncols, dt_start, colsize)
		
		body = cjson.encode(result_str)
		
		ngx.header.content_type = "application/json; charset=utf-8" 
		ngx.say(body)
		ngx.eof()
		return
	end

end 


--[[ 
*************************************************************************
	group by projection
*************************************************************************
--]]

local group_by = req_json["group-by"]

local project_result = false
local min_k, max_k, n_points, k_mode, v_mode, field
local group_by_output

if group_by ~= nil then
		
	-- descompacta field e extrai parametros
	if type(group_by) == "table" then
		min_k = group_by["min-k"]
		max_k = group_by["max-k"]
		n_points = group_by["n-points"]
		bin_size = group_by["bin-size"]
		k_mode = group_by["k"]
		v_mode = group_by["v"]
		field = group_by["field"]
		
		if min_k and max_k and (n_points or bin_size) then
			project_result = true
			group_by_output = tostring(req_json["group-by-output"])
			req_json["group-by-output"] = "kv"
			req_body = cjson.encode(req_json)
		end
		
		group_by = group_by.field
	end
	
	if type(group_by) == "string" then
		if group_by == "time" then
			process_ellapsed_time = true
			-- ngx.log(ngx.ERR,"++++++++++++++++++" .. "time" .. "+++++++")
		end
	end
	
end

--------------------------
-- Faz o http request
--------------------------

res = perform_http_request(httpc, url, req_body) 
if not res then return end

--[[
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
--]]

local end_time = os.clock()
local ms = math.floor((end_time - start_time) * 1000)
-- ngx.log(ngx.ERR,"++++++++++++++++++" .. ms .. "+++++++")

if false and process_ellapsed_time then 
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

--[[ 
*************************************************************************

	group-by result reduction 

*************************************************************************
--]]

local P_INDEX = 1
local P_MIN = 2
local P_MAX = 3
local P_SUM = 4
local P_N = 5
local P_FIRST = 6
local P_LAST = 7


-----------------------------
--
--
--
-----------------------------
local function extract_ks_vs_tp2(res) 
	
	if res.tp ~= 2 then return end
	result = res.result
	n = #result
	
	ks = {}
	vs = {}
	for i = 1, n do
		o = result[i]
		table.insert(vs,o.v[1])
		table.insert(ks,o.k[1])
	end
	return n, ks, vs
end

--
--
--
--
--
local function result_projection(min_k, max_k, n, ks, vs, n_pos)
    local delta_k = max_k - min_k

    local out = {}
    for i = 1, n_pos do
        out[i] = { }
    end
        
	ngx.log(ngx.ERR,"++++++++++++++++++ " .. "n_pos: " .. tostring(n_pos) .. "  " .. tostring(delta_k) .. " +++++++")
    local min_v, max_v, sum_v, n_v, vi, last_v, v
    local last_pos = -1
    
    local n_ks = #ks
    for i = 1, n_ks do
        local k = ks[i]
        last_v = v
        v = vs[i]
        
        local pos = math.floor(((k - min_k) / delta_k - 0.000001) * n_pos ) + 1
    
        if pos ~= last_pos then
			-- ngx.log(ngx.ERR,"++++++++++++++++++ " .. "last_pos: " .. tostring(k) .. "  " .. tostring(pos) .. " +++++++")
            if last_pos ~= -1 and last_pos <= n_pos then
                out[last_pos] = { last_pos-1, min_v, max_v, sum_v, n_v, vi, last_v }
            end
            
            last_pos = pos
            vi = v
            min_v, max_v, sum_v = v, v, v
            n_v = 1
        else
			-- ngx.log(ngx.ERR,"++++++++++++++++++ " .. "pos: " .. tostring(k) .. "  " .. tostring(pos) .. " +++++++")
            sum_v = sum_v + v
            n_v = n_v + 1
            if v < min_v then min_v = v end
            if v > max_v then max_v = v end
        end
    end
    
    if last_pos ~= -1 and last_pos <= n_pos then
        out[last_pos] = { last_pos-1, min_v, max_v, sum_v, n_v, vi, last_v }
    end
    return out
end

--
--
--
--
--
local function result_projection_bin(min_k, max_k, n, ks, vs, bin_size)
	local min_k0 = min_k - (min_k % bin_size)
	local max_k0 = max_k - (max_k % bin_size)
	
	local n_pos = math.floor((max_k0 - min_k0) / bin_size)

    local out = {}
    for i = 1, n_pos do
        out[i] = { }
    end
        
--	ngx.log(ngx.ERR,"++++++++++++++++++ " .. "  " .. tostring(min_k0) .. tostring(n_pos) .. "  " .. " +++++++")
    local min_v, max_v, sum_v, n_v, vi, last_v, v
    local last_pos = -1
    
    local n_ks = #ks
    for i = 1, n_ks do
        local k = ks[i]
        last_v = v
        v = vs[i]
        
        local pos = math.floor((k - min_k0) / bin_size)  + 1
    
        if pos ~= last_pos then
            if last_pos ~= -1 and last_pos <= n_pos then
                out[last_pos] = { last_pos-1, min_v, max_v, sum_v, n_v, vi, last_v }
            end
            
            last_pos = pos
            vi = v
            min_v, max_v, sum_v = v, v, v
            n_v = 1
        else
            sum_v = sum_v + v
            n_v = n_v + 1
            if v < min_v then min_v = v end
            if v > max_v then max_v = v end
        end
    end
    
    if last_pos ~= -1 and last_pos <= n_pos then
        out[last_pos] = { last_pos-1, min_v, max_v, sum_v, n_v, vi, last_v }
    end
    return min_k0, max_k0, out, n_pos
end

-- [[

------------------------------------------------------------------
local function get_points(points, min_k, max_k, n, fmt)
	local find = string.find
	local insert = table.insert
	
	local delta_k = max_k - min_k

	k_mode = string.upper(k_mode or "")
	if k_mode == "" then  k_mode =  'K' end

	local plot_k = (find(k_mode, "K") ~= nil)
	local plot_i = (find(k_mode, "O") ~= nil) and not plot_k

	v_mode = string.upper(v_mode or "")
	if v_mode == "" then  v_mode =  'A' end

	local plot_a = (find(v_mode, "A") ~= nil)
	
	local plot_m = (find(v_mode, "M") ~= nil)

	local plot_s = (find(v_mode, "S") ~= nil)
	local plot_n = (find(v_mode, "N") ~= nil)

	local plot_p = (find(v_mode, "P") ~= nil)
	local plot_l = (find(v_mode, "L") ~= nil) and not plot_p

	local plot_b = (find(v_mode, "B") ~= nil) and not plot_p and not plot_l
	local plot_t = (find(v_mode, "T") ~= nil) and not plot_p and not plot_l

	--local plot_f = (find(v_mode, "F") ~= nil) and not plot_p 
	--local plot_l = (find(v_mode, "L") ~= nil) and not plot_p 

	local result = {}
	if fmt ~= "vs_ks" then 
		for i = 1, n do
			local p = points[i]
			if (p[1] ~= nil) then

				local out_k = {}
				if plot_i then insert(out_k, p[1]) end

				if plot_k then 
					local k = math.floor((p[1] * delta_k) / n) + min_k
					insert(out_k, k ) 
				end
				
				local out = {}
				
				if plot_a then insert(out, math.floor((p[P_MIN]+p[P_MAX])/2)) end
				
				if plot_m then insert(out, math.floor(p[P_SUM]/p[P_N])) end

				if plot_b then insert(out, p[P_MIN]) end

				if plot_t then insert(out, p[P_MAX]) end
				
				if plot_l then 
					insert(out, p[P_MIN]) 
					insert(out, p[P_MAX]) 
				end

				if plot_p then 
					insert(out, p[P_MIN]) 
					insert(out, p[P_MAX]) 
					insert(out, p[P_FIRST]) 
					insert(out, p[P_LAST]) 
				end
				
				if plot_s then insert(out, p[P_SUM]) end

				if plot_n then insert(out, p[P_N]) end

				local t = {}
				t.k = out_k
				t.v = out
				table.insert(result, t)
				
				-- s = table.concat(out,", ")
				-- if s ~= "" then print(s) end
				-- print(out[i][1], out[i][2], out[i][3], out[i][4], out[i][5], out[i][6], out[i][7] )
			end
		end
	else 
		for i = 1, n do
			local p = points[i]
			if (p[1] ~= nil) then

				local out = {}
				
				if plot_a then insert(out, math.floor((p[P_MIN]+p[P_MAX])/2)) end
				
				if plot_m then insert(out, math.floor(p[P_SUM]/p[P_N])) end

				if plot_b then insert(out, p[P_MIN]) end

				if plot_t then insert(out, p[P_MAX]) end
				
				if plot_l then 
					insert(out, p[P_MIN]) 
					insert(out, p[P_MAX]) 
				end

				if plot_p then 
					insert(out, p[P_MIN]) 
					insert(out, p[P_MAX]) 
					insert(out, p[P_FIRST]) 
					insert(out, p[P_LAST]) 
				end
				
				if plot_s then insert(out, p[P_SUM]) end

				if plot_n then insert(out, p[P_N]) end

				if plot_i then insert(out, p[1]) end
				if plot_k then 
					local k = math.floor((p[1] * delta_k) / n) + min_k
					insert(out, k ) 
				end
				
				table.insert(result, out)
				
			end
		end

	end
	return result
end

--]]


if project_result then
	-- ngx.log(ngx.ERR,"++++++++++++++++++ " .. "PROJECT_RESULT" .. " +++++++")
	local jres = cjson.decode(res.body)
	if jres.tp == "0" or jres.tp == 0 then
		-- ngx.log(ngx.ERR,"++++++++++++++++++ " .. "ZERO" .. " +++++++")
	else
		local n, ks, vs = extract_ks_vs_tp2(jres)
		local points
		if bin_size == nil then 
			points = result_projection(min_k, max_k, n, ks, vs, n_points)
		else
			min_k, max_k, points, n_points = result_projection_bin(min_k, max_k, n, ks, vs, bin_size)
		end
		local result = get_points(points, min_k, max_k, n_points, group_by_output) 
		jres.result = result
		jres.min_k = min_k
		jres.max_k = max_k
		jres.n_points = n_points
		jres.delta_k = max_k - min_k
		jres.fmt = group_by_output
		
		res.body = cjson.encode(jres)
	end 
end

--
-- envia o resultado
--
-- ngx.header.content_type = 'text/plain';
ngx.header.content_type = "application/json; charset=utf-8" 
ngx.say(res.body)
ngx.eof()

