local M={}
local plan=require("supply")
local policy=require("policy")

local surface,force,actor,player,path_result,path_id
local stage,failure,task
local log,mark_ticks={},{}

local function position(x,y) return {x=x,y=y} end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
local function shifted(p,x,y) return position(p.x+x,p.y+y) end
local function amount(name) return actor.get_item_count(name) end
local function mark(name, extra)
  log[#log+1]={tick=game.tick, name=name, details=extra}
end

local function nearby(query, anchor)
  query.position, query.radius=anchor,query.radius or 145
  local results=surface.find_entities_filtered(query)
  table.sort(results,function(a,b)
    local left,right=distance(a.position,anchor),distance(b.position,anchor)
    if left==right then
      if a.position.x==b.position.x then return a.position.y<b.position.y end
      return a.position.x<b.position.x
    end
    return left<right
  end)
  return results
end

local function check(name,p,direction)
  if name~="character" and surface.find_entities_filtered{name=name,position=p,radius=0.1,limit=1}[1] then
    return false
  end
  return surface.can_place_entity{name=name,position=p,direction=direction or 0,force=force,
    build_check_type=defines.build_check_type.manual}
end

local function move_items(from,to,name,count)
  local n=math.min(count,from.get_item_count(name))
  if n>0 then
    local moved=to.insert{name=name,count=n}
    if moved>0 then assert(from.remove{name=name,count=moved}==moved) end
    return moved
  end
  return 0
end

local function research(name)
  local tech=force.technologies[name]
  if tech.researched then return end
  assert(force.add_research(name),"Could not queue "..name)
end

function M.path(event)
  if event.id==path_id then path_result=event.path or (event.try_again_later and "retry") or false end
end

function M.researched(event)
  if actor and event.research.force==force then
    local name=event.research.name
    if not mark_ticks[name] then
      mark_ticks[name]=game.tick
      mark("researched-"..name)
    end
  end
end

local queue, current = {}, nil
local function prepend(...)
  local tasks={...}
  for i=#tasks,1,-1 do table.insert(queue,1,tasks[i]) end
end

local function once(task)
  return function() task(); return true end
end

local function delay(ticks)
  local until_tick
  return function()
    until_tick=until_tick or game.tick+ticks
    return game.tick>=until_tick
  end
end

local function walk_to(goal,radius)
  local started, requested, index, attempt, target, acceptance, from
  local approaches={{0,0},{5,0},{0,5},{-5,0},{0,-5},{4,4},{-4,4},{4,-4},{-4,-4}}
  local function request()
    local offset=approaches[attempt]
    target=goal
    acceptance=radius
    if radius>7 and attempt>1 then
      target=surface.find_non_colliding_position("character",shifted(goal,offset[1],offset[2]),2,0.5)
        or shifted(goal,offset[1],offset[2])
      acceptance=1.5
    end
    path_result=nil
    requested=game.tick
    index=1
    path_id=surface.request_path{bounding_box=actor.prototype.collision_box,
      collision_mask=actor.prototype.collision_mask,start=actor.position,goal=target,force=force,
      radius=acceptance,entity_to_ignore=actor,pathfind_flags={prefer_straight_paths=true}}
  end
  return function()
    if distance(actor.position,goal)<=radius then
      actor.walking_state={walking=false,direction=0}
      return true
    end
    if not started then
      started,attempt,from=game.tick,1,actor.position
      request()
    end
    if path_result==false or path_result=="retry" or (not path_result and game.tick-requested>420)
        or game.tick-requested>2250 then
      if game.tick-requested<10 then return false end
      actor.walking_state={walking=false,direction=0}
      attempt=attempt+1
      assert(attempt<=#approaches and game.tick-started<5400,
        "No walkable route from "..from.x..","..from.y.." to "..goal.x..","..goal.y)
      request()
      return false
    end
    if not path_result then return false end
    if path_result[index] and distance(actor.position,path_result[index].position)<0.45 then index=index+1 end
    local point=path_result[index] and path_result[index].position or target
    local angle=math.atan2(point.x-actor.position.x,actor.position.y-point.y)
    actor.walking_state={walking=true,direction=(math.floor(angle/(math.pi/4)+0.5)*2)%16}
    return false
  end
end

local function mine_to(item,goal)
  return once(function()
    if amount(item)>=goal then return end
    local query=item=="wood" and {type="tree",radius=145} or {name=item,radius=145}
    local node=assert(nearby(query,actor.position)[1],"Resource unavailable: "..item)
    prepend(walk_to(node.position,2),function()
      if not node.valid or amount(item)>=goal then
        actor.mining_state={mining=false}
        return true
      end
      actor.selected=node
      actor.mining_state={mining=true,position=node.position}
      return false
    end,mine_to(item,goal))
  end)
end

local function secure_first_fuel()
  return once(function()
    local rock=nearby({name="huge-rock",radius=48},actor.position)[1]
    if rock then
      local at=rock.position
      prepend(walk_to(at,2),function()
        if not rock.valid then
          actor.mining_state={mining=false}
          mark("mined-coal-rock",{position=at,coal=amount("coal"),stone=amount("stone")})
          return true
        end
        actor.selected=rock
        actor.mining_state={mining=true,position=at}
        return false
      end)
    end
  end)
end

local function produce(item,wanted)
  local stalled=0
  return function()
    task="craft "..item.." x"..wanted
    if amount(item)>=wanted then return true end
    local crafter=player or actor
    if game.tick%60==0 and #(crafter.crafting_queue or {})==0 then
      local began=crafter.begin_crafting{recipe=item,count=wanted-amount(item)}
      stalled=began>0 and 0 or stalled+1
      assert(stalled<120, "Missing materials or technology for "..item)
    end
    return false
  end
end

local function build(item,p,direction,register)
  return once(function()
    task="build "..item.." at "..p.x..","..p.y
    local function put()
      assert(check(item,p,direction),"Placement blocked: "..item.." "..p.x..","..p.y)
      assert(actor.remove_item{name=item,count=1}==1,"Missing item: "..item)
      local e=assert(surface.create_entity{name=item,position=p,direction=direction or 0,force=force,raise_built=true})
      if register then register(e) end
    end
    prepend(walk_to(p,math.min(actor.build_distance-0.1,9.8)),once(function()
      local box=prototypes.entity[item].collision_box
      local clearance=math.max(-box.left_top.x,-box.left_top.y,box.right_bottom.x,box.right_bottom.y)+0.5
      if distance(actor.position,p)>clearance and check(item,p,direction) then put(); return end
      for _, delta in ipairs({{4,0},{-4,0},{0,4},{0,-4}}) do
        local side=shifted(p,delta[1],delta[2])
        if check("character",side) then
          prepend(walk_to(side,0.7),once(put))
          return
        end
      end
      error("Could not clear building footprint: "..item)
    end),delay(12))
  end)
end

local function produce_science_before_automation()
  local remaining=10
  return function()
    local crafter=player or actor
    if game.tick%60==0 and #(crafter.crafting_queue or {})==0 then
      if remaining<=0 then return true end
      remaining=remaining-crafter.begin_crafting{recipe="automation-science-pack",count=remaining}
    end
    return false
  end
end

local function research_queue(...)
  local techs={...}
  return once(function() for _,name in ipairs(techs) do research(name) end end)
end

local function tech_ready(name)
  return function()
    task="research "..name
    return force.technologies[name].researched
  end
end



local coal_mines,fuelers,outputs={},{},{}
local constructed,stages_done={},{}
local supplies,lab_inputs={},{}
local boilers={}
local first_events,native_received,checkpoints={},{},{}
local installed,blocks={},{ }
local hand_red=true
local start_tick
local science_items={"automation-science-pack","logistic-science-pack"}
local tracked={"iron-plate","copper-plate","coal","stone","electric-mining-drill","transport-belt","inserter",
  "iron-gear-wheel","electronic-circuit","automation-science-pack","logistic-science-pack","steel-plate"}

local function track(entity,material,inventory,real_belt,key)
  outputs[#outputs+1]={e=entity,item=material,inventory=inventory,native=real_belt,block=key}
end

local function load(inv,name,wanted,reserve)
  return move_items(actor.get_main_inventory(),inv,name,math.min(wanted,math.max(0,amount(name)-(reserve or 0))))
end

local function set_stage(name)
  return once(function() stage=name; mark(name) end)
end

local function built(stage_name)
  return once(function() stages_done[stage_name]=game.tick; mark("placed-"..stage_name) end)
end

local function expect(test,label,timeout)
  local since
  return function()
    task=label
    since=since or game.tick
    assert(game.tick-since<(timeout or 54000),"Timed out: "..label)
    return test()
  end
end

local pending_robot_recipes={}

local function element(spec,register)
  return once(function()
    local e=surface.find_entity(spec.name,spec.position)
    if e and distance(e.position,spec.position)<.05 then
      if register then register(e,spec) end
      return
    end
    prepend(produce(spec.name,1),build(spec.name,spec.position,spec.direction or 0,function(placed)
      if spec.recipe then
        if spec.defer_recipe and not force.recipes[spec.recipe].enabled then
          pending_robot_recipes[#pending_robot_recipes+1]={entity=placed,name=spec.recipe}
        else
          placed.set_recipe(spec.recipe)
          assert(placed.get_recipe().name==spec.recipe)
        end
      end
      constructed[#constructed+1]={name=placed.name,position=placed.position,tick=game.tick}
      if register then register(placed,spec) end
    end))
  end)
end

local function group(entities,register)
  return once(function()
    local list={}
    for _,spec in ipairs(entities) do list[#list+1]=element(spec,register) end
    prepend(table.unpack(list))
  end)
end

local function burner(kind,index)
  local s=plan.burners[kind][index]
  local metal=s.target=="stone-furnace"
  local output=kind
  if metal then output=kind=="iron-ore" and "iron-plate" or "copper-plate" end
  return once(function()
    prepend(element({name=s.target,position=s.out},function(e)
      if metal then fuelers[#fuelers+1]=e end
      track(e,output,metal and defines.inventory.crafter_output or defines.inventory.chest)
    end),element({name="burner-mining-drill",position=s.drill,direction=s.direction},function(e)
      local allocation=kind=="coal" and coal_mines or fuelers
      allocation[#allocation+1]=e
      mark("burner-"..kind,{position=e.position,target=s.out})
    end))
  end)
end



local function first(name,value)
  if not first_events[name] then
    first_events[name]=game.tick
    mark(name,value)
  end
end

local function fuel(entity,target)
  local inv=entity.get_inventory(defines.inventory.fuel)
  local held=inv.get_item_count("coal")
  if held<target-1 then load(inv,"coal",target-held) end
end

local limits={
  ["iron-plate"]={12,42},["copper-plate"]={10,18},["iron-gear-wheel"]={8,5},
  ["copper-cable"]={18,0},["electronic-circuit"]={8,4},
  ["transport-belt"]={8,8},inserter={8,6}
}
local local_stock={
  ["iron-plate"]=700,["copper-plate"]=450,coal=350,stone=200,["iron-gear-wheel"]=72,
  ["copper-cable"]=100,["electronic-circuit"]=96,["transport-belt"]=80,inserter=60,
  ["electric-mining-drill"]=20
}
local supply_priority={R0=1,R1=1,M1=2,M2=2,M3=2,M5=3,M4=3,G0=4,G1=4,M6=5}

local function fill_supplies()
  for _,box in ipairs(supplies) do
    if not box.product or amount(box.product)<local_stock[box.product] then
      for _,item in ipairs(box.items) do
        local rule=limits[item]
        local target=box.priority==1 and 6 or rule[1]
        local remaining=target-box.inv.get_item_count(item)
        local reserve=rule[2]
        if box.station=="S1" and not force.technologies["oil-gathering"].researched then
          reserve=100
        end
        if remaining>0 then load(box.inv,item,remaining,reserve) end
      end
    end
  end
end

local function service()
  for _,source in ipairs(outputs) do
    local capacity=local_stock[source.item]
    local request=capacity and math.min(100,math.max(0,capacity-amount(source.item))) or 100
    local inv=source.e.get_inventory(source.inventory)
    local ready=inv.get_item_count(source.item)>0
    local moved=move_items(inv,actor.get_main_inventory(),source.item,request)
    if source.native and ready then
      first("first-belt-"..source.item,source.block)
      first("first-output-"..source.block,source.item)
    end
    if moved>0 and source.native then
      native_received[source.item]=(native_received[source.item] or 0)+moved
      blocks[source.block].received=(blocks[source.block].received or 0)+moved
    end
  end
  for _,plant in ipairs(boilers) do fuel(plant,14) end
  for _,unit in ipairs(coal_mines) do fuel(unit,5) end
  for _,unit in ipairs(fuelers) do fuel(unit,3) end
  if hand_red and force.current_research then
    for _,inv in ipairs(lab_inputs) do
      local held=inv.get_item_count(science_items[1])
      if held<2 then load(inv,science_items[1],4-held) end
    end
  end
  fill_supplies()
  local stats=force.get_item_production_statistics(surface)
  for _,event in ipairs({{"green-produced",stats.get_input_count(science_items[2])},
                         {"green-consumed",stats.get_output_count(science_items[2])}}) do
    if event[2]>0 then first(event[1],event[2]) end
  end
end

local function selected(spec)
  local e=surface.find_entity(spec.name,spec.position)
  return e and distance(e.position,spec.position)<.05
end

local function batch_order(...)
  local parts={...}
  return once(function()
    local needs,names={},{}
    for _,part in ipairs(parts) do
      for _,spec in ipairs(part) do
        if not selected(spec) then
          if not needs[spec.name] then needs[spec.name]=0; names[#names+1]=spec.name end
          needs[spec.name]=needs[spec.name]+1
        end
      end
    end
    if #(player.crafting_queue or {})>0 then return end
    local batch_yields={["small-electric-pole"]=2,["transport-belt"]=2}
    for _,name in ipairs(names) do
      local missing=needs[name]-amount(name)
      if missing>0 then
        player.begin_crafting{recipe=name,count=math.ceil(missing/(batch_yields[name] or 1))}
      end
    end
  end)
end

local function register(e)
  if e.name=="boiler" then boilers[#boilers+1]=e end
  if e.name=="stone-furnace" then fuelers[#fuelers+1]=e end
end

local function wood_for(block)
  local poles,chests=0,0
  for _,part in ipairs({block.power,block.entities}) do
    for _,spec in ipairs(part) do
      if not selected(spec) then
        if spec.name=="small-electric-pole" then poles=poles+1 end
        if spec.name=="wooden-chest" then chests=chests+1 end
      end
    end
  end
  local needed=2*math.max(0,chests-amount("wooden-chest"))
    +math.ceil(math.max(0,poles-amount("small-electric-pole"))/2)
  return mine_to("wood",needed)
end

local function station(key, prerequisite)
  local b=assert(plan.blocks[key],key)
  return once(function()
    if installed[key] then return end
    blocks[key]={received=0,started=game.tick}
    mark("start-"..key)
    local function opened()
      installed[key]=true
      blocks[key].complete=game.tick
      for _,source in ipairs(b.outputs) do
        local chest=assert(surface.find_entity("wooden-chest",source.position))
        track(chest,source.item,defines.inventory.chest,source.belt,key)
      end
      local product=b.stock_product or (key:sub(1,1)=="M" and b.outputs[1].item or nil)
      for _,source in ipairs(b.supplies) do
        local chest=assert(surface.find_entity("wooden-chest",source.position))
        supplies[#supplies+1]={inv=chest.get_inventory(defines.inventory.chest),items=source.items,
          product=product,station=key,priority=supply_priority[key] or 6}
      end
      table.sort(supplies,function(a,b) return a.priority<b.priority end)
    end
    prepend(prerequisite and tech_ready(prerequisite) or once(function() end),
      wood_for(b),batch_order(b.power,b.entities),group(b.power),group(b.entities,register),
      once(opened),built(key))
  end)
end

local function counts()
  local produced,consumed={},{}
  local stats=force.get_item_production_statistics(surface)
  for _,name in ipairs(tracked) do
    produced[name]=stats.get_input_count(name)
    consumed[name]=stats.get_output_count(name)
  end
  return produced,consumed
end

local function sample_assemblers()
  local machines={}
  for _,e in ipairs(surface.find_entities_filtered{name="assembling-machine-1",force=force}) do
    local recipe=e.get_recipe()
    if recipe then
      machines[#machines+1]={position=e.position,recipe=recipe.name,status=e.status,
        ingredients=e.get_inventory(defines.inventory.crafter_input).get_contents(),
        product=e.get_inventory(defines.inventory.crafter_output).get_contents()}
    end
  end
  return machines
end

local process_stats,active_process
local robot_active,robot_stats
local scale_active,scale_stats
local function report(checkpoint)
  local produced,consumed=counts()
  local status,science,by_site={},{},{}
  local belt_arrivals={}
  for name,moved in pairs(native_received) do belt_arrivals[name]=moved end
  for _,source in ipairs(outputs) do
    if source.native then
      belt_arrivals[source.item]=(belt_arrivals[source.item] or 0)
        +source.e.get_inventory(source.inventory).get_item_count(source.item)
    end
  end
  for _,e in ipairs(surface.find_entities_filtered{force=force}) do
    local row=status[e.name] or {placed=0,connected=0,working=0}
    status[e.name]=row
    row.placed=row.placed+1
    local powered=e.is_connected_to_electric_network()
    if powered then row.connected=row.connected+1 end
    if e.status==defines.entity_status.working then row.working=row.working+1 end
    if e.name=="lab" then
      local inv=e.get_inventory(defines.inventory.lab_input)
      science[#science+1]={position=e.position,red=inv.get_item_count(science_items[1]),
        green=inv.get_item_count(science_items[2]),powered=powered,status=e.status}
    end
  end
  for key, block in pairs(blocks) do
    if block.complete then
      local observed={drills=0,working_drills=0,furnaces=0,working_furnaces=0}
      for _,spec in ipairs(plan.blocks[key].entities) do
        if spec.name=="stone-furnace" or spec.name=="electric-mining-drill" then
          local e=surface.find_entity(spec.name,spec.position)
          if e and spec.name=="stone-furnace" then
            observed.furnaces=observed.furnaces+1
            if e.status==defines.entity_status.working then observed.working_furnaces=observed.working_furnaces+1 end
          elseif e then
            observed.drills=observed.drills+1
            if e.status==defines.entity_status.working then observed.working_drills=observed.working_drills+1 end
          end
        end
      end
      if observed.drills>0 then by_site[key]=observed end
    end
  end
  local snapshot={tick=game.tick,start_tick=start_tick,elapsed_ticks=game.tick-start_tick,
    stage=stage,task=task,error=failure,produced=produced,consumed=consumed,
    native_received=native_received,belt_arrivals=belt_arrivals,science=science,by_site=by_site,status=status,
    milestones=log,stages_done=stages_done,blocks=blocks,player=actor.position,
    inventory=actor.get_main_inventory().get_contents(),queue_remaining=#queue,
    version=script.active_mods.base,seed=plan.seed,profile=plan.profile,order=policy.order,
    technologies={},power={}}
  for _,plant in ipairs(boilers) do
    snapshot.power[#snapshot.power+1]={position=plant.position,water=plant.get_fluid_count("water"),
                                      steam=plant.get_fluid_count("steam")}
  end
  for name in pairs(mark_ticks) do snapshot.technologies[#snapshot.technologies+1]=name end
  table.sort(snapshot.technologies)
  if force.current_research then
    snapshot.research=force.current_research.name
    snapshot.research_progress=force.research_progress
  end
  if active_process then snapshot.process=process_stats() end
  if checkpoint then
    local received={}
    for item,quantity in pairs(native_received) do received[item]=quantity end
    checkpoints[#checkpoints+1]={elapsed_ticks=snapshot.elapsed_ticks,produced=produced,consumed=consumed,
      by_site=by_site,native_received=received,belt_arrivals=belt_arrivals,status=status,stage=stage,task=task,
      research=snapshot.research,power=snapshot.power,assemblers=sample_assemblers(),
      carried={iron=amount("iron-plate"),copper=amount("copper-plate"),gear=amount("iron-gear-wheel")}}
  end
  if active_process and checkpoint then checkpoints[#checkpoints].process=snapshot.process end
  if robot_active then
    snapshot.robot=robot_stats()
    if checkpoint then
      local data=snapshot.robot
      local samples={total=data.samples.total,producing=data.samples.producing,
        power_wait=data.samples.power_wait,material_wait=data.samples.material_wait}
      checkpoints[#checkpoints].robot={liquids=data.liquids,tanks=data.tanks,holdings=data.holdings,
        units=data.units,samples=samples}
    end
  end
  if scale_active then
    snapshot.scale=scale_stats()
    if checkpoint then
      local data=snapshot.scale
      checkpoints[#checkpoints].scale={samples=data.samples,dedicated=data.dedicated,steam=data.steam,
        drills=data.drills,coal=data.coal,iron=data.iron,steel=data.steel,furnaces=data.furnaces}
    end
  end
  snapshot.checkpoints=checkpoints
  helpers.write_file("supply-trial.json",helpers.table_to_json(snapshot),false)
end

local process_sites=require("process-sites")
active_process=false
local process_units={labs={}}
local process_pending={}
local status_names={}
for name,value in pairs(defines.entity_status) do status_names[value]=name end
local probes,checked={},{}
local power_observations={samples=0,interrupted=0}

local function watch_process()
  for _,p in ipairs(process_sites.refineries) do
    local e=surface.find_entity("oil-refinery",p)
    if e and e.get_fluid_count("crude-oil")>0 then first("first-crude-at-refinery",p) end
  end
  for _,entry in ipairs(process_pending) do
    if not entry.done and force.technologies[entry.tech].researched then
      assert(entry.entity.set_recipe(entry.recipe),entry.recipe)
      entry.done=true
      mark("recipe-on-"..entry.recipe,entry.entity.position)
    end
  end
  local items=force.get_item_production_statistics(surface)
  local fluids=force.get_fluid_production_statistics(surface)
  for _,name in ipairs({"steel-plate","stone-brick","engine-unit","plastic-bar","sulfur",
                        "advanced-circuit","chemical-science-pack"}) do
    local count=items.get_input_count(name)
    if count>0 then first("first-produced-"..name,count) end
  end
  for _,name in ipairs({"crude-oil","petroleum-gas"}) do
    local count=fluids.get_input_count(name)
    if count>0 then first("first-produced-"..name,count) end
  end
  for _,lab in ipairs(process_units.labs) do
    if lab.get_inventory(defines.inventory.lab_input).get_item_count("chemical-science-pack")>0 then
      first("first-blue-at-lab",lab.position)
      break
    end
  end
  local used=items.get_output_count("chemical-science-pack")
  if used>0 then first("first-blue-consumed",used) end
  for _,key in ipairs({"NR0","NG0","T3","D1","B1","B2","E2"}) do
    if installed[key] and not checked[key] then
      checked[key]=true
      for _,spec in ipairs(plan.blocks[key].entities) do
        if spec.name=="assembling-machine-2" then
          probes[#probes+1]=assert(surface.find_entity(spec.name,spec.position))
          break
        end
      end
    end
  end
  if #probes>0 then
    power_observations.samples=power_observations.samples+1
    for _,e in ipairs(probes) do
      if e.status==defines.entity_status.low_power or e.status==defines.entity_status.no_power then
        power_observations.interrupted=power_observations.interrupted+1
        break
      end
    end
  end
end

process_stats=function()
  local fluids=force.get_fluid_production_statistics(surface)
  local result={liquid={},stock={},machines={},power_generators=0,
                policy={preparation=policy.prep,iron=policy.iron,tail=policy.tail},
                power_samples={samples=power_observations.samples,interrupted=power_observations.interrupted}}
  for _,name in ipairs({"crude-oil","petroleum-gas","water"}) do
    result.liquid[name]={made=fluids.get_input_count(name),used=fluids.get_output_count(name)}
  end
  for _,name in ipairs({"steel-plate","stone-brick","coal","iron-gear-wheel","copper-cable","electronic-circuit",
                       "plastic-bar","sulfur","engine-unit","advanced-circuit"}) do
    result.stock[name]=amount(name)
  end
  for _,e in ipairs(surface.find_entities_filtered{type={"assembling-machine","furnace","mining-drill","lab","generator"},force=force}) do
    local recipe=(e.type=="assembling-machine" or e.type=="furnace") and e.get_recipe()
    local name=recipe and recipe.name or e.name
    local row=result.machines[name] or {count=0,states={}}
    row.count=row.count+1
    local state=status_names[e.status] or tostring(e.status)
    row.states[state]=(row.states[state] or 0)+1
    result.machines[name]=row
    if e.type=="generator" and e.is_connected_to_electric_network() then
      result.power_generators=result.power_generators+1
    end
  end
  return result
end

local function register_chemistry()
  for _,entry in ipairs(plan.blocks.O1.pending) do
    process_pending[#process_pending+1]={entity=assert(surface.find_entity("chemical-plant",entry.position)),
                                       recipe=entry.recipe,tech=entry.tech}
  end
end

local function register_labs()
  for _,key in ipairs({"NL0","NL1","NL2","NL3"}) do
    for _,e in ipairs(plan.blocks[key].entities) do
      if e.name=="lab" and installed[key] then
        process_units.labs[#process_units.labs+1]=assert(surface.find_entity("lab",e.position))
      end
    end
  end
end

local function wire_field()
  local block=plan.blocks.O0
  local poles={}
  for _,spec in ipairs(block.entities) do
    if spec.name=="small-electric-pole" then poles[#poles+1]=spec end
  end
  return once(function()
    prepend(wood_for({power=block.power,entities=poles}),batch_order(block.power,poles),
      group(block.power),group(poles),built("oil-power"))
  end)
end

local function allocate_iron()
  if policy.iron=="original" then return end
  local_stock["iron-gear-wheel"]=72
  local_stock["steel-plate"]=95
  limits["steel-plate"]={8,16}
  local priorities={
    M1=2,M2=2,M3=2,T1=2,T2=2,T3=2,
    M4=3,M5=3,T4=3,T5=3,
    G0=4,G1=4,NG0=4,NG1=4,T6=4,
    S1=5,S2=5,S3=5,E1=5,E2=5,
    D1=6,D2=6,B1=7,B2=7
  }
  for key,value in pairs(priorities) do supply_priority[key]=value end
  for _,box in ipairs(supplies) do box.priority=supply_priority[box.station] or 6 end
  table.sort(supplies,function(a,b) return a.priority<b.priority end)
  mark("iron-priority")
end

local function limit_chemistry_storage()
  for _,spec in ipairs(plan.blocks.O1.outputs) do
    local box=assert(surface.find_entity("wooden-chest",spec.position))
    box.get_inventory(defines.inventory.chest).set_bar(2)
  end
  mark("chemical-box-limits")
end

local function start_process()
  active_process=true
  for key,b in pairs(process_sites.blocks) do plan.blocks[key]=b end
  for key,value in pairs({
    ["steel-plate"]={10,28},["stone"]={18,12},["coal"]={24,50},
    ["pipe"]={16,14},["copper-cable"]={22,0},["iron-plate"]={25,45},
    ["advanced-circuit"]={9,0},["engine-unit"]={10,0},["plastic-bar"]={14,0},["sulfur"]={10,0}
  }) do limits[key]=value end
  for key,value in pairs({
    ["steel-plate"]=70,["stone-brick"]=80,["pipe"]=200,["plastic-bar"]=180,
    ["sulfur"]=120,["engine-unit"]=160,["advanced-circuit"]=180,
    ["copper-cable"]=220,["electronic-circuit"]=170,["iron-gear-wheel"]=140,["coal"]=450,
    ["transport-belt"]=140,["inserter"]=95
  }) do local_stock[key]=value end
  for _,name in ipairs({"stone-brick","pipe","engine-unit","plastic-bar","sulfur",
                        "advanced-circuit","chemical-science-pack"}) do tracked[#tracked+1]=name end
  for _,key in ipairs({"NR0","NR1"}) do supply_priority[key]=1 end
  for _,key in ipairs({"S2","S3","T1","T2","T3","T4","T5","T6"}) do supply_priority[key]=2 end
  for _,key in ipairs({"NG0","NG1"}) do supply_priority[key]=4 end
  local extend={}
  local function add(...)
    for _,action in ipairs({...}) do extend[#extend+1]=action end
  end
  add(set_stage("process-preparation"))
  if policy.prep=="wait" then add(tech_ready("oil-gathering")) end
  add(station("PW3"),station("S1"),station("S2"))
  if policy.prep=="parallel" then
    add(station("PW4"),station("NL0"),station("NR0"),station("NG0"),station("NL1"),station("NL2"))
  end
  add(wire_field())
  if policy.prep~="wait" then add(tech_ready("oil-gathering")) end
  add(once(function() local_stock["steel-plate"]=160 end),
      set_stage("first-oil"),station("O0"),tech_ready("oil-processing"),
      research_queue("plastics","advanced-circuit","sulfur-processing",
                     "chemical-science-pack","advanced-oil-processing"),
      station("F0"),station("O1"),once(register_chemistry),once(allocate_iron),station("PW4"))
  if policy.iron=="expanded" then add(station("X1"),station("K3")) end
  add(set_stage("research-and-parts"),station("T1"),station("T2"),
      station("T3"),station("T4"),station("T5"),station("T6"),station("E1","engine"),
      station("NL0"),station("NR0"),station("NG0"),station("NR1"),station("NG1"),
      station("NL1"),station("NL2"),station("NL3"),once(register_labs))
  if policy.iron=="expanded" then add(station("PW5"),station("X2"),station("X3"),station("PW6")) end
  add(station("D1","advanced-circuit"),station("B0"),
      set_stage("blue-supply"),tech_ready("chemical-science-pack"),
      research_queue("lubricant","electric-engine","battery","robotics","construction-robotics"),station("B1"),
      walk_to(shifted(process_sites.research_origin,18,-14),3),
      walk_to(shifted(process_sites.research_origin,-14,-15),5),
      station("S3"),station("E2"),station("D2","advanced-circuit"),station("B2","chemical-science-pack"))
  if policy.tail~="baseline" then add(once(limit_chemistry_storage)) end
  if policy.tail=="power" then
    add(walk_to(shifted(process_sites.research_origin,37,-14),3),
        walk_to(shifted(process_sites.research_origin,-14,-15),5),station("K4"),station("PW7"))
  end
  add(set_stage("blue-flow-observation"))
  assert(not current and #queue==0,"Opening route still has queued tasks")
  prepend(table.unpack(extend))
end

local robot_sites=require("robot-sites")
local robot_items={"electric-engine-unit","battery","flying-robot-frame","construction-robot"}
local robot_fluids={"crude-oil","petroleum-gas","heavy-oil","light-oil","lubricant","sulfuric-acid"}
local robot_wave={expected={},built={},staged=0,loaded=0,delivered=0,count=0}
local robot_worksamples={total=0,blue={}}
local blue_intake={}
local port

local function robot_entity(name,position)
  return surface.find_entity(name,position)
end

local function ghost_key(name,position)
  return ("%s:%.1f:%.1f"):format(name,position.x,position.y)
end

function M.robot_built(event)
  if not robot_active then return end
  local entity=event.entity
  local key=ghost_key(entity.name,entity.position)
  if blue_intake.requested and key==ghost_key("inserter",robot_sites.blue_intake.position) then
    blue_intake.built=game.tick
    mark("robot-built-blue-intake",entity.position)
  end
  if not robot_wave.expected[key] or robot_wave.built[key] then return end
  robot_wave.built[key]=game.tick
  robot_wave.count=robot_wave.count+1
  first("first-robot-built",entity.name)
  if robot_wave.count==#plan.blocks.RW.entities then
    mark("robot-wave-built",robot_wave.count)
  end
end

local function robot_dispatch()
  if not port or not robot_wave.issued or robot_wave.loaded>=4 or not player.can_reach_entity(port) then
    return
  end
  local inv=port.get_inventory(defines.inventory.roboport_robot)
  local moved=load(inv,"construction-robot",4-robot_wave.loaded)
  if moved>0 then
    robot_wave.loaded=robot_wave.loaded+moved
    first("first-robot-loaded",moved)
  end
end

local function watch_robot()
  for i=#pending_robot_recipes,1,-1 do
    local entry=pending_robot_recipes[i]
    if force.recipes[entry.name].enabled then
      assert(entry.entity.set_recipe(entry.name),entry.name)
      mark("recipe-on-"..entry.name,entry.entity.position)
      table.remove(pending_robot_recipes,i)
    end
  end
  local items=force.get_item_production_statistics(surface)
  local fluid=force.get_fluid_production_statistics(surface)
  for _,name in ipairs(robot_items) do
    local made=items.get_input_count(name)
    if made>0 then first("first-produced-"..name,made) end
  end
  for _,name in ipairs({"heavy-oil","light-oil","lubricant","sulfuric-acid"}) do
    local made=fluid.get_input_count(name)
    if made>0 then first("first-produced-"..name,made) end
  end
  robot_dispatch()
  if blue_intake.built and not blue_intake.received then
    local lab=assert(robot_entity("lab",robot_sites.blue_intake.lab))
    local count=lab.get_inventory(defines.inventory.lab_input).get_item_count("chemical-science-pack")
    if count>0 then
      blue_intake.received=game.tick
      mark("first-blue-at-leading-lab",count)
    end
  end
  robot_worksamples.total=robot_worksamples.total+1
  local producing,power_wait,material_wait=0,0,0
  for _,key in ipairs({"B1","B2"}) do
    for _,spec in ipairs(plan.blocks[key].entities) do
      if spec.name=="assembling-machine-2" then
        local e=assert(robot_entity(spec.name,spec.position))
        local state=status_names[e.status]
        if state=="working" then producing=producing+1 end
        if state=="low_power" or state=="no_power" then power_wait=power_wait+1 end
        if state=="no_ingredients" or state=="item_ingredient_shortage" then material_wait=material_wait+1 end
        robot_worksamples.blue[state]=(robot_worksamples.blue[state] or 0)+1
      end
    end
  end
  if producing>0 then robot_worksamples.producing=(robot_worksamples.producing or 0)+1 end
  if power_wait>0 then robot_worksamples.power_wait=(robot_worksamples.power_wait or 0)+1 end
  if material_wait>0 then robot_worksamples.material_wait=(robot_worksamples.material_wait or 0)+1 end
end

robot_stats=function()
  local stats=force.get_fluid_production_statistics(surface)
  local result={order=policy.robot,liquids={},tanks={},holdings={},units={},
    wave=robot_wave,samples=robot_worksamples,blue_intake=blue_intake}
  for _,name in ipairs(robot_fluids) do
    result.liquids[name]={made=stats.get_input_count(name),used=stats.get_output_count(name)}
  end
  for _,tank in ipairs({{"light-oil",robot_sites.light_tank},{"lubricant",robot_sites.lube_tank}}) do
    local e=robot_entity("storage-tank",tank[2])
    if e then result.tanks[tank[1]]=e.get_fluid_count(tank[1]) end
  end
  for _,name in ipairs({"electronic-circuit","advanced-circuit","iron-gear-wheel","steel-plate",
    "battery","electric-engine-unit","flying-robot-frame","construction-robot","coal"}) do
    result.holdings[name]=amount(name)
  end
  for _,key in ipairs({"A0","LB","AC","BA","RE1","RE2","FR","RA","RH"}) do
    if installed[key] then
      local units={}
      for _,spec in ipairs(plan.blocks[key].entities) do
        if spec.recipe or spec.name=="roboport" then
          local e=assert(robot_entity(spec.name,spec.position))
          units[#units+1]={state=status_names[e.status],connected=e.is_connected_to_electric_network(),
            energy=e.energy,finished=spec.recipe and e.products_finished or nil}
        end
      end
      result.units[key]=units
    end
  end
  return result
end

local function fix_first_blue_intake()
  local spec=plan.blocks.BI.entities[1]
  return once(function()
    local lab=assert(robot_entity("lab",robot_sites.blue_intake.lab))
    local lab_inv=lab.get_inventory(defines.inventory.lab_input)
    assert(lab_inv.get_item_count("chemical-science-pack")==0,"Leading lab already has blue")
    local provider=assert(robot_entity("passive-provider-chest",robot_sites.robot.provider))
    assert(player.can_reach_entity(provider),"Reach the construction supply chest")
    assert(load(provider.get_inventory(defines.inventory.chest),"inserter",1)==1)
    assert(surface.create_entity{name="entity-ghost",inner_name=spec.name,position=spec.position,
      direction=spec.direction or 0,force=force,expires=false,raise_built=true},"Blue intake ghost")
    blue_intake.requested=game.tick
    mark("issued-blue-intake-ghost",spec.position)
  end)
end

local function wave_orders()
  local b=plan.blocks.RW
  local at=robot_sites.robot
  local required={}
  for _,spec in ipairs(b.entities) do required[spec.name]=(required[spec.name] or 0)+1 end
  local provider,receiver
  local staged=once(function()
    port=assert(robot_entity("roboport",at.port))
    assert(port.is_connected_to_electric_network() and player.can_reach_entity(port),"Reach a powered roboport")
    provider=assert(robot_entity("passive-provider-chest",at.provider)).get_inventory(defines.inventory.chest)
    for name,n in pairs(required) do
      assert(load(provider,name,n)==n,"Provider has no "..name)
      robot_wave.staged=robot_wave.staged+n
    end
    for _,spec in ipairs(b.entities) do
      assert(not selected(spec),"Robot target already built")
      local ghost=assert(surface.create_entity{name="entity-ghost",inner_name=spec.name,position=spec.position,
        direction=spec.direction or 0,force=force,expires=false,raise_built=true},"Ghost "..spec.name)
      assert(ghost.valid and ghost.ghost_name==spec.name)
      robot_wave.expected[ghost_key(spec.name,spec.position)]=true
    end
    robot_wave.issued=game.tick
    mark("robot-ghosts-issued",#b.entities)
  end)
  local feed=once(function()
    local send=assert(robot_entity("wooden-chest",at.send)).get_inventory(defines.inventory.chest)
    receiver=assert(robot_entity("wooden-chest",at.receive)).get_inventory(defines.inventory.chest)
    assert(receiver.get_item_count("iron-plate")==0)
    assert(load(send,"iron-plate",24)==24,"No test feed")
    robot_wave.feed_tick=game.tick
  end)
  return once(function()
    prepend(wood_for(b),batch_order(b.power,b.entities),group(b.power),
      produce("wooden-chest",required["wooden-chest"]),
      produce("small-electric-pole",required["small-electric-pole"]),
      produce("inserter",required.inserter),produce("transport-belt",required["transport-belt"]),
      walk_to(at.place_from,2),staged,
      expect(function() return robot_wave.count==#b.entities end,"native construction wave",54000),
      feed,expect(function()
        robot_wave.delivered=receiver.get_item_count("iron-plate")
        return robot_wave.delivered==24
      end,"24 plates through the robot-built belt",7200),
      once(function() mark("robot-belt-delivered-24",robot_wave.delivered) end))
  end)
end

local function start_robot()
  robot_active=true
  assert(not current and #queue==0,"Previous stage still running")
  for _,name in ipairs(robot_items) do tracked[#tracked+1]=name end
  local research_more=research_queue("advanced-material-processing","advanced-material-processing-2",
    "modules","productivity-module","logistics-2")
  if policy.robot=="observe" then
    prepend(set_stage("robot-control-observation"),research_more)
    return
  end
  for key,b in pairs(robot_sites.blocks) do
    plan.blocks[key]=b
    for _,spec in ipairs(b.entities) do
      if spec.recipe then spec.defer_recipe=true end
    end
  end
  for item,n in pairs({["electric-engine-unit"]=35,battery=65,["flying-robot-frame"]=24,
                      ["construction-robot"]=16}) do local_stock[item]=n end
  for item,rule in pairs({["electric-engine-unit"]={4,0},battery={8,0},["flying-robot-frame"]={5,0}}) do
    limits[item]=rule
  end
  local fluid={set_stage("robot-oil-and-materials"),station("A0"),station("AL"),station("LB"),
    station("LL"),station("RE1"),station("AC"),station("BA")}
  local hub=plan.blocks.RH
  local hub_poles={}
  for _,spec in ipairs(hub.entities) do
    if spec.name=="small-electric-pole" then hub_poles[#hub_poles+1]=spec end
  end
  local center={set_stage("robot-frame-and-port"),station("FR"),station("RA"),
    wood_for({power=hub.power,entities=hub_poles}),batch_order(hub.power,hub_poles),
    group(hub.power),group(hub_poles),station("RH","construction-robotics"),research_more}
  local rest={wave_orders(),set_stage("robot-supply-expansion")}
  if policy.lab then
    rest[#rest+1]=produce("inserter",1)
    rest[#rest+1]=fix_first_blue_intake()
  end
  rest[#rest+1]=station("RE2")
  if policy.lab then
    rest[#rest+1]=expect(function() return blue_intake.received~=nil end,"blue pack at the leading lab",14400)
  end
  rest[#rest+1]=set_stage("robot-and-blue-observation")
  prepend(table.unpack(rest))
  if policy.robot=="prepare" then
    prepend(table.unpack(fluid))
    prepend(table.unpack(center))
  else
    prepend(table.unpack(center))
    prepend(table.unpack(fluid))
  end
end

local scale_sites=policy.scale~="control" and require("steel-sites") or {}
local scale_blocks={}
local scale_wave={}
local scale={}
local scale_items={"rail","production-science-pack","processing-unit","low-density-structure"}
local scale_by_position={}
local scale_drills,scale_inserters,scale_steam,scale_steel={},{},{},{}
local scale_samples={total=0,no_power=0,active_labs=0}
local later_research={"railway","production-science-pack","processing-unit","low-density-structure","utility-science-pack"}
local next_research=1

local prior_researched=M.researched
function M.researched(event)
  prior_researched(event)
  if policy.speed and event.research.force==force and event.research.name=="construction-robotics" then
    research("research-speed-1")
    mark("queued-lab-speed",true)
  end
end

local prior_robot_built=M.robot_built
function M.robot_built(event)
  prior_robot_built(event)
  if not scale_active then return end
  local e=event.entity
  local address=ghost_key(e.name,e.position)
  local item=scale_by_position[address]
  if not item then return end
  scale_by_position[address]=nil
  local row=scale_wave[item]
  row.built=row.built+1
  if e.name=="electric-mining-drill" then
    scale_drills[#scale_drills+1]=e
  elseif e.name=="inserter" or e.name=="long-handed-inserter" then
    scale_inserters[#scale_inserters+1]=e
  end
  if row.built==row.issued then
    row.finished=game.tick
    mark("robots-built-"..item,row.built)
  end
end

local function steel_buffer(key)
  local count=0
  for _,out in ipairs(scale_blocks[key].outputs) do
    local c=robot_entity("wooden-chest",out.position)
    if c then count=count+c.get_item_count("steel-plate") end
  end
  return count
end

local function scale_rows_ready()
  for _,key in ipairs(scale_sites.core) do
    if not scale_wave[key] or not scale_wave[key].finished then return false end
  end
  return true
end

local function register_steel(key)
  for _,source in ipairs(scale_blocks[key].supplies) do
    local c=assert(robot_entity("wooden-chest",source.position))
    supplies[#supplies+1]={inv=c.get_inventory(defines.inventory.chest),items=source.items,station=key,priority=7}
  end
  for _,spec in ipairs(scale_blocks[key].entities) do
    if spec.name=="stone-furnace" or spec.name=="steel-furnace" then
      scale_steel[#scale_steel+1]=assert(robot_entity(spec.name,spec.position))
    end
  end
end

local function register_coal()
  for _,source in ipairs(scale_blocks.SXK.outputs) do
    local c=assert(robot_entity("wooden-chest",source.position))
    track(c,"coal",defines.inventory.chest,false,"SXK")
  end
end

local function sample_scale()
  local used=0
  scale_samples.total=scale_samples.total+1
  for _,lab in ipairs(process_units.labs) do
    if force.current_research and lab.status==defines.entity_status.working then used=used+1 end
  end
  scale_samples.active_labs=scale_samples.active_labs+used
  for _,e in ipairs(probes) do
    if e.status==defines.entity_status.low_power or e.status==defines.entity_status.no_power then
      scale_samples.no_power=scale_samples.no_power+1
      break
    end
  end
  if scale_wave.SX1 then
    local out1,out2=steel_buffer("SX1"),steel_buffer("SX2")
    if out1>0 then first("first-dedicated-steel-SX1",out1) end
    if out2>0 then first("first-dedicated-steel-SX2",out2) end
    if out1+out2>=100 then first("first-100-dedicated-steel",out1+out2) end
  end
  if #scale_steam>0 and not scale.wet then
    for _,e in ipairs(scale_steam) do
      if e.get_fluid_count("steam")<=0 then return end
    end
    if #scale_steam==8 then
      scale.wet=game.tick
      mark("extra-steam-ready",8)
    end
  end
  local name=later_research[next_research]
  if name and (force.technologies[name].researched or force.add_research(name)) then
    next_research=next_research+1
  end
end

scale_stats=function()
  local result={mode=policy.scale,waves=scale_wave,samples={total=scale_samples.total,
    no_power=scale_samples.no_power,labs_working=scale_samples.active_labs},
    dedicated={},drills={working=0,total=#scale_drills},unpowered_inserters=0,
    steam={},furnaces={},coal=amount("coal"),iron=amount("iron-plate"),steel=amount("steel-plate")}
  for _,e in ipairs(scale_drills) do
    if e.status==defines.entity_status.working then result.drills.working=result.drills.working+1 end
  end
  for _,e in ipairs(scale_inserters) do
    if not e.is_connected_to_electric_network() then result.unpowered_inserters=result.unpowered_inserters+1 end
  end
  for _,e in ipairs(scale_steam) do
    result.steam[#result.steam+1]={steam=e.get_fluid_count("steam"),
      connected=e.is_connected_to_electric_network()}
  end
  for _,e in ipairs(scale_steel) do
    local key=status_names[e.status] or tostring(e.status)
    result.furnaces[key]=(result.furnaces[key] or 0)+1
  end
  if scale_wave.SX1 then
    for _,key in ipairs({"SX1","SX2"}) do result.dedicated[key]=steel_buffer(key) end
  end
  return result
end

local function scale_power(first_module,last_module)
  local actions={}
  for module=first_module,last_module do
    local key=scale_sites.steam[module]
    actions[#actions+1]=station(key)
    actions[#actions+1]=once(function()
      for _,spec in ipairs(scale_blocks[key].entities) do
        if spec.name=="steam-engine" then scale_steam[#scale_steam+1]=assert(robot_entity(spec.name,spec.position)) end
      end
    end)
  end
  return once(function() prepend(table.unpack(actions)) end)
end

local function scale_ghosts(keys,add_crew)
  local entity_counts={}
  local names={}
  local power_specs,body_specs={},{}
  for _,key in ipairs(keys) do
    for _,e in ipairs(scale_blocks[key].power) do power_specs[#power_specs+1]=e end
    for _,e in ipairs(scale_blocks[key].entities) do body_specs[#body_specs+1]=e end
  end
  for _,part in ipairs({power_specs,body_specs}) do
    for _,spec in ipairs(part) do
      if not entity_counts[spec.name] then
        entity_counts[spec.name]=0
        names[#names+1]=spec.name
      end
      entity_counts[spec.name]=entity_counts[spec.name]+1
    end
  end
  local at=scale_sites.robot
  local actions={wood_for({power=power_specs,entities=body_specs}),batch_order(power_specs,body_specs),
    walk_to(at.standing,2)}
  for _,item in ipairs(names) do
    local count=entity_counts[item]
    local ready=produce(item,count)
    actions[#actions+1]=function()
      if not ready() then return false end
      local provider=assert(robot_entity("passive-provider-chest",at.provider))
      assert(player.can_reach_entity(provider))
      assert(load(provider.get_inventory(defines.inventory.chest),item,count)==count,item)
      return true
    end
  end
  actions[#actions+1]=once(function() mark("steel-building-materials-loaded",#power_specs+#body_specs) end)
  if add_crew and policy.crew>12 then
    actions[#actions+1]=expect(function() return amount("construction-robot")>=policy.crew end,
      "collect construction robots for the steel district",18000)
  end
  if not add_crew then
    actions[#actions+1]=expect(function()
      local delivered=steel_buffer("SX1")
      if delivered>0 then first("first-dedicated-steel-SX1",delivered) end
      return delivered>0
    end,"first dedicated steel before issuing the second row",54000)
  end
  actions[#actions+1]=once(function()
    local hub=assert(robot_entity("roboport",at.hub))
    assert(hub.is_connected_to_electric_network() and player.can_reach_entity(hub))
    if add_crew then
      assert(load(hub.get_inventory(defines.inventory.roboport_robot),"construction-robot",policy.crew)==policy.crew)
      if policy.crew>16 then local_stock["construction-robot"]=16 end
      mark("steel-robots-loaded",policy.crew)
    end
    for _,key in ipairs(keys) do
      local b=scale_blocks[key]
      local row={issued=#b.power+#b.entities,built=0,start=game.tick}
      scale_wave[key]=row
      for _,part in ipairs({b.power,b.entities}) do
        for _,spec in ipairs(part) do
          assert(math.max(math.abs(spec.position.x-at.hub.x),math.abs(spec.position.y-at.hub.y))<55,
            "Outside construction range: "..key)
          local address=ghost_key(spec.name,spec.position)
          assert(not selected(spec) and not scale_by_position[address],"Duplicate placement "..address)
          local ghost=assert(surface.create_entity{name="entity-ghost",inner_name=spec.name,
            position=spec.position,direction=spec.direction or 0,type=spec.type,force=force,
            expires=false,raise_built=true},address)
          assert(ghost.valid and ghost.ghost_name==spec.name)
          scale_by_position[address]=key
        end
      end
    end
    mark("issued-steel-district-ghosts",#power_specs+#body_specs)
  end)
  return once(function() prepend(table.unpack(actions)) end)
end

local function boot_steel_when_ready()
  for key,attach in pairs({SX1=register_steel,SX2=register_steel,SXK=register_coal}) do
    local row=scale_wave[key]
    if row and row.finished and not row.feed then
      attach(key)
      row.feed=game.tick
      mark("feed-"..key)
    end
  end
end

local function start_scale()
  scale_active=true
  assert(not current and #queue==0,"Robot stage still scheduled")
  for _,item in ipairs(scale_items) do tracked[#tracked+1]=item end
  local queue_tech=once(function() end)
  if policy.scale=="control" then
    prepend(set_stage("continued-research"),queue_tech)
    return
  end
  for key,b in pairs(scale_sites.blocks) do plan.blocks[key]=b; scale_blocks[key]=b end
  limits.coal={40,48}
  if policy.crew>16 then local_stock["construction-robot"]=policy.crew end
  if policy.scale=="upgrade" then
    for key,indices in pairs(scale_sites.upgrade) do
      for _,index in ipairs(indices) do scale_blocks[key].entities[index].name="steel-furnace" end
    end
  end
  local first_steam=scale_power(1,2)
  local second_steam=scale_power(3,4)
  local hub_ready=expect(function()
    return amount("roboport")>0 or
      (amount("steel-plate")>=45 and amount("iron-gear-wheel")>=45 and amount("advanced-circuit")>=45)
  end,"materials for the west roboport",18000)
  mark("west-roboport-before-steam",{steel=amount("steel-plate"),
    gear=amount("iron-gear-wheel"),circuits=amount("advanced-circuit")})
  local build=scale_ghosts({"SXK","SXO1","SX1"},true)
  local finish=scale_ghosts({"SXO2","SX2"},false)
  local done=expect(function()
    return scale_rows_ready() and steel_buffer("SX1")>0 and steel_buffer("SX2")>0 and scale.wet~=nil
  end,"both dedicated steel rows and additional steam",54000)
  if policy.scale=="serial" then
    prepend(queue_tech,set_stage("steam-then-steel"),first_steam,second_steam,hub_ready,station("SXH"),build,finish,done,
      set_stage("steel-and-power-observation"))
  else
    prepend(queue_tech,set_stage("steel-robots-and-steam"),first_steam,hub_ready,station("SXH"),build,second_steam,finish,done,
      set_stage("steel-and-power-observation"))
  end
end

function M.start()
  surface,force=game.surfaces.nauvis,game.forces.player
  start_tick=game.tick
  assert(surface.map_gen_settings.seed==plan.seed)
  surface.request_to_generate_chunks({0,0},8)
  surface.force_generate_chunk_requests()
  player=assert(game.get_player(1))
  actor=assert(player.character)
  mark("fresh-freeplay",{native_inventory=actor.get_main_inventory().get_contents()})

  prepend(set_stage("burner-start"),secure_first_fuel(),mine_to("coal",18),
    burner("iron-ore",1),mine_to("stone",32),burner("iron-ore",2),mine_to("wood",20),
    mine_to("coal",12),burner("coal",1),burner("stone",1),burner("coal",2),
    burner("copper-ore",1),burner("copper-ore",2),burner("iron-ore",3),burner("iron-ore",4),
    burner("iron-ore",5),
    tech_ready("steam-power"),tech_ready("electronics"),
    set_stage("steam-grid"),batch_order(plan.steam),group(plan.steam,register),
    expect(function() return boilers[1].get_fluid_count("steam")>.1 end,"steam supplied",9000),built("steam"),
    mine_to("wood",54),group(plan.blocks.L0.power),
    group(plan.lab,function(e)
      if e.name=="lab" then lab_inputs[#lab_inputs+1]=e.get_inventory(defines.inventory.lab_input) end
    end),
    built("labs"),tech_ready("automation-science-pack"),research_queue("automation"),
    produce_science_before_automation(),station("L0"),tech_ready("automation"),
    once(function() hand_red=false end),
    research_queue("electric-mining-drill","logistic-science-pack","steel-processing"),
    set_stage("build-red"),station("R0"))

  local function add(...)
    for _,action in ipairs({...}) do queue[#queue+1]=action end
  end
  if policy.order=="staged" then
    local r1=plan.blocks.R1
    local poles={}
    for _,spec in ipairs(r1.entities) do
      if spec.name=="small-electric-pole" then poles[#poles+1]=spec end
    end
    add(wood_for({power=r1.power,entities=poles}),group(r1.power),group(poles))
  else
    add(station("R1"))
  end
  add(station("M1"),station("M2"),station("M3"),
    set_stage("first-electric"),mine_to("wood",38),station("K1","electric-mining-drill"),station("I1"))
  if policy.order=="staged" then add(station("R1")) end
  add(station("C1"),station("M4"),station("M5"))

  if policy.order=="research" then
    add(station("G0","logistic-science-pack"),station("G1"),station("L1"),station("L2"),
        station("W1"),station("C2"),station("I2"))
  else
    add(station("W1"),station("C2"),station("I2"),station("G0","logistic-science-pack"),
        station("G1"),station("L1"),station("L2"))
  end
  add(research_queue("automation-2","engine","fluid-handling","oil-gathering","logistics"),
      set_stage("scale-supply"),mine_to("wood",50),station("W2"),station("C3"),station("K2"),
      station("I3"),station("C4"),station("M6"),set_stage("continuous-production"))
  report(true)
end

function M.tick()
  if not actor or game.tick-start_tick>policy.ticks then return end
  if not failure then
    local ok,message=pcall(function()
      if not active_process and stage=="continuous-production" and not current and #queue==0 then
        start_process()
      end
      if not robot_active and stage=="blue-flow-observation" and not current and #queue==0 then
        start_robot()
      end
      if not scale_active and stage=="robot-and-blue-observation" and not current and #queue==0 then
        start_scale()
      end
      if game.tick%120==0 then
        service(); if active_process then watch_process() end
        if robot_active then watch_robot() end
        if scale_active then boot_steel_when_ready(); sample_scale() end
      end
      current=current or table.remove(queue,1)
      if current and current() then current=nil end
    end)
    if not ok then
      failure=tostring(message)
      mark("trial-failure",{stage=stage,task=task,message=failure})
      actor.walking_state={walking=false,direction=0}
      actor.mining_state={mining=false}
      report(false)
    end
  end
  local elapsed=game.tick-start_tick
  if elapsed%3600==0 or elapsed==policy.ticks then report(true) end
end

function M.handoff()
  if failure then return nil,failure end
  if stages_done.steam then
    return {start=start_tick,outputs=outputs,burners=fuelers,boilers=boilers,coal_mines=coal_mines}
  end
end
return M
