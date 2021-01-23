-------------------------------------------------------------------------------------
-- Custom Mech Palette Library
-- v0.6
-- https://github.com/KnightMiner/ITB-KnightUtils/blob/master/libs/customPalettes.lua
-------------------------------------------------------------------------------------
-- Contains helpers to make custom mech palettes
-------------------------------------------------------------------------------------

-- Current library version, so we can ensure the latest library version is used
local VERSION = "0.6"

-- if we have a global that is newer than or the same version as us, use that
-- if our version is newer or its not yet loaded, load the library
if CUSTOM_PALETTES == nil or not modApi:isVersion(VERSION, CUSTOM_PALETTES.version) then
  -- if we have an older version, update that table with the latest functions
  -- ensures older copies of the library use the latest logic for everything
  local palettes = CUSTOM_PALETTES or {}
  CUSTOM_PALETTES = palettes

  -- ensure we have needed properties
  palettes.version = VERSION
  -- format: map ID -> {name, colors, index}
  palettes.map = palettes.map or {}
    -- format: index -> map ID
  palettes.indexMap = palettes.indexMap or {}

  ---------------
  -- Constants --
  ---------------

  --- Maximum number of palettes selectable in the hanger UI
  --- You get one palette for each of the 9 squads, then 2 more for random and custom
  local MAX_SELECTABLE = 11

  --- Path to animations that use palettes
  local PALETTE_PATH = "units/player"

  --- Human readible names for all vanilla maps, will return nil for non-vanilla
  local VANILLA_NAMES = {
    "Rift Walkers Olive",
    "Rusting Hulks Orange",
    "Zenith Guard Blue",
    "Blitzkrieg Yellow",
    "Steel Judoka Shivan",
    "Flame Behemoths Red",
    "Frozen Titans Blue",
    "Hazardous Mechs Tan",
    "Vek Squad Purple"
  }
  --- Internal names for each of the palettes, used for modders
  local VANILLA_IDS = {
    "RiftWalkers",
    "RustingHulks",
    "ZenithGuard",
    "Blitzkrieg",
    "SteelJudoka",
    "FlameBehemoths",
    "FrozenTitans",
    "HazardousMechs",
    "SecretSquad"
  }

  -------------
  -- Getters --
  -------------

  --[[--
    Gets the given key from a palette if the palette exists

    @param id       Palette ID
    @param key      Key to fetch
    @param fallback Optional fallback to use if the map exists, but the key does not
    @return Value of the key, or nil if the map does not exist
  ]]
  local function getIfPresent(id, key, fallback)
    -- IDs loaded from vanilla or libraries besids FURL are numerically indexed
    assert(type(id) == "string", "ID must be a string")
    assert(type(key) == "string", "Key must be a string")
    -- fetch the palette if it exists
    local palette = palettes.map[id]
    if palette == nil then
      return nil
    end
    -- fallback to ID for the name
    return palette[key] or fallback
  end

  --[[--
    Gets the colormap ID based on the given map index.

    @param index  Vanilla colormap index
    @return  Colormap ID for the given index, or nil if the ID is undefined
  ]]
  function palettes.getIndexID(index)
    assert(type(index) == "number", "Index must be a number")
    return palettes.indexMap[index]
  end

  --[[--
    Gets the colormap ID based on the given image offset.
    Used since there is a difference between the image offset of a pawn and the colors index in vanilla

    @param offset  ImageOffset from the pawn properties
    @return  Colormap ID for the given image offset
  ]]
  function palettes.getOffsetID(offset)
    assert(type(offset) == "number", "Offset must be a number")
    return palettes.indexMap[offset+1]
  end

  --[[--
    Gets the name for the given palette

    @param id  Palette ID
    @return  Palettes name, or nil if the ID does not exist
  ]]
  function palettes.getName(id)
    return getIfPresent(id, "name", id)
  end

  --[[--
    Gets the image offset for the given map ID

    @param id  Map ID
    @return  Image offset for the given map, or nil if the ID does not exist
  ]]
  function palettes.getOffset(id)
    local index = getIfPresent(id, "index")
    if index == nil then
      return nil
    end
    return index - 1
  end

  -- Vanilla overrides
  --
  -- These two functions are equivelent to the vanilla GetColorMap and GetColorCount respectively
  -- Difference is they are called through this library, and they may be outdated if another
  -- library (such as FURL) overrides the functions
  -- Calling palettes.migrateHooks() will migrate either vanilla or another library to this library,
  -- then ensure this library's functions are used

  --[[--
    Gets the colormap for the given index

    @param id  Colormap numeric index. Vanilla are 1-9
    @return  Colormap at the given index
  ]]
  function palettes.getColorMap(index)
    assert(type(index) == "number", "Index must be a number")
    -- convert the index to an ID, then fetch the coorsponding map
    local id = palettes.indexMap[index]
    if id ~= nil then
      return getIfPresent(id, "colors")
    end
    return nil
  end

  --[[--
    Gets the number of palettes loaded

    @return  Number of palettes currently loaded
  ]]
  function palettes.getCount()
    local count = #palettes.indexMap
    -- when in the hanger screen and the palette UI is showing
    -- limit to MAX_SELECTABLE as anything after is unabled to be clicked
    if count > MAX_SELECTABLE and sdlext.isHangar() then
      return MAX_SELECTABLE
    end
    return count
  end

  -------------------------------
  -- Main palette adding logic --
  -------------------------------

  --[[--
    Function to get a unique ID from a colormap

    @param index  Palette index
    @param map    Colormap
    @return A unique ID based on the primary color in the colormap
  ]]
  local function fallbackID(index, map)
    -- PlateLight is generally unique
    local color = map[2]
    -- format as a hex string
    local id = string.format("#%02x%02x%02x", color.r, color.g, color.b)
    -- if somehow that already exists, add the index at the end
    -- I suppose we could hash the whole map to a string,
    -- but clashes are unlikely enough, espeically once people use this lib
    if palettes.map[first] then
      id = id .. "," .. index
    end
    return id
  end

  --[[--
    Migrates missing palettes and overrides the vanilla functions
  ]]
  local function migratePalettes()
    -- if one of the two vanilla palette functions is not ours, run migrations
    -- uses the global to ensure we migrate to the latest library version
    if GetColorCount ~= palettes.getCount or GetColorMap ~= palettes.getColorMap then
      -- first, clone any palettes we are missing into our array

      local totalPalettes = GetColorCount()
      if totalPalettes > palettes.getCount() then
        -- first, create a map from indexes to FURL names
        local furlIDs = {}
        if type(FURL_COLORS) == "table" then
          for name, index in pairs(FURL_COLORS) do
            -- FURL stores imageOffset instead of palette index
            furlIDs[index+1] = name
          end
        end

        -- migrate any palettes we are missing
        for index = palettes.getCount()+1, totalPalettes do
          -- first, ensure there is a color map there
          local colors = GetColorMap(index)
          if colors == nil then
            break
          end

          -- use the name from FURL as the ID if present, or fallback to index (vanilla palettes)
          local id = VANILLA_IDS[index] or furlIDs[index] or fallbackID(index, colors)
          -- create the palette data
          palettes.map[id] = {
            name = VANILLA_NAMES[index],
            colors = colors,
            index = index
          }
          -- add the index to the index map, this map may change later
          palettes.indexMap[index] = id
        end
      end

      -- override the vanilla functions with our copies
      GetColorMap = palettes.getColorMap
      GetColorCount = palettes.getCount
    end
  end

  --[[--
    Checks if the given animation object uses palettes

    @param anim  Animation object
    @return true if the animation uses palettes
  ]]
  local function usesPalettes(anim)
    return anim ~= nil and anim:GetImage():sub(1, #PALETTE_PATH) == PALETTE_PATH
  end

  --[[--
    Updates all animation objects to the updated color count. Needs to be called every time a batch of palettes is added.
    Needed since increasing the palette count increases the generated images in an animation

    @param added  number of palettes added
  ]]
  local function updateAnimations(added)
    -- determine the old index we need to update
    local count = GetColorCount()
    local update = count - added

    -- update base objects, mostly needed for MechIcon as it does not have a units/player image path
    ANIMS.MechColors = count
    ANIMS.MechUnit.Height = count
    ANIMS.MechIcon.Height = count

    -- update other objects that use MechUnit
    for name, anim in pairs(ANIMS) do
      -- images loaded in units/player generate a vertical frame for each unit
      if type(anim) == "table" and anim.Height ~= nil and anim.Height >= update and anim.Height < count and usesPalettes(anim) then
        anim.Height = count
      end
    end
  end

  --- List of all key names for indexes in the vanilla palettes structure
  local PALETTE_KEYS = {
    "PlateHighlight",
    "PlateLight",
    "PlateMid",
    "PlateDark",
    "PlateOutline",
    "PlateShadow",
    "BodyColor",
    "BodyHighlight"
  }

  --[[--
    Adds a new palette to the game

    @param ...  Varargs table parameters for palette data. Contains all the colors from PALETTE_KEYS, plus:
           ID: Unique ID for this palette
           Name: Human readible name, if unset defaults to ID
  ]]
  function palettes.addPalette(...)
    -- ensure this library is in charge of palettes
    migratePalettes()

    -- allow passing in multiple palettes at once, more efficient for animation reloading
    local datas = {...}
    local added = #datas
    for _, data in ipairs(datas) do
      -- validations
      assert(type(data) == "table", "Palette data must be a table")
      assert(type(data.ID) == "string", "Invalid palette, missing string ID")
      assert(data.Name == nil or type(data.Name) == "string", "Name must be a string")

      -- if two mods add a palette with the same ID, ignore
      -- allows mods to "share" a palette
      if palettes.map[data.ID] ~= nil then
        added = added - 1
      else
        -- construct each of the pieces of the colors
        local colors = {}
        for i, key in ipairs(PALETTE_KEYS) do
          if type(data[key]) ~= "table" then
            error("Invalid palette, missing key " .. key)
          end
          assert(#data[key] == 3, "Color must contain three integers")
          colors[i] = GL_Color(unpack(data[key]))
        end

        -- create the palette
        local index = palettes.getCount() + 1
        palettes.map[data.ID] = {name = data.Name, colors = colors, index = index}
        palettes.indexMap[index] = data.ID
      end
    end

    -- reload animations to update the color count
    -- only need to reload once for all the palettes
    updateAnimations(added)
  end

  ---------------
  -- Palette UI --
  ---------------

  --- Default order of palettes before we made any changes
  local defaultPaletteOrder = {}

  --[[--
    Sets the palette list to the given order
    @param newOrder  new order of palettes from the config
  ]]
  local function setOrder(newOrder)
    assert(type(newOrder) == "table", "New order must be a table")
    assert(newOrder[1] == VANILLA_IDS[1], "RiftWalkers must be the first palette")
    -- new order will become the new index map, but we need a migration, plus newOrder may be incomplete
    local idToNewIndex = {}
    local newMap = {}
    for index, id in ipairs(newOrder) do
      -- skip missing palettes (means a mod was uninstalled) and duplicates (means someone messed with the config)
      if palettes.map[id] ~= nil and idToNewIndex[id] == nil then
        idToNewIndex[id] = index
        newMap[index] = id
      end
    end
    -- append any missing IDs in newOrder in their original order
    for _, id in ipairs(palettes.indexMap) do
      if idToNewIndex[id] == nil then
        local index = #newMap + 1
        idToNewIndex[id] = index
        newMap[index] = id
      end
    end
    -- create the migration as old index -> new index, then migrate all pawns
    local migration = {}
    for index, id in ipairs(palettes.indexMap) do
      -- image offsets are 1 less than palette indexes
      migration[index-1] = idToNewIndex[id]-1
    end
    for _, value in pairs(_G) do
      -- needs to have an image offset and an image that uses units/player (those use palettes)
      if type(value) == "table" and value.ImageOffset ~= nil and type(value.Image) == "string" and usesPalettes(ANIMS[value.Image]) then
        local newOffset = migration[value.ImageOffset]
        if newOffset ~= nil then
          value.ImageOffset = newOffset
        end
      end
    end
    -- update the palettes map
    palettes.indexMap = newMap
    for index, id in pairs(newMap) do
      palettes.map[id].index = index
    end
    -- update FURL colors
    if type(FURL_COLORS) == "table" then
      for id, offset in pairs(FURL_COLORS) do
        newOffset = migration[offset]
        if newOffset ~= nil then
          FURL_COLORS[id] = newOffset
        end
      end
    end
  end

  --[[--
    Trims the list to 11 elements

    @param order  order to trim
    @return copy of order with 11 elements
  ]]
  local function trimOrder(order)
    local copy = {}
    for i = 1, math.min(MAX_SELECTABLE, #order) do
      copy[i] = order[i]
    end
    return copy
  end

  --[[--
    Loads palettes from the config file
  ]]
  local function loadOrder()
    local order = nil
    sdlext.config("modcontent.lua", function(config)
      -- if not present, we will just write the default order at the end
      local order = config.customPaletteOrder
      if type(order) == "table" then
        -- rift walkers must be the first palette (all loading breaks otherwise), so remove if later
        if order[1] ~= VANILLA_IDS[1] then
          remove_element(order, VANILLA_IDS[1])
          table.insert(order, 1, VANILLA_IDS[1])
        end
        -- check if the order actually changed, saves a lot of effort if order is still default
        local orderChanged = false
        for i = 1, math.min(MAX_SELECTABLE, #order) do
          -- if any palette does not match, we need to reload
          if order[i] ~= palettes.indexMap[i] then
            orderChanged = true
            break
          end
        end
        -- update the palette order with the given data
        if orderChanged then
          setOrder(order)
        end
      end
      -- save the order to the config in case it changed
      config.customPaletteOrder = trimOrder(palettes.indexMap)
    end)
  end

  --- Copy of RiftWalkers palette using sdl.rgb
  local basePalette
  --- Cache of recolored images for each palette ID
  local paletteSurfaces = {}
  --- Frame header to use around the first 11 palettes
  local hangerHeader = DecoFrameHeader()
  hangerHeader.font = sdlext.font("fonts/JustinFont12Bold.ttf", 9)
  hangerHeader.height = 14

  -- palette UI dimensions
  local PALETTE_WIDTH = 134 + 8
  local PALETTE_HEIGHT = 66 + 8
  local PALETTE_GAP = 16
  local CELL_WIDTH = PALETTE_WIDTH + PALETTE_GAP
  local CELL_HEIGHT = PALETTE_HEIGHT + PALETTE_GAP

  --[[--
    Gets recolored images for the given palette, or creates them if missing

    @param id  Palette ID
    @return  Surface for this palette button
  ]]
  local function getOrCreatePaletteSurfaces(id)
    assert(id ~= nil, "ID must be defined")
    -- if missing, create
    local surfaces = paletteSurfaces[id]
    if surfaces == nil then
      -- uses two images to better show the palette
      surfaces = {
        sdlext.getSurface({path = "img/units/player/mech_guard_ns.png", scale = 2}),
        sdlext.getSurface({path = "img/units/player/color_boxes.png", scale = 2})
      }
      -- rift walkers does not need to be recolored
      if id ~= VANILLA_IDS[1] then
        -- all other palettes start from rift walkers
        if basePalette == nil then
          basePalette = {}
          assert(palettes.map[VANILLA_IDS[1]] ~= nil)
          for i, color in ipairs(palettes.map[VANILLA_IDS[1]].colors) do
            basePalette[i] = sdl.rgb(color.r, color.g, color.b)
          end
        end
        -- generate the color mapping
        local palette = palettes.map[id]
        if palette == nil then
          error("Palette " .. id .. " is missing from the UI, this should not be possible")
        end
        local colorReplacements = {}
        for i = 1, #PALETTE_KEYS do
          local color = palette.colors[i]
          colorReplacements[2*i-1] = basePalette[i]
          colorReplacements[2*i]   = sdl.rgb(color.r, color.g, color.b)
        end
        -- recolor both images
        for i = 1, 2 do
          surfaces[i] = sdl.colormapped(surfaces[i], colorReplacements)
        end
      end
      -- cache the surface for next time
      paletteSurfaces[id] = surfaces
    end
    return surfaces
  end

  --[[--
    Logic to create the actual palette UI
  ]]
  local function createUI()
    --- list of all palette buttons in the UI
    local buttons = {}

    --- Called on exit to save the palette order
    local function onExit(self)
      -- Rift Walkers is fixed, no moving
      local order = {VANILLA_IDS[1]}
      for i = 1, math.min(MAX_SELECTABLE, #buttons) do
        order[i+1] = buttons[i].id
      end
      -- write to config
      sdlext.config("modcontent.lua", function(config)
        config.customPaletteOrder = order
      end)
    end

    -- main UI logic
  	sdlext.showDialog(function(ui, quit)
  		ui.onDialogExit = onExit
      -- main frame
  		local frametop = Ui()
  			:width(0.8):height(0.8)
  			:posCentered()
  			:caption("Arrange Palettes")
  			:decorate({ DecoFrameHeader(), DecoFrame() })
  			:addTo(ui)
      -- scrollable content
  		local scrollarea = UiScrollArea()
  			:width(1):height(1)
  			:padding(24)
  			:addTo(frametop)
      -- blank pilot placeholder
  		local placeholder = Ui()
  			:pospx(-CELL_WIDTH, -CELL_HEIGHT)
  			:widthpx(PALETTE_WIDTH):heightpx(PALETTE_HEIGHT)
  			:decorate({})
  			:addTo(scrollarea)
      -- define the window size to fit as many palettes as possible, comes out to about 6
  		local palettesPerRow = math.floor(ui.w * frametop.wPercent / CELL_WIDTH)
  		frametop
  			:width((palettesPerRow * CELL_WIDTH + scrollarea.padl + scrollarea.padr) / ui.w)
  			:posCentered()
  		ui:relayout()
      -- add button area on the bottom
  		local line = Ui()
  				:width(1):heightpx(frametop.decorations[1].bordersize)
  				:decorate({ DecoSolid(frametop.decorations[1].bordercolor) })
  				:addTo(frametop)
  		local buttonHeight = 40
  		local buttonLayout = UiBoxLayout()
  				:hgap(20)
  				:padding(24)
  				:width(1)
  				:addTo(frametop)
  		buttonLayout:heightpx(buttonHeight + buttonLayout.padt + buttonLayout.padb)

  		ui:relayout()
  		scrollarea:heightpx(scrollarea.h - (buttonLayout.h + line.h))

  		line:pospx(0, scrollarea.y + scrollarea.h)
  		buttonLayout:pospx(0, line.y + line.h)

      --- Refreshes the positions of all buttons
  		local function refreshPaletteButtons()
        -- rift walkers is technically at index 0, as its immobile
  			for i = 1, #buttons do
  				local col = i % palettesPerRow
  				local row = math.floor(i / palettesPerRow)
  				local button = buttons[i]
  				button:pospx(CELL_WIDTH * col, CELL_HEIGHT * row)
          -- special handling of the placeholder
  				if button == placeholder then
  					placeholderIndex = i
  				end
  			end
  		end
      --- Button to set the order to the order the palettes were added
  		local defaultButton = Ui()
  			:widthpx(PALETTE_WIDTH * 2):heightpx(buttonHeight)
  			:settooltip("Restore default palette order")
  			:decorate({
  				DecoButton(),
  				DecoAlign(0, 2),
  				DecoText("Default"),
  			})
  			:addTo(buttonLayout)
  		function defaultButton.onclicked()
  			table.sort(buttons, function(a, b)
  				return defaultPaletteOrder[a.id] < defaultPaletteOrder[b.id]
  			end)
  			refreshPaletteButtons()
  			return true
  		end
      --- Button to randomly order all palettes
  		local randomizeButton = Ui()
  			:widthpx(PALETTE_WIDTH * 2):heightpx(buttonHeight)
  			:settooltip("Randomize pilot order")
  			:decorate({
  				DecoButton(),
  				DecoAlign(0, 2),
  				DecoText("Randomize"),
  			})
  			:addTo(buttonLayout)
  		function randomizeButton.onclicked()
  			for i = #buttons, 2, -1 do
  				local j = math.random(i)
  				buttons[i], buttons[j] = buttons[j], buttons[i]
  			end
  			refreshPaletteButtons()
  			return true
  		end

      --- Called to update the button's physical position based on where it hovers
  		local draggedElement
  		local function rearrange()
        -- if a button is being dragged, update its position in the buttons array
  			local index = list_indexof(buttons, placeholder)
  			if index ~= nil and draggedElement ~= nil then
  				local col = math.floor(draggedElement.x / CELL_WIDTH + 0.5)
  				local row = math.floor(draggedElement.y / CELL_HEIGHT + 0.5)
  				local desiredIndex = col + row * palettesPerRow
  				if desiredIndex < 1 then desiredIndex = 1 end
  				if desiredIndex > #buttons then desiredIndex = #buttons end
  				if desiredIndex ~= index then
  					table.remove(buttons, index)
  					table.insert(buttons, desiredIndex, placeholder)
  				end
  			end
        refreshPaletteButtons()
  		end

      --- Adds the hanger backdrop on the first 11 buttons
  		local function addHangarBackdrop(i)
  			local col = (i - 1) % palettesPerRow
  			local row = math.floor((i - 1) / palettesPerRow)
  			local backdrop = Ui()
  				:widthpx(PALETTE_WIDTH):heightpx(PALETTE_HEIGHT+hangerHeader.height)
  				:pospx(CELL_WIDTH * col, CELL_HEIGHT * row - hangerHeader.height)
          :caption("HANGAR")
  				:decorate({
            hangerHeader,
            DecoFrame(),
  					DecoAlign(0,-4)
  				})
  				:addTo(scrollarea)
  		end

      --- Adds a draggable palette button to the UI
  		local function addPaletteButton(i, id)
        -- create button, note Rift Walkers is index 0 so we start with 1
  			local col = i % palettesPerRow
  			local row = math.floor(i / palettesPerRow)
        local surfaces = getOrCreatePaletteSurfaces(id)
  			local button = Ui()
  				:widthpx(PALETTE_WIDTH):heightpx(PALETTE_HEIGHT)
  				:pospx(CELL_WIDTH * col, CELL_HEIGHT * row)
  				:settooltip(palettes.getName(id))
  				:decorate({
  					DecoButton(),
  					DecoAlign(-4),
  					DecoSurface(surfaces[1]),
  					DecoSurface(surfaces[2])
  				})
  				:addTo(scrollarea)
  			button:registerDragMove()
  			button.id = id
  			buttons[i] = button
        --- Called when a button starts moving to swap the button for the placeholder
  			function button:startDrag(mx, my, btn)
  				UiDraggable.startDrag(self, mx, my, btn)
          -- swap placeholder for self
  				draggedElement = self
  				placeholder.x = self.x
  				placeholder.y = self.y
  				local index = list_indexof(buttons, self)
  				if index ~= nil then
  					buttons[index] = placeholder
  				end
          -- start dragging
  				self:bringToTop()
  				rearrange()
  			end
        --- Called when a button is dropped to hide the placeholder and restore the button into the list
  			function button:stopDrag(mx, my, btn)
  				UiDraggable.stopDrag(self, mx, my, btn)
          -- fetch the placeholder index, its where we drop
  				local index = list_indexof(buttons, placeholder)
  				if index ~= nil and draggedElement ~= nil then
  					buttons[index] = draggedElement
  				end
          -- hide the placeholder
  				placeholder:pospx(-CELL_WIDTH, -CELL_HEIGHT)
  				draggedElement = nil
  				rearrange()
  			end
        --- Called while moving the element to update the index as it is dragged
  			function button:dragMove(mx, my)
  				UiDraggable.dragMove(self, mx, my)
  				rearrange()
  			end
  		end

      -- Add the Rift Walkers button, it cannot be moved as that breaks all palette loading
      local surfaces = getOrCreatePaletteSurfaces(VANILLA_IDS[1])
      local button = Ui()
        :widthpx(PALETTE_WIDTH):heightpx(PALETTE_HEIGHT)
        :pospx(0, 0)
        :settooltip(palettes.getName(VANILLA_IDS[1]).."\n\nLocked due to how palettes are loaded.")
        :decorate({
          DecoButton(),
          DecoAlign(-4),
          DecoSurface(surfaces[1]),
          DecoSurface(surfaces[2])
        })
        :addTo(scrollarea)
      button.disabled = true

      -- add buttons for all other palettes in the current order
  		for i = 2, #palettes.indexMap do
  			addPaletteButton(i-1, palettes.indexMap[i])
  		end
      -- add hangar backdrops behind first 11
  		for i = 1, MAX_SELECTABLE do
  			addHangarBackdrop(i)
  		end
  	end)
  end

  --[[--
    Called after all mods are loaded to finalize details for pallets.
    Added to the global library to ensure we call the latest version's finalize function, should not be called by mods.
  ]]
  function palettes._finalize()
    -- ensure this library is in charge of palettes and migrate remaining palettes
    migratePalettes()
    -- save the default order for the sake of the UI
    for index, id in ipairs(palettes.indexMap) do
      defaultPaletteOrder[id] = index
    end
    -- load config order, has to be done before resources.dat updates
    loadOrder()
    -- create the button in the mod config menu
    local button = sdlext.addModContent("", createUI)
    button.caption = "Arrange Palettes"
    button.tip = "Select which 11 palettes will be available on the hanger screen.\n\nRequires a restart to take effect\n\nWarning: Breaks current savegame."
  end

  -- add the UI hook, may have been added by an earlier library version
  if not palettes._addedFinalizeHook then
    palettes._addedFinalizeHook = true
    modApi:addModsInitializedHook(function()
      palettes._finalize()
    end)
  end
end

-- return library, in general the global should not be used outside this script
return CUSTOM_PALETTES
