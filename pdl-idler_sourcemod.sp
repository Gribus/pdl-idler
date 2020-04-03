/*
# pdl-idler_sourcemod.sp (0.9026)
# Copyright (c) 2011-2016 byteframe@primarydataloop

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/> */

#include <sdktools>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#include <sourceirc>

// print player count on change to assist script
PrintPlayerCount() {
  decl String:t[15];
  FormatTime(t, 15, "%D-%H:%M", GetTime());
  PrintToServer("[%s] Players: %d", t, GetClientCount(false));
}

// teleport spawners to halloween position and resize them
new Float:location[][3] = {{-1383.0,3018.0,-9550.0},
  {-372.0,-1417.0,-10019.0},{1647.0,952.0,-14076.0},
  {6320.0,7540.0,-4765.0}};
public Event_PlayerSpawn(Handle:evt, const String:n[], bool:db) {
  new c = GetClientOfUserId(GetEventInt(evt, "userid"));
  decl String:map[50];
  GetCurrentMap(map, sizeof(map));
  if (strcmp(map, "cp_manor_event", false) == 0) {
    TeleportEntity(c, location[0], NULL_VECTOR, NULL_VECTOR);
  } else if (strcmp(map, "koth_lakeside_event", false) == 0) {
    TeleportEntity(c, location[1], NULL_VECTOR, NULL_VECTOR);
  } else if (strcmp(map, "koth_viaduct_event", false) == 0) {
    TeleportEntity(c, location[2], NULL_VECTOR, NULL_VECTOR);
  } else if (strcmp(map, "plr_hightower_event", false) == 0) {
    TeleportEntity(c, location[3], NULL_VECTOR, NULL_VECTOR);
  } else {
    return;
  }
  SetEntProp(c, Prop_Data, "m_takedamage", 0, 1);
  SetEntPropFloat(c, Prop_Send, "m_flModelScale", 5000.0);
}

// create fake item event with console command
public Action:ItemEvent(c, args) {
  decl String:pattern[64];
  GetCmdArg(1, pattern, sizeof(pattern));
  new targets[MAXPLAYERS];
  new String:target_name[MAX_TARGET_LENGTH];
  new bool:tn_is_ml;
  ProcessTargetString(pattern, 0, targets, MAXPLAYERS,
    COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml);
  decl String:defindex[10], String:quality[10];
  GetCmdArg(2, defindex, sizeof(defindex));
  GetCmdArg(3, quality, sizeof(quality));
  new Handle:event = CreateEvent("item_found");
  SetEventInt(event, "player", targets[0]);
  SetEventInt(event, "quality", StringToInt(quality));
  SetEventInt(event, "method", 0);
  SetEventInt(event, "itemdef", StringToInt(defindex));
  FireEvent(event);
}

// form client connection duration
String:ClientTime(c) {
  new time = RoundToFloor(GetClientTime(c));
  new h = time / 3600;
  if (h < 1) {
    h = 0;
  }
  decl String:d[64];
  Format(d, sizeof(d), "%02d:%02d:%02d", h, (time-3600*h)/60, time%60);
  return d;
}

// send an irc message or queue it if not joined to the channel
new joined = 0;
new joiner_count = 0;
new String:joiner[50][IRC_MAXLEN];
QueueMsg(const String:msg[IRC_MAXLEN]) {
  if (joined == 1) {
    IRC_MsgFlaggedChannels("relay", msg);
  } else {
    joiner[joiner_count] = msg;
    joiner_count++;
  }
}

// print irc announcement of item drop when item events fire
new Handle:kv = INVALID_HANDLE;
public Action:ItemFound(Handle:evt, const String:n[], bool:db) {
  new c = GetEventInt(evt, "player"), color=6,
    index=GetEventInt(evt, "itemdef");
  decl String:msg[IRC_MAXLEN], String:name[256], String:type[64],
    String:slot[64], String:class[64], String:craft[64], String:armory[64],
    String:prefab[64], String:itemdef[10];
  Format(itemdef, sizeof(itemdef), "%i", index);
  if (KvJumpToKey(kv, itemdef)) {
    KvGetString(kv, "name", name, sizeof(name), "Unknown");
    KvGetString(kv, "prefab", prefab, sizeof(prefab), "");
    KvGetString(kv, "item_slot", slot, sizeof(slot), "");
    KvGetString(kv, "item_class", class, sizeof(class), "");
    KvGetString(kv, "craft_class", craft, sizeof(craft), "");
    KvGetString(kv, "armory_desc", armory, sizeof(armory), "");
    KvGetString(kv, "item_type_name", type, sizeof(type), "");
    KvGoBack(kv);
  } else {
    Format(name, sizeof(name), "Unknown Item");
  }
  msg[0] = '\0';
  switch (GetEventInt(evt, "quality")) {
    case 1:
      color = 3;
    case 3:
      color = 12;
    case 6:
      color = 8;
    case 11:
      color = 7;
    case 13:
      color = 6;
  }
  Format(msg, sizeof(msg), "%s\x0315%N [\x03%02d%s\x0315 %s]\x03",
    msg, c, color, name, ClientTime(c));
  if (StrContains(type, "#TF_Wearable", false) == 0
  || StrContains(prefab, "hat", false) > -1
  || StrContains(prefab, "misc", false) > -1) {
    if (!StrEqual(craft, "weapon", false)
    && StrContains(prefab, "weapon", false) == -1) {
      StrCat(msg, sizeof(msg), " \x0313(Cosmetic!)\x03");
    }
  } else if (StrContains(name, "Paint", false) != -1) {
    StrCat(msg, sizeof(msg), " \x0309(Paint!)\x03");
  } else if (StrEqual(class, "tool", false) || index == 5020) {
    StrCat(msg, sizeof(msg), " \x0312(Tool!)\x03");
  } else if (StrEqual(slot, "action", false)
  || StrEqual(class, "craft_item", false)) {
    StrCat(msg, sizeof(msg), " \x0304(Action!)\x03");
  } else if (StrEqual(class, "supply_crate", false)
  || StrEqual(armory, "supply_crate", false)
  || StrEqual(prefab, "eventcrate", false)) {
    StrCat(msg, sizeof(msg), " \x0307(Crate!)\x03");
  }
  QueueMsg(msg);
}

// show count on connect and park client if tv_nochat is set
public bool:OnClientConnect(c, String:rejectmsg[], maxlen) {
  decl String:tvnochat[2];
  GetClientInfo(c, "tv_nochat", tvnochat, 2);
  if (strcmp(tvnochat, "1", false) == 0) {
    InactivateClient(c);
  }
  PrintPlayerCount();
  return true;
}

// form tf2b url
stock String:tf2b(c) {
  decl String:id[64];
  GetClientAuthId(c, AuthId_SteamID64, id, sizeof(id));
  Format(id, sizeof(id), "http://tf2b.com/tf2/%s", id);
  return id;
}

// show player connection message
public void OnClientAuthorized(c, const String:auth[]) {
  decl String:name[IRC_MAXLEN]
  GetClientName(c, name, sizeof(name));
  Format(name, IRC_MAXLEN, "\x0315%s (%s)\x03", name, tf2b(c));
  QueueMsg(name);
  return;
}

// give player random team and set class to scout when client joins game
public OnClientPutInServer(c) {
  if (GetRandomInt(0, 1) == 1) {
    ChangeClientTeam(c, _:TFTeam_Blue);
  } else {
    ChangeClientTeam(c, _:TFTeam_Red);
  }
  TF2_SetPlayerClass(c, TFClass_Scout, false);
}

// show duration, reprint player count on disconnect, then stop server if empty
public Action:Event_PlayerDisconnect(Handle:evt, const String:n[], bool:db) {
  new c = GetClientOfUserId(GetEventInt(evt, "userid"));
  PrintToServer("Duration: %s", ClientTime(c));
  decl String:reason[128], String:name[IRC_MAXLEN];
  GetEventString(evt, "reason", reason,  sizeof(reason));
  for (new i = 0; i <= strlen(reason); i++) {
    if (reason[i] == '\n') {
      RemoveChar(reason, sizeof(reason), i);
    }
  }
  if (strcmp(reason, "Disconnect by user.", false) != 0) {
    GetClientName(c, name, sizeof(name));
    Format(name, IRC_MAXLEN,
      "%s (%s) %s [%s]", name, tf2b(c), reason, ClientTime(c));
    QueueMsg(name);
  }
}
public Action:Timer_OnClientDisconnect_Post(Handle:timer) {
  if (GetClientCount(false) == 0) {
    ServerCommand("quit");
  }
}
public OnClientDisconnect_Post(c) {
  PrintPlayerCount();
  CreateTimer(5.0, Timer_OnClientDisconnect_Post);
}

// detect irc channel join
public Action:IrcJoin_Timer(Handle:timer)
{
  for (new i = 0; i < joiner_count; i++) {
    IRC_MsgFlaggedChannels("relay", joiner[i]);
  }
}
public Action:IRCJoin(const String:hostmask[], args) {
  if (!joined) {
    joined = 1;
    CreateTimer(1.5, IrcJoin_Timer);
  }
}

// short gameinfo irc status
GameInfo(const String:nick[]) {
  decl String:hostname[256];
  GetClientName(0, hostname, sizeof(hostname));
  IRC_ReplyToCommand(nick, "(%d/%d): %s",
    GetClientCount(false), GetMaxClients(), hostname);
}
public Action:IRCGameInfo(const String:nick[], args) {
  GameInfo(nick);
  return Plugin_Handled;
}

// full irc status list
public Action:IRCStatus(const String:nick[], args) {
  GameInfo(nick);
  for (new i = 1; i <= GetMaxClients(); i++) {
    if (IsClientConnected(i)) {
      IRC_ReplyToCommand(nick, "# %d \"%N\" %s %s %d",
        GetClientUserId(i), i, tf2b(i), ClientTime(i),
        RoundToFloor(GetClientAvgLatency(i, NetFlow_Both)*1000.0));
    }
  }
  return Plugin_Handled;
}

// (de)initialize plugin and hook events
new loaded = 0;
public OnPluginStart() {
  PrintPlayerCount();
  HookEvent("player_spawn", Event_PlayerSpawn);
}
IRC_Loaded() {
  IRC_CleanUp();
  if (!loaded) {
    loaded = 1;
    IRC_HookEvent("366", IRCJoin);
    IRC_RegCmd("gameinfo", IRCGameInfo, "gameinfo");
    IRC_RegCmd("status", IRCStatus, "status");
    RegAdminCmd("itemevent", ItemEvent, ADMFLAG_SLAY, "");
    HookEvent("item_found", ItemFound);
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
    decl String:buffer[512];
    BuildPath(Path_SM, buffer, sizeof(buffer), "configs/items.kv");
    kv = CreateKeyValues("items");
    FileToKeyValues(kv, buffer);
  }
}
public OnLibraryAdded(const String:name[]) {
  if (StrEqual(name, "sourceirc", false)) {
    IRC_Loaded();
  }
}
public OnPluginEnd() {
  CloseHandle(kv);
  IRC_CleanUp();
}
