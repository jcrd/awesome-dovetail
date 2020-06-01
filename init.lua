--- A tiling layout featuring two visible tiled clients.
--
-- @author James Reed &lt;jcrd@tuta.io&gt;
-- @copyright 2019 James Reed
-- @module awesome-dovetail

local awful = require("awful")
local gtable = require("gears.table")

local dovetail = {}

--- Override this function to change how dovetail determines the current tag.
--- The function takes the current screen.
--
-- @param s The current screen.
-- @usage dovetail.get_tag = custom_get_tag
-- @function get_tag
function dovetail.get_tag(s)
    return s.selected_tag
end

local function new_layout(ornt, mirror)
    ornt = ornt or "horizontal"

    local layout = {
        type = "dovetail",
        name = "dovetail." .. ornt,
        is_dynamic = true,
        single = false,
        master_client = nil,
        master_queued = false,
        master_history = {},
        track_master_history = true,
        enable_single_master = true,
        centered = false,
        monocle = nil,
    }

    local w = "width"
    local x = "x"
    if ornt == "vertical" then
        w = "height"
        x = "y"
    end

    if mirror then
        layout.name = layout.name .. ".mirror"
    end

    layout.master = {}
    layout.master.history = {}

    local function remove_history(c, lo)
        lo = lo or layout
        local i = gtable.hasitem(lo.master_history, c)
        if i then table.remove(lo.master_history, i) end
    end

    function layout.master.history.add(c)
        remove_history(c)
        table.insert(layout.master_history, c)
    end

    function layout.master.history.get(i)
        local h = layout.master_history
        return h[#h - i]
    end

    local function master_untagged(c, t)
        remove_history(c, t.layout)
        c:disconnect_signal("untagged", master_untagged)
        if c == t.layout.master_client then
            t.layout.master.set(t.layout.master.history.get(0))
        end
    end

    function layout.master.set(c)
        if c == layout.master_client then return end

        local list = layout.master_client
        layout.master_client = c
        if list then
            list:emit_signal("dovetail::master::update", false)
        end
        if c then
            if layout.track_master_history then
                layout.master.history.add(c)
            end
            layout.centered = false
            c:connect_signal("untagged", master_untagged)
            c:emit_signal("dovetail::master::update", true)
            list = c
        end
        if list then list:emit_signal("list") end
    end

    function layout.master.queue()
        if layout.master_queued then return end
        local s = awful.screen.focused()
        function master(c)
            if layout.master_queued and c.screen == s and c:isvisible() then
                client.disconnect_signal("focus", master)
                layout.master.set(c)
                layout.master_queued = false
            end
        end
        layout.master_queued = true
        client.connect_signal("focus", master)
    end

    function layout.skip_gap(nclients, t)
        return not t.layout.master_client or nclients == 1
    end

    function layout.arrange(p)
        local tag = p.tag or dovetail.get_tag(screen[p.screen])
        local mwfact = tag.master_width_factor
        local cls = p.clients
        local wa = p.workarea

        if #cls == 0 then return end

        -- Client geometries are directly manipulated by awesome.
        -- See https://github.com/awesomeWM/awesome/issues/2676
        function new_geom(g)
            return {x = g.x, y = g.y, width = g.width, height = g.height}
        end

        function single_g(fact)
            local g = new_geom(wa)
            if layout.centered then
                g[w] = g[w] * fact
                g[x] = (wa[w] - g[w]) / 2
            end
            return g
        end

        function set_geom(c, g)
            p.geometries[c] = new_geom(g)
        end

        function arrange_stack(g)
            for _, c in ipairs(cls) do
                if c ~= layout.master_client then
                    set_geom(c, g)
                end
            end
        end

        if layout.master_client then
            local c = layout.master_client

            if #cls == 1 then
                set_geom(c, single_g(mwfact))
                if not layout.enable_single_master then
                    layout.master_client = nil
                end
            elseif c == client.focus and layout.monocle == "master" then
                set_geom(c, single_g(mwfact))
            elseif client.focus ~= c and layout.monocle == "stack" then
                arrange_stack(single_g(1 - mwfact))
            else
                local mw = wa[w] * mwfact
                local master_g = new_geom(wa)
                local stack_g = new_geom(wa)

                master_g[w] = mw
                stack_g[x] = wa[x] + mw
                stack_g[w] = wa[w] - mw

                if mirror then
                    set_geom(c, stack_g)
                    arrange_stack(master_g)
                else
                    set_geom(c, master_g)
                    arrange_stack(stack_g)
                end
            end
        else
            arrange_stack(single_g(1 - mwfact))
        end
    end

    return layout
end

local function with_layout(f, s)
    s = s or awful.screen.focused()
    local layout = dovetail.get_tag(s).layout
    if layout.type == "dovetail" then return f(layout, s) end
end

dovetail.layout = {}

--- Get the master client.
--
-- @param s The screen.
-- @return The master client.
-- @function layout.master
function dovetail.layout.master(s)
    return with_layout(function (lo) return lo.master_client end, s)
end

--- Master client predicate.
--
-- @param c The client.
-- @return `true` if the client is the current layout's master client.
-- @function layout.masterp
function dovetail.layout.masterp(c)
    if not c then return end
    return with_layout(function (lo) return lo.master_client == c end, c.screen)
end

--- Get the current layout.
--
-- @param s The screen.
-- @return The screen's layout.
-- @function layout.get
function dovetail.layout.get(s)
    return with_layout(function (lo) return lo end, s)
end

dovetail.layout.tile = {}

--- Default tiled layout.
--
-- @function layout.tile
setmetatable(dovetail.layout.tile, {__call = function ()
    return dovetail.layout.tile.horizontal()
end})

dovetail.layout.tile.horizontal = {}

--- Horizontally tiled layout with master on the left.
--
-- @function layout.tile.horizontal
setmetatable(dovetail.layout.tile.horizontal, {__call = function ()
    return new_layout("horizontal")
end})

--- Horizontally tiled layout with master on the right.
--
-- @function layout.tile.horizontal.mirror
dovetail.layout.tile.horizontal.mirror = function ()
    return new_layout("horizontal", true)
end

dovetail.layout.tile.vertical = {}

--- Vertically tiled layout with master on the top.
--
-- @function layout.tile.vertical
setmetatable(dovetail.layout.tile.vertical, {__call = function ()
    return new_layout("vertical")
end})

--- Vertically tiled layout with master on the bottom.
--
-- @function layout.tile.vertical.mirror
dovetail.layout.tile.vertical.mirror = function ()
    return new_layout("vertical", true)
end

dovetail.command = {}

local function get_stack(s, i)
    local layout = dovetail.get_tag(s).layout
    for _, c in ipairs(s.tiled_clients) do
        if c ~= layout.master_client then
            if not i or i == 0 then
                return c
            else
                i = i - 1
            end
        end
    end
end

local function set_focus(c, name)
    if c then
        c:emit_signal("request::activate", name, {raise=true})
    end
end

dovetail.command.master = {}

local function master(c, toggle)
    c = c or client.focus
    if not c then return end
    with_layout(function (lo)
        if toggle then
            c = c ~= lo.master_client and c
        end
        lo.master.set(c)
    end, c.screen)
end

--- Set the current layout's master client.
--
-- @param c The client.
-- @function command.master
setmetatable(dovetail.command.master, {__call = function (_, c) master(c) end})

--- Toggle the client's master status.
--
-- @param c The client.
-- @function command.master.toggle
function dovetail.command.master.toggle(c)
    master(c, true)
end

--- Toggle the current master client in or out of view.
-- @function command.master.viewtoggle
function dovetail.command.master.viewtoggle()
    with_layout(function (lo)
        lo.single = lo.master_client
        if lo.single then
            lo.master.set(nil)
        else
            lo.master.set(lo.master.history.get(0))
        end
    end)
end

--- Queue the set master command so that the next client to receive focus
--- becomes the master client.
-- @function command.master.queue
function dovetail.command.master.queue()
    with_layout(function (lo) lo.master.queue() end)
end

--- If the focused client is the master, replace it with the first client in
--- the stack. If it's not the master client, make it the master.
-- @function command.master.swap
function dovetail.command.master.swap()
    with_layout(function (lo, s)
        local stack = get_stack(s)
        if not (stack and lo.master_client) then return end
        lo.master.set(stack)
    end)
end

--- If the master client is focused, cycle through clients making each master.
--- If the stack is focused, cycle through clients other than the focused client.
-- @function command.master.cycle
function dovetail.command.master.cycle(i)
    i = i or 1
    local function focus(c)
        set_focus(c, "dovetail.command.master.cycle")
    end
    with_layout(function (lo, s)
        if not lo.master_client then
            lo.master.set(get_stack(s))
        else
            local focused = lo.master_client == client.focus
            local c = awful.client.next(i, lo.master_client)
            if not c then return end
            if c == client.focus then
                c = awful.client.next(i, c)
                if not c then return end
            end
            lo.master.set(c)
            if focused then
                focus(c)
                return
            end
        end
        local c = get_stack(s)
        if c then focus(c) end
    end)
end

--- Center all tiled clients according to the tag's master width factor.
-- @function command.toggle_centered
function dovetail.command.toggle_centered()
    with_layout(function (lo, s)
        lo.centered = not lo.centered
        if lo.centered then
            lo.master.set(nil)
        elseif not lo.single then
            lo.master.set(lo.master.history.get(0))
        end
        awful.layout.arrange(s)
    end)
end

dovetail.command.focus = {}
dovetail.command.focus.stack = {}

local function stack_next(layout, s, i)
    local target = awful.client.next(i, get_stack(s))
    if target == layout.master_client then
        target = awful.client.next(math.abs(i) > i and -1 or 1, target)
    end
    return target
end

--- Focus the first client in the stack.
-- @function command.focus.stack
local function focus_stack()
    local c = get_stack(awful.screen.focused())
    set_focus(c, "dovetail.command.focus.stack")
end

setmetatable(dovetail.command.focus.stack, {__call = focus_stack})

--- Focus the next client in the stack.
-- @function command.focus.stack.next
function dovetail.command.focus.stack.next()
    with_layout(function (layout, s)
        set_focus(stack_next(layout, s, 1),
            "dovetail.command.focus.stack.next")
    end)
end

--- Focus the previous client in the stack.
-- @function command.focus.stack.previous
function dovetail.command.focus.stack.previous()
    with_layout(function (layout, s)
        set_focus(stack_next(layout, s, -1),
            "dovetail.command.focus.stack.previous")
    end)
end

--- If the master client is focused, focus the first client in the stack, and
--- vice versa.
-- @function command.focus.other
function dovetail.command.focus.other()
    with_layout(function (layout, s)
        local target = layout.master_client
        if target == client.focus then
            target = get_stack(s)
        end
        set_focus(target, "dovetail.command.focus.other")
    end)
end

dovetail.widget = {}
dovetail.widget.tasklist = {}
dovetail.widget.tasklist.filter = {}

local function filter(s, f)
    for _, t in ipairs(s.selected_tags) do
        if f(t.layout) then return true end
    end
    return false
end

--- A filter to display only stacked clients in the tasklist.
--
-- @param c The client.
-- @param s The screen.
-- @return `true` if the client is in the screen's stack.
-- @function widget.tasklist.filter.stack
function dovetail.widget.tasklist.filter.stack(c, s)
    return c:isvisible() and filter(s, function (lo)
        return c ~= lo.master_client
    end)
end

--- A filter to display only the master client in the tasklist.
--
-- @param c The client.
-- @param s The screen.
-- @return `true` if the client is the screen's master client.
-- @function widget.tasklist.filter.master
function dovetail.widget.tasklist.filter.master(c, s)
    return c:isvisible() and filter(s, function (lo)
        return c == lo.master_client
    end)
end

return dovetail
