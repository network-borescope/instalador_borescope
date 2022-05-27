local ts = require "lib_tsql"
ngx.log(ngx.ERR,"@@@@@@@@@@@@@@ require: ".. ts.add(10,20) ) 


---------------------------------------------------------
--
--
--------------------------------------------------------

---------------------------------------------------------
-- Todo:
--    Check the valid of the structure 
--------------------------------------------------------


local from_info = {
    ufes = {
        items = {
            options = { pop_id = {map_cat = { AC=1, AM=2, AP=3, BA=4 } }, interface_id=1, location=1 },
            selectors = { time=1 },
            t_measures = { counter=1, ['*']=1 },
            s_measures = { counter=1, ['*']=1, pkt_loss_norm_avg=1, rtt_ns_avg=1, download_kbps_avg=1, upload_kbps_avg=1 },
        }
    },
    rnp_ttls = {
        items = {
            options = { cliente=1, ttl=1, location=1 },
            selectors = { time=1 },
            t_measures = { counter=1, ['*']=1, quantidades=1 },
            s_measures = { counter=1, ['*']=1, hsum=1, hc=1 },
        }
    }
}

local current_from = from_info.ufes

-----------------------------------------------------------------
--                 Filter Mappings
-----------------------------------------------------------------


-------------------------------------
--
--
--
--
local function map_to_epoch(s)
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


------------------------------------------------------------------

local PMIN, PMAX, PMAP, PHEAD, PTAIL = 1, 2, 3, 4, 5


local option_filters = {
    eq      = { [PMIN]=1, [PHEAD]="i", [PTAIL]="i" },
    zrect   = { [PMIN]=5, [PMAX]=5, [PHEAD]="iffff" },
    zpoly   = { [PMIN]=7, [PHEAD]="i", [PTAIL]="f" },
    between = { [PMIN]=2, [PMAX]=2, [PMAP]=map_to_epoch, [PHEAD]="ii" },
    range   = { [PMIN]=2, [PMAX]=2, [PMAP]=map_to_epoch, [PHEAD]="ii" },
}

local group_by_kws = {
    by         = { [PMIN]=1 },
    get        = { [PMIN]=3 },
    length     = { [PMIN]=1, [PMAX]=1 },
    binsize    = { [PMIN]=1, [PMAX]=1 },
    start_time = { [PMIN]=1 },
    end_time   = { [PMAX]=1 },
}

-----------------------------------------------------------------
--                 Exemplos
-----------------------------------------------------------------
--[[

    use ufes
    select ttt_ns_avg
    where pop_id = 10 
       and time range "2021-01-01", "2021-02-01"
    group by time
          get avg, min, max
          length 1000
          bin 2000    # seconds
          start-time ""
          end-time   ""

]]--


-----------------------------------------------------------------
--                 Types of Queries
-----------------------------------------------------------------
--[[
    valid combinations using schema:
    get schema

    valid combinations using bounds:

    bounds <option>
    bounds <option> where <option>
    bounds <option> where <selector>
    bounds <option> where <options> and <selector>

    bounds <selector>
    bounds <selector> where <option>
    bounds <selector> where <selector>
    bounds <selector> where <options> and <selector>

    valid combinations using select <t-measure>:

    select <t-measure>

    select <t-measure> where <option-filters>
    select <t-measure> group by <option>
    select <t-measure> where <option-filters> group by <option>

    select <t-measure> where <selector-filter>
    select <t-measure> group by <option>
    select <t-measure> where <selector-filter>  group by <option>

    select <t-measure> where <option-filters> and <selector-filter>
    select <t-measure> where <option-filters> and <selector-filter> group by <option>


    valid combinations using select <s-measure>:

    select <s-measure> where <option-filters>
    select <s-measure> where <selector-filter>
    select <s-measure> where <option-filters> and <selector-filter>

    select <s-measure> group by <selector>

    select <s-measure> where <option-filters> group by <selector>
    select <s-measure> where <selector-filter> group by <selector>
    select <s-measure> where <option-filters> and <selector-filter> group by <selector>

    NOT valid combinations using select <s-measure>:

    select <s-measure> group by <option> (???)
    select <s-measure> where <option-filters> group by <option>
    select <s-measure> where <selector-filter> group by <option>
    select <s-measure> where <option-filters> and <selector-filter> group by <option>


]]---------------------------------------------------------------

local LITERAL = 1
local STRING = 2

local SELECT = 10
local WHERE = 11
local GROUP_BY = 12
local OUTPUT = 13
local USE = 14
local BOUNDS = 17
local AND = 15
local COMMA = 16
local BY = 19

---------------------------------------------------------------
local CD=1
local TT=2
local DO=3

---------------------------------------------------------
--
--
--------------------------------------------------------

-------------------------------------
--
--
--
--
local function err_unk_measures(ident)
    local s = ""
    for k, v in pairs(current_from.items.t_measures) do
        s = s .. k .. " "
    end
    for k, v in pairs(current_from.items.s_measures) do
        s = s .. k .. " "
    end
    error("Unknown measure: "..ident..". Valid measures are: { " .. s .. " }")
end

-------------------------------------
--
--
--
--
local function err_unk_where_field(ident)
    local s = ""
    for k, v in pairs(current_from.items.options) do
        s = s .. k .. " "
    end
    for k, v in pairs(current_from.items.selectors) do
        s = s .. k .. " "
    end
    error("Unknown where-field: "..ident..". Valid values are: { " .. s .. " }")
end

-------------------------------------
--
--
--
--
local function err_unk_bounds_field(ident)
    local s = ""
    for k, v in pairs(current_from.items.options) do
        s = s .. k .. " "
    end
    for k, v in pairs(current_from.items.selectors) do
        s = s .. k .. " "
    end
    error("Unknown where-field: "..ident..". Valid values are: { " .. s .. " }")
end


-------------------------------------
--
--
--
--
local function do_use (q, tokens, pos, n)
    if q.use then error("Using 'use' twice in a single query") end
    table.insert(q.jstab, '"from":')
    local t = tokens[pos]
    if t[CD] ~= LITERAL then error("Literal expected but found: " .. t[TT]) end
    local ident = t[TT]
    if not from_info[ident] then error ('Unknown from: ' .. ident) end
    current_from = from_info[ident]

    local s = ' "' .. ident .. '"'
    table.insert(q.jstab, s)
    table.insert(q.jstab, ', ')

    q.common.use = true
    q.use = true

    if pos == n then return nil end
    return pos + 1
end


-------------------------------------
--
--
--
--
local function do_select (q, tokens, pos, n)
    if not q.common.use then error("You must have selected a tinycubes with 'use'") end
    if q.schema then error("You cannot use 'select' clause with 'schema' clause") end
    if q.bound then error("You cannot use 'select' clause with 'bounds' clause") end
    if q.select then error("You cannot use 'select' clause twice on a query") end
    q.select = true
    q.someQuery = true

    table.insert(q.jstab, '"select": [')
    local t
    while true do
        t = tokens[pos]
        if t[CD] ~= LITERAL then error("Literal expected") end
        local ident = t[TT]
        if current_from.items.s_measures[ident] then
            q.sel_s_m = 1
        elseif current_from.items.t_measures[ident] then
            q.sel_t_m = 1
        else
            err_unk_measures(ident) 
        end
        if q.bounds then error("query cannot use 'bounds' and 'select'") end
        q.select=1
        local s = '"' .. ident .. '"'
        table.insert(q.jstab, s)
        if pos == n then pos = nil; break end
        pos = pos + 1

        t = tokens[pos]
        if t[CD] ~= COMMA then break end
        table.insert(q.jstab, ', ')
    end            
    table.insert(q.jstab, '], ')

    return pos
end
    
-------------------------------------
--
--
--
--
local function do_bounds(q, tokens, pos, n)
    if not q.common.use then error("You must have selected a tinycubes with 'use'") end
    if q.schema then error("You cannot use 'bounds' clause with 'schema' clause") end
    if q.select then error("You cannot use 'bounds' clause with 'select' clause") end
    if q.bounds then error("You cannot use 'bounds' clause more than once") end
    q.someQuery = true

    table.insert(q.jstab, '"bounds":')

    local t = tokens[pos]
    if t[CD] ~= LITERAL then error("Literal expected") end

    local ident = t[TT]
    if current_from.items.selectors[ident] then
        q.bounds_S = 1
    elseif current_from.items.options[ident] then
        q.bounds_O = 1
    else
        err_unk_bounds_field(ident)
    end
    if q.select then error("query cannot use 'bounds' and 'select'.") end
    q.bounds=1

    local s = ' "' .. ident .. '"'
    table.insert(q.jstab, s)

    table.insert(q.jstab, ', ')

    if pos == n then return nil end
    return pos + 1
end

-------------------------------------
--
--
--
--
local function do_where_clause(q, tokens, pos, n)
    table.insert(q.jstab, '[')
    
    local t, s
    local ident

    -- ident
    t = tokens[pos]
    if t[CD] ~= LITERAL then error("Literal expected but found: " .. t[TT]) end
    
    ident = t[TT]
    if q.select_fields[ident] then error('Trying to create a second filter using the same field: '..ident) end
    q.select_fields[ident] = true

    local map_cat
    local ident_option = current_from.items.options[ident]
    if ident_option then
        map_cat = type(ident_option) == "table"
        q.where_O = true
    elseif current_from.items.selectors[ident] then
        q.where_S = true
    else
        err_unk_where_field(ident)
    end
    s = ' "' .. ident .. '"'
    table.insert(q.jstab, s)
    if pos == n then error("Incomplete where clause: missing where field") end
    pos = pos + 1

    -- op-filter
    t = tokens[pos]
    if t[CD] ~= LITERAL then error("Literal expected") end
    local filter_name = t[TT]
    local filter_info = option_filters[filter_name]
    local min_args = filter_info[PMIN]
    local max_args = filter_info[PMAX]
    local head_fmt = filter_info[PHEAD]
    local tail_fmt = filter_info[PTAIL]
    if not filter_info then error("Unknown option filter: ".. filter_name) end
    s = ', "' .. filter_name .. '"'
    table.insert(q.jstab, s)
    if pos == n then error("Incomplete where clause: missing where function") end
    pos = pos + 1

    -- filter-arguments
    local n_args = 0
    local found_and = false

    while true do
        t = tokens[pos]
        local v = t[TT]
        local cd = t[CD]

        if cd == LITERAL then
            if not tonumber(v) then
                -- print(ident, ident_option, v)
                if not (ident_option and type(ident_option) == "table") then error("There is no map rule for '"..ident.."' to map ".. v) end
                local new = ident_option.map_cat[v] 
                if not new then error("Could not map ["..v.."] for ident '"..ident.."'") end
                v = new
            end        
        elseif cd == STRING then
            local f = filter_info[PMAP]
            if type(f) == "function" then
                v = tostring(f(v))
            elseif map_cat then
                local unquoted = v:sub(2,#v-1)
                v = ident_option.map_cat[unquoted] or v
            end
        else
            error("Incomplete where clause: missing a literal value") 
        end

        n_args = n_args + 1
        if max_args and n_args > max_args then error(string.format("Too many filter arguments for function '%s'. Max: %d Found %d ", filter_name, max_args, n_args)) end

        local fmt = string.sub(head_fmt, n_args, n_args) or string.sub(tail_fmt, 1, 1)
        if fmt == 'i' and string.find(v, '%.') then error("Invalid float point parameter '"..v.."' at argument"..n_args.." of '"..ident.."'") end
        
        s = ', ' .. v
        table.insert(q.jstab, s)


        if pos == n then pos = nil; break end
        pos = pos + 1       -- consumes literal

        t = tokens[pos]

        -- and keyword?
        if t[CD] == AND then
            found_and = true
            pos = pos + 1    -- consumes AND
            break            -- stop this clause 
        end
        
        -- not "," ? stop!
        if t[CD] ~= COMMA then break end
        pos = pos + 1        -- consumes ","
    end            
    
    if min_args and n_args < min_args then error(string.format("Too few filter arguments for function '%s'. Min: %d Found %d ", filter_name, min_args, n_args)) end

    table.insert(q.jstab, ']')
    return pos, found_and
    
end    

-------------------------------------
--
--
--
--
local function do_where(q, tokens, pos, n)
    if not q.select and not q.bound then error("'where' clause requires previous either 'select' or 'bounds' clause") end
    if q.schema then error("You cannot use 'where' clause with 'schema' clause") end
    if q.where then error("You cannot use 'where' clause twice in the same query") end
    -- if not q.common.use then error("You must have selected a tinycubes with 'use'") end

    q.select_fields = {}

    table.insert(q.jstab, '"where": [')

    while true do 
        local found_and
        pos, found_and = do_where_clause(q, tokens, pos, n)
        if not pos then break end
        if not found_and then break end
        table.insert(q.jstab, ', ')
    end
        
    table.insert(q.jstab, '], ')

    return pos
end


-------------------------------------
--
--
--
--
local function do_group_by(q, tokens, pos, n)
    if not q.select then error("'group by' clause requires a previous 'select' clause") end
    if q.bounds then error("You cannot use 'group by' clause with 'bound' clause") end
    if q.schema then error("You cannot use 'group by' clause with 'schema' clause") end
    if q.group_by then error("You cannot use 'group-by' clause more than once") end
    if not q.common.use then error("You must have selected a tinycubes with 'use'") end

    local t
    while true do
        t = tokens[pos]
        if t[CD] ~= LITERAL then error("Literal expected but found: " .. t[TT]) end

        local ident = t[TT]
        if current_from.items.selectors[ident] then
            if q.group_by and q.group_by ~= 'S' then  error("Mixing different kinds of sources in 'group by'") end
            --if q.where_S then  error("A where clause using a selector cannot coexist with a group by over a selector") end
            q.group_by = 'S'
        elseif current_from.items.options[ident] then
            if q.group_by and q.group_by ~= 'O' then  error("Mixing different kinds of sources in 'group by'") end
            --if q.where_O then  error("A where clause using an option cannot coexist with a group by over an option") end
            q.group_by = 'O'
        else
            err_unk_bounds_field(ident)
        end
    
        local s = ' "' .. ident .. '"'
        table.insert(q.jstab, s)
        if pos == n then pos=nil; break end
        pos = pos + 1

        t = tokens[pos]
        if t[CD] ~= COMMA then break end
        pos = pos + 1

        table.insert(q.jstab, ', ')
    end

    return pos
end

    -------------------------------------
--
--
--
--
local function parse_list(tokens, pos, n)
    -- filter-arguments
    local n_args = 0
    local args = {}

    while true do
        local t = tokens[pos]
        local v = t[CD]
        if v == STRING then
            -- deveria mapear strings para literais
            v = LITERAL
        end

        if v ~= LITERAL then error("Incomplete list: missing literal value.  Found:"..t[TT]) end
        table.insert(args, t[TT])
        n_args = n_args + 1

        if pos == n then pos = nil; break end
        pos = pos + 1       -- consumes literal

        t = tokens[pos]
        -- not "," ? stop!
        if t[CD] ~= COMMA then break end
        pos = pos + 1        -- consumes ","
    end
    return pos, args
end

    -------------------------------------
--
--
--
--
local function do_group_by_2(q, tokens, pos, n)
    local t 
    t = tokens[pos]
    if t[CD] ~= BY then error("'by' expected") end

    table.insert(q.jstab, '"group by": [')
    pos = do_group_by(q, tokens, pos+1, n)

    if pos then
        local args = {}
        while true do
            t = tokens[pos]
            if t[CD] ~= LITERAL then break end
            local ident = t[TT]
            local kw =  group_by_kws[ident]
            if not kw then error("Invalid group additional-clause. Found: "..ident) end

            pos, args[kw] = parse_list(tokens, pos+1, n)
            if not pos then break end
        end

        if #args > 0 then 
            if args.length then
            elseif args.binsize then
            else
                error("When using group projection you must specify either the 'length' or the 'binsize'. ")
            end
        end
    end
    table.insert(q.jstab, '], ')

    return pos
end

-------------------------------------
--
--
--
--
local function do_output(q, tokens, pos, n)
    table.insert(q.jstab, '"output": [')
    local t
    while true do
        t = tokens[pos]
        if t[CD] ~= LITERAL then error("Literal expected") end
        local s = ' "' .. t[TT] .. '"'
        table.insert(q.jstab, s)
        if pos == n then pos=nil; break end
        pos = pos + 1

        t = tokens[pos]
        if t[CD] ~= COMMA then break end
        table.insert(q.jstab, ', ')
    end

    table.insert(q.jstab, '], ')
    return pos
end

---------------------------------------------------------



--------------------------------------------------------

local map = {
    select    =     { SELECT, do_select },
    where     =     { WHERE, do_where },
    ["group-by"]  = { GROUP_BY, do_group_by },
    ["group"]  =    { GROUP_BY, do_group_by_2 },
    ["by"]    =     { BY, nil },
    output    =     { OUTPUT, do_output },
    use       =     { USE, do_use },
    ["and"]       = { AND, nil },
    [","]         = { COMMA, nil },
    bounds    =     { BOUNDS, do_bounds }
}

---------------------------------------------------------



--------------------------------------------------------

-------------------------------------
--
--
--
--
function string:split(sep)
   local sep, fields = sep or " ", {}
   local pattern = string.format("([^%s\n]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

-------------------------------------
--
--
--
--
local function tokenize(str)
    local sqls = {}
    local toks = {}
    local first = 0
    local p

    while true do
        p = str:find('[",;#]', first+1)

        local plain = str:sub(first+1, (p or 0) - 1)
        plain:gsub("([^ \r\n]+)", 
            function(c)
                local m, v, f = map[c], LITERAL, nil
                if m then v = m[1]; f = m[2] end
                table.insert(toks, { v, c, f } )
            end)
        if not p then break end

        local c = str:sub(p,p)
        if c == ',' then 
            table.insert(toks, { COMMA, ',', nil } )
        elseif c == ';' then
            if #toks > 0 then -- ignores sequences of ';'
                table.insert(sqls, toks)
                toks = {}
            end
        elseif c == '#' then
            local p0 = p
            p = str:find('\n', p0+1)
            if not p then break end
        else
            local p0 = p
            p = str:find('"', p0+1)
            if not p then error("Unterminated string") end
            table.insert(toks, { STRING, str:sub(p0,p) } )
        end
        first = p
    end
    if #toks ~= 0 then 
        table.insert(sqls, toks)
    end
    --[[ for k, v in ipairs(sqls) do 
        for k2, t in ipairs(v) do
            print(k2,t[TT])
        end
    end]]--
    return sqls
end

-------------------------------------
--
--
--
--
local function print_tokens(toks)
    
    for i, t in ipairs(toks) do
        print(t[CD], t[TT])
    end
end

-------------------------------------
--
--
--
--
local function compile_tsql_query(common, tokens, pos, queries)
    local q = { common = common, jstab = { '{  "id":100, ' } }
    local n = #tokens
    while true do
        local t = tokens[pos]
        local do_fun = t[DO] 
        if not do_fun then error("Unknown clause: '" .. t[TT] .. "' " .. common.src ) end
        pos = pos + 1
        pos = do_fun(q, tokens, pos, n)
        if not pos or pos == n then break end
    end

    table.insert(q.jstab, ' "end": 1}')

    if q.someQuery then
        -- print("no errors")
        local query = table.concat(q.jstab, "")
		ngx.log(ngx.ERR,"!!!!!!!!!!!!!! tsql query: " .. query .. " !!!!!!!")
		
        table.insert(queries, query)
    end
    
end

-------------------------------------
--
--
--
--
local function jsError(err)
    return string.format('{ "tp":0, "id":0, "err": "%s"}', err)
end

-------------------------------------
--
--
--
--
local function compile_tsql(str, queries)
    local pos = 1
	ngx.log(ngx.ERR,"!!!!!!!!!!!!!! str: " .. str .. " !!!!!!!")
    local tok_queries = tokenize(str)
    if #tok_queries == 0 then 
        table.insert(queries, jsError("Request without queries"))
        return
    end
    local common = { src = str }
    for _, tokens in ipairs(tok_queries) do
        local ok, err = pcall(compile_tsql_query, common, tokens, pos, queries)
        if not ok then table.insert(queries, { jsError(err) } ) end
    end
end    


---------------------------------------------------------
--
-- Test
--
--------------------------------------------------------
-- local str0 = [[
    -- ;;
    -- # teste
    -- ;

    -- ;
-- ]]

-- local str1 = [[
    -- use ufes 
    -- select rtt_ns_avg 
    -- # comment
    -- where time between "2020-10-01", "2020-10-02" 
          -- and location zrect 5, -12.13, 12.1, 121, 33
          -- and pop_id eq AC
          -- and interface_id eq 1
    -- group by pop_id
-- ]]

-- local str2 = [[
    -- use ufes 
    -- select rtt_ns_avg 
    -- # comment
    -- where time between "2020-10-01", "2020-10-02" 
          -- and location zrect 5, -12.13, 12.1, 121, 33
          -- and pop_id eq AC
          -- and interface_id eq 1
    -- group by pop_id, location
        -- get avg, min
        -- length 500;
        -- ; ; 
        -- # test to accept empty statements
        -- ;  ;
    -- bounds time;
-- ]]

-- local str = str1

-- print(str)

-- local skt = require "socket"
-- local ms = skt.gettime()*1000
-- local tm = os.time()
-- for i = 1, 10*1000 do
    -- local jsons = {}
    -- local status, json_str = pcall(compile_tsql, str, jsons)
    -- if not status then
        -- print("err:", json_str)
        -- break
    -- else
        -- for k,js in pairs(jsons) do
            -- if type(js) == "string" then print(js) end
        -- end
    -- end
-- end
-- print(os.time() - tm)
--print(skt.gettime()*1000 - ms)


---------------------------------------------------------
--
-- Running
--
--------------------------------------------------------

local http = require "resty.http"
local cjson = require "cjson"

if ngx.req.get_method() ~= 'POST' then
	return
end

ngx.req.read_body()
local req_body = ngx.req.get_body_data()

local queries = {}
ngx.log(ngx.ERR,"!!!!!!!!!!!!!! trq_body: " .. req_body .. " !!!!!!!")
local status, json_str = pcall(compile_tsql, req_body, queries)
if not status then
	ngx.say(json_str)
	return
end



-- prepara o http request
local httpc = http.new() 
httpc:set_timeout(60000)

---------------------------------------------
--
---------------------------------------------
local function raw_perform_http_request(httpc, url, req_body) 
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
---		ngx.log(ngx.ERR,"@@@@@@@@@@@@@@ failed to request: "..err) 
		ngx.say("failed to request: ", err)
		return 
	end 
	
	return res
end




--if true then return end
local res_table = {}

for k,v in ipairs(queries) do
	if type(v) == "string" then
		-- local s = ngx.location.capture("/tc/query",{ method = ngx.HTTP_POST, body = v }).body
		local s = raw_perform_http_request(httpc, "http://127.0.0.1:8000/tc/query", v).body
		table.insert(res_table, s)
	else
		table.insert(res_table,v[1])
	end
end

local response = "[" .. table.concat(res_table, ",") .. "]"

ngx.header.content_type = "application/json; charset=utf-8"
ngx.say(response)
ngx.eof()