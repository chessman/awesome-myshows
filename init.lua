local wibox     = require("wibox")
local awful     = require("awful")
local naughty   = require("naughty")
local pread     = awful.util.pread

module("myshows")

myshows = {}

function get_buttons()
    return awful.util.table.join(
    awful.button({ }, 1, function()
        notify('unwatched')
    end),
    awful.button({ }, 3, function()
        notify('next')
    end))
end

function notify(type)

    awful.util.spawn(awful.util.getdir("config") ..
                     "/myshows/myshows.pl -o notify-send -t " ..  type .. " 2>&1")
end

myshows.icon_widget = wibox.widget.imagebox()

local image = awful.util.getdir("config") .. "/myshows/myshows.png"
myshows.icon_widget:set_image(image)
myshows.icon_widget:buttons(get_buttons())

return myshows
