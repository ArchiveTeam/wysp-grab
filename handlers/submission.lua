local module = {}
local retry_common = require("Lib/retry_common")

local sc


module.get_urls = function(file, url, is_css, iri)
    if sc == 404 then
        assert(get_body():match("Page not found"))
        return
    end
    -- Queue the image URL
    if get_body():match('sapImage') then -- Only image posts
        queue_request({url=get_body():match('<img class="sapImage" src="(https?://%S-)"')}, retry_common.only_retry_handler(5, {200}), false)
        -- Also the "full size" image
        local full_size = get_body():match('<a href="(https?://%S-)" class="theaterStatlineLink" target="_blank">Full size</a>')
        queue_request({url=full_size}, retry_common.only_retry_handler(5, {200}), false)
    end

    local id = url:match("^https?://www%.wysp.ws/post/(%d+)/")
    queue_request({url="https://www.wysp.ws/comments/box/?url=/post/" .. id .. "/&rg=20&order=antichronological", first_page=true}, "comments", false)

    local author = get_body():match('<a class="sapAuthorUrl" href="(%S-)">')
    assert(author:match('/[^/"]+/') or author:match('/profile/%d+/'))
    queue_request({url="https://wysp.ws" .. author}, "user", true)
    
    -- The expand line will not be sent by the server if the UA begins with "arch", case-insensitive.
    if get_body():match('<a href="#" class="viewBookmarks"') then
        queue_request({url="https://www.wysp.ws/timeline/bookmarks/?pid=" .. id .. "&card=1"}, "bookmarks", false)
    end
end


module.take_subsequent_actions = function(url, http_stat)
    sc = http_stat["statcode"]
    if sc == 200 or sc == 404 then
        return true
    else
        retry_common.retry_unless_hit_iters(5, false)
        return false
    end
end


return module
