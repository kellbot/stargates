
local homeworlds_only = {
    type = "bool-setting",
    name = "stargates-se-homeworlds-only",
    setting_type = "runtime-global",
    default_value = false
  }

  data:extend({
    homeworlds_only
  })