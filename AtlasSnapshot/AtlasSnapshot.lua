local addon = ...
local frame = CreateFrame("Frame")
local ready, pending = false, false
local unpack = unpack or table.unpack
local issues
local function call(fn, ...)
    if type(fn) ~= "function" then
        if issues then issues.missingAPICalls=issues.missingAPICalls+1 end
        return nil
    end
    local result = {pcall(fn, ...)}
    if result[1] then return unpack(result, 2) end
    if issues then
        issues.failedAPICalls=issues.failedAPICalls+1
        if #issues.errors<5 then issues.errors[#issues.errors+1]=tostring(result[2]) end
    end
    return nil
end
-- Never persist restricted values, functions, userdata, or cyclic tables.
local function clean(v, depth)
    if issecretvalue and issecretvalue(v) then return {unavailable="restricted by game client"} end
    local t = type(v)
    if t == "string" or t == "boolean" then return v end
    if t == "number" then if v == v and v ~= math.huge and v ~= -math.huge then return v end return nil end
    if t ~= "table" then return nil end
    if (depth or 0) > 20 then return {unavailable="export depth limit"} end
    local out = {}
    for k, value in pairs(v) do
        if not (issecretvalue and issecretvalue(k)) and (type(k) == "string" or type(k) == "number") then
            out[k] = clean(value, (depth or 0) + 1)
        end
    end
    return out
end
local function section(fn)
    issues={missingAPICalls=0,failedAPICalls=0,errors={}}
    local ok, data = pcall(fn)
    local diagnostics=issues
    issues=nil
    if not ok then return {status="error", message=tostring(data),diagnostics=diagnostics} end
    local good, safe = pcall(clean, data)
    if not good then return {status="restricted", message="Client restricted this section"} end
    return {status="captured", capturedAt=time(), data=safe,diagnostics=diagnostics}
end
local function item(link)
    local r = {link=link}
    local api = C_Item or {}
    local name, _, quality, level, required, class, subclass, stack, equip = call(api.GetItemInfo or GetItemInfo, link)
    r.name, r.quality, r.itemLevel, r.requiredLevel = name, quality, level, required
    r.class, r.subclass, r.stackSize, r.equipLocation = class, subclass, stack, equip
    r.cachePending = name == nil
    r.stats = call(api.GetItemStats or GetItemStats, link)
    return r
end
local collectors = {}
function collectors.character()
    local class, token = UnitClass("player")
    return {name=UnitName("player"), realm=GetRealmName(), class=class, classToken=token,
        race=UnitRace("player"), level=UnitLevel("player"), faction=UnitFactionGroup("player"),
        moneyCopper=GetMoney(), xp=UnitXP("player"), xpMax=UnitXPMax("player"), restedXP=call(GetXPExhaustion),
        health=UnitHealth("player"), healthMax=UnitHealthMax("player"), mana=UnitPower("player",0), manaMax=UnitPowerMax("player",0),
        dead=UnitIsDeadOrGhost("player"), inCombat=UnitAffectingCombat("player"), resting=IsResting(),
        hearthLocation=call(GetBindLocation), freeTalentPoints=call(GetUnspentTalentPoints)}
end
function collectors.location()
    local id = call(C_Map and C_Map.GetBestMapForUnit,"player")
    local pos = id and call(C_Map.GetPlayerMapPosition,id,"player")
    local x,y
    if pos then x,y=pos:GetXY() end
    return {zone=GetZoneText(), subzone=GetSubZoneText(), mapID=id, x=x,y=y,
        coordinateScale="0 to 1", instance={GetInstanceInfo()}}
end
function collectors.equipment()
    local out={}
    for slot=1,19 do
        local link=GetInventoryItemLink("player",slot)
        local r=link and item(link) or {empty=true}
        r.slot=slot
        r.durability,r.maxDurability=call(GetInventoryItemDurability,slot)
        out[#out+1]=r
    end
    return out
end
function collectors.bags()
    local api=C_Container
    assert(api and api.GetContainerItemInfo,"Container API unavailable")
    local out={}
    for bag=0,4 do
        local b={bag=bag,slots=api.GetContainerNumSlots(bag),items={}}
        b.freeSlots=call(api.GetContainerNumFreeSlots,bag)
        for slot=1,b.slots do
            local data=api.GetContainerItemInfo(bag,slot)
            if data then
                local r=data.hyperlink and item(data.hyperlink) or {}
                r.slot,r.itemID,r.count=slot,data.itemID,data.stackCount
                r.cooldown={call(api.GetContainerItemCooldown,bag,slot)}
                b.items[#b.items+1]=r
            end
        end
        out[#out+1]=b
    end
    return out
end
function collectors.quests()
    local out={}
    assert(C_QuestLog and C_QuestLog.GetInfo,"Quest API unavailable")
    local n=C_QuestLog.GetNumQuestLogEntries()
    local header
    for i=1,n do
        local q=C_QuestLog.GetInfo(i)
        if q then
            if q.isHeader then header=q.title else
                q.header=header
                q.objectives=call(C_QuestLog.GetQuestObjectives,q.questID)
                q.complete=call(C_QuestLog.IsComplete,q.questID)
                out[#out+1]=q
            end
        end
    end
    return out
end
function collectors.completedQuests()
    local out={api="C_QuestLog.GetAllCompletedQuestIDs",queriedAt=time(),
        captureStatus="unavailable",ids={},titlesByID={},
        absenceMeansNeverCompleted=false,lifetimeHistoryGuaranteed=false,
        scope="Completion flags currently exposed by the client, not a lifetime quest ledger"}
    local api=C_QuestLog
    if not api or type(api.GetAllCompletedQuestIDs)~="function" then
        out.reason="Completed quest API unavailable"
        return out
    end
    -- Do not convert a failed or restricted query into an empty successful history.
    local ok,ids=pcall(api.GetAllCompletedQuestIDs)
    if not ok then out.captureStatus="error"; out.reason=tostring(ids); return out end
    if issecretvalue and issecretvalue(ids) then
        out.captureStatus="restricted"; return out
    end
    if type(ids)~="table" then out.reason="Client returned no quest list"; return out end
    local seen={}
    out.invalidEntries=0
    for _,id in pairs(ids) do
        if not (issecretvalue and issecretvalue(id)) and type(id)=="number"
            and id>0 and id<math.huge and id==math.floor(id) then
            if not seen[id] then seen[id]=true; out.ids[#out.ids+1]=id end
        else out.invalidEntries=out.invalidEntries+1 end
    end
    table.sort(out.ids)
    out.count=#out.ids
    out.namedCount=0
    out.titleSource="C_QuestLog.GetTitleForQuestID; available client cache only"
    for _,id in ipairs(out.ids) do
        local title=call(api.GetTitleForQuestID,id)
        if not (issecretvalue and issecretvalue(title)) and type(title)=="string" and title~="" then
            out.titlesByID[id]=title
            out.namedCount=out.namedCount+1
        end
    end
    out.unresolvedTitleCount=out.count-out.namedCount
    out.captureStatus=out.invalidEntries>0 and "partial" or (out.count==0 and "empty_unconfirmed" or "captured")
    out.note="Absent IDs are unknown. Repeatable/reset, hidden, alternate, and account-wide flags can differ from lifetime character completion. Missing titles do not invalidate IDs."
    return out
end
function collectors.spells()
    local api=C_SpellBook
    assert(api and api.GetNumSpellBookSkillLines,"Spell book API unavailable")
    local out={}
    local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    for tab=1,api.GetNumSpellBookSkillLines() do
        local line=api.GetSpellBookSkillLineInfo(tab)
        for i=line.itemIndexOffset+1,line.itemIndexOffset+line.numSpellBookItems do
            local info=api.GetSpellBookItemInfo(i,bank)
            if info then
                local r={bookIndex=i,skillLine=line.name,info=info}
                r.name,r.rank=call(api.GetSpellBookItemName,i,bank)
                if info.spellID and C_Spell then
                    r.details=call(C_Spell.GetSpellInfo,info.spellID)
                    r.description=call(C_Spell.GetSpellDescription,info.spellID)
                    r.cooldown=call(C_Spell.GetSpellCooldown,info.spellID)
                    r.powerCost=call(C_Spell.GetSpellPowerCost,info.spellID)
                    r.charges=call(C_Spell.GetSpellCharges,info.spellID)
                end
                out[#out+1]=r
            end
        end
    end
    return out
end
function collectors.talents()
    -- Forever uses trait trees, even though the Classic talent shims may exist.
    if C_Traits and C_Traits.GetConfigInfo then
        local ids,seen={},{}
        local active=call(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
        local function add(id)
            if type(id)=="number" and id>0 and not seen[id] then seen[id]=true; ids[#ids+1]=id end
        end
        add(active)
        for _,kind in pairs(Enum and Enum.TraitConfigType or {}) do
            for _,id in ipairs(call(C_Traits.GetConfigsByType,kind) or {}) do add(id) end
        end
        local out={api="C_Traits",activeConfigID=active,configs={}}
        for _,id in ipairs(ids) do
            local config=call(C_Traits.GetConfigInfo,id)
            if config then
                local c={configID=id,info=config,trees={},hasStagedChanges=call(C_Traits.ConfigHasStagedChanges,id)}
                for _,treeID in ipairs(config.treeIDs or {}) do
                    local tree={treeID=treeID,currency=call(C_Traits.GetTreeCurrencyInfo,id,treeID,true),
                        currencyExcludesStagedChanges=true,nodes={}}
                    for _,nodeID in ipairs(call(C_Traits.GetTreeNodes,treeID) or {}) do
                        local node=call(C_Traits.GetNodeInfo,id,nodeID)
                        if node then
                            local n={nodeID=nodeID,info=node,entries={}}
                            for _,entryID in ipairs(node.entryIDs or {}) do
                                local entry=call(C_Traits.GetEntryInfo,id,entryID)
                                local def=entry and entry.definitionID and call(C_Traits.GetDefinitionInfo,entry.definitionID)
                                n.entries[#n.entries+1]={entryID=entryID,info=entry,definition=def,
                                    spell=def and def.spellID and call(C_Spell and C_Spell.GetSpellInfo,def.spellID),
                                    description=def and def.spellID and call(C_Spell and C_Spell.GetSpellDescription,def.spellID)}
                            end
                            tree.nodes[#tree.nodes+1]=n
                        end
                    end
                    c.trees[#c.trees+1]=tree
                end
                out.configs[#out.configs+1]=c
            end
        end
        if #out.configs>0 then return out end
    end
    local api=C_SpecializationInfo
    assert(api and api.GetTalentInfo,"Talent API unavailable")
    local out={trees={},entries={}}
    for tree=1,3 do
        out.trees[tree]={call(api.GetSpecializationInfo,tree,false,false)}
        for index=1,40 do
            local info=call(api.GetTalentInfo,{specializationIndex=tree,talentIndex=index,isInspect=false,isPet=false})
            if info then out.entries[#out.entries+1]={tree=tree,index=index,info=info} end
        end
    end
    if #out.entries==0 then
        for tier=1,15 do for column=1,4 do
            local info=call(api.GetTalentInfo,{tier=tier,column=column,isInspect=false,isPet=false})
            if info then out.entries[#out.entries+1]={tier=tier,column=column,info=info} end
        end end
    end
    assert(#out.entries>0,"Talent layout not exposed by this beta build")
    return out
end
function collectors.stats()
    local out={attributes={},resistances={}}
    for i=1,5 do out.attributes[i]={call(UnitStat,"player",i)} end
    for i=0,6 do out.resistances[i]={call(UnitResistance,"player",i)} end
    out.attributeOrder={"strength","agility","stamina","intellect","spirit"}
    out.armor={call(UnitArmor,"player")}
    out.attackPower={call(UnitAttackPower,"player")}
    out.weaponDamage={call(UnitDamage,"player")}
    out.attackSpeed={call(UnitAttackSpeed,"player")}
    out.crit=call(GetCritChance)
    out.dodge=call(GetDodgeChance)
    out.parry=call(GetParryChance)
    out.block=call(GetBlockChance)
    out.manaRegen={call(GetManaRegen)}
    out.healingBonus=call(GetSpellBonusHealing)
    out.spellDamage={}
    for school=1,7 do out.spellDamage[school]=call(GetSpellBonusDamage,school) end
    return out
end
function collectors.auras()
    assert(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex,"Aura API unavailable")
    local out={}
    for _,filter in ipairs({"HELPFUL","HARMFUL"}) do
        out[filter]={}
        for i=1,80 do
            local a=C_UnitAuras.GetAuraDataByIndex("player",i,filter)
            if not a then break end
            out[filter][#out[filter]+1]=a
        end
    end
    return out
end
function collectors.target()
    if not UnitExists("target") then return {exists=false} end
    return {exists=true,name=UnitName("target"),level=UnitLevel("target"),
        classification=UnitClassification("target"),creatureType=UnitCreatureType("target"),
        health=UnitHealth("target"),healthMax=UnitHealthMax("target"),
        hostile=UnitCanAttack("player","target"),dead=UnitIsDead("target")}
end
function collectors.actions()
    local out={}
    for slot=1,120 do
        local kind,id,subtype=GetActionInfo(slot)
        if kind then out[#out+1]={slot=slot,type=kind,id=id,subtype=subtype} end
    end
    return out
end
function collectors.skills()
    local count=C_SkillInfo and C_SkillInfo.GetNumSkillLines or GetNumSkillLines
    local info=C_SkillInfo and C_SkillInfo.GetSkillLineInfo or GetSkillLineInfo
    assert(count and info,"Skill-line API unavailable")
    local out={}
    for i=1,count() do
        local name,header,expanded,rank,temp,modifier,maxRank=info(i)
        if type(name)=="table" then out[#out+1]=name else
            out[#out+1]={name=name,isHeader=header,isExpanded=expanded,rank=rank,
                temporaryBonus=temp,modifier=modifier,maxRank=maxRank}
        end
    end
    return out
end
function collectors.professions()
    assert(GetProfessions and GetProfessionInfo,"Profession API unavailable; check skills section")
    local out={}
    for _,index in pairs({GetProfessions()}) do
        local name,icon,rank,maxRank,numAbilities,offset,skillLine=GetProfessionInfo(index)
        out[#out+1]={name=name,rank=rank,maxRank=maxRank,skillLine=skillLine}
    end
    return out
end
function collectors.context()
    return {groupSize=call(GetNumGroupMembers),inGroup=call(IsInGroup),inRaid=call(IsInRaid),
        pvpFlagged=call(UnitIsPVP,"player"),pvpZoneType=call(GetZonePVPInfo),
        movementSpeed=call(GetUnitSpeed,"player"),mounted=call(IsMounted),swimming=call(IsSwimming),
        latency={call(GetNetStats)}}
end
local function capture(reason)
    if not ready then return end
    local snapshot={schemaVersion=2,addonVersion="0.3.0",capturedAt=time(),
        reason=reason,build={GetBuildInfo()},clockSeconds=GetTime(),sections={}}
    for name,fn in pairs(collectors) do snapshot.sections[name]=section(fn) end
    AtlasSnapshotDB = type(AtlasSnapshotDB)=="table" and AtlasSnapshotDB or {}
    -- Keep a separately timestamped baseline, never substitute it for current data.
    local character=snapshot.sections.character.data
    if character and character.inCombat==false then
        AtlasSnapshotDB.lastOutOfCombat={capturedAt=snapshot.capturedAt,character=snapshot.sections.character,
            stats=snapshot.sections.stats,auras=snapshot.sections.auras,location=snapshot.sections.location}
    elseif AtlasSnapshotDB.lastOutOfCombat then
        local previous=AtlasSnapshotDB.lastOutOfCombat.character.data
        if not character or previous.name~=character.name or previous.realm~=character.realm then
            AtlasSnapshotDB.lastOutOfCombat=nil
        end
    end
    AtlasSnapshotDB.latest=snapshot
    AtlasSnapshotDB.note="Snapshot only. Disk updated by WoW on reload/logout. Cooldowns use clockSeconds. Missing values are unknown."
end
local function say(message) print("|cff66ccffAtlas Snapshot:|r "..message) end
frame:SetScript("OnEvent",function(self,event)
    if event=="PLAYER_LOGIN" then
        ready=true
        capture(event)
        say("Ready. Reload or log out to save a snapshot for Atlas.")
    elseif event=="PLAYER_LOGOUT" then capture(event)
    elseif ready and not pending then
        pending=true
        C_Timer.After(2,function() pending=false; capture(event) end)
    end
end)
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_LOGOUT","PLAYER_ENTERING_WORLD","QUEST_LOG_UPDATE",
    "PLAYER_EQUIPMENT_CHANGED","BAG_UPDATE_DELAYED","SPELLS_CHANGED","PLAYER_LEVEL_UP",
    "ZONE_CHANGED_NEW_AREA","ZONE_CHANGED","PLAYER_TARGET_CHANGED","PLAYER_MONEY","PLAYER_REGEN_ENABLED",
    "TRAIT_CONFIG_UPDATED","PLAYER_TALENT_UPDATE","SKILL_LINES_CHANGED","UPDATE_INVENTORY_DURABILITY",
    "QUEST_TURNED_IN","QUEST_DATA_LOAD_RESULT"}) do
    pcall(frame.RegisterEvent,frame,event)
end
SLASH_ATLASSNAPSHOT1="/atlassnapshot"
SlashCmdList.ATLASSNAPSHOT=function()
    capture("manual")
    local failed={}
    for name,s in pairs(AtlasSnapshotDB.latest.sections) do
        if s.status~="captured" or (name=="completedQuests" and s.data.captureStatus~="captured") then
            failed[#failed+1]=name
        end
    end
    say("Refreshed in memory. Use /reload to write it to disk.")
    if #failed>0 then say("Unavailable sections: "..table.concat(failed,", ")) end
end
