local module = {}
local retry_common = require("Lib/retry_common")
local backfeed = require("Framework/backfeed")

local sc

module.get_urls = function(file, url, is_css, iri)
    if sc == 404 then
        assert(get_body():match("Page not found"))
        return
    end

    -- All Wysp users have a numerical ID (though sadly they appear to be non-contiguous); not all have a slug name
    -- If this is a numerical page, try guessing the slug - if this succeeds, it will get duplicate data,
    --  but I expect it to seldom happen, as there is little motivation for anyone to link to numerical pages
    --  for users that have a slug URL
    if string.match(current_options.url, '^https?://www%.wysp%.ws/profile/%d+/$') then
        local profile_name = get_body():match('<h1 class="profile%-name" style="font%-size:25px; margin%-top:5px; float:left; margin%-top:9px;">(.-)</h1>')
        -- N.b. this will be made lowercase by the queue_request wrapper in the general project script
        queue_request({url="https://www.wysp.ws/" .. profile_name .. "/"}, "user", true)
    else
        -- If this is a slug page, get the numerical one non-backfed, for accessibility purposes
        local id_form = get_body():match('<div class="wysp%-comments" target_url=\'(/profile/%d+/)\' start_with=\'15\'')
        queue_request({url="https://www.wysp.ws" .. id_form}, retry_common.only_retry_handler(5, {200}), false)
    end

    -- Avatar
    local avatar_url = get_body():match('<img id="profile%-avatar%-img" src="(.-)"')
    queue_request({url=avatar_url}, "required_resource", true)

    -- Shouts
    local comments_target = get_body():match("<div class=\"wysp%-comments\" target_url='(/profile/%d+/)' start_with='15' order=\"antichronological\"　id=\"profileComments\">")
    queue_request({url="https://www.wysp.ws/comments/box/?url=" .. comments_target .. "&rg=15&order=antichronological", first_page=true}, "comments", false)

    -- Homepage URL
    -- E.g. https://www.wysp.ws/busket/
    -- Wrapped like this in case I am extracting it wrong
    if get_body():match("glyphicon%-home") then
        local homepage_url = get_body():match("<span class=\"glyphicon glyphicon%-home\" style=\"font%-size:12px;\"></span>&nbsp;&nbsp;(.-)%s*</div>")
        backfeed.queue_external_url_for_upload(homepage_url)
    end

    local header_image_url = get_body():match('<img id="profile%-header%-pic" src="([^"<>"]+)" style="position:absolute')
    if header_image_url then
        queue_request({url=header_image_url}, "required_resource", false)
    else
        assert(not get_body():match('id="profile%-header%-pic'))
    end

    local user_name = current_options.url:match('^https:?//www%.wysp%.ws/(.+)/$')

    -- Featured/homepage submissions
    local showcase_url = get_body():match('<div class="timeline" id="user%-showcase%-tl" tlid="(user%-showcase%-%d+)" nb_col="2" rg="14" order="antichronological">')
    queue_request({url="https://www.wysp.ws/timeline/load/?tlid=" .. showcase_url .. "&start=-1&rg=14&nb_col=2&order=antichronological"}, "gallery", false)

    local main_gallery_url = get_body():match('<div class="timeline" id="complete%-feed%-tl" tlid="(user%-main%-%d+)" nb_col="4", rg="20" order="antichronological">')
    queue_request({url="https://www.wysp.ws/timeline/load/?tlid=" .. main_gallery_url .. "&start=-1&rg=20&nb_col=4&order=antichronological"}, "gallery", false)

    local bookmarks_url = get_body():match('<div class="timeline" id="bookmarks%-feed%-tl" tlid="(user%-bookmarks%-%d+)" nb_col="4", rg="20" order="antichronological">')
    queue_request({url="https://www.wysp.ws/timeline/load/?tlid=" .. bookmarks_url .. "&start=-1&rg=20&nb_col=4&order=antichronological"}, "gallery", false)

    local followees_id = get_body():match("{'uid':(%d+), 'card':1}")
    queue_request({url="https://www.wysp.ws/connect/followees/?uid=" .. followees_id .. "&card=1"}, "following", false)

    -- Unauthenticated, it appears the followers URL only returns 302 to /landing/
    queue_request({url="https://www.wysp.ws/connect/followers/?uid=" .. followees_id .. "&card=1"}, retry_common.only_retry_handler(2, {302}), false)

    -- Authenticated but unsaved
    queue_request({url="https://www.wysp.ws/connect/followers/?uid=" .. followees_id .. "&card=1", do_not_wtw=true}, "following", false)
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