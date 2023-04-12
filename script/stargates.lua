local util = require("script_util")
local stargate_name = "stargate"
local Stargate = {}


local data =
{
  networks = {},
  rename_frames = {},
  button_actions = {},
  stargate_map = {},
  stargate_frames = {},
  player_linked_stargate = {},
  to_be_removed = {},
  tag_map = {},
  search_boxes = {},
  recent = {}
}

local preview_size = 256

local debug_print = false
local print = function(string)
  if not debug_print then return end
  game.print(string)
  log(string)
end


local clear_gui = function(frame)
  if not (frame and frame.valid) then return end
  util.deregister_gui(frame, data.button_actions)
  frame.clear()
end

local close_gui = function(frame)
  if not (frame and frame.valid) then return end
  util.deregister_gui(frame, data.button_actions)
  frame.destroy()
end

local get_rename_frame = function(player)
  local frame = data.rename_frames[player.index]
  if frame and frame.valid then return frame end
  data.rename_frames[player.index] = nil
end

local get_stargate_frame = function(player)
  local frame = data.stargate_frames[player.index]
  if frame and frame.valid then return frame end
  data.stargate_frames[player.index] = nil
end

local make_rename_frame = function(player, caption)

  local stargate_frame = get_stargate_frame(player)
  if stargate_frame then
    stargate_frame.ignored_by_interaction = true
  end

  player.opened = nil

  local force = player.force
  local stargates = data.networks['player']
  local param = stargates[caption]
  local text = param.flying_text
  local gui = player.gui.screen
  local frame = gui.add{type = "frame", caption = {"gui-train-rename.title", caption}, direction = "horizontal"}
  frame.auto_center = true
  player.opened = frame
  data.rename_frames[player.index] = frame



  local textfield = frame.add{type = "textfield", text = caption}
  textfield.style.horizontally_stretchable = true
  textfield.focus()
  textfield.select_all()
  util.register_gui(data.button_actions, textfield, {type = "confirm_rename_textfield", textfield = textfield, flying_text = text, tag = param.tag})

  local confirm = frame.add{type = "sprite-button", sprite = "utility/enter", style = "tool_button", tooltip = {"gui-train-rename.perform-change"}}
  util.register_gui(data.button_actions, confirm, {type = "confirm_rename_button", textfield = textfield, flying_text = text, tag = param.tag})

end

local format_energy = function(energy)
  return string.format("%.2f",energy/1000000000) .. "GJ"
end

local get_force_color = function(force)
  local player = force.connected_players[1]
  if player and player.valid then
    return player.chat_color
  end
  return {r = 1, b = 1, g = 1}
end

local add_recent = function(player, stargate)
  local recent = data.recent[player.name]
  if not recent then
    recent = {}
    data.recent[player.name] = recent
  end
  recent[stargate.unit_number] = game.tick
  if table_size(recent) >= 9 then
    local min = math.huge
    local index
    for k, tick in pairs (recent) do
      if tick < min then
        min = tick
        index = k
      end
    end
    if index then recent[index] = nil end
  end
end

local unlink_stargate = function(player)
  if player.character then player.character.active = true end
  close_gui(get_stargate_frame(player))
  local source = data.player_linked_stargate[player.index]
  if source and source.valid then
    source.active = true
    add_recent(player, source)
  end
  data.player_linked_stargate[player.index] = nil
end

local clear_stargate_data = function(stargate_data)
  local flying_text = stargate_data.flying_text
  if flying_text and flying_text.valid then
    flying_text.destroy()
  end
  local map_tag = stargate_data.tag
  if map_tag and map_tag.valid then
    data.tag_map[map_tag.tag_number] = nil
    map_tag.destroy()
  end
end


local get_sort_function = function()
  return
  function(t, a, b) return a < b end
end

local make_stargate_gui = function(player, source)

  local location
  local stargate_frame = get_stargate_frame(player)
  if stargate_frame then
    location = stargate_frame.location
    data.stargate_frames[player.index] = nil
    print("Frame already exists")
    close_gui(stargate_frame)
    player.opened = nil
  end

  if not (source and source.valid and not data.to_be_removed[source.unit_number]) then
    unlink_stargate(player)
    return
  end

  local force = source.force
  local network = data.networks['player']
  if not network then return end

  local gui = player.gui.screen
  local frame = gui.add{
    type = "frame", 
    direction = "vertical", 
    ignored_by_interaction = false,
    tags = {
      unit_number = source.unit_number
    }
  }
  if location then
    frame.location = location
  else
    frame.auto_center = true
  end

  player.opened = frame
  data.stargate_frames[player.index] = frame
  frame.ignored_by_interaction = false
  
  local title_flow = frame.add{type = "flow", direction = "horizontal"}
  title_flow.style.vertical_align = "center"
  local title = title_flow.add{type = "label", style = "heading_1_label"}
  title.drag_target = frame

  local rename_button = title_flow.add{type = "sprite-button", sprite = "utility/rename_icon_small_white", style = "frame_action_button", visible = source.force == player.force}
  local pusher = title_flow.add{type = "empty-widget", direction = "horizontal", style = "draggable_space_header"}
  pusher.style.horizontally_stretchable = true
  pusher.style.vertically_stretchable = true
  pusher.drag_target = frame

  local search_box = title_flow.add{type = "textfield", visible = false}
  local search_button = title_flow.add{type = "sprite-button", style = "frame_action_button", sprite = "utility/search_white", tooltip = {"gui.search-with-focus", {"search"}}}
  util.register_gui(data.button_actions, search_button, {type = "search_button", box = search_box})
  data.search_boxes[player.index] = search_box

  local close_button = title_flow.add{ -- Close button
      type = "sprite-button",
      sprite = "utility/close_white",
      hovered_sprite = "utility/close_black",
      clicked_sprite = "utility/close_black",
      style="close_button"
    }
  util.register_gui(data.button_actions, close_button, {type = "close_button"})

  outer = frame.add{ type="frame", name="stargate_outer_gui", direction="vertical", style="b_inner_frame"}
  outer.style.padding = 10

  local energy_bar = outer.add{ type="progressbar", name="stargate_energy_progress", size = 300, value=0, caption="Energy: ", style="space_platform_progressbar_capsule"}
  energy_bar.caption={"stargates-se.energy-label",
     format_energy(source.energy) .. " / " .. (Stargate.energy_required(source) and format_energy(Stargate.energy_required(source)) or "?")
  }
  energy_bar.value = Stargate.energy_required(source) and ((source.energy or 0) / Stargate.energy_required(source)) or 0
  energy_bar.style.bottom_margin = 10

  local inner = outer.add{type = "frame", style = "inside_deep_frame", direction = "vertical"}

  local scroll = inner.add{type = "scroll-pane", direction = "vertical"}
  scroll.style.maximal_height = (player.display_resolution.height / player.display_scale) * 0.8
  local column_count = ((player.display_resolution.width / player.display_scale) * 0.6) / preview_size
  local holding_table = scroll.add{type = "table", column_count = column_count}
  util.register_gui(data.button_actions, search_box, {type = "search_text_changed", parent = holding_table})

  holding_table.style.horizontal_spacing = 2
  holding_table.style.vertical_spacing = 2
  local any = false
  --print(table_size(network))

  local recent = data.recent[player.name] or {}

  local sorted = {}
  local i = 1
  for name, stargate in pairs (network) do
    if stargate.stargate.valid then
      sorted[i] = {name = name, stargate = stargate, unit_number = stargate.stargate.unit_number}
      i = i + 1
    else
      clear_stargate_data(stargate)
    end
  end

  table.sort(sorted, function(a, b)
    if recent[a.unit_number] and recent[b.unit_number] then  
      return recent[a.unit_number] > recent[b.unit_number]
    end

    if recent[a.unit_number] then
      return true
    end

    if recent[b.unit_number] then
      return false
    end

    return a.name:lower() < b.name:lower()
  end)

  local sorted_network = {}
  for k, sorted_data in pairs (sorted) do
    sorted_network[sorted_data.name] = sorted_data.stargate
  end

  local chart = player.force.chart
  for name, stargate in pairs(sorted_network) do
    local stargate_entity = stargate.stargate
    if not (stargate_entity.valid) then
      clear_stargate_data(stargate)
    elseif stargate_entity == source then
      title.caption = name
      util.register_gui(data.button_actions, rename_button, {type = "rename_button", caption = name})
    else
      local position = stargate_entity.position
      local area = {{position.x - preview_size / 2, position.y - preview_size / 2}, {position.x + preview_size / 2, position.y + preview_size / 2}}
      chart(stargate_entity.surface, area)
      local button = holding_table.add{type = "button", name = "_"..name}
      button.style.height = preview_size + 32 + 8
      button.style.width = preview_size + 8
      button.style.left_padding = 0
      button.style.right_padding = 0
      local inner_flow = button.add{type = "flow", direction = "vertical", ignored_by_interaction = true}
      inner_flow.style.vertically_stretchable = true
      inner_flow.style.horizontally_stretchable = true
      inner_flow.style.horizontal_align = "center"



      local map = inner_flow.add
      {
        type = "minimap",
        surface_index = stargate_entity.surface.index,
        zoom = 0.5,
        force = stargate_entity.force.name,
        position = position,
      }
      map.ignored_by_interaction = true
      map.style.height = preview_size
      map.style.width = preview_size
      map.style.horizontally_stretchable = true
      map.style.vertically_stretchable = true
      local caption = name
      if recent[stargate_entity.unit_number] then
        caption = "[img=quantity-time] "..name
      end
      local label = inner_flow.add{type = "label", caption = caption}
      label.style.horizontally_stretchable = true
      label.style.font = "default-dialog-button"
      label.style.font_color = {}
      label.style.horizontally_stretchable = true
      label.style.maximal_width = preview_size
      util.register_gui(data.button_actions, button, {type = "teleport_button", gates = {origin = source, destination = stargate.stargate}})
      any = true
    end
  end
  if not any then
    holding_table.add{type = "label", caption = {"stargates-se.no-stargates"}}
  end
end

function spairs(t, order)
  -- collect the keys
  local keys = {}
  for k in pairs(t) do keys[#keys+1] = k end

  -- if order function given, sort by it by passing the table and keys a, b,
  -- otherwise just sort the keys
  if order then
      table.sort(keys, function(a,b) return order(t, a, b) end)
  else
      table.sort(keys)
  end

  -- return the iterator function
  local i = 0
  return function()
      i = i + 1
      if keys[i] then
          return keys[i], t[keys[i]]
      end
  end
end

local refresh_stargate_frames = function()
  local players = game.players
  for player_index, source in pairs (data.player_linked_stargate) do
    local player = players[player_index]
    local frame = get_stargate_frame(player)
    if frame then
      print("Refreshing frame")
      make_stargate_gui(player, source)
    end
  end
end

local check_player_linked_stargate = function(player)
  print("Checking player linked stargate")
  local source = data.player_linked_stargate[player.index]
  if source and source.valid then
    print("Linked stargate exists...")
    make_stargate_gui(player, source)
  else
    print("Unlinnkgin")
    unlink_stargate(player)
  end
end

local resync_stargate = function(name, stargate_data)
  local stargate = stargate_data.stargate
  if not (stargate and stargate.valid) then
    return
  end
  local force = stargate.force
  local surface = stargate.surface
  local color = get_force_color(force)

  clear_stargate_data(stargate_data)

  local flying_text = stargate.surface.create_entity
  {
    name = "stargate-flying-text",
    text = name,
    position = {stargate.position.x, stargate.position.y - 2},
    force = force,
    color = color
  }
  flying_text.active = false
  stargate_data.flying_text = flying_text

  data.adding_tag = true
  local map_tag = force.add_chart_tag(surface,
  {
    icon = {type = "item", name = stargate_name},
    position = stargate.position,
    text = name
  })
  data.adding_tag = false

  if map_tag then
    stargate_data.tag = map_tag
    data.tag_map[map_tag.tag_number] = stargate_data
  end

end

local is_name_available = function(force, name)
  local network = data.networks['player']
  return not network[name]
end

local rename_stargate = function(force, old_name, new_name)
  if old_name == new_name then
    refresh_stargate_frames()
    return
  end
  local network = data.networks['player']
  local stargate_data = network[old_name]
  network[new_name] = stargate_data
  network[old_name] = nil
  resync_stargate(new_name, stargate_data)
  refresh_stargate_frames()
end

local gui_actions =
{
  close_button = function(event, param)
    local player = game.players[event.player_index]
    local stargate_frame = get_stargate_frame(player)
    close_gui(stargate_frame)
    unlink_stargate(player)
  end,
  rename_button = function(event, param)
    make_rename_frame(game.get_player(event.player_index), param.caption)
  end,
  cancel_rename = function(event, param)
    local player = game.get_player(event.player_index)
    close_gui(get_rename_frame(player))

    print("On cancel rename linked check")
    check_player_linked_stargate(player)
  end,
  confirm_rename_button = function(event, param)
    if event.name ~= defines.events.on_gui_click then return end
    local flying_text = param.flying_text
    if not (flying_text and flying_text.valid) then return end
    local player = game.players[event.player_index]
    if not (player and player.valid) then return end
    local old_name = flying_text.text
    local new_name = param.textfield.text

    if new_name ~= old_name and not is_name_available(player.force, new_name) then
      player.print({"name-already-taken"})
      return
    end

    close_gui(get_rename_frame(player))
    rename_stargate(player.force, old_name, new_name)

    print("On rename linked check")
    --check_player_linked_stargate(player)
  end,
  confirm_rename_textfield = function(event, param)
    if event.name ~= defines.events.on_gui_confirmed then return end
    local flying_text = param.flying_text
    if not (flying_text and flying_text.valid) then return end
    local player = game.players[event.player_index]
    if not (player and player.valid) then return end
    local old_name = flying_text.text
    local new_name = param.textfield.text

    if new_name ~= old_name and not is_name_available(player.force, new_name) then
      player.print({"name-already-taken"})
      return
    end

    close_gui(get_rename_frame(player))
    rename_stargate(player.force, old_name, new_name)

    print("On rename linked check")
    --check_player_linked_stargate(player)
  end,
  teleport_button = function(event, param)
    local gates = param.gates
    Stargate.activate(gates.origin, gates.destination, event.player_index)
  end,

  search_text_changed = function(event, param)
    local box = event.element
    local search = box.text
    local parent = param.parent
    for k, child in pairs (parent.children) do
      child.visible = child.name:lower():find(search:lower(), 1, true)
    end
  end,
  search_button = function(event, param)
    param.box.visible = not param.box.visible
    if param.box.visible then param.box.focus() end
  end
}

local get_network = function(name)
  local network = data.networks[name]
  if network then return network end
  data.networks[name] = {}
  return data.networks[name]
end

function Stargate.activate(origin, destination, player_index)

    -- Check that dialing gate has sufficient power. This should maybe happen earlier.
    if not (origin and origin.valid) then return end

    local player = game.players[player_index]
    
    if not (player and player.valid) then return end

   
    -- -- TODO: energy, error message
    if not Stargate.can_fire(origin, Stargate.energy_required(origin)) then 
      player.print({"stargates-se.low-power-stargate"})
      return
    end 

    rendering.draw_animation { animation = "event-horizon",
            target = origin,
            target_offset = target_offset or { 0, 0 },
            surface = player.surface,
            animation_speed = animation_speed or 1,
            animation_offset = animation_offset or 0,
            time_to_live = 120,
          }

        rendering.draw_animation { animation = "event-horizon",
          target = destination,
          target_offset = target_offset or { 0, 0 },
          surface = player.surface,
          animation_speed = animation_speed or 1,
          animation_offset = animation_offset or 0,
          time_to_live = 120,
          render_layer = 129,
        }

    if not (destination and destination.valid) then return end

    local destination_surface = destination.surface
    local destination_position = { x = destination.position.x, y = destination.position.y + 3 }
 --This teleport doesn't check collisions. If someone complains, make it check 'can_place' and if false find a positions etc....
    player.teleport(destination_position, destination_surface)
    origin.energy = origin.energy - Stargate.energy_required(origin)
    unlink_stargate(player)
    add_recent(player, destination)
end

local on_built_entity = function(event)
  local entity = event.created_entity or event.entity or event.destination
  if not (entity and entity.valid) then return end
  if entity.name ~= stargate_name then return end
  local surface = entity.surface
  -- If enabled, Stargates can only be build on homeworlds
  if settings.global["stargates-se-homeworlds-only"].value then
    local zone = remote.call("space-exploration", "get_zone_from_surface_index", { surface_index = surface.index})
    if not zone.is_homeworld then
      remote.call("space-exploration", "cancel_entity_creation",  {entity=entity, player_index=event.player_index, message={"stargates-se.homeworld-only"}}, event)
      return
    end
  end
  local force = entity.force
  local name = surface.name .. " ".. entity.unit_number
  local network = get_network('player')
  local stargate_data = {stargate = entity, flying_text = text, tag = tag}
  network[name] = stargate_data
  data.stargate_map[entity.unit_number] = stargate_data
  resync_stargate(name, stargate_data)
  refresh_stargate_frames()
end

local on_stargate_removed = function(entity)
  if not (entity and entity.valid) then return end 
  if entity.name ~= stargate_name then return end
  local force = entity.force
  local stargate_data = data.stargate_map[entity.unit_number]
  if not stargate_data then return end
  local caption = stargate_data.flying_text.text
  local network = get_network('player')
  network[caption] = nil
  clear_stargate_data(stargate_data)
  data.stargate_map[entity.unit_number] = nil

  data.to_be_removed[entity.unit_number] = true
  refresh_stargate_frames()
  data.to_be_removed[entity.unit_number] = nil
end

local on_entity_removed = function(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end
  on_stargate_removed(entity)
end


local on_entity_died = function(event)
  on_stargate_removed(event.entity)
end

local on_player_mined_entity = function(event)
  on_stargate_removed(event.entity)
end

local on_robot_mined_entity = function(event)
  on_stargate_removed(event.entity)
end

local on_gui_action = function(event)
  local element = event.element
  if not (element and element.valid) then return end
  local player_data = data.button_actions[event.player_index]
  if not player_data then return end
  local action = player_data[element.index]
  if action then
    gui_actions[action.type](event, action)
    return true
  end
end


local on_gui_closed = function(event)
  --print("CLOSED "..event.tick)
  local element = event.element
  if not element then return end

  local player = game.get_player(event.player_index)

  local rename_frame = get_rename_frame(player)
  if rename_frame and rename_frame == element then
    close_gui(rename_frame)
    print("Closed rename frame, checking player linked")
    check_player_linked_stargate(player)
    return
  end

  local stargate_frame = get_stargate_frame(player)
  if stargate_frame and stargate_frame == element and not stargate_frame.ignored_by_interaction then
    close_gui(stargate_frame)
    unlink_stargate(player)
    print("Frame unlinked")
    return
  end

end

local on_player_removed = function(event)
  local player = game.get_player(event.player_index)
  close_gui(get_rename_frame(player))
  unlink_stargate(player)
end

local resync_all_stargates = function()
  for force, network in pairs (data.networks) do
    for name, stargate_data in pairs (network) do
      resync_stargate(name, stargate_data)
    end
  end
end

local on_chart_tag_modified = function(event)
  local force = event.force
  local tag = event.tag
  if not (force and force.valid and tag and tag.valid) then return end
  local stargate_data = data.tag_map[tag.tag_number]
  if not stargate_data then
    --Nothing to do with us...
    return
  end
  local player = event.player_index and game.get_player(event.player_index)

  local old_name = event.old_text
  local new_name = tag.text
  if tag.icon and tag.icon.name ~= stargate_name then
    --They're trying to modify the icon! Straight to JAIL!
    if player and player.valid then player.print({"cant-change-icon"}) end
    tag.icon = {type = "item", name = stargate_name}
  end
  if new_name == old_name then
    return
  end
  if new_name == "" or not is_name_available(force, new_name) then
    if player and player.valid then
      player.print({"name-already-taken"})
    end
    tag.text = old_name
    return
  end
  rename_stargate(force, old_name, new_name)
end

local on_chart_tag_removed = function(event)
  local force = event.force
  local tag = event.tag
  if not (force and force.valid and tag and tag.valid) then return end
  local stargate_data = data.tag_map[tag.tag_number]
  if not stargate_data then
    --Nothing to do with us...
    return
  end
  local name = tag.text
  resync_stargate(name, stargate_data)
end

local on_chart_tag_added = function(event)
  if data.adding_tag then return end
  local tag = event.tag
  if not (tag and tag.valid) then
    return
  end
  local icon = tag.icon
  if icon and icon.type == "item" and icon.name == stargate_name then
    --Trying to add a fake stargate tag! JAIL!
    local player = event.player_index and game.get_player(event.player_index)
    if player and player.valid then player.print({"cant-add-tag"}) end
    tag.destroy()
    return
  end
end

local toggle_search = function(player)
  local box = data.search_boxes[player.index]
  if not (box and box.valid) then return end
  box.visible = true
  box.focus()
end

local on_search_focused = function(event)
  local player = game.get_player(event.player_index)
  toggle_search(player)
end

local on_player_display_resolution_changed = function(event)
  local player = game.get_player(event.player_index)
  check_player_linked_stargate(player)
end

local on_player_display_scale_changed = function(event)
  local player = game.get_player(event.player_index)
  check_player_linked_stargate(player)
end

local on_gui_opened= function(event)
  if event.entity and event.entity.valid then
    if event.entity.name == stargate_name then
      Stargate.triggered(event.entity, (game.players[event.player_index]))
    end
  end

end

function Stargate.update_gui(player)
  local root = get_stargate_frame(player)
  if not (root  and root.tags and root.tags.unit_number) then return end

  local stargate = data.stargate_map[root.tags.unit_number].stargate
  local energy_bar = util.find_first_descendant_by_name(root, "stargate_energy_progress")
  energy_bar.value = Stargate.energy_required(stargate) and ((stargate.energy or 0) / Stargate.energy_required(stargate)) or 0


end

function Stargate.triggered(entity, player)
  local character = player.character
  -- don't do anything in editor mode
  if not character then return end
  if not (entity and entity.valid and entity.name == stargate_name) then return error("HEOK") end
  if character.type ~= "character" then return end
  local force = entity.force
  local surface = entity.surface
  local position = entity.position
  local param = data.stargate_map[entity.unit_number]
  if not player then return end

  entity.active = false
  character.active = false
  data.player_linked_stargate[player.index] = entity
  make_stargate_gui(player, entity)
end

function Stargate.can_fire(stargate, energy_required)
  return stargate and stargate.energy >= energy_required
end

function Stargate.energy_required(origin) 
  -- Right now this is a constant but in the future we might want to make it vary with the distance between gates
  return 1000000000;
end

function Stargate.on_tick(event)
  if event.tick % 60 == 0 then
    for _, player in pairs(game.connected_players) do
      Stargate.update_gui(player)
    end
  end
end


local stargates = {}

stargates.events =
{
  [defines.events.on_built_entity] = on_built_entity,
  [defines.events.on_robot_built_entity] = on_built_entity,
  [defines.events.script_raised_built] = on_built_entity,
  [defines.events.script_raised_revive] = on_built_entity,
  [defines.events.on_entity_cloned] = on_built_entity,

  [defines.events.on_entity_died] = on_entity_removed,
  [defines.events.on_player_mined_entity] = on_entity_removed,
  [defines.events.on_robot_mined_entity] = on_entity_removed,
  [defines.events.script_raised_destroy] = on_entity_removed,

  [defines.events.on_gui_click] = on_gui_action,
  [defines.events.on_gui_text_changed] = on_gui_action,
  [defines.events.on_gui_confirmed] = on_gui_action,
  [defines.events.on_gui_closed] = on_gui_closed,
--   ["stargate-focus-search"] = on_search_focused,
  [defines.events.on_player_display_resolution_changed] = on_player_display_resolution_changed,
  [defines.events.on_player_display_scale_changed] = on_player_display_scale_changed,

  [defines.events.on_player_died] = on_player_removed,
  [defines.events.on_player_left_game] = on_player_removed,
  [defines.events.on_player_changed_force] = on_player_removed,

  [defines.events.on_chart_tag_modified] = on_chart_tag_modified,
  [defines.events.on_chart_tag_removed] = on_chart_tag_removed,
  [defines.events.on_chart_tag_added] = on_chart_tag_added,

 [defines.events.on_gui_opened] = on_gui_opened,
 [defines.events.on_tick] = Stargate.on_tick,
--   [defines.events.on_rocket_launched] = on_rocket_launched

}

stargates.on_init = function()
  global.stargates = global.stargates or data
end

stargates.on_load = function()
    log('loaded')
  data = global.stargates
end

return stargates