local path = "__stargates__/data/entities/stargate/"
local name = 'stargate'
local localised_name = {'stargates-se.stargate'}

local stargate = {
    type = "electric-energy-interface",
    name = "stargate",
    localised_name = localised_name,
    collision_box = {{-6, -2.5}, {6, 4.5}},
    selection_box = {{-6, -6}, {6, 6}},
    drawing_box = {{-6, -6}, {6, 6}},
    collision_mask = {
      "floor-layer",
      "object-layer",
      "water-tile",
    },
    max_health = 5000,
    corpse = "medium-remnants",
    flags = {
        "not-blueprintable",
        "placeable-neutral",
        "placeable-player",
        "player-creation",
        "not-upgradable",
        "not-rotatable"
    },
    energy_source = {
        buffer_capacity = "5GJ",
        input_flow_limit = "50MW",
        output_flow_limit = "0kW",
        type = "electric",
        usage_priority = "secondary-input",
        drain = "100kW" 
      },
    energy_production = "0KW",
    energy_usage = "0GW",
    se_allow_in_space = false,
    minable = {result = name, mining_time = 3},
    icon = path.."gateway.png",
    icon_size = 500,
    picture = {
      layers = {
      {
        filename = path.."gateway.png",
        priority = "medium",
        width = 500,
        height = 500,
        scale = 1.4
      },
      {
        filename = path.."gateway-shadow.png",
        draw_as_shadow = true,
        priority = "medium",
        width = 500,
        height = 500,
        scale = 1.4
      }
    }
  },

}

local event_horizon = {
  type = "animation",
  name = "event-horizon",
  filename = path.."event-horizon-sr.png",
  width = 500,
  height = 500,
  line_length = 8,
  frame_count = 64,
  animation_speed = 0.5,
  scale = 1.4

}

local stargate_item = {
    type = "item",
    name = name,
    icon = path.."gateway-item.png",
    icon_size = 256,
    subgroup = "transport",
    stack_size = 1,
    place_result = name
}


local recipe = {
  type = "recipe",
  name = name,
  localised_name = localised_name,
  enabled = false,
  ingredients = {
    { "glass", 200 },
    { "copper-plate", 200 },
    { "steel-plate", 1000 },
    { "concrete", 200 },
    { "stone-brick", 500 },
    { "accumulator", 100 },
    { "processing-unit", 100 },
  },
  energy_required = 10,
  result = name,  
  category = "space-manufacturing",
  always_show_made_in = true
}

local technology =
{
  type = "technology",
  name = name,
  localised_name = localised_name,
  icon_size = 500,
  icon = path.."gateway-icon.png",
  effects =
  {
    {
      type = "unlock-recipe",
      recipe = name
    }
  },
  unit =
  {
    count = 500,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"space-science-pack", 1},
    },
    time = 30
  },
  prerequisites = {"advanced-electronics", "battery"},
  order = "y-a"
}


local stargate_flying_text = util.copy(data.raw["flying-text"]["tutorial-flying-text"])
stargate_flying_text.name = "stargate-flying-text"

local hotkey_name = require"shared".hotkeys.focus_search
local hotkey =
{
  type = "custom-input",
  name = hotkey_name,
  linked_game_control = "focus-search",
  key_sequence = "Control + F"
}


data:extend
{
  stargate,
  stargate_item,
  recipe,
  event_horizon,
  technology,
  stargate_flying_text,
  hotkey
}