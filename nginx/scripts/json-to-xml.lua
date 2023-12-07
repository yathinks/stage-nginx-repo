if ngx.var.base_url == nil or  ngx.var.base_url == "" then 
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.log(ngx.ERR, "Plugin is not configured properly. base_url variable is not set.")
    ngx.say("Plugin is not configured properly. base_url variable is not set.")
    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end
local http = require "resty.http"
local json = require ("dkjson")
local httpc = http.new()
ngx.req.read_body()
local base_url = ngx.var.base_url
local request_headers = ngx.req.get_headers()
local url_with_query
local query_string = ngx.var.args
if query_string == nil then
    url_with_query = base_url
else
    url_with_query = base_url .. "?" .. query_string
end
local request_host = string.match(base_url, "^https://([^/]+)")
request_headers["host"] = request_host
local res, err = httpc:request_uri(url_with_query, {
    method = ngx.var.request_method,
    body = ngx.req.get_body_data(),
    headers = request_headers
})

local function convert_table_to_xml(tbl)
    local xml_str = ""
    for key, value in pairs(tbl) do
        xml_str = xml_str .. '<' .. key .. '>'
        if type(value) == "table" then
            xml_str = xml_str .. convert_table_to_xml(value)
        else
            xml_str = xml_str .. value
        end
        xml_str = xml_str .. '</' .. key .. '>'
    end
    return xml_str
end

if res then
    ngx.status = res.status
    local contentType = res.headers["content-type"]
    for key, value in pairs(res.headers) do
        ngx.header[key] = value
    end
    if res.status >= 200 and res.status < 300  and contentType == 'application/json'then
        local json_obj = json.decode(res.body)
        local xml_str = convert_table_to_xml(json_obj)
        ngx.header.content_type = 'application/xml';
        ngx.print(xml_str);
    else 
        ngx.print(res.body);
    end
else 
    ngx.say("no response")
end
