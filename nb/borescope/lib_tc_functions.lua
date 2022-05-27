local _m = {}

-------------------------------------
--
--
--
--
function _m.wrap_error_message(err, id)
	id = id or 0
    return string.format('{ "tp":0, "id":%d, "err": "%s"}', id, err)
end

-------------------------------------
--
--
--
--
function _m.buildError(err)
    return string.format('{ "tp":0, "id":0, "err": "%s"}', err)
end

-------------------------------------
--
--
--
--
function _m.wrap_error_message(err)
    return string.format('{ "tp":0, "id":0, "err": "%s"}', err)
end


-------------------------------------
--
--
--
--
function _m.str_to_epoch(s)
    local year, month, day, hour, min, sec
    if not s:find(" ") then
        -- date only
        year, month, day = s:match("(%d+)-(%d+)-(%d+)");  hour, min, sec = 0, 0, 0
    else
        -- date time
        year, month, day, hour, min, sec = s:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    end
    if (not year) or (not month) or (not day) then error("Invalid date: "..s) end
    local offset = os.time() - os.time(os.date("!*t"))
    local tm = os.time({day=day,month=month,year=year,hour=hour,min=min,sec=sec}) + offset
    -- print(s, tm, os.date("!%c",tm))
    return tm
end

------------------------------------------------------------------------------ 
--
--                             GROUP BY PROJECTION 
--
------------------------------------------------------------------------------ 

-----------------------------
--
--
--
-----------------------------
function _m.get_tp2_result_as_nkv(response_json) 
	if response_json.tp ~= 2 then return end
	result = response_json.result
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



-----------------------------
--
--
--
-----------------------------
local P_INDEX = 1
local P_MIN = 2
local P_MAX = 3
local P_SUM = 4
local P_N = 5
local P_FIRST = 6
local P_LAST = 7

--
--
--
--
--
local function get_npos_projection_for_nkv(min_k, max_k, n_pos, n, ks, vs)
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
local function get_binsize_projection_for_nkv(min_k, max_k, bin_size, n, ks, vs)
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


--
--
--
--
--
local function get_points(points, min_k, max_k, n, fmt, k_mode, v_mode)
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


--
--
--
--
--
function _m.project_group_by_response(response_json, min_k, max_k, n_points, bin_size, k_mode, v_mode) 

	local n, ks, vs = _m.get_tp2_result_as_nkv(response_json)
	
	local points
	if bin_size == nil then 
		points = get_npos_projection_for_nkv(min_k, max_k, n_points, n, ks, vs)
	else
		min_k, max_k, points, n_points = get_binsize_projection_for_nkv(min_k, max_k, bin_size, n, ks, vs)
	end
	
	local result = get_points(points, min_k, max_k, n_points, group_by_output, k_mode, v_mode) 
	jres.result = result
	jres.min_k = min_k
	jres.max_k = max_k
	jres.n_points = n_points
	jres.delta_k = max_k - min_k
	jres.fmt = group_by_output
	
	return jres
end

--[[
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
		end
		
		group_by = group_by.field
	end
	
	if type(group_by) == "string" then
		if group_by == "time" then
			process_time = true
			-- ngx.log(ngx.ERR,"++++++++++++++++++" .. "time" .. "+++++++")
		end
	end
	
end
--]]



return _m