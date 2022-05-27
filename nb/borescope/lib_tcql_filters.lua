local fs = require "lib_tc_functions"

local _m = {}

_m.option_filters = {
    eq      = { vmin=1, vhead="i", vtail="i" },
    zrect   = { vmin=5, vmax=5, vhead="iffff" },
    zpoly   = { vmin=7, vhead="i", vtail="f" },
    between = { vmin=2, vmax=2, vmap=fs.str_to_epoch, vhead="ii" },
    range   = { vmin=2, vmax=2, vmap=fs.str_to_epoch, vhead="ii" },
}

_m.procs = {
    increase = { vmin = 3, vmax = 3, pars_str = "vii", vproc = tsql_increase }
}

_m.filters = {
    eq      = { vmin=1, vhead="i", vtail="i" },
    zrect   = { vmin=5, vmax=5, vhead="iffff" },
    zpoly   = { vmin=7, vhead="i", vtail="f" },
    between = { vmin=2, vmax=2, vmap=fs.str_to_epoch, vhead="ii" },
    range   = { vmin=2, vmax=2, vmap=fs.str_to_epoch, vhead="ii" },
}

return _m