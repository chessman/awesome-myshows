# Myshows widget for Awesome WM

This widget interacts with [Myshows](http://myshows.me) site and shows unwatched
(left mouse button) and coming soon (right mouse button) TV series.

The widget uses Perl script for fetching and formatting data. This script can be
used standalone without Awesome.

## Installation

Required Perl packages: libwww-perl, JSON.

Optional: HTTP-Async.

    cd ~/.config/awesome
    git clone git://github.com/chessman/awesome-myshows.git myshows

    echo "login=<myshows-login>" > ~/.myshowsrc
    echo "password=<myshows-password>" >> ~/.myshowsrc

### rc.lua

    local myshows = require("myshows")

Add myshows.icon\_widget in desired place. For example:

    right_layout:add(myshows.icon_widget)
