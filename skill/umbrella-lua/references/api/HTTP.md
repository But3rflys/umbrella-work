# HTTP
Table to work with HTTP requests.

HTTP.Request(method: string, url: string, [data: {headers:table<string>, cookies:string|table<string>, data:string|table<string>, timeout:number} = {}], callback: fun(tbl: {response: string, code: string, header: string, param: string, error_code: number, error_message: string}):nil, [param: string = ""]) -> boolean
  Do HTTP request. Returns true if request was sent successfully.
  method: HTTP method
  url: URL
  data: data to send
  callback: callback function to call when request is done. Take 1 argument - response data table, see example.
  param: string parameter to pass to callback function to identify request
```lua
-- http_request.lua
local url = "https://reqres.in/api/users/2";

local headers = {
    ["User-Agent"] = "Umbrella/1.0",
    ['Connection'] = 'Keep-Alive',
}

local JSON = require('assets.JSON')
local callback = function(response)
    Log.Write(response["response"]);
    Log.Write(response["code"]);
    Log.Write(response["header"]);
    Log.Write(response["param"]);

    local json = JSON:decode(response["response"]);
    Log.Write(json["data"]["email"]);
end

HTTP.Request("GET", url, { 
		headers = headers,
	}, callback, "reqres_get");
```
