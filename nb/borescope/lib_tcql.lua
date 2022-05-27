local tsfilters = require "lib_tcql_filters"
local tc_hosts  = require "lib_tc_hosts"
local tc        = require "lib_tc_functions"

local statics   = require "lib_tc_statics"

local _m = {}

-----------------------------------------------------------------
--                 Group By Keywords
-----------------------------------------------------------------

local PMIN, PMAX, PMAP, PHEAD, PTAIL = 1, 2, 3, 4, 5

local group_by_kws = {
    by         = { [PMIN]=1 },
    get        = { [PMIN]=3 },
    length     = { [PMIN]=1, [PMAX]=1 },
    binsize    = { [PMIN]=1, [PMAX]=1 },
    start_time = { [PMIN]=1 },
    end_time   = { [PMAX]=1 },
}

-- {  "field": "time",  "min-k": 1630454400,  "max-k": 1631748300,  "n-points": 1024,  "v": "AMPNS" }

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
local VARIABLE = 3

local SELECT = 10
local WHERE = 11
local GROUP_BY = 12
local OUTPUT = 13
local USE = 14
local BOUNDS = 17
local AND = 15
local COMMA = 16
local BY = 19
local INTO = 20
local RETURN = 21
local FRESH = 22
local CALL = 23
local LIST = 24
local GET = 25

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
local function err_unk_use(q, ident)
	local s = ""
	
	for k, _ in pairs(q.common.hosts) do
		if type(k) ~= "number" then s = s .. k .. ", " end
	end
	
	error ('Unknown from: ' .. ident .. ". Valid values are: { " .. s:sub(1, #s-2) .. " }")
end

-------------------------------------
--
--
--
--
local function err_unk_measures(q, ident)
--[[
    local s = ""
    for k, v in pairs(q.common.hosts.items.t_measures) do
        s = s .. k .. " "
    end
    for k, v in pairs(q.common.hosts.items.s_measures) do
        s = s .. k .. " "
    end
	
	error("Unknown measure: "..ident..". Valid measures are: { " .. s .. " }")
--]]

	 -- Arthur 30/11/2021
    local s = ""
	local host_items = q.common.sel_use.items
	if not host_items then error("Unknown measure: "..ident) end
	
	for k1, v1 in pairs(host_items.t_measures) do
		s = s .. k1 .. ", "
	end

	for k1, v1 in pairs(host_items.s_measures) do
		s = s .. k1 .. ", "
	end

	s = s:sub(1, #s-2) -- remove ", "


    error("Unknown measure: "..ident..". Valid values for " .. q.common.use:sub(10, #q.common.use -1) .. " are: { " .. s .. " }")
end

-------------------------------------
--
--
--
--
local function err_unk_where_field(q, ident)
--[[
    local s = ""
    for k, v in pairs(q.common.hosts.items.options) do
        s = s .. k .. " "
    end
    for k, v in pairs(q.common.hosts.items.selectors) do
        s = s .. k .. " "
    end

    error("Unknown where-field: "..ident..". Valid values are: { " .. s .. " }")
--]]

	 -- Arthur 30/11/2021
    local s = ""
	local host_items = q.common.sel_use.items
	if not host_items then error("Unknown where-field: "..ident) end
	
	for k1, v1 in pairs(host_items.options) do
		s = s .. k1 .. ", "
	end

	for k1, v1 in pairs(host_items.selectors) do
		s = s .. k1 .. ", "
	end

	s = s:sub(1, #s-2) -- remove ", "


    error("Unknown where-field: "..ident..". Valid values for " .. q.common.use:sub(10, #q.common.use -1) .. " are: { " .. s .. " }")
end

-------------------------------------
--
--
--
--
local function err_unk_bounds_field(q, ident)
--[[
    local s = ""
    for k, v in pairs(q.common.hosts.items.options) do
        s = s .. k .. " "
    end
    for k, v in pairs(q.common.hosts.items.selectors) do
        s = s .. k .. " "
    end
    error("Unknown bounds-field: "..ident..". Valid values are: { " .. s .. " }")
--]]

	-- Arthur 30/11/2021
    local s = ""
	local host_items = q.common.sel_use.items
	if not host_items then error("Unknown where-field: "..ident) end
	
	for k1, v1 in pairs(host_items.options) do
		s = s .. k1 .. ", "
	end

	for k1, v1 in pairs(host_items.selectors) do
		s = s .. k1 .. ", "
	end

	s = s:sub(1, #s-2) -- remove ", "


    error("Unknown bounds-field: "..ident..". Valid values for " .. q.common.use:sub(10, #q.common.use -1) .. " are: { " .. s .. " }")
end


-------------------------------------
--
--
--
--
local function do_use (q, tokens, ntok, n)
    if q.use then error("Using 'use' twice in a single query") end
    local t = tokens[ntok]
    if t[CD] ~= LITERAL then error("Literal expected but found: " .. t[TT]) end
    local ident = t[TT]
    --local use_ident = q.common.hosts[ident] -- tc_hosts.load_host(ident)
	local host = tc_hosts.load_host(ident)
    --if not host then error ('Unknown from: ' .. ident) end
	if not host then err_unk_use(q, ident) end -- Arthur 01/12/2021
	q.common.sel_use = host


--[[
    local s = ' "' .. ident .. '"'
    table.insert(q.jstab, '"from":')
    table.insert(q.jstab, s)
    table.insert(q.jstab, ', ')
    q.common.use = true
--]]
    q.common.use = '"from": "' .. ident .. '"'
	q.common.url = host.url
	
    q.use = true

    if ntok == n then return nil end
    return ntok + 1
end


-------------------------------------
--
--
--
--
local function do_select (q, tokens, ntok, n)
    if not q.common.use then error("You must have selected a tinycubes with 'use'") end
    if q.schema then error("You cannot use 'select' clause with 'schema' clause") end
    if q.bound then error("You cannot use 'select' clause with 'bounds' clause") end
    if q.select then error("You cannot use 'select' clause twice on a query") end
    q.select = true
    q.someStat = true

    table.insert(q.jstab, '"select": [')
    local t
    while true do
        t = tokens[ntok]
		local ident -- Arthur 30/11/2021
        if t[CD] ~= LITERAL then
			--error("Literal expected")
			local const = q.common.sel_use.schema.const
			if not const then error("Literal or Schema constant expected") end -- Arthur 30/11/2021
			ident = const[t[TT]:sub(2, #t[TT]-1)] -- Arthur 30/11/2021
			if not ident then error("Literal or Schema constant expected") end -- Arthur 30/11/2021
		end
        --local ident = t[TT]
		ident = ident or t[TT] -- Arthur 30/11/2021
        if q.common.sel_use.items.s_measures[ident] then
            q.sel_s_m = 1
        elseif q.common.sel_use.items.t_measures[ident] then
            q.sel_t_m = 1
        else
            err_unk_measures(q, ident) 
        end
        if q.bounds then error("query cannot use 'bounds' and 'select'") end
        q.select=1
        local s = '"' .. ident .. '"'
        table.insert(q.jstab, s)
        if ntok == n then ntok = nil; break end
        ntok = ntok + 1

        t = tokens[ntok]
        if t[CD] ~= COMMA then break end
        table.insert(q.jstab, ', ')
    end            
    table.insert(q.jstab, '], ')

    return ntok
end
    
-------------------------------------
--
--
--
--
local function do_bounds(q, tokens, ntok, n)
    if not q.common.use then error("You must have selected a tinycubes with 'use'") end
    if q.schema then error("You cannot use 'bounds' clause with 'schema' clause") end
    if q.select then error("You cannot use 'bounds' clause with 'select' clause") end
    if q.bounds then error("You cannot use 'bounds' clause more than once") end
    q.someStat = true

    table.insert(q.jstab, '"bounds":')

    local t = tokens[ntok]
    if t[CD] ~= LITERAL then error("Literal expected") end

    local ident = t[TT]
    if q.common.sel_use.items.selectors[ident] then
        q.bounds_S = 1
    elseif q.common.sel_use.items.options[ident] then
        q.bounds_O = 1
    else
        err_unk_bounds_field(q, ident)
    end
    if q.select then error("query cannot use 'bounds' and 'select'.") end
    q.bounds=1

    local s = ' "' .. ident .. '"'
    table.insert(q.jstab, s)

    table.insert(q.jstab, ', ')

    if ntok == n then return nil end
    return ntok + 1
end

-------------------------------------
--
--
--
--
local function do_where_clause(q, tokens, ntok, n)
    table.insert(q.jstab, '[')
    
    local t, s
    local ident

    -- ident
    t = tokens[ntok]
    if t[CD] ~= LITERAL then error("Literal expected but found: " .. t[TT]) end
    
    ident = t[TT]
    if q.select_fields[ident] then error('Trying to create a second filter using the same field: '..ident) end
    q.select_fields[ident] = true

    local map_cat
    local ident_option = q.common.sel_use.items.options[ident]
    if ident_option then
        map_cat = type(ident_option) == "table"
        q.where_O = true
    elseif q.common.sel_use.items.selectors[ident] then
        q.where_S = true
    else
        err_unk_where_field(q, ident)
    end
    s = ' "' .. ident .. '"'
    table.insert(q.jstab, s)
    if ntok == n then error("Incomplete where clause: missing where field") end
    ntok = ntok + 1

    -- op-filter
    t = tokens[ntok]
    if t[CD] ~= LITERAL then error("Literal expected") end
    local filter_name = t[TT]
    local filter_info = q.common.option_filters[filter_name]
    if not filter_info then error("Unknown option filter: ".. filter_name) end
    local min_args = filter_info.vmin
    local max_args = filter_info.vmax
    local head_fmt = filter_info.vhead
    local tail_fmt = filter_info.vtail
    s = ', "' .. filter_name .. '"'
    table.insert(q.jstab, s)
    if ntok == n then error("Incomplete where clause: missing where function") end
    ntok = ntok + 1

    -- filter-arguments
    local n_args = 0
    local found_and = false

    while true do
        t = tokens[ntok]
        local v = t[TT]
        local cd = t[CD]

        if cd == LITERAL then
            if not tonumber(v) then
                -- print(ident, ident_option, v)
				local const = q.common.sel_use.schema.const -- Arthur 01/12/2021
				if const then -- Arthur 01/12/2021
					local new_v = const[v] -- Arthur 01/12/2021
					if new_v then -- Arthur 01/12/2021
						v = new_v -- Arthur 01/12/2021
						
						goto continue -- Arthur 01/12/2021
					end -- Arthur 01/12/2021
				end -- Arthur 01/12/2021
				
				
                if not (ident_option and type(ident_option) == "table") then error("There is no map rule for '"..ident.."' to map ".. v) end
                local new = ident_option.map_cat[v] 
                if not new then error("Could not map ["..v.."] for ident '"..ident.."'") end
                v = new
            end        
        elseif cd == STRING then
            local f = filter_info.vmap
            if type(f) == "function" then
                v = tostring(f(v))
            elseif map_cat then
                local unquoted = v:sub(2,#v-1)
                v = ident_option.map_cat[unquoted] or v
            end
        else
            error("Incomplete where clause: missing a literal value") 
        end
		::continue:: -- Arthur 01/12/2021

        n_args = n_args + 1
        if max_args and n_args > max_args then error(string.format("Too many filter arguments for function '%s'. Max: %d Found %d ", filter_name, max_args, n_args)) end

        local fmt = string.sub(head_fmt, n_args, n_args) or string.sub(tail_fmt, 1, 1)
        if fmt == 'i' and string.find(v, '%.') then error("Invalid float point parameter '"..v.."' at argument"..n_args.." of '"..ident.."'") end
        
        s = ', ' .. v
        table.insert(q.jstab, s)


        if ntok == n then ntok = nil; break end
        ntok = ntok + 1       -- consumes literal

        t = tokens[ntok]

        -- and keyword?
        if t[CD] == AND then
            found_and = true
            ntok = ntok + 1    -- consumes AND
            break            -- stop this clause 
        end
        
        -- not "," ? stop!
        if t[CD] ~= COMMA then break end
        ntok = ntok + 1        -- consumes ","
    end            
    
    if min_args and n_args < min_args then error(string.format("Too few filter arguments for function '%s'. Min: %d Found %d ", filter_name, min_args, n_args)) end

    table.insert(q.jstab, ']')
    return ntok, found_and
    
end    

-------------------------------------
--
--
--
--
local function do_where(q, tokens, ntok, n)
    if not q.select and not q.bound then error("'where' clause requires previous either 'select' or 'bounds' clause") end
    if q.schema then error("You cannot use 'where' clause with 'schema' clause") end
    if q.where then error("You cannot use 'where' clause twice in the same query") end
    -- if not q.common.use then error("You must have selected a tinycubes with 'use'") end

    q.select_fields = {}

    table.insert(q.jstab, '"where": [')

    while true do 
        local found_and
        ntok, found_and = do_where_clause(q, tokens, ntok, n)
        if not ntok then break end
        if not found_and then break end
        table.insert(q.jstab, ', ')
    end
        
    table.insert(q.jstab, '], ')

    return ntok
end


-------------------------------------
--
--
--
--
local function do_group_by_head(q, tokens, ntok, n)
    
    if not q.select then error("'group by' clause requires a previous 'select' clause") end
    if q.bounds then error("You cannot use 'group by' clause with 'bound' clause") end
    if q.schema then error("You cannot use 'group by' clause with 'schema' clause") end
    if q.group_by then error("You cannot use 'group-by' clause more than once") end
    if not q.common.use then error("You must have selected a tinycubes with 'use'") end

    local t
    while true do
        t = tokens[ntok]
        if t[CD] ~= LITERAL then error("Literal expected but found: " .. t[TT]) end

        local ident = t[TT]
        if q.common.sel_use.items.selectors[ident] then
            if q.group_by and q.group_by ~= 'S' then  error("Mixing different kinds of sources in 'group by'") end
            --if q.where_S then  error("A where clause using a selector cannot coexist with a group by over a selector") end
            q.group_by = 'S'
        elseif q.common.sel_use.items.options[ident] then
            if q.group_by and q.group_by ~= 'O' then  error("Mixing different kinds of sources in 'group by'") end
            --if q.where_O then  error("A where clause using an option cannot coexist with a group by over an option") end
            q.group_by = 'O'
        else
            err_unk_bounds_field(q, ident)
        end
    
        local s = ' "' .. ident .. '"'
        table.insert(q.jstab, s)
        if ntok == n then ntok=nil; break end
        ntok = ntok + 1

        t = tokens[ntok]
        if t[CD] ~= COMMA then break end
        ntok = ntok + 1

        table.insert(q.jstab, ', ')
    end

    return ntok
end

-------------------------------------
--
--
--
--
local function parse_list(tokens, ntok, n)
    -- filter-arguments
    local n_args = 0
    local args = {}

    while true do
        local t = tokens[ntok]
        local v = t[CD]
        if v == STRING then
            -- deveria mapear strings para literais
            v = LITERAL
        end

        if v ~= LITERAL then error("Incomplete list: missing literal value.  Found:"..t[TT]) end
        table.insert(args, t[TT])
        n_args = n_args + 1

        if ntok == n then ntok = nil; break end
        ntok = ntok + 1       -- consumes literal

        t = tokens[ntok]
        -- not "," ? stop!
        if t[CD] ~= COMMA then break end
        ntok = ntok + 1        -- consumes ","
    end
    return ntok, args
end


local giving_options = { avg='A' , min='B', max='T', median='M' }

-------------------------------------
--
--
--
--
local function do_g_as(q, tokens, ntok, n)
    local t, tt
    local options = ''
    local c = 0
    while true do 
        t = tokens[ntok]; ntok = ntok + 1
        if not t then if c > 0 then return end error('Missing giving')  end
        c = c + 1
        tt = t[TT]
        local o = giving_options[tt]
        if not o then error("Invalid 'as' option "..tt) end
        options = options .. o

        t = tokens[ntok]; if not t then return end; 
        if t[CD] ~= COMMA then break end
        ntok = ntok + 1
    end
    return ntok
end

--[[

    into x

    group by pop_id
        using 500 bins | using binsize 300
        as avg, min
        since x 
    until | last y

    call


]]--

local function tointeger(s)
    local r = tonumber(s)
    if r and not s:find('.') then return r end
end

-------------------------------------
--
--
--
--
local function do_group_by(q, tokens, ntok, n)
    local t, tt 
    t = tokens[ntok]
    if t[CD] ~= BY then error("'by' expected") end

    table.insert(q.jstab, '"group-by": [')
    ntok = do_group_by_head(q, tokens, ntok+1, n)
    if ntok then
        local do_it = function()
            -- "giving" name-list
            t = tokens[ntok]
            print(1)
            if t[TT] == 'using' then
                ntok = ntok + 1

                -- next after 'using'
                t = tokens[ntok]; if not t then error("Missing bin definition")  end; tt = t[TT]
                ntok = ntok + 1

                print("tt", tt)
                -- 'binsize' $integer 
                if tt == 'binsize' then
                    t = tokens[ntok]; if not t then error("Missing binsize value") end; tt = t[TT]; ntok = ntok + 1
                    if t[CD] ~= LITERAL or tointeger(tt) == nil then error("1111") end
                    -- tointeger(tt) 
                
                -- $integer 'bins'
                elseif t[CD] == LITERAL then
                    local v = tonumber(tt)
                    if v == nil or tt:find('%.') then error('invalid bin number: '.. tt) end
                    t = tokens[ntok]; if not t then error("Missing 'bins'") end; tt = t[TT]; ntok = ntok + 1
                    if tt ~= 'bins' then error("Expecting 'bins' but found: "..tt) end

                else
                    error("Missing bin definition. Found: "..tt)
                end

                -- as ...
                t = tokens[ntok]; if not t then return end; tt = t[TT]
                if tt ~= 'as' then return end
                ntok = do_g_as(q, tokens, ntok+1, n)

                -- since value
                t = tokens[ntok]; if not t then return end; tt = t[TT]
                if tt ~= 'since' then return end
                ntok = ntok + 1

                t = tokens[ntok]; tt = t[TT]; ntok = ntok + 1
                if not t then error("Missing 'since' value") end
                -- convert date-string to epoch

                t = tokens[ntok]; if not t then return end; tt = t[TT]
                local s = tt
                if tt ~= 'until' and tt ~= 'last' then return end
                ntok = ntok + 1
                
                t = tokens[ntok]; tt = t[TT]; ntok = ntok + 1
                if not t then error("Missing 'until'/'last' value") end

                return true
            end
        end
        do_it() -- then ntok = nil end
    end
    table.insert(q.jstab, '], ')

    return ntok
end

-------------------------------------
--
--
--
--
local function do_into(q, tokens, ntok, n)
	-- ngx.log(ngx.ERR,"++++++++++++++++++ into := " .. tostring("INTOTOTOTOT") .. " +++++++")
    if not q.select and not q.call then error("'into' clause requires a previous 'select' or 'call' clause") end

	t = tokens[ntok]; 
	if not t then error ("variable expected but received "..tt) end; 
	tt = t[TT]; ntok = ntok + 1
	if t[CD] ~= VARIABLE then error ("variable expected but received "..tt) end
    q.into = tt
	-- ngx.log(ngx.ERR,"++++++++++++++++++ into := " .. tostring(tt) .. " +++++++")

    return ntok
end

-------------------------------------
--
--
--
--
local function do_return(q, tokens, ntok, n)
	if q.nclauses > 0 then error("return must be a unique clause") end
	local variables = {}
	while true do
		local t 
		t = tokens[ntok]; if not t or t[CD] ~= VARIABLE then error ("variable expected but received "..tt) end
		tt = t[TT]; ntok = ntok + 1
		variables[#variables+1] = tt
		
		t = tokens[ntok];
		if t[CD] ~= COMMA then break end
	end
	
    q.do_return = variables
	q.someStat = true

    return ntok
end

-------------------------------------
--
-- fresh (SELECT | BOUNDS)
-- 
--
local function do_fresh(q, tokens, ntok, n)
--	if q.nclauses > 0 then error("return must be a unique clause") end
	
	t = tokens[ntok]; 
	if t and (t[CD] == SELECT or t[CD] == BOUNDS) then 
		q.fresh = true
	else
		error("Fresh must preceed only 'select' or 'bounds'") 
	end

    return ntok
end

-------------------------------------
--
--
--
--
local function do_call(q, tokens, ntok, n)
    local t, s

    -- proc
    t = tokens[ntok]
    if t[CD] ~= LITERAL then error("Literal expected") end
	
    local proc_name = t[TT]
    local proc = statics.procs[proc_name]
    if not proc then error("Unknown proc: ".. proc_name) end
    local min_args = proc.vmin
    local max_args = proc.vmax
    local head_fmt = proc.vhead or ""
    local tail_fmt = proc.vtail or ""
    ntok = ntok + 1

    -- proc args
	local n_args = 0

    q.call = {} 
	local call = q.call
	call.proc = proc.vproc
	call.args = {}
	call.vars = {}
	
	q.someStat = true

    while true do
        t = tokens[ntok]
        local cd = t[CD]
        local v = t[TT]
		local is_var = false
		local arg

        if cd == LITERAL then
			arg = tonumber(v)
            if not arg then
				error('Number expected: '..v)
                -- -- print(ident, ident_option, v)
                -- if not (ident_option and type(ident_option) == "table") then error("There is no map rule for '"..ident.."' to map ".. v) end
                -- local new = ident_option.map_cat[v] 
                -- if not new then error("Could not map ["..v.."] for ident '"..ident.."'") end
                -- v = new
            end  
			
        elseif cd == STRING then
			error('Number expected: '..v)
            -- local f = filter_info.vmap
            -- if type(f) == "function" then
                -- v = tostring(f(v))
            -- elseif map_cat then
                -- local unquoted = v:sub(2,#v-1)
                -- v = ident_option.map_cat[unquoted] or v
            -- end
        elseif cd == VARIABLE then
			is_var = true
			arg = v
        else
            error("Invalid 'call' clause: missing variable or literal value") 
        end

		-- 
        n_args = n_args + 1 

        if max_args and n_args > max_args then 
			error(string.format("Too many arguments for proc '%s'. Max: %d Found %d ", proc_name, max_args, n_args)) 
		end

        local fmt = string.sub(head_fmt, n_args, n_args) or string.sub(tail_fmt, 1, 1)
        if fmt == 'i' then
			if not tonumber(v) or string.find(v, '%.') then 
				error("Invalid parameter '"..v.."' at argument"..n_args.." for '"..proc_name.."'")
			end
        elseif fmt == 'f' then
			if not tonumber(v) then 
				error("Invalid float point parameter '"..v.."' at argument"..n_args.." for '"..proc_name.."'")
			end
        elseif fmt == 'R' then
			if not is_var then 
				error("Invalid parameter '"..v.."' at argument"..n_args.." for '"..proc_name.."'")
			end
		end

		-- neste ponto tem o parametro valido
		call.args[n_args] = arg
		if is_var then table.insert(call.vars, { position = n_args, name = v } ) end
 
        if ntok == n then ntok = nil; break end
        ntok = ntok + 1       -- consumes literal

		-- look-ahead the next token
        t = tokens[ntok]

		-- not "," ? stop!
        if t[CD] ~= COMMA then break end
		
        ntok = ntok + 1        -- consumes ","
    end            

    if min_args and n_args < min_args then 
		error(string.format("proc '%s'. Min: %d Found %d ", procname_name, min_args, n_args)) 
	end
	
    return ntok
end    

-------------------------------------
--
--
--
--
local function do_output(q, tokens, ntok, n)
    table.insert(q.jstab, '"output": [')
    local t
    while true do
        t = tokens[ntok]
        if t[CD] ~= LITERAL then error("Literal expected") end
        local s = ' "' .. t[TT] .. '"'
        table.insert(q.jstab, s)
        if ntok == n then ntok=nil; break end
        ntok = ntok + 1

        t = tokens[ntok]
        if t[CD] ~= COMMA then break end
        table.insert(q.jstab, ', ')
    end

    table.insert(q.jstab, '], ')
    return ntok
end

-------------------------------------
--
-- Arthur 01/12/2021
--
--
local function do_list(q, tokens, ntok, n)
	local t = tokens[ntok]

	local function process_list(list)
		local s = ""
		for k, v in pairs(list) do
			s = s .. '"' .. k .. '", '
		end
		
		q.list = '{"id": 100, "tp": 1, "result": [' .. s:sub(1, #s-2) .. ']}' -- tc format
		q.someStat = true
	end
	
	local list = q.common.sel_use.items[t[TT]]
	if list then
		process_list(list)
		return ntok + 1
	end

	-- list enum?
	if t[CD] == LITERAL and t[TT] ~= "enum" then error('Invalid list option') end
	
	-- list enum const?
	ntok = ntok + 1
	t = tokens[ntok]

	list = q.common.sel_use.schema[t[TT]] -- t is const
	if t[CD] == LITERAL and list then
		process_list(list)
		return ntok + 1
	end

	-- list enum maps?
	if t[CD] == LITERAL and t[TT] ~= "maps" then error('Invalid list enum option') end
	
	-- list enum maps <option>?
	ntok = ntok + 1
	t = tokens[ntok]
	
	list = q.common.sel_use.items.options[t[TT]]
	if not list then error('Invalid list enum maps option') end
	
	local map_cat = list.map_cat
	if not map_cat then error("No map found for option " .. t[TT] .. ".") end
	process_list(map_cat)
	return ntok + 1
end

-------------------------------------
--
-- Arthur 02/12/2021
--
--
local function do_get(q, tokens, ntok, n)
	local t = tokens[ntok]

	if t[CD] == LITERAL and t[TT] == "schema" then
		table.insert(q.jstab, '"schema": 1,')
		q.someStat = true
		return ntok + 1
	end
	
	-- get dimensions, ...
	ntok = ntok + 1
	if not  q.commom.sel_use.schema[t[TT]] then error("Invalid definition") end
	
	q._get = t[TT]
	q.someStat = true
	return ntok + 1
end

---------------------------------------------------------



--------------------------------------------------------

local reserved = {
    select    = { SELECT, do_select },
    where     = { WHERE, do_where },
    ["group"] = { GROUP_BY, do_group_by },
    ["by"]    = { BY, nil },
    output    = { OUTPUT, do_output },
    use       = { USE, do_use },
    ["and"]   = { AND, nil },
    [","]     = { COMMA, nil },
    bounds    = { BOUNDS, do_bounds },
    into      = { INTO, do_into },
    reply     = { RETURN, do_return },
    fresh     = { FRESH, do_fresh },
    call      = { CALL, do_call },
    list      = { LIST, do_list }, -- Arthur 01/12/2021
    get       = { GET, do_get },   -- Arthur 02/12/2021
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
        plain:gsub("([^ \t\r\n]+)", 
            function(c)
                local m, v, f = reserved[c], LITERAL, nil
                if not m then 
					if c:sub(1,1) == '$' then v = VARIABLE end
				else
					v = m[1]; f = m[2] 
				end
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
local function compile_tsql_query(common, tokens, ntok)
    local q = { common = common, jstab = { '{  "id":100, ' }, nclauses = 0 }
    local n = #tokens
    while true do
        local t = tokens[ntok]
        if not t then break end
        local do_fun = t[DO]
        if not do_fun then error("Unknown clause: '" .. t[TT] .. "' " ) end
        ntok = ntok + 1
        ntok = do_fun(q, tokens, ntok, n)
        if not ntok or ntok == n then break end
		q.nclauses = q.nclauses + 1
    end
    if not q.someStat then return end
    table.insert(q.jstab, q.common.use)
    table.insert(q.jstab, ' }')
	local query_js = table.concat(q.jstab, "")
	local instruction = { 
		js = query_js,
		url = q.common.url,
		_into = q.into, 
		_return = q.do_return, 
		_fresh = q.fresh,
		_call = q.call,
		_list = q.list, -- Arthur 02/12/2021
	}
	return instruction
end

-------------------------------------
--
--
--
--
function _m.compile_tsql(source, param_use_table)
	local queries = {}
    
	local queries_tokens = tokenize(source)
	
    if #queries_tokens == 0 then 
        table.insert(queries, tc.buildError("Request without queries"))
    else
		local ntok = 1
		-- Arthur 29/11/2021
        --local common = {src = source, hosts = tc_hosts.hosts, option_filters = tsfilters.option_filters}
		local common = {src = source, hosts = tc_hosts.get_hosts(), option_filters = tsfilters.option_filters}
		
		for _, tokens in ipairs(queries_tokens) do
			local ok, js_table = pcall (compile_tsql_query, common, tokens, ntok)
			if not ok then
				--local p0, p1 = js_table:find(":%d+:")
				local p1 = -1
				table.insert(queries, { err = tc.buildError(js_table:sub(p1+2)) } ) -- js_query has the err string
			elseif js_table then 
				table.insert(queries, js_table)
			else
				-- there was no actual statement in the query
			end
		end
	end
    return queries
end


return _m
