local opening=require("opening")
local factory=require("factory")
local policy=require("trial-policy")
local watch=policy.visible and require("watch")
local watch_failed=false
local initialized=false

script.on_init(function()
  if policy.visible then remote.call("freeplay","set_skip_intro",true) end
end)

local function save_stop(name)
  if game.is_multiplayer() then game.server_save(name) else game.auto_save(name) end
end

script.on_event(defines.events.on_tick,function()
  if not initialized then
    if not storage.factory then
      if game.tick<policy.start_tick then return end
      local player=game.get_player(1)
      if not player or not player.character then return end
      helpers.write_file("opening-start.json",helpers.table_to_json{
        seed=game.surfaces.nauvis.map_gen_settings.seed,
        base=script.active_mods.base,
        world_tick=game.tick,
      },false)
    end
    initialized=true
    game.speed=policy.speed
    if storage.factory then
      factory.bind()
      storage.factory.error=nil
      storage.stop=nil
    else
      opening.start()
    end
  end
  if storage.stop then return end
  if not storage.factory then
    opening.tick()
    local ready,problem=opening.handoff()
    if problem then
      storage.stop=true
      helpers.write_file("opening-error.json",helpers.table_to_json{problem=problem,tick=game.tick},false)
      save_stop("mass-through-diagnostic")
      if policy.test_run then script.finish_test(false) end
      return
    end
    if ready then factory.start(ready) end
  else
    local ok,problem=pcall(factory.tick)
    if not ok then
      factory.failed(problem)
      storage.stop=true
      if policy.test_run then script.finish_test(false) end
      return
    end
    if policy.test_run and storage.factory.events.delivery then script.finish_test(true) end
    if not storage.factory.events.delivery and game.tick-storage.factory.start>=policy.horizon then
      factory.report()
      save_stop("mass-through-checkpoint")
      storage.stop=true
      if policy.test_run then script.finish_test(false) end
    end
  end
  if watch and not watch_failed then
    local ok,problem=pcall(watch.tick)
    if not ok then
      helpers.write_file("watch-error.txt",tostring(problem),false)
      watch_failed=true
    end
  end
end)
script.on_event(defines.events.on_script_path_request_finished,opening.path)
script.on_event(defines.events.on_research_finished,function(e)
  if storage.factory then factory.researched(e) else opening.researched(e) end
end)
script.on_event(defines.events.on_rocket_launched,factory.launched)
script.on_event(defines.events.on_rocket_launch_ordered,function(event)
  factory.launch_ordered(event)
  if watch then watch.ordered(event) end
end)
if defines.events.on_cargo_pod_delivered_cargo then
  script.on_event(defines.events.on_cargo_pod_delivered_cargo,factory.pod_delivered)
end
script.on_event(defines.events.on_pre_scenario_finished,function(event)
  factory.victory(event)
  if watch and event.player_won and storage.factory then
    factory.report()
    watch.won()
  end
end)
