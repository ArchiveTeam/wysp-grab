local module = {}
local retry_common = require "Lib/retry_common"
local JSON = require 'Lib/JSON'

-- Similar to comments and there is a lot of copy/paste between them

-- "do_not_wtw" controls whether the results are written to warc
-- The general project script will set auth cookies if do_not_wtw is set

module.get_urls = function(file, url, is_css, iri)
    ---@type string
    local html -- HTML of body, for processing common to initial and subsequent pages
    if not current_options.url:match('&start=') then
        -- First page
        html = JSON:decode(get_body())["html"]
        local start, uid, type, cursor = html:match('<div id="loadMoreUsers" class="loadMoreUsers cardCenteredLink" start="(%d+)" nid="" uid="(%d+)" type="([a-zA-Z]+)" cursor="(.-)" pid="">See more</div>')
        if start then
            cursor = cursor:gsub("=", "%%3D")
            local nextType
            if type == "followUser" then
                nextType = "followers"
            else
                assert(type == "youFollow")
                nextType = "followees"
            end
            queue_request({url="https://www.wysp.ws/connect/" .. nextType .. "/?nid=&uid=" .. uid .. "&cursor=" .. cursor .. "&start=" .. start .. "&pid=",  do_not_wtw=current_options.do_not_wtw}, current_handler, false)
        else
            assert(not html:match('<div id="loadMoreUsers"'))
        end
    else
        local j = JSON:decode(get_body())
        html = j["users"]
        if j["cursor"] ~= "" then
            assert(j["start"] == 0)
            local cursor = j["cursor"]:gsub("=", "%%%%3D") -- Escaped for gsub
            queue_request({url=current_options.url:gsub("&cursor=.-&start=", "&cursor=" .. cursor .. "&start="), do_not_wtw=current_options.do_not_wtw}, current_handler, false)
        else
            assert(j["start"] == -1)
        end
    end

    for avatar in html:gmatch('<img class="searchAvatar" src="(https?://[^%s"]-)"') do
        queue_request({url=avatar}, "optional_resource", true)
    end

    for user_url in html:gmatch('<div class="userSearchResult">%s*<a href="(.-)">') do
        queue_request({url="https://www.wysp.ws" .. user_url}, "user", true)
    end

end

module.write_to_warc = function(url, http_stat)
    return not current_options.do_not_wtw
end

module.take_subsequent_actions = retry_common.status_code_subsequent_actions(5, {200})

return module