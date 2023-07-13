local module = {}
local retry_common = require("Lib/retry_common")
local JSON = require 'Lib/JSON'

-- TODO extraction of external links (maybe just skip DCP and put it in get_urls? Since it needs to be run on JSON)

module.get_urls = function(file, url, is_css, iri)
    ---@type string
    local html -- HTML of body, for processing common to initial and subsequent pages
    if current_options.first_page then
        local rg, ref, cursor = get_body():match('<button class="loadButton loadCommentsButton" rg="(%d+)" ref="(.-)" cursor="(.-)" ref_container_id=".-" total_comment_count="%d+" order="antichronological" hidden_count="%d+" index="%d+">')
        if ref then
            cursor = cursor:gsub("=", "%%3D")
            queue_request({url="https://www.wysp.ws/comments/load/?cursor=" .. cursor .. "&rg=" .. rg .. "&order=antichronological&ref=" .. ref}, current_handler, false)
        else
            assert(not get_body():match("loadCommentsButton"))
        end
        html = get_body()
    else
        -- Subsequent page
        local json = JSON:decode(get_body())["success"]
        if json["more"] then
            assert(not current_options.threaded) -- "Replies to replies" which have continuation specified. Not sure how to handle these
            local cursor = json["cursor"]:gsub("=", "%%3D")
            ---@type string
            local ref = current_options.url:match("ref=([^&]+)")
            local rg = current_options.url:match("rg=(%d+)")
            queue_request({url="https://www.wysp.ws/comments/load/?cursor=" .. cursor .. "&rg=" .. rg .. "&order=antichronological&ref=" .. ref}, current_handler, false)
        end
        html = json["html"]
    end

    -- Extract replies to replies
    -- E.g. on https://www.wysp.ws/post/6977061/
    local n_found = 0
    for rg, id in html:gmatch('<button class="loadButton loadRepliesButton" id="%d+_load_replies_button" rg="(%d+)" in_reply="(%d+)" ref_container_id="%d+_replies_container" cursor="" total_reply_count="" hidden_count="%d+">See more %(%d+ more reply%)</button>') do
        queue_request({url="https://www.wysp.ws/comments/load/replies/?cursor=&rg=" .. rg .. "&id=" .. id, threaded=true}, current_handler, false)
        n_found = n_found + 1
    end
    assert(n_found == 0 or html:match("loadRepliesButton"))

    -- And general user/avatar link detection
    for user in html:gmatch('<a class="comAuthorName" href="(.-)">') do
        -- https://www.wysp.ws/auzurin%20/ has a space in the name
        assert(user:match('/[^/"]+/') or user:match('/profile/%d+/'))
        queue_request({url="https://www.wysp.ws" .. user}, "user", true)
    end

    for avatar in html:gmatch('<img class="avatar" src="(https?://.-)"/>') do
        queue_request({url=avatar}, "optional_resource", true)
    end
end


module.take_subsequent_actions = function(url, http_stat)
    if http_stat["statcode"] == 200 then
        return true
    else
        retry_common.retry_unless_hit_iters(5, false)
        return false
    end
end

return module