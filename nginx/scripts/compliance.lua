if ngx.var.base_url == nil or  ngx.var.base_url == "" then 
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.log(ngx.ERR, "Compliance Plugin is not configured properly. base_url variable is not set.")
    ngx.say("Compliance Plugin is not configured properly. base_url variable is not set.")
    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end
local http = require "resty.http"
local json = require ("dkjson")
local httpc = http.new()
ngx.req.read_body()
local base_url = ngx.var.base_url
local request_headers = ngx.req.get_headers()
local url_with_query
local query_params = {}
local query_string = ngx.var.args
if query_string == nil then
    url_with_query = base_url
    query_params = json.null
else
    url_with_query = base_url .. "?" .. query_string
    for key, value in string.gmatch(query_string, "([^&]+)=([^&]+)") do
        query_params[key] = value
    end
end
local request_host = string.match(base_url, "^https://([^/]+)")
request_headers["host"] = request_host

local hexRef = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"};
local val = "";
for i = 0, 16
do
    val = val .. hexRef[math.random(1, 16)];
end

local traceId = request_headers["traceId"]
local spanId = request_headers["span-id"]

if spanId ~= nil then 
    request_headers["parentSpanId"] = spanId
end
if traceId == nil then
    request_headers["traceId"] = val
end
request_headers["span-id"] = val


local reqTimeStamp = ngx.now()*1000
local res, err = httpc:request_uri(url_with_query, {
    method = ngx.var.request_method,
    body = ngx.req.get_body_data(),
    headers = request_headers
})
local resTimeStamp = ngx.now()*1000
if res then
    ngx.status = res.status
    for key, value in pairs(res.headers) do
        ngx.header[key] = value
    end
    ngx.print(res.body)
else 
    ngx.log(ngx.ERR, "Error from URL.", err)
end

local request_method = ngx.var.request_method
local compliance_request_headers = request_headers
compliance_request_headers["request-timestamp"] = reqTimeStamp
compliance_request_headers["response-timestamp"] = resTimeStamp
compliance_request_headers["gateway-type"] = "NGINX"
local request_path = url_with_query
local formParams = {}
local raw_request_body = ngx.req.get_body_data()
local request_body
if raw_request_body then
    request_body = tostring(raw_request_body)
else 
    request_body = json.null
end

local response_headers = res.headers
local response_status = res.status
local response_body
if res.body then
    response_body = res.body
else 
    response_body = json.null
end

if(response_headers["content-type"] ~= nil) then
    local contentType = response_headers["content-type"]
    response_headers["content-type"] = nil
    response_headers["Content-Type"] = contentType
end

-- Construct the JSON payload
local payload = {
    request = {
        headerParams = compliance_request_headers,
        verb = request_method,
        path = request_path,
        hostname = request_host,
        queryParams = query_params,
        requestBody = request_body
    },
    response = {
        headerParams = response_headers,
        responseBody = tostring(response_body),
        statusCode = tostring(response_status)
    }
}
local json_payload = json.encode(payload,{ indent = true })
-- compliance payload
-- ngx.print(json_payload)

local complianceRes = ngx.location.capture("/apiwiz-compliance", {
    method = ngx.HTTP_POST,
    body = json_payload
})

if not complianceRes or complianceRes.status ~= 200 then
    ngx.log(ngx.ERR, "Apiwiz Compliance Call-out failed")
    if complianceRes.body then
        ngx.log(ngx.ERR, "Error: ", complianceRes.body)
    end
else 
    ngx.log(ngx.INFO, "Apiwiz Compliance call-out was successful, Transaction Id : ",complianceRes.body)
end
-- Compliance response
-- ngx.print(complianceRes.body)
