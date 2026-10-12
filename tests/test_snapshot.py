from pathlib import Path
from lupa import LuaRuntime

ADDON_PATH = Path(__file__).resolve().parents[1] / 'AtlasSnapshot' / 'AtlasSnapshot.lua'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
events={}; timers={}; SlashCmdList={}; printed={}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function(self,k,f) events[k]=f end} end
C_Timer={After=function(t,f) timers[#timers+1]=f end}
function print(s) printed[#printed+1]=s end
function time() return 1000 end
function GetTime() return 50 end
function GetBuildInfo() return '1.60.1','70170','date',16001 end
function UnitClass() return 'Paladin','PALADIN' end
function UnitName(u) return u=='player' and 'TestPaladin' or 'TestSkeleton' end
function GetRealmName() return 'TestRealm' end
function UnitRace() return 'Human' end
function UnitLevel() return 23 end
function UnitFactionGroup() return 'Alliance' end
function GetMoney() return 25000 end
function UnitXP() return 100 end
function UnitXPMax() return 1000 end
function UnitHealth() return 500 end
function UnitHealthMax() return 1000 end
function UnitPower() return 200 end
function UnitPowerMax() return 500 end
function UnitIsDeadOrGhost() return false end
function UnitAffectingCombat() return false end
function IsResting() return false end
function GetZoneText() return 'Duskwood' end
function GetSubZoneText() return 'Darkshire' end
function GetInstanceInfo() return 'Eastern Kingdoms','none' end
C_Map={GetBestMapForUnit=function() return 1431 end,GetPlayerMapPosition=function() return {GetXY=function() return .73,.58 end} end}
function GetInventoryItemLink(u,s) if s==16 then return 'item:123' end end
C_Item={GetItemInfo=function() return 'Test sword','item:123',2,20,15 end,GetItemStats=function() return {STR=2} end}
C_Container={GetContainerNumSlots=function() return 1 end,GetContainerItemInfo=function(b,s) if b==0 then return {itemID=1205,hyperlink='item:1205',stackCount=20} end end}
C_QuestLog={GetNumQuestLogEntries=function() return 2 end,GetInfo=function(i) if i==1 then return {isHeader=true,title='Duskwood'} end return {title='Night Watch',questID=56,level=24} end,GetQuestObjectives=function() return {{text='Mages',numFulfilled=2,numRequired=6}} end}
C_SpellBook={GetNumSpellBookSkillLines=function() return 1 end,GetSpellBookSkillLineInfo=function() return {name='Holy',itemIndexOffset=0,numSpellBookItems=1} end,GetSpellBookItemInfo=function() return {spellID=635} end,GetSpellBookItemName=function() return 'Holy Light','Rank 1' end}
C_Spell={GetSpellInfo=function() return {name='Holy Light'} end,GetSpellDescription=function() return 'Heal an ally' end,GetSpellCooldown=function() return {startTime=0,duration=0} end}
C_SpecializationInfo={GetTalentInfo=function(q) if q.talentIndex==1 then return {name='Test Talent',rank=2} end end}
C_UnitAuras={GetAuraDataByIndex=function() return nil end}
function UnitExists() return false end
function GetActionInfo(s) if s==1 then return 'spell',635 end end
''')
lua.execute(ADDON_PATH.read_text(encoding='utf-8-sig'))
lua.execute("events.OnEvent(nil,'PLAYER_LOGIN')")
s=lua.globals().AtlasSnapshotDB.latest
assert s.sections.character.data.level==23
assert s.sections.location.data.x==.73
assert s.sections.bags.data[1]['items'][1].count==20
assert s.sections.quests.data[1].objectives[1].numFulfilled==2
assert s.sections.spells.data[1].rank=='Rank 1'
assert s.sections.equipment.data[16].name=='Test sword'
assert s.sections.target.data.exists is False
assert s.sections.talents.status=='captured'
lua.execute("C_QuestLog.GetInfo=function() error('simulated beta failure') end; events.OnEvent(nil,'PLAYER_LOGOUT')")
s=lua.globals().AtlasSnapshotDB.latest
assert s.reason=='PLAYER_LOGOUT'
assert s.sections.quests.status=='error'
assert s.sections.character.status=='captured'
lua.execute("C_QuestLog=nil; C_SpecializationInfo=nil; SlashCmdList.ATLASSNAPSHOT()")
assert lua.globals().AtlasSnapshotDB.latest.sections.talents.status=='error'
lua.execute("events.OnEvent(nil,'BAG_UPDATE_DELAYED'); events.OnEvent(nil,'BAG_UPDATE_DELAYED')")
assert len(lua.globals().timers)==1
lua.execute("timers[1]()")
assert lua.globals().AtlasSnapshotDB.latest.reason=='BAG_UPDATE_DELAYED'
print('PASS: Lua load, character, location, inventory, quests, spellbook, talents, logout, error isolation, missing API handling, event debounce')
lua.execute('''
C_ClassTalents={GetActiveConfigID=function() return 77 end}
Enum={TraitConfigType={Combat=1}}
C_Traits={
GetConfigsByType=function() return {77} end,
GetConfigInfo=function(id) return {treeIDs={88},name='Paladin'} end,
GetTreeNodes=function() return {99} end,
GetNodeInfo=function() return {entryIDs={100},currentRank=3,activeRank=3} end,
GetEntryInfo=function() return {definitionID=101} end,
GetDefinitionInfo=function() return {spellID=635} end,
ConfigHasStagedChanges=function() return false end}
function GetNumSkillLines() return 1 end
function GetSkillLineInfo() return 'Two-Handed Maces',false,true,100,0,0,115 end
function GetProfessions() return 1 end
function GetProfessionInfo() return 'First Aid',0,50,75,0,0,129 end
secret={}
function issecretvalue(v) return rawequal(v,secret) end
function UnitHealth() return secret end
events.OnEvent(nil,'PLAYER_LOGOUT')
''')
s=lua.globals().AtlasSnapshotDB.latest
assert s.sections.talents.data.api=='C_Traits'
assert len(s.sections.talents.data.configs)==1
assert s.sections.talents.data.configs[1].trees[1].nodes[1].info.currentRank==3
assert s.sections.character.data.health.unavailable=='restricted by game client'
assert s.sections.skills.data[1].rank==100
assert s.sections.professions.data[1].name=='First Aid'
assert s.sections.context.diagnostics.missingAPICalls>0
assert lua.globals().AtlasSnapshotDB.lastOutOfCombat.capturedAt==1000
lua.execute("function UnitAffectingCombat() return true end; function time() return 1001 end; events.OnEvent(nil,'PLAYER_LOGOUT')")
assert lua.globals().AtlasSnapshotDB.lastOutOfCombat.capturedAt==1000
assert lua.globals().AtlasSnapshotDB.latest.capturedAt==1001
print('PASS: trait-tree capture and deduplication, explicit restricted values, professions, weapon skills, API diagnostics, separately dated baseline')
lua.execute('''
GetNumSkillLines=nil; GetSkillLineInfo=nil
C_SkillInfo={GetNumSkillLines=function() return 1 end,GetSkillLineInfo=function() return {name='Two-Handed Maces',rank=105,maxRank=115} end}
C_Traits.GetTreeCurrencyInfo=function(c,t,exclude) assert(exclude==true); return {{traitCurrencyID=1,quantity=1,spent=13}} end
events.OnEvent(nil,'PLAYER_LOGOUT')
''')
s=lua.globals().AtlasSnapshotDB.latest
entry=s.sections.talents.data.configs[1].trees[1].nodes[1].entries[1]
assert entry.spell.name=='Holy Light'
assert entry.definition.spellID==635
assert entry.info.definitionID==101
assert s.sections.skills.data[1].rank==105
assert s.sections.talents.data.configs[1].trees[1].currency[1].quantity==1
print('PASS: deeply nested talent names and definitions, modern skill API, committed talent currency')

lua.execute('''
C_QuestLog={GetAllCompletedQuestIDs=function() return {200,100,200,300} end,
GetTitleForQuestID=function(id) if id==100 then return 'Known quest' end end}
events.OnEvent(nil,'PLAYER_LOGOUT')
''')
h=lua.globals().AtlasSnapshotDB.latest.sections.completedQuests.data
assert h.captureStatus=='captured'
assert list(h.ids.values())==[100,200,300]
assert h.namedCount==1 and h.unresolvedTitleCount==2
assert h.titlesByID[100]=='Known quest'
assert h.absenceMeansNeverCompleted is False
assert h.queriedAt==1001
for body,expected in [("return {}",'empty_unconfirmed'),("return nil",'unavailable'),("error('failed query')",'error'),("return secret",'restricted'),("return {100,secret,'bad',-1}",'partial')]:
    lua.execute("C_QuestLog.GetAllCompletedQuestIDs=function() "+body+" end; events.OnEvent(nil,'PLAYER_LOGOUT')")
    assert lua.globals().AtlasSnapshotDB.latest.sections.completedQuests.data.captureStatus==expected
lua.execute("C_QuestLog.GetAllCompletedQuestIDs=nil; events.OnEvent(nil,'PLAYER_LOGOUT')")
assert lua.globals().AtlasSnapshotDB.latest.sections.completedQuests.data.captureStatus=='unavailable'
lua.execute("C_QuestLog.GetAllCompletedQuestIDs=function() return {400} end; events.OnEvent(nil,'QUEST_TURNED_IN'); timers[#timers]()")
assert lua.globals().AtlasSnapshotDB.latest.sections.completedQuests.data.ids[1]==400
assert lua.globals().AtlasSnapshotDB.latest.sections.character.data.health.unavailable=='restricted by game client'
assert lua.globals().AtlasSnapshotDB.latest.addonVersion=='0.3.0'
print('PASS: completed IDs independent of active log, deduplication, missing titles, timestamps, unavailable/error/empty/restricted/partial states, turn-in refresh, existing secret-value protection')
