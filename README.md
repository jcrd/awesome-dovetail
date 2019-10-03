# awesome-dovetail

awesome-dovetail is a layout for [Awesome](https://github.com/awesomeWM/awesome)
featuring two visible tiled clients.

## Installation

```
$ git clone https://github.com/jcrd/awesome-dovetail.git
$ cd awesome-dovetail
$ luarocks make --local rockspec/awesome-dovetail-devel-1.rockspec
```

## Usage

Require the library:
```lua
local dovetail = require("awesome-dovetail")
```

Add it to your layouts:
```lua
awful.layout.layouts = {
    dovetail.layout.tile,
}
```

Or initialize your tags with it:
```lua
awful.tag(
    {"1", "2", "3"},
    s,
    dovetail.layout.tile.vertical,
)
```

Or create a new tag using it:
```lua
awful.tag.add("dovetail", {
    layout = dovetail.layout.tile.horizontal.mirror,
})
```

See the [API documentation](https://jcrd.github.io/awesome-dovetail/) for
descriptions of all functions.

## License

awesome-dovetail is licensed under the GNU General Public License v3.0 or later
(see [LICENSE](LICENSE)).
