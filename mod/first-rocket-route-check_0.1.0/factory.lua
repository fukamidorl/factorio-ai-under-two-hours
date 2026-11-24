local encoded = require("design")
local design = helpers.json_to_table(encoded)
local M = {}
local S, surface, force, player
local directions = {[0]={0,-1},[4]={1,0},[8]={0,1},[12]={-1,0}}
local power_kw = {
  ["electric-mining-drill"]=90, ["assembling-machine-1"]=75, ["assembling-machine-2"]=150,
  ["chemical-plant"]=210, ["oil-refinery"]=420, ["pumpjack"]=90, ["electric-furnace"]=180,
  lab=60, ["rocket-silo"]=4000,
}
local caps = {
  ["iron-ore"]=4500, ["copper-ore"]=3800, coal=16000, stone=7500, wood=360,
  ["iron-plate"]=5200, ["copper-plate"]=3800, ["steel-plate"]=9500, ["stone-brick"]=6500,
  ["iron-gear-wheel"]=1700, ["iron-stick"]=1500, ["copper-cable"]=4600, ["electronic-circuit"]=6500,
  ["advanced-circuit"]=4200, ["processing-unit"]=1600, ["low-density-structure"]=1800,
  ["rocket-fuel"]=1250, ["solid-fuel"]=4000, ["plastic-bar"]=3500, ["engine-unit"]=750,
  ["electric-engine-unit"]=480, ["flying-robot-frame"]=450, ["construction-robot"]=350,
  sulfur=1150, battery=1000, rail=1800, ["electric-furnace"]=110, ["productivity-module"]=160,
  ["electric-mining-drill"]=90, ["assembling-machine-1"]=52, ["assembling-machine-2"]=120,
  ["stone-furnace"]=110, ["steel-furnace"]=140, ["small-electric-pole"]=130, ["iron-chest"]=95,
  ["wooden-chest"]=100, lab=32, boiler=45, ["steam-engine"]=75, pipe=400, inserter=250,
  ["transport-belt"]=700, concrete=1800, ["solar-panel"]=145, accumulator=145, radar=12,
  ["medium-electric-pole"]=160, pumpjack=12, ["oil-refinery"]=40, ["chemical-plant"]=65,
  ["rocket-silo"]=1, ["cargo-landing-pad"]=1, satellite=1,
  ["speed-module"]=124, ["speed-module-2"]=16, ["speed-module-3"]=4,
  water=9000, ["crude-oil"]=10000, ["petroleum-gas"]=15000, ["light-oil"]=13000,
  ["heavy-oil"]=9000, lubricant=2500, ["sulfuric-acid"]=4500,
}
local reserve_targets = {
  ["processing-unit"]=1310, ["low-density-structure"]=1100, ["rocket-fuel"]=1050,
  ["steel-plate"]=1025, concrete=1200, ["electric-engine-unit"]=200,
  ["solar-panel"]=100, accumulator=100, radar=5, pipe=100,
}
local oil_priority = {pumpjack=true,["oil-refinery"]=true,["chemical-plant"]=true,
  ["basic-oil-processing"]=true,["advanced-oil-processing"]=true,["engine-unit"]=true,
  ["steel-plate"]=true,["plastic-bar"]=true,sulfur=true,["chemical-science-pack"]=true,
  ["advanced-circuit"]=true,
}
local science_products={}
for _,pack in ipairs(design.science) do science_products[pack]=true end
local terminal_recipes={["rocket-silo"]=true,satellite=true,["cargo-landing-pad"]=true}
local terminal_supply={concrete=6,["solar-panel"]=5,accumulator=5,radar=1}
local terminal_supply_order={"concrete","solar-panel","accumulator","radar"}
local silo_modules={"speed-module-3","speed-module-2","speed-module"}
local speed_module_assemblers={["speed-module"]=10,["speed-module-2"]=4,["speed-module-3"]=3}
local late_science={
  rail=true,["iron-stick"]=true,["electric-furnace"]=true,["productivity-module"]=true,
  ["production-science-pack"]=true,["utility-science-pack"]=true,
}
local continuing_mall={
  pumpjack=2,["oil-refinery"]=2,["chemical-plant"]=3,["assembling-machine-2"]=5,
  ["electric-mining-drill"]=3,["steel-furnace"]=5,["stone-furnace"]=2,
  boiler=2,["steam-engine"]=6,pipe=3,["small-electric-pole"]=3,["medium-electric-pole"]=6,["iron-chest"]=2,
}
local build_order = {
  "iron-plate","copper-plate","iron-gear-wheel","copper-cable","electronic-circuit","steel-plate",
  "lab","automation-science-pack","logistic-science-pack","transport-belt","inserter",
  "electric-mining-drill","stone-furnace","assembling-machine-1","wooden-chest","small-electric-pole","medium-electric-pole",
  "boiler","steam-engine","pipe","steel-furnace","assembling-machine-2","iron-chest","offshore-pump",
  "oil-refinery","pumpjack","chemical-plant","basic-oil-processing","advanced-oil-processing",
  "heavy-oil-cracking","light-oil-cracking","lubricant","plastic-bar","advanced-circuit","sulfur","sulfuric-acid",
  "engine-unit","chemical-science-pack","battery","electric-engine-unit","flying-robot-frame",
  "construction-robot","stone-brick","rail","iron-stick","electric-furnace","productivity-module",
  "processing-unit","low-density-structure","solid-fuel","rocket-fuel","production-science-pack",
  "utility-science-pack","solar-panel","accumulator","radar","concrete",
  "speed-module","speed-module-2","speed-module-3",
  "satellite","cargo-landing-pad","rocket-silo",
}
for _,color in ipairs(design.science) do caps[color]=2200 end
local startup_caps={
  ["iron-gear-wheel"]=90,["copper-cable"]=160,["electronic-circuit"]=100,
  ["transport-belt"]=120,inserter=30,["stone-brick"]=65,["stone-furnace"]=38,
  ["small-electric-pole"]=45,["assembling-machine-1"]=25,lab=10,
  ["automation-science-pack"]=210,["logistic-science-pack"]=180,
}
local commissioning_limits={
  ["iron-plate"]=12,["copper-plate"]=8,["steel-plate"]=2,["stone-brick"]=1,
  ["iron-gear-wheel"]=2,["copper-cable"]=2,["electronic-circuit"]=2,
  ["automation-science-pack"]=3,["logistic-science-pack"]=2,lab=1,
  ["transport-belt"]=1,inserter=1,["electric-mining-drill"]=2,["burner-mining-drill"]=1,
  ["assembling-machine-1"]=1,["stone-furnace"]=1,["small-electric-pole"]=1,
  ["medium-electric-pole"]=1,["wooden-chest"]=1,["iron-chest"]=1,
  boiler=1,["steam-engine"]=1,pipe=1,["offshore-pump"]=1,
}
local commissioning_drills={{"coal",6},{"iron-ore",6},{"copper-ore",3}}
caps["offshore-pump"]=6

local function stock(name) return S.stock[name] or 0 end
local function add(name,count) S.stock[name]=stock(name)+count end
local function held(name) return S.reserve[name] or 0 end
local function mark(name,value)
  if not S.events[name] then S.events[name]={tick=game.tick-S.start,value=value} end
end
local function researched(name)
  local tech=force.technologies[name]
  return tech and tech.researched
end
local function recipe(name)
  return force.recipes[design.recipes[name] or name]
end
local function active_recipe(name)
  local r=recipe(name)
  return r and r.enabled and r or nil
end
local function key(p) return math.floor(p.x)..","..math.floor(p.y) end
local function available(name,n)
  return stock(name)>=n
end
local function capacity(name)
  if S.profile==1 and startup_caps[name] then return startup_caps[name] end
  if name=="steel-plate" and S.profile<3 then return 620 end
  return caps[name] or 350
end
local function transfer(inv,name,count)
  local n=math.floor(math.min(count,stock(name)))
  if n<=0 then return 0 end
  local moved=inv.insert{name=name,count=n}
  if moved>0 then add(name,-moved) end
  return moved
end
local function collect(inv,name,count)
  local space=math.max(0,capacity(name)-stock(name))
  local bank=name=="electric-engine-unit" and S.profile>=3 and not researched("rocket-silo")
  local remaining=bank and math.max(0,reserve_targets[name]-held(name)) or 0
  local n=math.floor(math.min(count,space+remaining))
  if n<=0 then return end
  local moved=inv.remove{name=name,count=n}
  if moved<=0 then return end
  if remaining>0 then
    local eligible=moved+(S.engine_share_remainder or 0)
    local reserved=math.min(remaining,math.max(math.floor(eligible/2),moved-space))
    S.engine_share_remainder=eligible%2
    S.reserve[name]=held(name)+reserved
    moved=moved-reserved
    if held(name)==reserve_targets[name] then mark("silo-electric-engines-ready",held(name)) end
  end
  if moved>0 then add(name,moved) end
end
local function material_request(name,count,priority)
  local row=S.requests[name]
  if not row or row.priority>priority then S.requests[name]={priority=priority,count=count} end
end

local function construction_floor(product,item)
  if not S.priority_craft or product==S.priority_craft then return 0 end
  return S.priority_parts[item] or 0
end

local function mine_tree(entity)
  if entity.mine{inventory=S.scratch,ignore_minable=false,raise_destroyed=true} then
    for _,stack in pairs(S.scratch.get_contents()) do add(stack.name,stack.count) end
    S.scratch.clear()
    S.cleared=S.cleared+1
    S.work=S.work-1
    return true
  end
  return false
end

local function put(spec,priority)
  local existing=surface.find_entity(spec.name,spec.position)
  if spec.name=="small-electric-pole" then
    existing=existing or surface.find_entity("medium-electric-pole",spec.position)
    if stock("medium-electric-pole")>0 or stock("small-electric-pole")==0 and stock("wood")<15 and active_recipe("medium-electric-pole") then
      spec={name="medium-electric-pole",position=spec.position}
    end
  end
  if existing then return existing end
  if not available(spec.name,1) then material_request(spec.name,1,priority); return nil,"material" end
  if S.work<=0 then return nil,"time" end
  local p=spec.position
  local check={name=spec.name,position=p,direction=spec.direction or 0,force=force}
  if not surface.can_place_entity(check) then
    local c=prototypes.entity[spec.name].collision_box
    local r=math.max(-c.left_top.x,-c.left_top.y,c.right_bottom.x,c.right_bottom.y)+.4
    for _, obstacle in pairs(surface.find_entities_filtered{
      area={{p.x-r,p.y-r},{p.x+r,p.y+r}}, force="neutral", type={"tree","simple-entity"}}) do
      if S.work<=0 then return nil,"time" end
      mine_tree(obstacle)
    end
    if not surface.can_place_entity(check) then return nil,"site" end
  end
  check.raise_built=true
  local entity=surface.create_entity(check)
  if entity then
    add(spec.name,-1)
    S.work=S.work-1
    S.built[spec.name]=(S.built[spec.name] or 0)+1
    S.rated=S.rated+(power_kw[spec.name] or 0)
    return entity
  end
  return nil,"site"
end

local function spare_wire(target,priority)
  local root=surface.find_entity("small-electric-pole",{x=-12.5,y=-43.5})
  if not root then return false,"site" end
  local network=root.electric_network_id
  local anchors=surface.find_entities_filtered{type="electric-pole",position=target,radius=34,force=force}
  local live={}
  for _,anchor in ipairs(anchors) do if anchor.electric_network_id==network then live[#live+1]=anchor end end
  if #live==0 then return false,"site" end
  local path=S.spare_wire and S.spare_wire[key(target)]
  if not path then
    local function fits(p)
      return surface.can_place_entity{name="small-electric-pole",position=p,force=force}
    end
    local nodes,seen={},{}
    for dx=-2,2 do
      for dy=-2,2 do
        local p={x=target.x+dx,y=target.y+dy}
        if fits(p) then nodes[#nodes+1]={p=p};seen[key(p)]=true end
      end
    end
    local steps={{6,0},{-6,0},{0,6},{0,-6},{4,4},{-4,-4},{4,-4},{-4,4},
                 {5,2},{-5,2},{5,-2},{-5,-2},{2,5},{2,-5},{-2,5},{-2,-5}}
    local cursor=1
    while nodes[cursor] and cursor<=260 do
      local node=nodes[cursor]
      local p=node.p
      for _,anchor in ipairs(live) do
        local q=anchor.position
        if (p.x-q.x)^2+(p.y-q.y)^2<=7.5^2 then
          path={}
          local at=cursor
          while at do
            path[#path+1]=nodes[at].p
            at=nodes[at].from
          end
          break
        end
      end
      if path then break end
      for _,step in ipairs(steps) do
        local q={x=p.x+step[1],y=p.y+step[2]}
        local k=key(q)
        if not seen[k] then
          seen[k]=true
          if fits(q) then nodes[#nodes+1]={p=q,from=cursor} end
        end
      end
      cursor=cursor+1
    end
    if not path then return false,"site" end
    S.spare_wire=S.spare_wire or {}
    S.spare_wire[key(target)]=path
  end
  local final
  for _,p in ipairs(path) do
    local placed,why=put({name="small-electric-pole",position=p},priority)
    if not placed then
      if why=="site" then S.spare_wire[key(target)]=nil end
      return false,why
    end
    final=placed
  end
  if final then
    S.poles[key(target)]=final
    mark("live-power-bypass-"..key(target),final.position)
    return true
  end
  return false,"site"
end

local function pole_at(p,priority)
  local k=key(p)
  if S.poles[k] and S.poles[k].valid then return true end
  local queue,cursor={},p
  while cursor and not S.poles[key(cursor)] do
    queue[#queue+1]=cursor
    cursor=design.poles[key(cursor)]
  end
  for i=#queue,1,-1 do
    local site=queue[i]
    local detour
    if key(site)=="-12,-6" then
      for _,waypoint in ipairs({{x=-17.5,y=-11.5},{x=-16.5,y=-5.5},{x=-17.5,y=.5}}) do
        local e,reason=put({name="small-electric-pole",position=waypoint},priority)
        if not e then return false,reason end
      end
      detour={x=-11.5,y=-.5}
    end
    local e,reason=put({name="small-electric-pole",position=detour or site},priority)
    if e and detour then mark("wreck-power-detour",e.position) end
    if not e and reason=="site" then
      local parent=design.poles[key(site)]
      local upstream=parent and S.poles[key(parent)]
      for _,dy in ipairs({0,-1,1,-2,2}) do
        for _,dx in ipairs({-1,1,0,-2,2}) do
          local nearby={x=site.x+dx,y=site.y+dy}
          local distance=upstream and ((upstream.position.x-nearby.x)^2+(upstream.position.y-nearby.y)^2) or 0
          if (dx~=0 or dy~=0) and distance<=7.5^2 then
            e,reason=put({name="small-electric-pole",position=nearby},priority)
            if e or reason~="site" then break end
          end
        end
        if e or reason~="site" then break end
      end
      if e then mark("rerouted-power-pole-"..key(site),e.position) end
    end
    if not e then
      if reason=="site" then
        mark("blocked-power-pole-"..key(site))
        return spare_wire(p,priority)
      end
      return false,reason
    end
    S.poles[key(site)]=e
  end
  return true
end

local function count_group(product)
  local group=S.groups[product]
  return group and #group or 0
end
local function register(entity,product,r,passive)
  local entry={entity=entity,product=product,recipe=r and r.name,passive=passive}
  S.units[#S.units+1]=entry
  if product then
    S.groups[product]=S.groups[product] or {}
    table.insert(S.groups[product],entry)
  end
  return entry
end
local function new_power(target)
  if S.extra_boilers>=target then return end
  for i,site in ipairs(design.water) do
    if not S.pumps[i] then
      local a=put({name="offshore-pump",position=site.pump},1)
      if not a then return end
      local b=put({name="pipe",position=site.pipe},1)
      if not b then return end
      S.pumps[i]=b
    end
    if i==1 and target<48 then break end
  end
  local next_bank=math.floor(S.extra_boilers/20)+1
  local b=S.power_order and S.power_order[next_bank] or next_bank
  local index=S.extra_boilers%20+1
  local bank=design.power[b]
  if not bank or not pole_at(bank.connection,1) then return end
  local items=bank.slices[index]
  for _,spec in ipairs(items) do
    local e,reason=put(spec,1)
    if not e then
      if reason=="site" then error("Steam collision "..spec.name.." "..key(spec.position)) end
      return
    end
    if spec.water_inlet and (not S.water_inlets[b] or e.position.x<S.water_inlets[b].position.x) then S.water_inlets[b]=e end
    if e.name=="boiler" and not S.seen[e.unit_number] then
      S.seen[e.unit_number]=true
      S.boilers[#S.boilers+1]={entity=e,solid=next_bank>=5}
    end
    if e.name=="steam-engine" then S.engines[e.unit_number]=e end
  end
  S.extra_boilers=S.extra_boilers+1
  if S.extra_boilers==20 then mark("first-36-mw-bank") end
end

local function bridge_power()
  local index=(S.bridge_done or 0)+1
  if index>2 then return true end
  local x=-10.5+4*index
  local items={
    {name="pipe",position={x=x+2,y=-52.5}}, {name="pipe",position={x=x,y=-50.5}},
    {name="pipe",position={x=x,y=-44.5}}, {name="small-electric-pole",position={x=x-2,y=-48.5}},
    {name="small-electric-pole",position={x=x-2,y=-43.5}},
    {name="boiler",position={x=x,y=-52},direction=8},
    {name="steam-engine",position={x=x,y=-47.5},direction=8},
    {name="steam-engine",position={x=x,y=-41.5},direction=8},
  }
  for _,spec in ipairs(items) do
    local e,why=put(spec,0)
    if not e then
      if why=="site" then mark("opening-power-bridge-collision",spec);S.bridge_done=index end
      return false
    end
    if e.name=="boiler" and not S.seen[e.unit_number] then
      S.seen[e.unit_number]=true
      S.boilers[#S.boilers+1]={entity=e}
    elseif e.name=="steam-engine" then
      S.engines[e.unit_number]=e
    end
  end
  S.bridge_done=index
  mark("opening-power-bridge-"..index)
  return index==2
end

local function mining(material,goal)
  local slots=design.drills[material]
  local last=S.mined[material] or 0
  if (S.used_drills[material] or 0)>=goal or last>=#slots then return end
  local site=slots[last+1]
  if not available("electric-mining-drill",1) then material_request("electric-mining-drill",4,2); return end
  if not pole_at(site.pole,3) then return end
  local chest=surface.find_entity("wooden-chest",site.drop) or surface.find_entity("iron-chest",site.drop)
  local chest_type=(stock("iron-chest")>0 or stock("wood")<12) and "iron-chest" or "wooden-chest"
  if not chest then
    local blocked
    chest,blocked=put({name=chest_type,position=site.drop},2)
    if not chest then
      if blocked=="site" then
        S.dropped_sites=S.dropped_sites+1
        S.mined[material]=last+1
        mark("skipped-blocked-"..material.."-collection-site",site.drop)
      end
      return
    end
  end
  local e,reason=put({name="electric-mining-drill",position=site.position,direction=site.direction},2)
  if not e then
    if reason=="site" then
      S.dropped_sites=S.dropped_sites+1
      S.mined[material]=last+1
    end
    return
  end
  if not S.seen[chest.unit_number] then
    S.seen[chest.unit_number]=true
    S.extraction[#S.extraction+1]={entity=chest,item=material}
  end
  S.mined[material]=last+1
  S.used_drills[material]=(S.used_drills[material] or 0)+1
  mark("first-electric-"..material.."-drill-placed",e.position)
end

local function starter_coal()
  local cursor=S.starter_coal+1
  local site=design.burner_coal[cursor]
  if not site or (S.used_drills.coal or 0)>=10 then return end
  if not available("burner-mining-drill",1) then material_request("burner-mining-drill",1,1);return end
  local chest,blocked=put({name="wooden-chest",position=site.drop},1)
  if not chest then
    if blocked=="site" then
      S.starter_coal=cursor
      S.dropped_sites=S.dropped_sites+1
    end
    return
  end
  local e,reason=put({name="burner-mining-drill",position=site.drill,direction=site.direction},1)
  if e then
    S.coal_burners[#S.coal_burners+1]=e
    S.extraction[#S.extraction+1]={entity=chest,item="coal"}
    S.starter_coal=cursor
  elseif reason=="site" then
    S.starter_coal=cursor
    S.dropped_sites=S.dropped_sites+1
  end
end

local function shift_drill()
  if stock("electric-mining-drill")>=3 then return end
  if (S.used_drills.coal or 0)>=14 and (S.used_drills["copper-ore"] or 0)>=15 and (S.used_drills.stone or 0)>=4 then return end
  for _,source in ipairs({{"iron-ore",28,2600},{"copper-ore",15,1800},{"stone",5,1000}}) do
    local name,keep,buffer=source[1],source[2],source[3]
    if (S.used_drills[name] or 0)>keep and stock(name)>=buffer then
      for i=(S.mined[name] or 0),1,-1 do
        local pos=design.drills[name][i].position
        local entity=surface.find_entity("electric-mining-drill",pos)
        if entity and entity.mine{inventory=S.scratch,ignore_minable=false,raise_destroyed=true} then
          for _,item in pairs(S.scratch.get_contents()) do add(item.name,item.count) end
          S.scratch.clear()
          S.work=S.work-1
          S.used_drills[name]=S.used_drills[name]-1
          S.rated=S.rated-power_kw["electric-mining-drill"]
          S.reassigned_drills=(S.reassigned_drills or 0)+1
          mark("surplus-drills-redeployed-from-"..name,pos)
          return
        end
      end
    end
  end
end

local function oil(goal)
  if #S.oils>=goal or not researched("oil-gathering") then return end
  local site=design.oils[#S.oils+1]
  if not site or not pole_at(site.pole,3) then return end
  local e,reason=put({name="pumpjack",position=site.position},3)
  if not e and reason=="site" then error("Oil pump collision "..key(site.position)) end
  if e then S.oils[#S.oils+1]=e end
end

local function install(name,product,r,priority)
  if not available(name,1) then material_request(name,4,priority); return false end
  local large=name=="oil-refinery"
  local cursor=large and "large_cursor" or "cursor"
  local site=(large and design.large_sites or design.sites)[S[cursor]]
  if not site then return false end
  local connected,failure=pole_at(site.pole,priority)
  if not connected then
    if failure=="site" then
      S.dropped_sites=S.dropped_sites+1
      S[cursor]=S[cursor]+1
      mark("skipped-unpowered-factory-site",site.position)
    end
    return false
  end
  local e,reason=put({name=name,position=site.position},priority)
  if not e then
    if reason=="site" then
      S.dropped_sites=S.dropped_sites+1
      S[cursor]=S[cursor]+1
    end
    return false
  end
  S[cursor]=S[cursor]+1
  if e.type=="lab" then
    S.labs[#S.labs+1]=e
  else
    if r and e.type~="furnace" then assert(e.set_recipe(r.name),r.name) end
    register(e,product,r,false)
  end
  return true
end

local function machine_for(product,r)
  if r.has_category("smelting") then
    return stock("steel-furnace")>0 and "steel-furnace" or "stone-furnace"
  elseif r.has_category("oil-processing") then
    return "oil-refinery"
  elseif r.has_category("chemistry") then
    return "chemical-plant"
  elseif active_recipe("assembling-machine-2") then
    local older=prototypes.entity["assembling-machine-1"].crafting_categories
    if stock("assembling-machine-2")==0 then
      for _,category in ipairs(r.categories) do
        if older[category] then return "assembling-machine-1" end
      end
    end
    return "assembling-machine-2"
  end
  return "assembling-machine-1"
end

local function upgrade_smelter(product,limit)
  if S.work<=0 or not available("steel-furnace",1) then return end
  S.smelter_upgrades=S.smelter_upgrades or {}
  S.smelter_cursor=S.smelter_cursor or {}
  local done=S.smelter_upgrades[product] or 0
  if done>=limit then return end
  local units=S.groups[product] or {}
  local i=S.smelter_cursor[product] or 1
  while i<=#units and units[i].entity.name~="stone-furnace" do i=i+1 end
  if i>#units then S.smelter_cursor[product]=i;return end

  local unit=units[i]
  local site=unit.entity.position
  local spec={name="steel-furnace",position=site,force=force}
  if not surface.can_fast_replace(spec) then
    S.smelter_cursor[product]=i+1
    return
  end
  if not unit.entity.mine{inventory=S.scratch,raise_destroyed=true} then return end
  for _,item in pairs(S.scratch.get_contents()) do add(item.name,item.count) end
  S.scratch.clear()

  local placed=put(spec,2)
  if not placed then
    unit.entity=assert(put({name="stone-furnace",position=site},2))
    S.smelter_cursor[product]=i+1
    return
  end
  unit.entity=placed
  S.built["stone-furnace"]=S.built["stone-furnace"]-1
  S.smelter_upgrades[product]=done+1
  S.smelter_cursor[product]=i+1
  mark("first-smelter-upgrade-"..product)
end

local function start_steel()
  local r=active_recipe("steel-plate")
  if not r or count_group("steel-plate")>=4 or stock("stone-brick")<200 then return end
  local kilns=S.groups["stone-brick"] or {}
  if #kilns<=2 then return end
  for i=#kilns,1,-1 do
    local unit=kilns[i]
    local e=unit.entity
    if e.crafting_progress==0 then
      for _,api in ipairs({defines.inventory.crafter_input,defines.inventory.crafter_output}) do
        local inv=e.get_inventory(api)
        for _,item in pairs(inv.get_contents()) do add(item.name,inv.remove{name=item.name,count=item.count}) end
      end
      table.remove(kilns,i)
      unit.product,unit.recipe="steel-plate",r.name
      S.groups["steel-plate"]=S.groups["steel-plate"] or {}
      table.insert(S.groups["steel-plate"],unit)
      mark("brick-kilns-switched-to-steel")
      break
    end
  end
end

local function replace_wooden_pole_mall()
  local r=active_recipe("medium-electric-pole")
  local old=S.groups["small-electric-pole"]
  if not r or stock("wood")>=15 or count_group("medium-electric-pole")>0 or not old or #old==0 then return end
  local unit=old[#old]
  if unit.entity.crafting_progress~=0 then return end
  for _,idx in ipairs({defines.inventory.crafter_input,defines.inventory.crafter_output}) do
    local inv=unit.entity.get_inventory(idx)
    for _,item in pairs(inv.get_contents()) do add(item.name,inv.remove{name=item.name,count=item.count}) end
  end
  assert(unit.entity.set_recipe(r.name))
  unit.product,unit.recipe="medium-electric-pole",r.name
  table.remove(old)
  S.groups[unit.product]={unit}
  mark("wood-free-power-poles")
end

local function desired(profile,product)
  local take=design.profiles[tostring(profile)]
  local n=take[product] or 0
  if profile>=2 then n=math.max(n,continuing_mall[product] or 0) end
  if not S.foundation_ready then
    n=math.min(n,commissioning_limits[product] or 0)
    if product=="iron-plate" or product=="copper-plate" then
      local raw=product=="iron-plate" and "iron-ore" or "copper-ore"
      return math.min(n,math.ceil((S.used_drills[raw] or 0)*1.65))
    end
    return n
  end
  if product=="basic-oil-processing" then return researched("advanced-oil-processing") and 0 or 8 end
  local petrol_short=profile>=3 and stock("petroleum-gas")<4000
  if product=="advanced-oil-processing" then
    if petrol_short and stock("crude-oil")>=7500 then return 26 end
    return profile>=3 and 19 or 6
  end
  if product=="solid-fuel" and profile>=3 then return math.max(n,20) end
  if product=="heavy-oil-cracking" or product=="light-oil-cracking" then
    local target=profile>=3 and 6 or 2
    if petrol_short and product=="heavy-oil-cracking" and stock("heavy-oil")>2000 then target=12 end
    if petrol_short and product=="light-oil-cracking" and stock("light-oil")>5000 then target=18 end
    return math.max(n,target)
  end
  if product=="sulfuric-acid" and profile>=3 then return math.max(n,3) end
  if product=="stone-brick" and profile>=2 then return math.max(n,profile>=3 and 24 or 14) end
  if profile>=3 then
    if product=="chemical-science-pack" then return math.max(n,32) end
    if product=="low-density-structure" and profile>=4 then return math.max(n,50) end
    if terminal_supply[product] then return math.max(n,terminal_supply[product]) end
    if speed_module_assemblers[product] then return speed_module_assemblers[product] end
    if late_science[product] and researched("processing-unit") then
      n=math.max(n,design.profiles["4"][product] or 0)
    end
  end
  if profile>=3 and held("electric-engine-unit")<reserve_targets["electric-engine-unit"] and not S.silo then
    if product=="electric-engine-unit" then return math.max(n,18) end
    if product=="engine-unit" then return math.max(n,36) end
    if product=="lubricant" then return math.max(n,3) end
  end
  if product=="processing-unit" or product=="low-density-structure" or product=="rocket-fuel" then
    n=math.max(n,design.profiles["3"][product] or 0)
  end
  if product=="offshore-pump" or product=="iron-chest" or product=="wooden-chest" or product=="lab" then
    n=math.max(n,1)
  end
  if product=="satellite" or product=="rocket-silo" or product=="cargo-landing-pad" then return 1 end
  if product=="iron-plate" or product=="copper-plate" then
    local raw=product=="iron-plate" and "iron-ore" or "copper-ore"
    n=math.min(math.max(n,6),math.ceil((S.used_drills[raw] or 0)*1.45)+3)
  elseif product=="steel-plate" and profile<3 then
    n=math.min(n,math.ceil((S.used_drills["iron-ore"] or 0)/5)+2)
  end
  return n
end

local function early_lines()
  local first={"automation-science-pack","logistic-science-pack","electronic-circuit","assembling-machine-1",
               "copper-cable","iron-gear-wheel","electric-mining-drill","inserter","transport-belt"}
  for _,name in ipairs(first) do
    local r=active_recipe(name)
    local target=(name=="automation-science-pack" and 3 or (name=="logistic-science-pack" and 2 or 1))
    local count=count_group(name)
    if r and count<target then
      if count==0 and not available("assembling-machine-1",1) and stock("iron-gear-wheel")>=90 and name=="automation-science-pack" then
        local surplus=S.groups["iron-gear-wheel"]
        local unit=surplus and surplus[#surplus]
        if unit and unit.entity.crafting_progress==0 then
          local inv=unit.entity.get_inventory(defines.inventory.crafter_input)
          for _,item in pairs(inv.get_contents()) do add(item.name,inv.remove{name=item.name,count=item.count}) end
          assert(unit.entity.set_recipe(r.name))
          table.remove(surplus)
          unit.product,unit.recipe=name,r.name
          S.groups[name]={unit}
          mark("gear-machine-reassigned-to-red")
        end
      else
        if install(machine_for(name,r),name,r,1) then return end
      end
    end
  end
end

local function upgrade_refineries()
  local advanced=active_recipe("advanced-oil-processing")
  local basic=S.groups["basic-oil-processing"] or {}
  if not advanced or #basic==0 then return end
  for i=#basic,1,-1 do
    local unit=basic[i]
    local e=unit.entity
    if e.crafting_progress==0 then
      for _,fluid in ipairs({"crude-oil","petroleum-gas"}) do
        local remaining=e.get_fluid_count(fluid)
        if remaining>0 then add(fluid,e.extract_fluid{name=fluid,amount=remaining}) end
      end
      assert(e.set_recipe(advanced.name))
      unit.product,unit.recipe=advanced.name,advanced.name
      table.remove(basic,i)
      S.groups[advanced.name]=S.groups[advanced.name] or {}
      table.insert(S.groups[advanced.name],unit)
      mark("refineries-switched-to-advanced")
      return
    end
  end
end

local function all_requirements(wanted,count)
  local reserved,requirements={},{}
  local function visit(name,n,recurse)
    local available_count=math.max(0,stock(name)-(reserved[name] or 0)-construction_floor(wanted,name))
    if recurse and available_count>0 then
      local use=math.min(n,available_count)
      requirements[name]=(requirements[name] or 0)+use
      reserved[name]=(reserved[name] or 0)+use
      n=n-use
    end
    if n==0 then return true end
    local r=force.recipes[name]
    if not r or not r.enabled then return false end
    local hand_categories=player.character.prototype.crafting_categories
    local can_craft=false
    for _,category in ipairs(r.categories) do
      if hand_categories[category] then can_craft=true; break end
    end
    if not can_craft then return false end
    local yield
    for _,p in ipairs(r.products) do if p.name==name then yield=p.amount end end
    if not yield then return false end
    for _,i in ipairs(r.ingredients) do
      if i.type~="item" or not visit(i.name,i.amount*math.ceil(n/yield),true) then return false end
    end
    return true
  end
  return visit(wanted,count,false) and requirements or nil
end

local function collect_player()
  if not player or not player.character then return end
  local inv=player.get_main_inventory()
  if #(player.crafting_queue or {})>0 then
    local made=S.hand_item and inv.get_item_count(S.hand_item) or 0
    if made>0 then add(S.hand_item,inv.remove{name=S.hand_item,count=made}) end
    return
  end
  S.hand_item=nil
  for _,item in pairs(inv.get_contents()) do
    if item.name~="pistol" and item.name~="firearm-magazine" then
      add(item.name,inv.remove{name=item.name,count=item.count})
    end
  end
end

local function handcraft()
  if not player or not player.character then return end
  if #(player.crafting_queue or {})>0 then return end
  local request={}
  for name,row in pairs(S.requests) do request[#request+1]={name=name,count=row.count,priority=row.priority} end
  table.sort(request,function(a,b)
    if a.priority~=b.priority then return a.priority<b.priority end
    return a.name<b.name
  end)
  for _,entry in ipairs(request) do
    if stock(entry.name)==0 and (entry.name==S.priority_craft or count_group(entry.name)==0 or not S.foundation_ready or S.profile==1) then
      for n=entry.count,1,-1 do
        local needs=all_requirements(entry.name,n)
        if needs then
          local inv=player.get_main_inventory()
          for name,count in pairs(needs) do assert(transfer(inv,name,count)==count) end
          local began=player.begin_crafting{recipe=entry.name,count=n}
          assert(began>0,"Native crafting rejected "..entry.name)
          S.hand_item=entry.name
          S.hand_orders=S.hand_orders+began
          return
        end
      end
    end
  end
end

local function commission()
  if S.foundation_ready then return end
  local complete=true
  for _,goal in ipairs(commissioning_drills) do
    if (S.used_drills[goal[1]] or 0)<goal[2] then complete=false;break end
  end
  if complete then
    S.foundation_ready=true
    mark("powered-mining-foundation-ready")
  end
end

local function plant_load()
  local kw,capacity=0,0
  for _,engine in pairs(S.engines) do
    capacity=capacity+900
    kw=kw+engine.energy_generated_last_tick*60/1000
  end
  return kw,capacity
end

local function protect_parts(r,batches,parts)
  for _,i in ipairs(r.ingredients) do
    if i.type=="item" then
      local previous=parts[i.name] or 0
      local need=i.amount*batches
      parts[i.name]=previous+need
      local short=math.min(need,math.max(0,previous+need-stock(i.name)))
      local intermediate=short>0 and active_recipe(i.name)
      if intermediate and intermediate.has_category("crafting") and intermediate.name~=r.name then
        local amount=intermediate.products[1].amount
        protect_parts(intermediate,math.ceil(short/amount),parts)
      end
    end
  end
end

local function choose_priority_craft(short_power)
  local candidates={}
  if short_power or not S.foundation_ready then
    candidates={"steam-engine","boiler","offshore-pump","pipe","medium-electric-pole","small-electric-pole"}
  end
  if S.profile<3 then
    candidates[#candidates+1]="medium-electric-pole"
    candidates[#candidates+1]="small-electric-pole"
    candidates[#candidates+1]="iron-chest"
    candidates[#candidates+1]="wooden-chest"
    candidates[#candidates+1]="pumpjack"
    candidates[#candidates+1]="oil-refinery"
    candidates[#candidates+1]="chemical-plant"
  end
  if S.profile<=2 then candidates[#candidates+1]="electric-mining-drill" end

  S.priority_craft,S.priority_parts=nil,nil
  for _,name in ipairs(candidates) do
    local r=S.requests[name] and active_recipe(name)
    if r and not available(name,1) then
      S.priority_craft,S.priority_parts=name,{}
      protect_parts(r,1,S.priority_parts)
      material_request(name,2,0)
      break
    end
  end
end

local function commission_mines()
  local pending={}
  for _,goal in ipairs(commissioning_drills) do
    local count=S.used_drills[goal[1]] or 0
    if count<goal[2] then pending[#pending+1]={item=goal[1],target=goal[2],share=count/goal[2]} end
  end
  table.sort(pending,function(a,b)
    if a.share==b.share then return a.item<b.item end
    return a.share<b.share
  end)
  for _,entry in ipairs(pending) do mining(entry.item,entry.target) end
end

local function prepare_terminal_power()
  if S.terminal_ready then return true end
  if not pole_at(design.terminal.pole,2) then return false end
  local site=design.terminal.silo
  local terminal=put({name="small-electric-pole",position={x=site.x-5,y=site.y-1}},2)
  if not terminal then return false end
  S.terminal_ready=true
  mark("terminal-power-ready")
  return true
end

local function select_profile()
  if researched("production-science-pack") and researched("utility-science-pack") then return 4 end
  if researched("chemical-science-pack") then return 3 end
  if researched("automation-2") then return 2 end
  return 1
end

local function speed_up_stone_mining()
  local missing_tier2=math.max(0,(4-stock("speed-module-3"))*4-stock("speed-module-2"))
  local spare=stock("speed-module")-missing_tier2*4
  if spare<=0 then return end
  for _,site in ipairs(design.drills.stone) do
    local drill=surface.find_entity("electric-mining-drill",site.position)
    if drill then
      local inv=drill.get_module_inventory()
      local moved=transfer(inv,"speed-module",math.min(spare,#inv-inv.get_item_count("speed-module")))
      if moved>0 then
        S.stone_modules=(S.stone_modules or 0)+moved
        S.work=S.work-1
        mark("first-stone-speed-modules",site.position)
        return
      end
    end
  end
end

local function switch_idle_science_assembler(product)
  if count_group(product)>0 or S.work<=0 then return end
  local r=active_recipe(product)
  if not r then return end
  for _,pack in ipairs(design.science) do
    local group=S.groups[pack] or {}
    for i=#group,1,-1 do
      local unit=group[i]
      local e=unit.entity
      if e.name=="assembling-machine-2" and not e.is_crafting() then
        for _,index in ipairs({defines.inventory.crafter_input,defines.inventory.crafter_output}) do
          local inv=e.get_inventory(index)
          for _,item in pairs(inv.get_contents()) do add(item.name,inv.remove{name=item.name,count=item.count}) end
        end
        assert(e.set_recipe(r.name),r.name)
        table.remove(group,i)
        unit.product,unit.recipe=product,r.name
        S.groups[product]={unit}
        S.work=S.work-1
        mark("science-assembler-reassigned-to-"..product,e.position)
        return
      end
    end
  end
end

local function build()
  S.work,S.requests=5,{}
  collect_player()
  commission()
  if S.wood_cursor<=#S.trees and stock("wood")<(stock("coal")<120 and S.profile>=2 and 300 or 65) then
    local tree=S.trees[S.wood_cursor]
    S.wood_cursor=S.wood_cursor+1
    if tree.valid then mine_tree(tree) end
  end
  local profile=select_profile()
  if S.profile~=profile then S.profile=profile; mark("profile-"..profile) end
  local load,installed=plant_load()
  local short_power=installed>0 and (load>=installed*.84 or installed<9000)
  if profile>=2 then start_steel();replace_wooden_pole_mall() end
  if profile>=3 then upgrade_refineries() end
  if profile>=2 and S.work>0 then shift_drill() end
  starter_coal()
  local goal=math.min(({20,58,110,120})[profile],math.max(4,math.ceil(S.rated/1950)+5))
  if (S.foundation_ready or S.rated>=900 and (S.used_drills.coal or 0)>=2) and bridge_power() and S.foundation_ready then new_power(goal) end
  if #S.labs==0 and active_recipe("lab") then install("lab",nil,nil,0) end
  if not S.foundation_ready then
    commission_mines()
  else
    if S.work>0 then mining("coal",({30,80,112,126})[profile]) end
    local iron=({60,204,252,268})[profile]
    local copper=({30,90,194,207})[profile]
    if S.work>0 and (S.used_drills["copper-ore"] or 0)*2 < (S.used_drills["iron-ore"] or 0) then
      mining("copper-ore",copper)
    end
    if S.work>0 then mining("iron-ore",iron) end
    if S.work>0 then mining("copper-ore",copper) end
    if S.work>0 then mining("stone",({8,13,26,32})[profile]) end
  end
  if S.work>0 then oil(profile>=3 and 5 or 2) end
  if (profile==1 or not S.foundation_ready) and S.work>0 then early_lines() end
  local goal_labs=S.foundation_ready and math.min(({18,38,72,96})[profile],math.max(6,math.floor(installed/450))) or 4
  if #S.labs<goal_labs and active_recipe("lab") then install("lab",nil,nil,2) end
  if #S.labs>0 and count_group(design.science[1])==0 and stock(design.science[1])<10 then
    material_request(design.science[1],10,1)
  end
  if profile>=4 and S.work>0 then prepare_terminal_power() end
  if S.silo or researched("rocket-silo") then
    switch_idle_science_assembler("rocket-silo")
    switch_idle_science_assembler("cargo-landing-pad")
    switch_idle_science_assembler("satellite")
    if not S.pad and available("cargo-landing-pad",1) then
      S.pad=put({name="cargo-landing-pad",position=design.terminal.pad},1)
    end
    if not S.silo and available("rocket-silo",1) and prepare_terminal_power() then
      S.silo=put({name="rocket-silo",position=design.terminal.silo},1)
      if S.silo then
        mark("silo-placed",{position=S.silo.position})
        local modules=assert(S.silo.get_module_inventory())
        local count=0
        for _,name in ipairs(silo_modules) do count=count+transfer(modules,name,4-count) end
        S.silo_modules=modules.get_contents()
        mark("silo-modules-installed",S.silo_modules)
      end
    end
  end
  if profile>=3 and not researched("rocket-silo") and stock("coal")>=2000 then
    if stock("iron-plate")>=750 and stock("steel-plate")<1800 then upgrade_smelter("steel-plate",92) end
    if stock("iron-ore")>=1500 and stock("iron-plate")<3000 then upgrade_smelter("iron-plate",185) end
    if stock("copper-ore")>=1200 and stock("copper-plate")<2500 then upgrade_smelter("copper-plate",145) end
    if stock("stone")>=500 and stock("stone-brick")<2000 then upgrade_smelter("stone-brick",15) end
  end
  if profile>=3 and S.work>0 and not researched("rocket-silo") then speed_up_stone_mining() end
  local origin=S.build_cursor
  for i=1,#build_order do
    local j=(origin+i-2)%#build_order+1
    local name=build_order[j]
    local r=active_recipe(name)
    local current=count_group(name)
    if r and (current<desired(profile,name)) then
      local machine=machine_for(name,r)
      local priority=(current==0 and 2 or 5)
      if install(machine,name,r,priority) then S.build_cursor=j%#build_order+1 end
    end
    if S.work<=0 then break end
  end
  choose_priority_craft(short_power)
  handcraft()
end

local function take_fluids(entity,ingredients,owner)
  for _,i in ipairs(ingredients) do
    if i.type=="fluid" then
      local want=math.min(stock(i.name),i.amount*3-entity.get_fluid_count(i.name))
      if i.name=="light-oil" and owner=="light-oil-cracking" and researched("rocket-fuel") then
        want=math.min(want,stock(i.name)-1000)
      end
      if want>.05 then
        local accepted=entity.insert_fluid{name=i.name,amount=want}
        add(i.name,-accepted)
      end
    end
  end
end

local function collect_unit(unit)
  local e=unit.entity
  if not e.valid then return end
  local r=unit.recipe and force.recipes[unit.recipe]
  local inv=e.get_output_inventory()
  if inv then
    for _,item in pairs(inv.get_contents()) do collect(inv,item.name,item.count) end
  end
  if r then
    for _,p in ipairs(r.products) do
      if p.type=="fluid" then
        local amount=math.min((caps[p.name] or 5000)-stock(p.name),e.get_fluid_count(p.name))
        if amount>.05 then add(p.name,e.extract_fluid{name=p.name,amount=amount}) end
      end
    end
  end
end

local function feed_unit(unit)
  local e=unit.entity
  if not e.valid or unit.passive then return end
  local r=unit.recipe and force.recipes[unit.recipe]
  if not r or not r.enabled then return end
  local tech=force.current_research
  local studying_silo=tech and tech.name=="rocket-silo"
  local silo_done=researched("rocket-silo")
  local terminal=terminal_recipes[unit.product]
  if unit.product=="rocket-silo" and S.silo or unit.product=="cargo-landing-pad" and S.pad
      or unit.product=="satellite" and S.events["satellite-loaded"] then return end
  if terminal and e.is_crafting() then return end
  if silo_done and (science_products[unit.product] or unit.product=="flying-robot-frame"
                  or unit.product=="construction-robot") then return end
  if unit.product=="utility-science-pack" then
    local remaining=studying_silo and math.ceil(1000*(1-force.research_progress)) or 1000
    if stock(unit.product)>=remaining+40 then return end
  end
  if studying_silo or silo_done then
    if unit.product=="low-density-structure" and held(unit.product)>=1100 and stock(unit.product)>180 then return end
    if unit.product=="solar-panel" and held(unit.product)+stock(unit.product)>=110 then return end
    local purple_ready=silo_done or stock("production-science-pack")>math.ceil((1-force.research_progress)*1000)+80
    if purple_ready and (unit.product=="production-science-pack" or unit.product=="rail"
        or unit.product=="electric-furnace" or unit.product=="productivity-module") then return end
  end
  if unit.product=="basic-oil-processing" and researched("advanced-oil-processing") and count_group("advanced-oil-processing")>=4 then
    return
  end
  if unit.product and stock(unit.product)>=capacity(unit.product) then return end
  if unit.product=="stone-brick" and stock("stone")<24 and (S.profile==1 or stock("stone-brick")>140) then return end
  if S.profile>=2 and (count_group("basic-oil-processing")+count_group("advanced-oil-processing")<5)
      and not oil_priority[unit.product] and unit.product~="medium-electric-pole" and stock("steel-plate")<90 then
    for _,i in ipairs(r.ingredients) do if i.name=="steel-plate" then return end end
  end
  local inv=e.get_inventory(defines.inventory.crafter_input)
  if inv then
    local batches=terminal and 1 or 3
    local ingredients=r.ingredients
    for _,i in ipairs(ingredients) do
      local n=i.type=="item" and inv.get_item_count(i.name) or e.get_fluid_count(i.name)
      local movable=math.max(0,stock(i.name)-construction_floor(unit.product,i.name))+(terminal and held(i.name) or 0)
      batches=math.min(batches,math.floor((movable+n)/i.amount))
    end
    if batches>=1 then
      for _,i in ipairs(ingredients) do
        if i.type=="item" then
          local needed=i.amount*batches-inv.get_item_count(i.name)
          if terminal and needed>0 and held(i.name)>0 then
            local moved=inv.insert{name=i.name,count=math.min(needed,held(i.name))}
            S.reserve[i.name]=held(i.name)-moved
            needed=needed-moved
          end
          local movable=stock(i.name)-construction_floor(unit.product,i.name)
          transfer(inv,i.name,math.min(movable,needed))
        end
      end
      take_fluids(e,ingredients,unit.recipe)
    end
  else
    take_fluids(e,r.ingredients,unit.recipe)
  end
end

local function fluids()
  for _,pump in ipairs(S.pumps) do
    if stock("water")<caps.water then
      add("water",pump.extract_fluid{name="water",amount=math.min(100,caps.water-stock("water"))})
    end
  end
  for _,e in pairs(S.water_inlets) do
    local want=math.min(150,stock("water"))
    if want>.05 then add("water",-e.insert_fluid{name="water",amount=want}) end
  end
  for _,pump in ipairs(S.oils) do
    if stock("crude-oil")<caps["crude-oil"] then
      add("crude-oil",pump.extract_fluid{name="crude-oil",amount=math.min(500,caps["crude-oil"]-stock("crude-oil"))})
    end
  end
end

local function fuel()
  if S.share_solid then
    if stock("coal")>13000 or stock("solid-fuel")<900 then S.share_solid=false end
  elseif stock("coal")<9000 and stock("solid-fuel")>2000 then
    S.share_solid=true
    mark("solid-fuel-shared-with-steam")
  end
  if stock("coal")<3 then
    for _,row in ipairs(S.boilers) do
      if row.entity.get_fluid_count("water")<1 then
        local f=row.entity.get_fuel_inventory()
        local surplus=f.get_item_count("coal")-1
        if surplus>0 then add("coal",f.remove{name="coal",count=surplus}) end
      end
    end
  end
  for _,e in ipairs(S.coal_burners) do
    local inv=e.get_fuel_inventory()
    if inv.get_item_count("coal")<2 then
      if transfer(inv,"coal",3)==0 and inv.get_item_count("wood")==0 then transfer(inv,"wood",2) end
    end
  end
  for _,e in ipairs(S.burners) do
    local inv=e.get_fuel_inventory()
    if inv.get_item_count("coal")<2 then
      if transfer(inv,"coal",2)==0 and inv.get_item_count("wood")==0 and stock("wood")>15 then
        transfer(inv,"wood",1)
      end
    end
  end
  for _,row in ipairs(S.boilers) do
    local inv=row.entity.get_fuel_inventory()
    local use_solid=(row.solid or stock("coal")<240) and stock("solid-fuel")>=80
    local item=(use_solid or S.share_solid and stock("solid-fuel")>=900) and "solid-fuel" or "coal"
    if inv.get_item_count("coal")+inv.get_item_count("solid-fuel")+inv.get_item_count("wood")<3 then
      if transfer(inv,item,4)==0 and stock("wood")>30 then transfer(inv,"wood",4) end
    end
  end
  for _,unit in ipairs(S.units) do
    local inv=unit.entity.get_fuel_inventory()
    if inv and inv.get_item_count("coal")+inv.get_item_count("wood")<2 then
      if transfer(inv,"coal",4)==0 and stock("wood")>75 then transfer(inv,"wood",3) end
    end
  end
end

local function research()
  if not force.current_research then
    for _,name in ipairs(design.research) do
      local tech=force.technologies[name]
      if tech and not tech.researched and tech.enabled then
        local ready=true
        for _,p in pairs(tech.prerequisites) do if not p.researched then ready=false;break end end
        if ready then
          for _,i in ipairs(tech.research_unit_ingredients) do
            if stock(i.name)<i.amount then ready=false; break end
          end
        end
        if ready and force.add_research(tech) then mark("research-start-"..name); break end
      end
    end
  end
  if force.current_research then
    local tech=force.current_research
    for j=1,#S.labs do
      local lab=S.labs[(S.lab_cursor+j-2)%#S.labs+1]
      local inv=lab.get_inventory(defines.inventory.lab_input)
      local complete=true
      for _,i in ipairs(tech.research_unit_ingredients) do
        if inv.get_item_count(i.name)+stock(i.name)<i.amount then complete=false;break end
      end
      if complete then
        for _,i in ipairs(tech.research_unit_ingredients) do
          transfer(inv,i.name,i.amount*2-inv.get_item_count(i.name))
        end
      end
    end
    if #S.labs>0 then S.lab_cursor=(S.lab_cursor+2)%#S.labs+1 end
  end
end

local function launch_stock()
  local tech=force.current_research
  local studying=tech and tech.name=="rocket-silo"
  local preparing=S.profile>=4 and not researched("rocket-silo") and stock("utility-science-pack")<120
  if studying or preparing then
    local remaining=studying and math.ceil(1000*(1-force.research_progress))+42 or 120
    local need=math.ceil(math.max(0,remaining-stock("utility-science-pack"))*2/3)
    local n=math.min(held("processing-unit"),math.max(0,need-stock("processing-unit")))
    if n>0 then
      S.reserve["processing-unit"]=held("processing-unit")-n
      add("processing-unit",n)
      S.released_for_yellow=(S.released_for_yellow or 0)+n
      mark("released-processing-units-for-yellow",n)
    end
  end
  if S.profile>=3 and not researched("rocket-silo") then
    for item,goal in pairs(reserve_targets) do
      local limit=(item=="steel-plate" and 420 or (item=="processing-unit" or item=="low-density-structure") and 190 or 25)
      local amount=math.floor(math.min(goal-held(item),math.max(0,stock(item)-limit)/6))
      if amount>0 and item~="electric-engine-unit" and not ((studying or preparing) and item=="processing-unit") then
        S.reserve[item]=held(item)+amount;add(item,-amount)
      end
    end
    if not S.events["terminal-stock-ready"] then
      local ready=true
      for item,goal in pairs(reserve_targets) do
        if held(item)+stock(item)<goal then ready=false;break end
      end
      if ready then mark("terminal-stock-ready") end
    end
  end
  if S.silo and S.pad then
    local silo=S.silo
    local input=assert(silo.get_inventory(defines.inventory.crafter_input))
    local manifest={"processing-unit","low-density-structure","rocket-fuel"}
    for _,item in ipairs(manifest) do
      local need=120-input.get_item_count(item)
      if need>0 then
        local taken=math.max(0,math.min(held(item),need))
        if taken>0 then
          local moved=input.insert{name=item,count=taken}
          S.reserve[item]=held(item)-moved
          need=need-moved
        end
        if need>0 then transfer(input,item,need) end
      end
    end
    local rocket=silo.get_inventory(defines.inventory.rocket_silo_rocket)
    if rocket and stock("satellite")>0 and not S.events["satellite-loaded"] then
      if transfer(rocket,"satellite",1)==1 then
        mark("satellite-loaded")
        silo.send_to_orbit_automatically=true
      end
    end
  end
end

local function service()
  for _,t in ipairs(S.old_outputs) do
    if t.e.valid then
      local inv=t.e.get_inventory(t.inventory)
      if inv then collect(inv,t.item,math.floor((caps[t.item] or 300))) end
    end
  end
  for _,t in ipairs(S.extraction) do collect(t.entity.get_inventory(defines.inventory.chest),t.item,400) end
  for _,unit in ipairs(S.units) do collect_unit(unit) end
  fuel()
  research()
  launch_stock()
  local oil_first=S.profile>=2 and not researched("advanced-oil-processing")
  local tech=force.current_research
  local finishing=researched("rocket-silo") or tech and tech.name=="rocket-silo"
  local fed={}
  local function feed_group(name)
    if fed[name] then return end
    fed[name]=true
    for _,unit in ipairs(S.groups[name] or {}) do feed_unit(unit) end
  end
  if S.priority_craft then feed_group(S.priority_craft) end
  feed_group(design.science[1])
  feed_group(design.science[2])
  if S.profile>=3 then
    if stock("chemical-science-pack")<400 and not researched("rocket-silo") then
      for _,name in ipairs({"chemical-science-pack","engine-unit","pipe","sulfur"}) do feed_group(name) end
    end
    if not researched("rocket-silo") and stock("iron-plate")>=750
        and (not S.smelter_upgrades or (S.smelter_upgrades["steel-plate"] or 0)<80) then
      feed_group("steel-furnace")
    end
    for _,name in ipairs(terminal_supply_order) do feed_group(name) end
    if stock("production-science-pack")<1100 and not researched("rocket-silo") then
      for _,name in ipairs({"production-science-pack","electric-furnace"}) do feed_group(name) end
      if stock("productivity-module")<12 then feed_group("productivity-module") end
      if stock("rail")<300 or stock("stone-brick")>=350 then feed_group("rail") end
      if stock("stone-brick")<350 then feed_group("stone-brick") end
    end
    if S.profile>=4 and held("low-density-structure")<1100 and stock("low-density-structure")<190 then
      feed_group("low-density-structure")
    end
    if stock("speed-module-3")<4 then
      feed_group("speed-module-3")
      feed_group("speed-module-2")
    end
  end
  if oil_first then
    for _,name in ipairs({"sulfur","chemical-science-pack","pumpjack","oil-refinery","chemical-plant",
                          "basic-oil-processing","advanced-oil-processing","engine-unit","steel-plate","plastic-bar","advanced-circuit"}) do
      feed_group(name)
    end
  end
  if finishing then
    for _,name in ipairs({"rocket-silo","satellite","cargo-landing-pad","electric-engine-unit","engine-unit","lubricant",
                          "utility-science-pack","chemical-science-pack","processing-unit","electronic-circuit",
                          "advanced-circuit","copper-cable"}) do
      feed_group(name)
    end
    if researched("rocket-silo") then
      feed_group("low-density-structure")
      feed_group("rocket-fuel")
    end
  end
  for j=1,#S.units do
    local unit=S.units[(S.feed_cursor+j-2)%#S.units+1]
    if not fed[unit.product] then feed_unit(unit) end
  end
  if #S.units>0 then S.feed_cursor=(S.feed_cursor+31)%#S.units+1 end
end

local function read_stats()
  local stats=force.get_item_production_statistics(surface)
  local list={
    "iron-ore","copper-ore","stone","coal","iron-plate","copper-plate","steel-plate","stone-brick","rail",
    "electronic-circuit","advanced-circuit","processing-unit","low-density-structure","rocket-fuel","solid-fuel",
    "electric-mining-drill","construction-robot","plastic-bar","electric-furnace","productivity-module",
    "electric-engine-unit","flying-robot-frame","lab","boiler","steam-engine","solar-panel","accumulator",
    "rocket-silo","satellite","cargo-landing-pad","inserter","transport-belt",
    "speed-module","speed-module-2","speed-module-3",
  }
  for _,i in ipairs(design.science) do list[#list+1]=i end
  local made,used={},{}
  for _,item in ipairs(list) do
    made[item],used[item]=stats.get_input_count(item),stats.get_output_count(item)
    if made[item]>0 then mark("first-"..item,made[item]) end
  end
  local liquids=force.get_fluid_production_statistics(surface)
  for _,item in ipairs({"crude-oil","petroleum-gas","light-oil","sulfuric-acid"}) do made[item]=liquids.get_input_count(item) end
  return made,used
end

local function sample_activity()
  if researched("rocket-silo") then return end
  S.activity=S.activity or {research_and_work=0,research_only=0,work_only=0,neither=0}
  local progress=force.research_progress
  local tech=force.current_research and force.current_research.name
  local researching=tech and progress>0 and (S.last_activity_tech~=tech or progress~=(S.last_activity_progress or 0))
  local working=S.work<5 or player and player.character and #(player.crafting_queue or {})>0
  local kind=researching and (working and "research_and_work" or "research_only") or (working and "work_only" or "neither")
  S.activity[kind]=S.activity[kind]+1
  S.last_activity_tech,S.last_activity_progress=tech,progress
end

function M.report()
  local made,used=read_stats()
  local active,generated,rated=0,0,0
  for _,g in pairs(S.engines) do
    generated=generated+g.energy_generated_last_tick*60/1000000
    rated=rated+.9
  end
  for _,lab in ipairs(S.labs) do
    if lab.status==defines.entity_status.working then active=active+1 end
  end
  local counts,states={},{}
  local labels={}
  for name,id in pairs(defines.entity_status) do labels[id]=name end
  for name,group in pairs(S.groups) do
    counts[name]=#group
    states[name]={}
    for _,u in ipairs(group) do
      local label=labels[u.entity.status] or "unknown"
      states[name][label]=(states[name][label] or 0)+1
    end
  end
  local science=S.pad and S.pad.get_item_count("space-science-pack") or 0
  local latest={
    seed=design.seed,base=script.active_mods.base,tick=game.tick-S.start,world_tick=game.tick,profile=S.profile,
    events=S.events,produced=made,consumed=used,warehouse=S.stock,launch_reserve=S.reserve,
    research=force.current_research and force.current_research.name,progress=force.research_progress,
    labs=#S.labs,active_labs=active,steam_mw=generated,steam_capacity_mw=rated,
    used_drills=S.used_drills,equipment=S.built,recipes=counts,status=states,cleared=S.cleared,
    hand_crafts=S.hand_orders,blocked_sites=S.dropped_sites,grade_technology=force.mining_drill_productivity_bonus,
    reassigned_drills=S.reassigned_drills,smelter_upgrades=S.smelter_upgrades,
    released_for_yellow=S.released_for_yellow,
    activity_seconds=S.activity,priority_craft=S.priority_craft,
    construction_sites=S.cursor-1,silo_modules=S.silo_modules,stone_modules=S.stone_modules,
    silo_parts=S.silo and S.silo.rocket_parts or 0,rockets=force.rockets_launched,
    satellites=force.get_item_launched("satellite"),space_science=science,error=S.error,
    current_build_requests=S.requests,
  }
  local text=helpers.table_to_json(latest)
  helpers.write_file("through-latest.json",text,false)
  helpers.write_file("through-stream.jsonl",text.."\n",true)
  return latest
end

function M.bind()
  S=storage.factory
  surface,force,player=game.surfaces.nauvis,game.forces.player,game.get_player(1)
  for i,bank in ipairs(design.power) do
    local p=bank.origin
    local inlet=surface.find_entity("pipe",{x=p[1]-1.5,y=p[2]+1.5})
    if inlet then S.water_inlets[i]=inlet end
  end
end

function M.start(old)
  storage.factory={
    start=old.start,events={},stock={},reserve={},scratch=game.create_inventory(32),
    old_outputs=old.outputs,burners={},coal_burners={},starter_coal=0,boilers={},engines={},pumps={},water_inlets={},oils={},
    units={},groups={},labs={},extraction={},mined={},used_drills={},poles={},built={},seen={},
    cursor=1,large_cursor=1,build_cursor=1,feed_cursor=1,lab_cursor=1,
    cleared=0,wood_cursor=1,hand_orders=0,dropped_sites=0,rated=0,profile=1,extra_boilers=0,
  }
  M.bind()
  S.power_order={}
  for i in ipairs(design.power) do S.power_order[#S.power_order+1]=i end
  local root=design.pole_root
  local function distance(p) return (p.x-root.x)^2+(p.y-root.y)^2 end
  table.sort(S.power_order,function(a,b)
    return distance(design.power[a].connection)<distance(design.power[b].connection)
  end)
  for _,e in ipairs(old.burners) do S.burners[#S.burners+1]=e end
  for _,e in ipairs(old.coal_mines) do S.coal_burners[#S.coal_burners+1]=e end
  for _,e in ipairs(old.boilers) do S.boilers[#S.boilers+1]={entity=e} end
  for _,e in ipairs(surface.find_entities_filtered{name="steam-engine",force=force}) do S.engines[e.unit_number]=e end
  S.trees=surface.find_entities_filtered{force="neutral",type="tree",area={{-128,-110},{163,139}}}
  table.sort(S.trees,function(a,b)
    return math.abs(a.position.x)+math.abs(a.position.y)<math.abs(b.position.x)+math.abs(b.position.y)
  end)
  player.character.walking_state={walking=false,direction=0}
  player.character.mining_state={mining=false}
  collect_player()
  mark("mass-route-handoff")
  M.report()
end

function M.tick()
  if not S then M.bind() end
  if S.error or S.events["delivery"] then return end
  local elapsed=game.tick-S.start
  if elapsed%15==0 then fluids() end
  if elapsed%30==0 then service() end
  if elapsed%60==0 and not S.events["ascent-ready"] then
    build()
    sample_activity()
  end
  if elapsed%3600==0 then M.report() end
  if S.pad and S.pad.get_item_count("space-science-pack")>=1000 and force.get_item_launched("satellite")==1 then
    mark("delivery",S.pad.get_item_count("space-science-pack"))
    M.report()
    game.speed=1
    if game.is_multiplayer() then game.server_save("mass-through-delivered") else game.auto_save("mass-through-delivered") end
  end
  if S.silo and S.pad and S.events["satellite-loaded"] and not S.events["ascent-ready"] then
    mark("ascent-ready",S.silo.rocket_parts)
    M.report()
    if not game.is_multiplayer() then game.auto_save("mass-through-ascent") end
  end
  if elapsed%(15*3600)==0 then
    local name="mass-through-minute-"..elapsed/3600
    if game.is_multiplayer() then game.server_save(name) else game.auto_save(name) end
  end
end

function M.failed(message)
  if not S then M.bind() end
  S.error=tostring(message)
  M.report()
  if game.is_multiplayer() then game.server_save("mass-through-diagnostic") else game.auto_save("mass-through-diagnostic") end
end
function M.researched(event)
  if S then mark("research-done-"..event.research.name) end
end
function M.launched(event)
  if S then mark("launch",event.rocket_silo and event.rocket_silo.position) end
end
function M.victory(event)
  if S and event.player_won then mark("victory") end
end

return M
