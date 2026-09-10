-- use karabiner to map this to caps lock
hyper = {"cmd", "alt", "ctrl", "shift"}

-- enables the `hs` CLI (already on PATH) to talk to this config
require("hs.ipc")


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

-- Hyper+P: push the clipboard image to helios and put the *remote* path on the
-- clipboard, so pasting inside an ssh/tmux session hands the far side a file it
-- can actually open. Stage events come from clip-push; motion indicates activity,
-- not a byte percentage. Keep the task alive and prevent overlapping pushes.
local clipPushTask, clipPushPanel, clipPushTimer, clipPushAnim
local clipPushStarted

local function showClipPushStatus(state, message)
    if clipPushTimer then clipPushTimer:stop(); clipPushTimer = nil end
    if clipPushAnim then clipPushAnim:stop(); clipPushAnim = nil end
    if clipPushPanel then clipPushPanel:delete(); clipPushPanel = nil end

    local working = state == "working"
    local accent = ({
        working = { red = 0.35, green = 0.65, blue = 1, alpha = 1 },
        done = { red = 0.35, green = 0.85, blue = 0.55, alpha = 1 },
        error = { red = 1, green = 0.4, blue = 0.4, alpha = 1 },
    })[state]
    local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local f = screen:frame()
    local w, h = math.min(420, f.w - 32), 112
    local c = hs.canvas.new({ x = f.x + f.w - w - 16, y = f.y + 16, w = w, h = h })
    clipPushPanel = c
    c:level("overlay"):behavior({ "canJoinAllSpaces", "fullScreenAuxiliary" })
    local title = working and "Clipboard · sending" or (state == "done" and "Clipboard · ready to paste" or "Clipboard · failed")
    c:appendElements(
        { type = "rectangle", action = "fill", roundedRectRadii = { xRadius = 12, yRadius = 12 },
          fillColor = { white = 0.09, alpha = 0.96 }, frame = { x = 0, y = 0, w = w, h = h } },
        { type = "text", text = title, textSize = 15, textColor = accent,
          frame = { x = 18, y = 12, w = w - 36, h = 22 } },
        { type = "text", text = message, textSize = 12, textColor = { white = 0.95 },
          frame = { x = 18, y = 38, w = w - 36, h = 38 } },
        { type = "text", text = "", textSize = 10, textColor = { white = 0.6 },
          frame = { x = 18, y = 77, w = w - 36, h = 16 } },
        { type = "rectangle", action = "fill", fillColor = { white = 1, alpha = 0.12 },
          frame = { x = 18, y = h - 12, w = w - 36, h = 3 } },
        { type = "rectangle", action = "fill", fillColor = accent,
          frame = { x = 18, y = h - 12, w = working and 72 or w - 36, h = 3 } }
    )
    local function tick()
        local elapsed = hs.timer.secondsSinceEpoch() - clipPushStarted
        c[4].text = string.format("%.0fs%s", elapsed, working and (elapsed >= 15 and " · still waiting for completion" or " · in progress") or " · click to dismiss")
        if working then
            local travel = w - 36 - 72
            local phase = (elapsed % 2.4) / 1.2
            c[6].frame = { x = 18 + travel * (phase <= 1 and phase or 2 - phase), y = h - 12, w = 72, h = 3 }
        end
    end
    tick()
    c:show()
    if working then
        clipPushAnim = hs.timer.new(0.03, tick):start()
    else
        local function dismiss()
            if clipPushTimer then clipPushTimer:stop(); clipPushTimer = nil end
            if clipPushPanel == c then c:delete(); clipPushPanel = nil end
        end
        c:canvasMouseEvents(true, false, false, false):mouseCallback(dismiss)
        clipPushTimer = hs.timer.doAfter(3, dismiss)
    end
end

hs.hotkey.bind(hyper, "p", function()
    if clipPushTask then return end
    clipPushStarted = hs.timer.secondsSinceEpoch()
    showClipPushStatus("working", "Starting clipboard upload")
    local pending, errors, failure, remotePath = "", "", nil, nil
    local function consume(stdout, stderr)
        errors = (errors .. (stderr or "")):sub(-4000)
        pending = pending .. (stdout or "")
        while pending:find("\n", 1, true) do
            local line, rest = pending:match("^(.-)\n(.*)$")
            pending = rest
            local stage, message = line:match("^CLIP_PUSH\t([^\t]+)\t(.*)$")
            if stage == "error" then
                failure = message
            elseif stage == "done" then
                remotePath = message
            elseif stage then
                showClipPushStatus("working", message)
            end
        end
    end
    clipPushTask = hs.task.new("/bin/zsh", function(code, stdout, stderr)
        consume(stdout, stderr)
        clipPushTask = nil
        if code == 0 and remotePath then
            showClipPushStatus("done", remotePath)
        else
            hs.printf("clip-push failed (%s): %s", code, errors)
            showClipPushStatus("error", failure or ("Upload did not finish (exit " .. code .. "). See Hammerspoon Console."))
        end
    end, function(task, stdout, stderr)
        -- hs.task may send a final stream callback after the exit callback.
        if task then consume(stdout, stderr) end
        return true
    end, { "-lc", 'CLIP_PUSH_STATUS=1 exec "$HOME/.local/bin/clip-push"' })
    if not clipPushTask or not clipPushTask:start() then
        clipPushTask = nil
        showClipPushStatus("error", "Could not start clip-push")
    end
end)

-- launch script on unlock and log to file
hs.caffeinate.watcher
    .new(function(event)
        if event == hs.caffeinate.watcher.screensDidUnlock then
            hs.execute(os.getenv("HOME") .. "/.local/bin/unlock > /tmp/unlock.log 2>&1", true)
        end
    end)
    :start()
