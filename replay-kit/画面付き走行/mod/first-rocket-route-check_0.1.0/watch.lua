local design = helpers.json_to_table(require("design"))
local policy = require("trial-policy")
local M = {}
local view_name = "factory_live_view"
local clock_name = "factory_live_clock"
local lift_off_frames = {60, 180, 300, 420, 540, 660, 780, 900, 1020, 1140}

local function elapsed_clock(ticks)
  local seconds = math.floor(ticks / 60)
  return string.format("%d:%02d:%02d", math.floor(seconds / 3600),
                       math.floor(seconds / 60) % 60, seconds % 60)
end

local function take_picture(path, position, zoom)
  local ok, problem = pcall(game.take_screenshot, {
    surface = game.surfaces.nauvis, position = position, zoom = zoom,
    resolution = {1600, 900}, path = path, show_gui = false, force_render = true,
  })
  if not ok then helpers.write_file("watch-picture-error.txt", tostring(problem) .. "\n", true) end
end

local function group_position(factory, recipe)
  local units = factory.groups[recipe] or {}
  local unit = units[math.ceil(#units / 2)]
  return unit and unit.entity.valid and unit.entity.position
end

local function watch_scene(factory, elapsed, player)
  local overview=storage.captured_overview
  if factory.events.delivery and overview then
    local display=player.display_resolution
    local ratio=math.min(display.width*.85/overview.width,display.height*.75/overview.height)
    return overview.center,math.max(.05,overview.zoom*ratio),"工場全景・着荷完了"
  end
  local sequence = math.floor(elapsed / 18000) % 3
  if factory.events["research-done-rocket-silo"] then
    local site = design.terminal.silo
    return {x=site.x+3, y=site.y-8}, .72, "ロケットサイロ"
  end
  if factory.profile == 1 then
    if sequence == 1 then return {x=-28, y=-22}, .50, "蒸気発電と採掘の立ち上げ" end
    if sequence == 2 then return {x=-36, y=24}, .50, "石炭・鉄・銅の増産" end
    return {x=12, y=-25}, .55, "最初の組立と研究"
  end
  if factory.profile == 2 or factory.profile == 3 then
    if sequence == 1 and factory.oils[1] and factory.oils[1].valid then
      return factory.oils[1].position, .68, "採油"
    end
    if sequence == 2 then return {x=-53, y=48}, .47, "原料の採掘" end
    return {x=96, y=12}, .42, "組立工場と精油"
  end
  if sequence == 1 then
    local lab = factory.labs[math.ceil(#factory.labs / 2)]
    if lab and lab.valid then return lab.position, .60, "研究所" end
  elseif sequence == 2 then
    local science = group_position(factory, "production-science-pack")
    if science then return science, .60, "上位サイエンスの製造" end
  end
  return {x=96, y=18}, .33, "工場全景"
end

local function frame_for(player, position, zoom)
  local frame = player.gui.screen[view_name]
  if not frame then
    frame = player.gui.screen.add{
      type="frame", name=view_name, direction="vertical", ignored_by_interaction=true,
    }
    frame.add{
      type="camera", name="view", surface_index=game.surfaces.nauvis.index,
      position=position, zoom=zoom, ignored_by_interaction=true,
    }
    frame.auto_center = true
  end
  local camera = frame.view
  local screen = player.display_resolution
  local scale = player.display_scale
  local width = math.floor(screen.width / scale * .91) - 24
  local height = math.floor(screen.height / scale * .84) - 48
  if camera.style.minimal_width ~= width or camera.style.minimal_height ~= height then
    camera.style.size = {width, height}
    frame.force_auto_center()
  end
  camera.position = position
  camera.zoom = zoom
  return frame
end

local function set_speed(view, speed)
  if view.speed ~= speed then
    game.speed = speed
    view.speed = speed
  end
end

function M.tick()
  local player = game.get_player(1)
  if not player then return end
  storage.live_watch = storage.live_watch or {start=game.tick}
  local view = storage.live_watch
  local factory = storage.factory
  local elapsed = game.tick - (factory and factory.start or view.start)
  local events = factory and factory.events
  if view.ordered then
    local frame_at = lift_off_frames[view.picture or 1]
    if frame_at and game.tick - view.ordered >= frame_at then
      take_picture(string.format("watch-lift-off-%04d.png",frame_at), view.lift_off_focus,.78)
      view.picture = (view.picture or 1) + 1
    end
  end
  if game.tick % 60 ~= 0 and view.speed then return end

  local speed = not factory and (elapsed<3600 and 2 or 8) or policy.speed
  if events and events["research-done-rocket-silo"] then speed = 4 end
  if factory and factory.silo and factory.silo.valid then
    speed = factory.silo.rocket_parts >= 90 and 1 or 2
  end
  if view.ordered or events and (events.delivery or events.victory) then speed = 1 end
  set_speed(view, speed)

  local status = elapsed_clock(elapsed) .. "  ｜  ×" .. tostring(speed)
  if not factory then
    local clock = player.gui.top[clock_name] or player.gui.top.add{
      type="label", name=clock_name, ignored_by_interaction=true,
    }
    clock.caption = status
    return
  end
  if player.gui.top[clock_name] then player.gui.top[clock_name].destroy() end
  local position, zoom, caption = watch_scene(factory, elapsed, player)
  local frame = frame_for(player, position, zoom)
  if events["silo-placed"] and not view.silo_picture then
    take_picture("watch-silo-ready.png", position, .68)
    view.silo_picture = true
  end
  if factory.silo and factory.silo.valid and not events.delivery then
    caption = view.ordered and "ロケット発射" or string.format("ロケット部品 %d / 100",factory.silo.rocket_parts)
  end
  frame.caption = caption .. "  ｜  " .. status
  helpers.write_file("watch-latest.json",helpers.table_to_json{
    tick=elapsed,speed=speed,scene=caption,position=position,
  }, false)
end

function M.ordered(event)
  local state = storage.live_watch
  if not state then return end
  local p = event.rocket_silo.position
  state.lift_off_focus = {x=p.x+2, y=p.y-10}
  state.ordered = game.tick
  set_speed(state,1)
end

function M.won()
  game.speed = 1
  local state = storage.live_watch
  if state then state.speed = 1 end
  local player = game.get_player(1)
  if player and player.gui.screen[view_name] then
    player.gui.screen[view_name].caption = "衛星打ち上げ完了  ｜  " .. elapsed_clock(game.tick-storage.factory.start)
  end
  game.auto_save("watch-rocket-launched")
end

return M
