local base = require "lib_nx_base"
local cjson = require "cjson"

local _m = {}

_m.hosts0 = {
    ufes = {
        items = {
            options = { pop_id = {map_cat = { AC=1, AM=2, AP=3, BA=4 } }, interface_id=1, location=1 },
            selectors = { time=1 },
            t_measures = { counter=1, ['*']=1 },
            s_measures = { counter=1, ['*']=1, pkt_loss_norm_avg=1, rtt_ns_avg=1, download_kbps_avg=1, upload_kbps_avg=1 },
        }
    },
    rnp_ttls = {
		url = "http://127.0.0.1:9001/tc/query",
		from = "rnp_ttls",
        items = {
            options = { cliente=1, ttl=1, location=1 },
            selectors = { time=1 },
            t_measures = { counter=1, ['*']=1, quantidades=1 },
            s_measures = { counter=1, ['*']=1, hsum=1, hc=1 },
        }
    }
}

-- Arthur 29/11/2021
local hosts = {
	false,
	rnp_ttls = { url = "http://127.0.0.1:9001/tc/query" },
	rnp_serv = { url = "http://127.0.0.1:9002/tc/query" },
	rnp_dns = { url = "http://127.0.0.1:9003/tc/query" },
	
	perfsonar = { url = "http://127.0.0.1:9105/tc/query" }, -- esta rodando numa porta de "teste".
}

local xxx = [[
{"result":{
    "metadata": {
        "version": "1.0",
        "caption": "POP-DF",
        "geo.anchors": [
            { "lat":0, "lon":0, "id":"POP-AC" }
        ]
    },

    "registry": {
        "seconds/format": "yyyy-mm-dd hh:nn:ss",
        "seconds/origin": "1970-01-01 00:00:01",
        "seconds/what": "e",
        "geo/length": "25"
    },

    "pops": {
        "caption": "POPs ",
        "items": [{ "id": "df", "cod": 1, "caption": "Distrito Federal", "sub": "clientes_df" }]
    },

    "clientes_df": {
        "caption": "Clientes do POP-DF",
        "items": [
			{ "cod":1, "id": "OTHERS", "caption": "OTHERS", "lat": -15.814495, "lon": -47.825561},
			{ "cod":2, "id": "AEB", "caption": "AEB", "lat": -15.815952, "lon": -47.943111},
			{ "cod":3, "id": "BNB", "caption": "BNB", "lat": -15.796741, "lon": -47.880261},
			{ "cod":4, "id": "CEBRASPE", "caption": "CEBRASPE", "lat": -15.771946, "lon": -47.865842},
			{ "cod":5, "id": "CGEE", "caption": "CGEE", "lat": -15.795682, "lon": -47.893624},
			{ "cod":6, "id": "CPRM", "caption": "CPRM", "lat": -15.788514, "lon": -47.879242},
			{ "cod":7, "id": "CONIF", "caption": "CONIF", "lat": -15.796845, "lon": -47.886535},
			{ "cod":8, "id": "Biotic", "caption": "Biotic", "lat": -15.710741, "lon": -47.911236},
			{ "cod":9, "id": "ESCS", "caption": "ESCS", "lat": -15.784173, "lon": -47.886892},
			{ "cod":10, "id": "CNE", "caption": "CNE", "lat": -15.821832, "lon": -47.895005},
			{ "cod":11, "id": "CONSECTI", "caption": "CONSECTI", "lat": -15.709371, "lon": -47.911080},
			{ "cod":12, "id": "EMBRAPA", "caption": "EMBRAPA", "lat": -15.731598, "lon": -47896735},
			{ "cod":13, "id": "EMBRAPA_AGROENERGIA", "caption": "EMBRAPA AGROENERGIA", "lat": -15.732396, "lon": -47.900091},
			{ "cod":14, "id": "EMBRAPA_CERRADOS", "caption": "EMBRAPA CERRADOS", "lat": -15.602484, "lon": -47.734280},
			{ "cod":15, "id": "EMBRAPA_SUCUPIRA", "caption": "EMBRAPA SUCUPIRA", "lat": -15.909348, "lon": -48.045474},
			{ "cod":16, "id": "EMBRAPA_HORTALIÇAS", "caption": "EMBRAPA HORTALIÇAS", "lat": -15.932820, "lon": -48.144700},
			{ "cod":17, "id": "EMBRAPA_RECURSOS_ENERGETICOS", "caption": "EMBRAPA RECURSOS ENERGETICOS", "lat": -15.731231, "lon": -47.902760},
			{ "cod":18, "id": "EMBRAPA_TRANSFERENCIA_ENERGIA", "caption": "EMBRAPA TRANSFERENCIA ENERGIA", "lat": -15.732396, "lon": -47.900091},
			{ "cod":19, "id": "EBC", "caption": "EBC", "lat": -15.795682, "lon": -47.893624},
			{ "cod":20, "id": "EMBRAPII", "caption": "EMBRAPII", "lat": -15.790370, "lon": -47.878825 },
			{ "cod":21, "id": "EBSERH HUB", "caption": "EBSERH HUB", "lat": -15.770945, "lon": -47.873543 },
			{ "cod":22, "id": "EBSERH", "caption": "EBSERH", "lat": -15.795682, "lon": -47.893624 },
			{ "cod":23, "id": "EPL", "caption": "EPL", "lat": -15.795682, "lon": -47.893624},
			{ "cod":24, "id": "FIOCRUZ", "caption": "FIOCRUZ", "lat": -15.771045, "lon": -47.871423},
			{ "cod":25, "id": "CAPES", "caption": "CAPES", "lat": -15.790370, "lon": -47.878825},
			{ "cod":26, "id": "ENAP", "caption": "ENAP", "lat": -15.830376, "lon": -47.930627},
			{ "cod":27, "id": "FUNARTE", "caption": "FUNARTE", "lat": -15.789177, "lon": -47.896319},
			{ "cod":28, "id": "UNB", "caption": "UNB", "lat": -15.762928, "lon": -47.867211},
			{ "cod":29, "id": "UNB_CEM4", "caption": "UNB CEM4", "lat": -15.828950, "lon": -48.109367},
			{ "cod":30, "id": "UNB_FAL", "caption": "UNB FAL", "lat": -15.948651, "lon": -47.934006},
			{ "cod":31, "id": "UNB_CEAG", "caption": "UNB CEAG", "lat": -15.766740, "lon": -47.878497},
			{ "cod":32, "id": "UNB_CEILÂNDIA", "caption": "UNB CEILÂNDIA", "lat": -15.843958, "lon": -48.102575},
			{ "cod":33, "id": "UNB_GAMA", "caption": "UNB GAMA", "lat": -15.989680, "lon": -48.044288},
			{ "cod":34, "id": "UNB_HVET", "caption": "UNB HVET", "lat": -15.749141, "lon": -47.877077},
			{ "cod":35, "id": "UNB_PLANALTINA", "caption": "UNB PLANALTINA", "lat": -15.600561, "lon": -47.658129},
			{ "cod":36, "id": "UNB_PRATICAS JURIDICAS", "caption": "UNB PRATICAS JURIDICAS", "lat": -15.821519, "lon": -48.113436},
			{ "cod":37, "id": "UNB-TV", "caption": "UNB-TV", "lat": -15.761087, "lon": -47.870662},
			{ "cod":38, "id": "FNDE", "caption": "FNDE", "lat": -15.801176, "lon": -47.883463},
			{ "cod":39, "id": "HFA", "caption": "HFA", "lat": -15.801478, "lon": -47.934763},
			{ "cod":40, "id": "HOSPITAL_SARAH_CENTRO", "caption": "HOSPITAL SARAH CENTRO", "lat": -15.79562, "lon": -47.891049},
			{ "cod":41, "id": "HOSPITAL_SARAH_LAGO NORTE", "caption": "HOSPITAL SARAH LAGO NORTE", "lat": -15.752444, "lon": -47.829375},
			{ "cod":42, "id": "IFB_REITORIA", "caption": "IFB REITORIA", "lat": -15.801132, "lon": -47.879293},
			{ "cod":43, "id": "IFB_BRASÍLIA", "caption": "IFB BRASÍLIA", "lat": -15.753950, "lon": -47.879337},
			{ "cod":44, "id": "IFB_SÃO SEBASTIÃO", "caption": "IFB SÃO SEBASTIÃO", "lat": -15.891531, "lon": -47.780283},
			{ "cod":45, "id": "IFB_PLANALTINA", "caption": "IFB PLANALTINA", "lat": -15.657779, "lon": -47.694783},
			{ "cod":46, "id": "IFB_RIACHO_FUNDO", "caption": "IFB RIACHO FUNDO", "lat": -15.881106, "lon": -48.008870},
			{ "cod":47, "id": "IFB_RECANTO_DAS_EMAS", "caption": "IFB RECANTO DAS EMAS", "lat": -15.912691, "lon": -48.077123},
			{ "cod":48, "id": "IFB_ESTRUTURAL", "caption": "IFB ESTRUTURAL", "lat": -15.793476, "lon": -47.969170},
			{ "cod":49, "id": "IFB_TAGUATINGA_NORTE", "caption": "IFB TAGUATINGA NORTE", "lat": -15.794036, "lon": -48.101760},
			{ "cod":50, "id": "IFB_CEILÂNDIA", "caption": "IFB CEILÂNDIA", "lat": -15.843058, "lon": -48.098376},
			{ "cod":51, "id": "IFB_SAMAMBAIA", "caption": "IFB SAMAMBAIA", "lat": -15.863034, "lon": -48.053854},
			{ "cod":52, "id": "INEP", "caption": "INEP", "lat": -15.787983, "lon": -47.914191},
			{ "cod":53, "id": "INMET", "caption": "INMET", "lat": -15.787685, "lon": -47.921448},
			{ "cod":54, "id": "INMETRO", "caption": "INMETRO", "lat": -15.794712, "lon": -47.910944},
			{ "cod":55, "id": "MCTIC SPO", "caption": "MCTIC SPO", "lat": -15.816786, "lon": -47.943379},
			{ "cod":56, "id": "MCTIC", "caption": "MCTIC", "lat": -15.799629, "lon": -47.870035},
			{ "cod":57, "id": "MD", "caption": "MD", "lat": -15.796647, "lon": -47.868991},
			{ "cod":58, "id": "MEC", "caption": "MEC", "lat": -15.795423, "lon": -47.873152},
			{ "cod":59, "id": "FINEP", "caption": "FINEP", "lat": -15.859067, "lon": -47.927017},
			{ "cod":60, "id": "CMB", "caption": "CMB", "lat": -15.781107, "lon": -47.892917},
			{ "cod":61, "id": "CNEN", "caption": "CNEN", "lat": -15.786728, "lon": -47.887426},
			{ "cod":62, "id": "ESR", "caption": "ESR", "lat": -15.804671, "lon": -47.881720},
			{ "cod":63, "id": "IBICT", "caption": "IBICT", "lat": -15.804671, "lon": -47.881720},
			{ "cod":64, "id": "ITI", "caption": "ITI", "lat": -15.787986, "lon": -47.884660},
			{ "cod":65, "id": "UNESCO", "caption": "UNESCO", "lat": -15.804671, "lon": -47.881720},
			{ "cod":66, "id": "IFB GAMA", "caption": "IFB GAMA", "lat": -15.993008, "lon": -48.053233},
			{ "cod":67, "id": "ANDIFES", "caption": "ANDIFES", "lat": -15.797419, "lon": -47.885995},
			{ "cod":68, "id": "CNPq", "caption": "CNPq", "lat": -15.859067, "lon": -47.927017}
        ]
    },

    "record": {
        "fields": [
            { "id":"seconds", "type": "int" },
            { "id":"lat", "type": "double" },
            { "id":"lon", "type": "double" },
            { "id":"pop", "type": "int"},
            { "id":"cliente", "type": "int"},
            { "id":"ttl", "type": "int" },
            { "id":"proto", "type": "int" },
            { "id":"z1", "type": "int" },
            { "id":"z2", "type": "int" },
            { "id":"npackets", "type": "int" }
        ]
    },

    "dimensions": [
        { "id": "location", "height": 25, "class": [ "geo", "lat", "lon" ],
            "desc": "Geolocalization of Event" },

        { "id": "cliente", "height": 1, "class": [ "cat", "cliente" ],
            "desc": "Cliente do POP"
			,
			"map_cat0": {"CNPq": 68, "ANDIFES": 67, "UNESCO": 65},
			"map_cat": "clientes_df"
		},
			
        { "id": "ttl", "height": 1, "class": [ "cat", "ttl" ],
            "desc": "TTL" }
    ],
	

    "dimensions_com_pop": [
        { "id": "location", "height": 25, "class": [ "geo", "lat", "lon" ],
            "desc": "Geolocalization of Event" },

        { "id": "pop_cliente", "height": 2,
            "desc": "POP/Cliente",
            "members": [
                { "id": "pop", "class": [ "cat", "pop" ]},
                { "id": "cliente", "class": [ "cat", "cliente" ]}
            ]
        }, 
		
        { "id": "ttl", "height": 1, "class": [ "cat", "ttl" ],
            "desc": "TTL" }
    ],	

    "terminal": {
        "default": {
            "caption": "N", "unity":"N"
        },
        "contents": [
            { "id": "quantidades", "formula":["sum", "npackets" ] },
            { "id": "time", "container": {
	            "bin": 60,
                "class": ["binlist", "seconds"],
                "contents": [
                    { "id": "hsum", "caption": "NPackets", "unity":"N.Packets", "formula":["sum", "npackets" ] },
                    { "id": "hc",   "caption": "Distintos", "unity":"Distintos", "formula":["counter"] }
                ] 
            }}
        ]
    },

    "input": {
        "type": "csv",
        "sep": ";",
        "data": [
            { "id": "seconds", 
                "conv": [ "datetime_to_epoch", "seconds", "@format", "@origin" ] 
            },
            { "id": "lat" },
            { "id": "lon" },
            { "id": "pop" },
            { "id": "cliente" },
            { "id": "ttl"},
            { "id":"proto"},
            { "id":"z1"},
            { "id":"z2"},
            { "id": "npackets"}
        ]
	}
}


}
]]


--------------------
--
--
--
local function map_cat(src, result)
	if not src then return end
	local t = src
	if type(t) == "string" then
		t = result[src]
	end
	
	if type(t) ~= "table" then
		return
	end
	
	local map_cat = {}

	--[[ padrao: {
			{ "cod":1, "id": "OTHERS", "caption": "OTHERS", "lat": -15.814495, "lon": -47.825561},
			{ "cod":2, "id": "AEB", "caption": "AEB", "lat": -15.815952, "lon": -47.943111},...
		}
	--]]
	if t.items and type(t.items) == "table" then -- array de objetos com cod e id
		for _, obj in ipairs(t.items) do
			map_cat[obj.id] = obj.cod
		end
	
	-- padrao: { "1": "WEB", "2": "SMTP", ... }
	elseif t["1"] then 
		for id, cod in pairs(t) do
			map_cat[cod] = tonumber(id)
		end
	
	-- padrao: { id: cod, id: cod }
	else
		for id, cod in pairs(t) do
			map_cat[id] = cod
		end
	end
	return {map_cat = map_cat}
end

--------------------
--
--
--
--local function load_info_from_schema(host)
local function load_info_from_schema(url)
	-- if not _m.hosts[host] then return end -- eh verificado em load_host
	
	-- already loaded ?
	-- if _m.hosts[host] then return end -- eh verificado em load_host
	
	--local query_str = '{"schema": 1, "from": "' .. url .. '"}'
	local query_str = '{"schema": 1}'
	local response_str = base.body_request(query_str, url)


	local response_json = cjson.decode(response_str)
	
	local schema_json = response_json.result
	if not schema_json then return end
	
	local options, selectors, t_measures, s_measures = {}, {}, {}, {}

	local items = {
		options = options,
		selectors = selectors,
		t_measures = t_measures,
		s_measures = s_measures
	}
	
	-- parse schema.dimensions
	for k2, v2 in pairs(schema_json.dimensions) do
		if v2.class then
			--local t = map_cat(v2.map_cat) or 1
			options[v2.id] = map_cat(v2.map_cat, schema_json) or 1 --options
		elseif v2.members then
			for k3, v3 in pairs(v2.members) do
				options[v3.id] = map_cat(v3.map_cat, schema_json) or 1 --options
			end
		end
	end
		
	-- parse schema.terminal
	for k2, v2 in pairs(schema_json.terminal.contents) do
		if not v2.container then
			t_measures[v2.id] = 1
		else -- t_measures
			selectors[v2.id] = 1 -- selector
			for k3, v3 in pairs(v2.container.contents) do -- s_measures
				s_measures[v3.id] = 1
			end
		end
	end
	
	return items, schema_json
end


--------------------
--
--
--
local function load_host(hosts, host)
	local h = hosts[host]
	if not h then return end

	-- incomplete host table?
	if not h.items then
		--local t = load_info_from_schema(host)
		if not h.url then return end
		local t, s = load_info_from_schema(h.url)
		if not t then return end
		h.items = t
		h.schema = s
	end

	return h
end


--------------------
--
--
--
function _m.load_host(host)
	return load_host(hosts, host)
end




local loading 

--------------------
--
--
function _m.get_hosts()
	if hosts[1] then return hosts end

	if loading then 
		repeat 
			ngx.sleep(0.1)
		until not loading
		if hosts[1] then return hosts end
	end
	
	loading = true
	
	-- load_all
	for k, v in pairs(hosts) do
		if type(k) ~= "number" then 
			local ok, err = pcall(load_host, hosts, k)
			if not ok then 
				loading = false
				error(err)
			end
		end
	end
	
	hosts[1] = true
	loading = nil
	
	return hosts
end

return _m
