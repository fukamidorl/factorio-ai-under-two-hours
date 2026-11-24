local M = {}
local design = helpers.json_to_table(require("design"))

local excluded_types = {
  character=true, ["character-corpse"]=true, ["entity-ghost"]=true, ["tile-ghost"]=true,
  ["item-entity"]=true, ["item-request-proxy"]=true, ["cargo-pod"]=true,
  ["rocket-silo-rocket"]=true, ["rocket-silo-rocket-shadow"]=true, explosion=true,
  projectile=true, stream=true, smoke=true, ["smoke-with-trigger"]=true,
  ["construction-robot"]=true, ["logistic-robot"]=true, ["combat-robot"]=true,
}
local belt_types = {["transport-belt"]=true, ["underground-belt"]=true, splitter=true, loader=true, ["loader-1x1"]=true}

local function point(position)
  if not position then return nil end
  local x,y = position.x or position[1],position.y or position[2]
  if type(x)~="number" or type(y)~="number" then return nil end
  return {x=x,y=y}
end

local function position_key(position)
  local p = point(position)
  if not p then return nil end
  return math.floor(p.x) .. "," .. math.floor(p.y)
end

local function enlarge(bounds, left, top, right, bottom)
  if not bounds then return {left=left,top=top,right=right,bottom=bottom} end
  bounds.left = math.min(bounds.left,left)
  bounds.top = math.min(bounds.top,top)
  bounds.right = math.max(bounds.right,right)
  bounds.bottom = math.max(bounds.bottom,bottom)
  return bounds
end

local function include(bounds, row)
  return enlarge(bounds, row.left,row.top,row.right,row.bottom)
end

local function center(bounds)
  return {x=(bounds.left+bounds.right)/2,y=(bounds.top+bounds.bottom)/2}
end

local function add_group(groups, key, row)
  local group = groups[key] or {count=0}
  group.count = group.count + 1
  group.bounds = include(group.bounds,row)
  groups[key] = group
end

local function configured_units(factory)
  local jobs, mineral_sites = {}, {}
  for _, unit in ipairs(factory.units or {}) do
    if unit.entity and unit.entity.valid and unit.entity.unit_number then
      jobs[unit.entity.unit_number] = {recipe=unit.recipe,product=unit.product}
    end
  end
  for mineral,sites in pairs(design.drills or {}) do
    for _,site in ipairs(sites) do
      local key = position_key(site.position or site.drill)
      if key then mineral_sites[key] = mineral end
    end
  end
  for _,site in ipairs(design.burner_coal or {}) do
    local key = position_key(site.drill or site.position)
    if key then mineral_sites[key] = "coal" end
  end
  return jobs,mineral_sites
end

local function inspect(surface, force, factory)
  local jobs,mineral_sites = configured_units(factory)
  local rows, groups, entities, entity_by_id = {},{},{},{}
  local bounds, lab_bounds, terminal_bounds
  for _, entity in ipairs(surface.find_entities_filtered{force=force}) do
    if not excluded_types[entity.type] then
      local pos, box = entity.position, entity.selection_box
      local left_top = box and point(box.left_top) or pos
      local right_bottom = box and point(box.right_bottom) or pos
      local row = {
        unit_number=entity.unit_number,name=entity.name,type=entity.type,
        x=pos.x,y=pos.y,direction=entity.direction,
        width=right_bottom.x-left_top.x,height=right_bottom.y-left_top.y,
        left=left_top.x,top=left_top.y,right=right_bottom.x,bottom=right_bottom.y,
      }
      local job = row.unit_number and jobs[row.unit_number]
      if job then row.recipe,row.product = job.recipe,job.product end
      if entity.type=="mining-drill" then
        local mineral = entity.mining_target
        if mineral and mineral.valid and mineral.type=="resource" then
          row.resource,row.resource_source = mineral.name,"mining_target"
        else
          row.resource = mineral_sites[position_key(pos)]
          if row.resource then row.resource_source = "route_site" end
        end
      end
      bounds = include(bounds,row)
      if entity.type=="lab" then lab_bounds = include(lab_bounds,row) end
      if entity.name=="rocket-silo" or entity.name=="cargo-landing-pad" then
        terminal_bounds = include(terminal_bounds,row)
      end
      rows[#rows+1] = row
      add_group(groups,"type:" .. row.type,row)
      add_group(groups,"name:" .. row.name,row)
      if row.recipe then add_group(groups,"recipe:" .. row.recipe,row) end
      if row.product then add_group(groups,"product:" .. row.product,row) end
      if row.resource then add_group(groups,"resource:" .. row.resource,row) end
      if row.unit_number then
        entities[#entities+1] = entity
        entity_by_id[row.unit_number] = row
      end
    end
  end
  for _, group in pairs(groups) do group.center = center(group.bounds) end
  return rows,groups,bounds,lab_bounds,terminal_bounds,entities,entity_by_id
end

local function get_connections(entity, typ)
  if typ=="belt" then
    local neighbours = entity.belt_neighbours
    local outputs = neighbours.outputs
    if entity.type=="underground-belt" and entity.belt_to_ground_type=="input" then
      local other = entity.underground_belt_neighbour
      if other then outputs[#outputs+1] = other end
    end
    return {outputs}
  end
  return entity.fluidbox_neighbours
end

local function physical_links(entities, entity_by_id)
  local links, seen, failed = {},{},{}
  for _, entity in ipairs(entities) do
    local a = entity.unit_number
    for _, kind in ipairs{"belt","pipe"} do
      if kind=="pipe" or belt_types[entity.type] then
        local ok, groups = pcall(get_connections,entity,kind)
        if not ok then failed[kind]=(failed[kind] or 0)+1 end
        if ok and groups then
          for _, group in pairs(groups) do
            for _, other in pairs(group) do
              local b = other.valid and other.unit_number
              if b and b~=a and entity_by_id[b] then
                local first,second = entity_by_id[a],entity_by_id[b]
                local from,to = a,b
                if kind=="pipe" and b<a then from,to,first,second=b,a,second,first end
                local key = kind..":"..from..":"..to
                if not seen[key] then
                  seen[key] = true
                  links[#links+1] = {
                    kind=kind, from_id=from, to_id=to,
                    from={x=first.x,y=first.y}, to={x=second.x,y=second.y},
                  }
                end
              end
            end
          end
        end
      end
    end
  end
  return links,failed
end

local function view(file, bounds, width, height, margin, max_zoom)
  local x_span = bounds.right-bounds.left+2*margin
  local y_span = bounds.bottom-bounds.top+2*margin
  local scale = math.min(width/x_span,height/y_span,max_zoom*32)
  local mid = center(bounds)
  return {file=file,width=width,height=height,zoom=scale/32,center=mid,pixels_per_tile=scale,
          world_bounds={left=mid.x-width/2/scale,top=mid.y-height/2/scale,
                        right=mid.x+width/2/scale,bottom=mid.y+height/2/scale}}
end

local function position_of(entity)
  if not entity or not entity.valid then return nil end
  return point(entity.position)
end

local function save_scene(factory)
  assert(factory.events.delivery,"Delivery event is required for factory capture.")
  local surface = game.surfaces.nauvis
  local force = game.forces.player
  local rows,groups,bounds,lab_bounds,terminal_bounds,entities,by_id = inspect(surface,force,factory)
  assert(bounds and lab_bounds and terminal_bounds,"Expected factory, lab, and terminal equipment is missing.")
  local views = {
    overview=view("factory-overview.png",bounds,4096,3008,16,.75),
    terminal=view("factory-terminal.png",terminal_bounds,1920,1280,10,1.15),
    labs=view("factory-labs.png",lab_bounds,2304,1536,8,.94),
  }
  local requests = {}
  for _, name in ipairs{"overview","terminal","labs"} do
    local camera = views[name]
    local ok, problem = pcall(game.take_screenshot,{
      surface=surface,position=camera.center,resolution={camera.width,camera.height},zoom=camera.zoom,
      path=camera.file,show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,
      hide_health_bars=true,daytime=0,force_render=true,
    })
    requests[name]={requested=ok,error=not ok and tostring(problem) or nil}
  end

  local links_ok,links,link_query_failures = pcall(physical_links,entities,by_id)
  if not links_ok then
    link_query_failures = {error=tostring(links)}
    links = {}
  end
  local pad = factory.pad
  local event_names = {"launch-ordered","launch","cargo-pod-delivered","delivery"}
  local data = {
    schema_version=1, world_tick=game.tick, elapsed_tick=game.tick-factory.start,
    seed=surface.map_gen_settings.seed, base=script.active_mods.base, surface=surface.name, force=force.name,
    bounds=bounds, entities=rows, entity_count=#rows, groups=groups, views=views, screenshots=requests,
    physical_links=links, link_query_failures=link_query_failures,
    terminal={bounds=terminal_bounds,silo=position_of(factory.silo),pad=position_of(pad),
              pad_space_science=pad and pad.valid and pad.get_item_count("space-science-pack")},
    labs={bounds=lab_bounds,count=groups["type:lab"].count},
    events={},
  }
  for _, name in ipairs(event_names) do
    local event = factory.events[name]
    if event then data.events[name]={elapsed_tick=event.tick,world_tick=factory.start+event.tick,value=event.value} end
  end
  helpers.write_file("factory-layout.json",helpers.table_to_json(data),false)
  return views.overview
end

function M.delivered(factory)
  local ok, overview = pcall(save_scene,factory)
  if not ok then
    helpers.write_file("factory-capture-error.txt",tostring(overview) .. "\n",false)
    return nil
  end
  return overview
end

return M
