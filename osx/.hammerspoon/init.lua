-- use karabiner to map this to caps lock
hyper = {"cmd", "alt", "ctrl", "shift"}


-- app hotkeys
singleapps = {
    -- top row
	-- {'W', 'Sublime'},
    -- {'E', 'Warp'},
    -- {'R', 'Obsidian'},
    -- -- T is quick save in Anybox
    -- -- middle row
    -- {'A', 'Brave Browser'},
    -- {'S', 'Cursor'},
    -- -- {'S', 'Visual Studio Code'},
    -- {'D', 'Slack'},
    -- -- {'F', 'LM Studio'},
    -- {'H', 'Slack'},
    -- {'J', 'Messages'},
    -- -- K is Cardhop (defined in app)
    -- {'L', 'Podcasts'},
    -- bottom row
    -- {'Z', 'Google Chrome'},
    -- C is Copy 'Em (defined in app)
    -- V is Clipboard (defined in app)
    -- {'M', 'Mail'},
    {'I', 'MacGPT'},
    -- Space is quick find Anybox
  }

  for i, app in ipairs(singleapps) do
     hs.hotkey.bind(hyper, app[1], function() hs.application.launchOrFocus(app[2]); end)
  end

  -- looks pretty but gets jittery when right aligning
  hs.window.animationDuration = 0

-- Window focus hints
hs.hotkey.bind(hyper, "return", hs.hints.windowHints)

-- Launch new wezterm window on current desktop
hs.hotkey.bind({ "alt" }, "return", function()
    hs.osascript.applescriptFromFile(os.getenv("HOME") .. "/.local/bin/new-wezterm.applescript")
end)

-- launch script on unlock and log to file
hs.caffeinate.watcher
    .new(function(event)
        if event == hs.caffeinate.watcher.screensDidUnlock then
            hs.execute(os.getenv("HOME") .. "/.local/bin/unlock > /tmp/unlock.log 2>&1", true)
        end
    end)
    :start()

