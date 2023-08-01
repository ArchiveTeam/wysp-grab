--require "strict"

require "Lib/table_show"
local backfeed_l = require "Framework/backfeed"
local queue_item_utils = require "Framework/queue_item"


local module = {}

_ = nil

-- TODO lowercase user pages (but try to avoid lowercasing the URLencoding? Or is that uninportant?)
-- TODO cookies on gallery pages when not being backfed

local old_queue_request = queue_request
queue_request = function(options_table, handler, backfeed)
    -- Mistakenly sent Egloos items here
    if type(handler) == "string" and handler:match("^api_.*") or handler == "resources" then
        backfeed_l.queue_for_sending_back_to_egloos(handler, queue_item_utils.serialize_request_options(options_table))
        return
    end
    
    -- Weird stuff
    if options_table.url:match('^https?://static/') then
        return
    end
    
    -- Non-users
    local user = options_table.url:match('^https?://www%.wysp%.ws/([^/%?]+)/$')
    if handler == "user" and
        user == "faq"
        or user == "feedback"
        or user == "friends"
        or user == "landing"
        or user == "practice"
        or user == "login"
        or user == "register"
        or user == "about"
        or user == "terms"
        or user == "connect"
        or user == "inspiration"
        or user == "submit"
        or user == "wysp-feedback"
        or user == "logout"
        or user == "static"
        or (user and user:match("&")) then
        return
    end

    local opts = deep_copy(options_table)
    if handler == "user" and backfeed then
        opts.url = opts.url:lower()
    end
    
    if opts.url:match('^https?://wysp%.ws/') then
        assert(not backfeed) -- This should only handle items coming directly in from the tracker
        print("Diverting " .. opts.url)
        opts.url = opts.url:gsub('^https?://wysp%.ws/', 'https://www.wysp.ws/')
        queue_request(opts, handler, true)
        return
    end
    
    assert(not (opts.url:match('^https?://www%.wysp.ws/post/%d+$') or opts.url:match('^https?://www%.wysp.ws/[^/%?]+$')))
    
    
    
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
    
    if not opts.url then
        print(debug.traceback())
        print(table.show(opts))
    end

    -- E.g. entry on the followers of https://www.wysp.ws/panema/
    opts.url = opts.url:gsub('^https:///', 'https://')

    old_queue_request(opts, handler, backfeed)
end

return module
