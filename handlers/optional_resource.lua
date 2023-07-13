local retry_common = require("Lib/retry_common")

local module = {}

module.write_to_warc = function(url, http_stat)
    if http_stat["statcode"] == 200 then
        return true
    else
        retry_common.retry_unless_hit_iters(5, true)
        return current_options.try == 6 -- Save the error page
    end
end

return module