-- This project is licensed under the MIT License (see LICENSE).

--- A tiling layout featuring two visible tiled clients.
--
-- @author James Reed &lt;jcrd@tuta.io&gt;
-- @copyright 2019-2020 James Reed
-- @module awesome-dovetail

local awful = require("awful")
local gears = require("gears")

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

local function arrange(p, ornt, mirror)
    ornt = ornt or "horizontal"

    local w = "width"
    local x = "x"
    if ornt == "vertical" then
        w = "height"
        x = "y"
    end

    local tag = p.tag or dovetail.get_tag(screen[p.screen])
    local mwfact = tag.master_width_factor
    local cls = p.clients
    local wa = p.workarea

    if #cls == 0 then
        return
    end

    -- Client geometries are directly manipulated by awesome.
    -- See https://github.com/awesomeWM/awesome/issues/2676
    function new_geom(g)
        return {x = g.x, y = g.y, width = g.width, height = g.height}
    end

    function set_geom(c, g)
        p.geometries[c] = new_geom(g)
    end

    function arrange_stack(g)
        for i, c in ipairs(cls) do
            if i > 1 then
                set_geom(c, g)
            end
        end
    end

    local master = cls[1]

    if #cls == 1 then
        set_geom(master, wa)
    else
        local mw = wa[w] * mwfact
        local master_g = new_geom(wa)
        local stack_g = new_geom(wa)

        master_g[w] = mw
        stack_g[x] = wa[x] + mw
        stack_g[w] = wa[w] - mw

        if mirror then
            set_geom(master, stack_g)
            arrange_stack(master_g)
        else
            set_geom(master, master_g)
            arrange_stack(stack_g)
        end
    end
end

dovetail.layout = {}

--- Check if a layout is a dovetail layout.
--
-- @param layout The layout or the current layout if nil.
-- @return `true` if layout is a dovetail layout.
-- @function layout
setmetatable(dovetail.layout, {__call = function (layout)
    return gears.string.startswith(awful.layout.getname(layout), "dovetail")
end})

function dovetail.layout.skip_gap(nclients)
    return nclients == 1
end

--- Horizontally tiled layout with stack on the right.
--
-- @function layout.right
dovetail.layout.right = {
    name = "dovetail.layout.right",
    arrange = arrange,
    skip_gap = dovetail.layout.skip_gap,
}

--- Horizontally tiled layout with stack on the left.
--
-- @function layout.left
dovetail.layout.left = {
    name = "dovetail.layout.left",
    arrange = function (p) arrange(p, "horizontal", true) end,
    skip_gap = dovetail.layout.skip_gap,
}

--- Vertically tiled layout with stack on the bottom.
--
-- @function layout.bottom
dovetail.layout.bottom = {
    name = "dovetail.layout.bottom",
    arrange = function (p) arrange(p, "vertical") end,
    skip_gap = dovetail.layout.skip_gap,
}

--- Vertically tiled layout with stack on the top.
--
-- @function layout.top
dovetail.layout.top = {
    name = "dovetail.layout.top",
    arrange = function (p) arrange(p, "vertical", true) end,
    skip_gap = dovetail.layout.skip_gap,
}

local function set_focus(c, name)
    if c then
        c:emit_signal("request::activate", name, {raise=true})
    end
end

local function with_focus(func, c)
    c = c or client.focus
    if not c then
        return
    end
    local master = awful.client.getmaster(c.screen)
    local z = c.screen.tiled_clients
    return func(c, master, z[2])
end

dovetail.focus = {}

--- Focus a client in the stack by its relative index.
-- @param i The index.
-- @return `true` if conditions were met to search for a client.
-- If `false`, a fallback `focus.byidx` method should be used.
-- @function focus.byidx
function dovetail.focus.byidx(i)
    local name = "dovetail.focus.byidx"
    if not dovetail.layout() then
        return false
    end
    return with_focus(function (c, master, stack)
        if c.floating then
            return false
        end
        if c == master then
            if not stack then
                return false
            end
            c = stack
        end
        local n = awful.client.next(i, c)
        while n and n ~= c do
            if n ~= master then
                set_focus(n, name)
                break
            end
            n = awful.client.next(i, n)
        end
        return true
    end)
end

--- If the master client is focused, focus the visible client in the stack, and
--- vice versa.
-- @function focus.other
function dovetail.focus.other()
    local name = "dovetail.focus.other"
    with_focus(function (c, master, stack)
        if c == master then
            set_focus(stack, name)
        else
            set_focus(master, name)
        end
    end)
end

return dovetail
