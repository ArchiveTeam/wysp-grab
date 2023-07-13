local module = {}
local JSON = require 'Lib/JSON'
local retry_common = require "Lib/retry_common"

module.get_urls = function(file, url, is_css, iri)
    local json = JSON:decode(get_body())


    -- Things that just need to be remembered
    local start = json["next"]
    local rg = current_options.url:match("[&%?]rg=(%d+)")
    local nb_col = current_options.url:match("[&%?]nb_col=(%d+)")
    local tlid = current_options.url:match("[&%?]tlid=([^&%?]+)")
    local order = current_options.url:match("[&%?]order=([^&%?]+)")


    ---@type number[]
    local heights
    if current_options.heights then
        heights = deep_copy(current_options.heights)
    else
        heights = {}
        for i=1,tonumber(nb_col) do
            table.insert(heights, 0)
        end
    end

    local col_heights_string = "%5B"

    -- If it's not an empty gallery...
    if json["columns"][1] ~= "" then
        for i=1,tonumber(nb_col) do
            local html = json["columns"]["html"][i]
            for url in html:gmatch('<img [^<]- src="(https?://.-)"') do
                queue_request({url=url}, "required_resource", url)
            end
            for post_url in html:gmatch('/post/%d+/') do
                queue_request({url="https://www.wysp.ws" .. post_url}, "submission", true)
            end
            -- Should be redundant
            for _, id in pairs(json["columns"]["idList"]) do
                queue_request({url="https://www.wysp.ws/post/" .. id .. "/"}, "submission", true)
            end

            -- Calculate the heights
            for height_percent in html:gmatch('padding%-top:([%d%.]+)%%;"') do
                -- 415... empirically determined
                heights[i] = heights[i] + 415.3499755859375 * tonumber(height_percent) / 100.0 + 10
            end

            for _ in html:gmatch('<div class="noteContainer">') do
                -- This is just a wild guess - there are 2 types of these (attached/not to a image)
                --  and they seem to have heights based on the text contained
                -- In the interest of my sanity I have chosen not to write a browser in Lua and instead
                --  just let these probably fail playback (which will happen if the user's browser width isn't
                --  1920 anyway)
                heights[i] = heights[i] + 149.31666564941406
            end

            col_heights_string = col_heights_string .. tostring(math.floor(heights[i] + 0.5)) .. "%2C" -- 2C is comma
        end

        col_heights_string = col_heights_string:gsub("%%2C$", "%%5D") -- 5D is ']'


        if json["next"] ~= -1 then
            queue_request({url="https://www.wysp.ws/timeline/load/?start=" .. tostring(start) .. "&rg=" .. rg .. "&nb_col=" .. nb_col .. "&col_heights=" .. col_heights_string .. "&tlid=" .. tlid .. "&order=" .. order .. "&cursor=", heights=heights}, "gallery", false)
        end
    end
end


module.take_subsequent_actions = retry_common.status_code_subsequent_actions(5, {200})

return module