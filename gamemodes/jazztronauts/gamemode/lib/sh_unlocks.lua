if SERVER then 
	util.AddNetworkString( "unlock_msg" )
	AddCSLuaFile("sh_unlocks.lua")
end

module( "unlocks", package.seeall )

local unlock_lists = {}

function Register( list_name )

	if unlock_lists[list_name] then return end

	if CLIENT then 

		unlock_lists[list_name] = {}

	else

		local table_name = "unlocklist_" .. list_name
		local columns = "steamid bigint(64) DEFAULT '0', strkey varchar(32)"

		--for testing
		--sql.Query( "DROP TABLE " .. table_name )

		if not sql.TableExists( table_name ) then

			--deal with it
			if false == sql.Query( ("CREATE TABLE %s (%s)"):format(table_name, columns) ) then
				print("ERROR: " .. tostring( sql.LastError() ) )
			end
		end

		unlock_lists[list_name] = table_name

	end

end

function IsUnlocked( list_name, ply, key )

	if CLIENT then

		return unlock_lists[list_name][key] or false

	else

		if not unlock_lists[list_name] then return false end
		local steam_id = ply:SteamID64()
		local result = sql.Query( ("SELECT * FROM %s WHERE steamid = '%s' AND strkey = '%s'"):format( 
			unlock_lists[list_name],
			steam_id,
			key ) )

		if false == result then
			print("ERROR: " .. tostring( sql.LastError() ) )
			return false
		end

		return result ~= nil

	end

	return false

end

function Unlock( list_name, ply, key )

	if not unlock_lists[list_name] then return false end
	if IsUnlocked( list_name, ply, key ) then return false end

	if CLIENT then

		unlock_lists[list_name][key] = true
		hook.Call( "OnUnlocked", nil, list_name, key, ply )
		return true

	end

	local steam_id = ply:SteamID64()
	local result = sql.Query( ("INSERT INTO %s VALUES ('%s','%s')"):format( 
		unlock_lists[list_name],
		steam_id,
		key ) )

	if false == result then
		print("ERROR: " .. tostring( sql.LastError() ) )
		return false
	end

	hook.Call( "OnUnlocked", nil, list_name, key, ply )

	net.Start( "unlock_msg" )
	net.WriteString( list_name )
	net.WriteString( key )
	net.Send( ply )

	return true

end

function GetAll( list_name, ply )

	local steam_id = ply:SteamID64()
	local result = sql.Query( ("SELECT * FROM %s WHERE steamid = '%s'"):format( 
		unlock_lists[list_name],
		steam_id ) )

	if false == result then
		print("ERROR: " .. tostring( sql.LastError() ) )
		return false
	end

	local t = {}
	for k,v in pairs( result or {} ) do
		table.insert(t, v.strkey)
	end

	return t

end

if CLIENT then

	net.Receive( "unlock_msg", function()

		local list_name = net.ReadString()
		local key = net.ReadString()

		if not unlock_lists[list_name] then
			Register( list_name )
		end

		Unlock( list_name, LocalPlayer(), key )
		
	end )

end

--DOWNLOADING

local function EncodeList( list_name, ply )

	local blob = list_name .. '\0'

	for x, str in pairs( GetAll( list_name, ply ) ) do 
		blob = blob .. str .. '\0'
	end

	return blob

end

local function DecodeList( blob )

	local buf = ""
	local strings = {}

	for i=1, #blob do
		if blob[i] == '\0' then
			table.insert( strings, buf )
			buf = ""
		else
			buf = buf .. blob[i]
		end
	end

	local name = strings[1]
	table.remove( strings, 1 )

	return name, strings

end

download.Register( "download_unlocks", function( cb, dl )

	if CLIENT then

		if cb == DL_FINISHED then

			local list_name, strings = DecodeList( dl:GetData() )

			for _, key in pairs( strings ) do

				Unlock( list_name, LocalPlayer(), key )

			end

		end

	else

		if cb == DL_PROGRESS then

			print( dl.list_name .. " : " .. tostring(dl:GetPlayer()) .. " : " .. tostring(dl))

		end

	end

end )

function DownloadToPlayer( list_name, ply )

	if CLIENT then return end

	local data = EncodeList( list_name, ply )
	if #data > 0 then
		local dl = download.Start( "download_unlocks", data, ply, 1024 )
		if dl then
			dl.list_name = list_name
		end
	end

end

hook.Add( "PlayerInitialSpawn", "download_unlocks", function(ply)

	for list_name, _ in pairs( unlock_lists ) do

		DownloadToPlayer( list_name, ply )
		
	end

end )


hook.Add( "OnUnlocked", "unlock_test", function( list_name, key, ply ) 

	print( ("  UNLOCKED[ %s ] => %s (for %s)" ):format( list_name, key, tostring(ply) ) )

end )


--[[Register("ballocs")
Unlock("ballocs", player.GetAll()[1], "props/props_static/this_prop_sucks.mdl")
Unlock("ballocs", player.GetAll()[1], "props/props_dynamic/this_prop_sucks_too.mdl")
Unlock("ballocs", player.GetAll()[1], "props/props_dynamic/this_prop_sucks_too.mdl")
Unlock("ballocs", player.GetAll()[1], "props/props_junk/fuck_this.mdl")


DownloadToPlayer("ballocs", player.GetAll()[1])]]