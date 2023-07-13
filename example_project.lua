--require "strict"


local module = {}

_ = nil

-- TODO lowercase user pages (but try to avoid lowercasing the URLencoding? Or is that uninportant?)
-- TODO cookies on gallery pages when not being backfed

local old_queue_request = queue_request
queue_request = function(options_table, handler, backfeed)
    local opts = deep_copy(options_table)
    if handler == "user" and backfeed then
        opts.url = opts.url:lower()
    end
    -- Auth cookies on gallery pages, follower discovery, and user pages (cosmetic, as these more closely
    --  reflect the experience of an authed user by showing NSFW)
    if (handler == "gallery"
        or options_table.do_not_wtw
        or handler == "user") and not backfeed then
        if not opts.headers then
            opts.headers = {}
        end
        opts.headers.Cookie = "session=eyJ1aWQiOjU5NzU0MDE4NDU3NTE4MDh9|1689164164|c1d9c1b2180b0b354ceba74f46f00f692788ae94"
    end

    -- E.g. entry on the followers of https://www.wysp.ws/panema/
    opts.url = opts.url:gsub('^https:///', 'https://')

    old_queue_request(opts, handler, backfeed)
end

return module
