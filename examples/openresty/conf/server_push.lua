
-- Link:</stle.css>;rel=preload; as=style,</stle.css>;rel=preload; as=jpg; nopush
local ffi = require("ffi")

ffi.cdef[[
    int ngx_http_v2_push(void *r, const char *u_str, size_t u_len);
]]

function split(s, delim)
    if type(delim) ~= "string" or string.len(delim) <= 0 then
        return
    end

    local start = 1
    local t = {}
    while true do
    local pos = string.find (s, delim, start, true) -- plain find
        if not pos then
          break
        end

        table.insert (t, string.sub (s, start, pos - 1))
        start = pos + string.len (delim)
    end
    table.insert (t, string.sub (s, start))

    return t
end
local r = getfenv(0).__ngx_req
if not r then
    return error("no request found")
end

local res_paths= tostring(ngx.req.get_headers()["Link"])
local paths = split(res_paths,',')
if not paths then
   ngx.log(ngx.ERR, "link header have no push resources")
   goto push_complete
end

local m,n
local npath = #paths
if ngx.req.get_headers()["Link"] then
    for i in ipairs(paths) do
        --print(paths[i])
        m,n = string.find(paths[i],'nopush')
        if m and n then
            ngx.log(ngx.ERR,"the Link url have <nopush> flag")
            if i >= npath then 
                goto push_complete
            else
                goto push_continue
            end
        end
        m,n = string.find(paths[i],'rel=preload')
        if not m and not n then
            --print "link have no preload keyword"
            if i >= npath then 
                goto push_complete
            else
                goto push_continue
            end
        end
        m,_ = string.find(paths[i],'<')
        _,n = string.find(paths[i],'>')
        if m and n then
            local path = string.sub(paths[i],m+1,n-1)
            local rc = ffi.C.ngx_http_v2_push(r, path, #path)
            if rc ~= 0 then
                ngx.log(ngx.ERR, "push failed: ", rc)
            end
            if i >= npath then 
                goto push_complete
            else
                goto push_continue
            end
        else
            ngx.log(ngx.ERR, "link header have no push resources")
            if i >= npath then 
                goto push_complete
            else
                goto push_continue
            end
            --print(path)
        end
        ::push_continue::
    end
end
::push_complete::
