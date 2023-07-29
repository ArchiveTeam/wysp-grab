local module = {}
local retry_common = require("Lib/retry_common")
local JSON = require 'Lib/JSON'

local sc

module.get_urls = function(file, url, is_css, iri)
    if sc == 500 then
        return
    end
    ---@type table<string, string>
    local json = JSON:decode(get_body())
    if json["html"] then
        local cursor, pid = json["html"]:match('<div id="loadMoreUsers" class="loadMoreUsers cardCenteredLink" start="0" nid="" uid="" type="bookmarks" cursor="(%S-)" pid="(%d+)">See more</div>')
        if cursor then
            queue_request({url="https://www.wysp.ws/timeline/bookmarks/?nid=&uid=&cursor=" .. cursor .. "&start=0&pid=" .. pid}, current_handler, false)
        end
    else
        assert(json["cursor"])
        if json["cursor"] ~= "" then
            local pid = current_options["url"]:match("&pid=(%d+)")
            queue_request({url="https://www.wysp.ws/timeline/bookmarks/?nid=&uid=&cursor=" .. json["cursor"] .. "&start=0&pid=" .. pid}, current_handler, false)
        end
    end

    -- For initial reqs it is in html; else in users
    for avatar in (json["html"] or json["users"]):gmatch('<img class="searchAvatar" src="(https?://%S-)"') do
        queue_request({url=avatar}, "optional_resource", true)
    end

    -- This needs to cover both /profile/ and human-name profiles
    for user in (json["html"] or json["users"]):gmatch('<a href="(%S-)"') do
        queue_request({url="https://www.wysp.ws" .. user}, "user", true)
    end
end

module.take_subsequent_actions = function(url, http_stat)
    sc = http_stat["statcode"]
    if sc == 200 or sc == 500 then
        return true
    else
        retry_common.retry_unless_hit_iters(5, false)
        return false
    end
end


return module
