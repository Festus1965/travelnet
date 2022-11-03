--[[
	Teleporter networks that allow players to choose a destination out of a list
	Copyright (C) 2013 Sokomine

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.

--]]

-- integration test
if minetest.settings:get_bool("travelnet.enable_travelnet_integration_test") then
	dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/integration_test.lua")
end

-- Required to save the travelnet data properly in all cases
if not minetest.safe_file_write then
	error("[Mod travelnet] Your Minetest version is no longer supported. (version < 0.4.17)")
end

travelnet = {}

travelnet.player_formspec_data = {}
travelnet.targets = {}
travelnet.path = minetest.get_modpath(minetest.get_current_modname())

local function mod_dofile(filename)
	dofile(travelnet.path .. "/"..filename..".lua")
end

-- privs
mod_dofile("privs")

-- read the configuration
mod_dofile("config")

-- saving / reading
mod_dofile("persistence")

-- common functions
mod_dofile("functions")
mod_dofile("actions/main")

-- formspec stuff
mod_dofile("formspecs")
mod_dofile("formspecs-legacy")

-- travelnet / elevator update
mod_dofile("update_formspec")

-- add button
mod_dofile("add_target")

-- receive fields handler
mod_dofile("on_receive_fields")

-- meta-formspec migration lbm
if travelnet.travelnet_cleanup_lbm then
	mod_dofile("migrate_formspecs_lbm")
end

-- invisible node to place inside top of travelnet box and elevator
minetest.register_node("travelnet:hidden_top", {
	drawtype = "nodebox",
	paramtype = "light",
	sunlight_propagates = true,
	pointable = false,
	diggable = false,
	drop = "",
	groups = { not_in_creative_inventory=1 },
	tiles = { "travelnet_blank.png" },
	use_texture_alpha = "clip",
	node_box = {
		type = "fixed",
		fixed = { -0.5, 0.45, -0.5, 0.5, 0.5, 0.5 },
	},
	collision_box = {
		type = "fixed",
		fixed = { -0.5, 0.45, -0.5, 0.5, 0.5, 0.5 },
	},
})


if travelnet.travelnet_effect_enabled then
	minetest.register_entity("travelnet:effect", {
		hp_max = 1,
		physical = false,
		weight = 5,
		collisionbox = { -0.4, -0.5, -0.4, 0.4, 1.5, 0.4 },
		visual = "upright_sprite",
		visual_size = { x=1, y=2 },
		textures = { "travelnet_flash.png" }, -- number of required textures depends on visual
		spritediv = { x=1, y=1 },
		initial_sprite_basepos = { x=0, y=0 },
		is_visible = true,
		makes_footstep_sound = false,
		automatic_rotate = true,

		anz_rotations = 0,

		on_step = function(self)
			-- this is supposed to be more flickering than smooth animation
			self.object:set_yaw(self.object:get_yaw()+1)
			self.anz_rotations = self.anz_rotations+1
			-- eventually self-destruct
			if self.anz_rotations > 15 then
				self.object:remove()
			end
		end
	})
end


-- basic travelling stuff -- in at 04.08./15.04.2022 from Pandorabox be Thomas (again)
travelnet.allow_travel = function( player_name, owner_name, network_name, station_name_start, station_name_target )

	local has_override_priv = minetest.check_player_privs(player_name, { protection_bypass=true })
	if has_override_priv then
		-- admin can go everywhere...
		return true
	end

	-- extracted target pos
	local target_pos

	-- sanity check
	if travelnet.targets[owner_name] and travelnet.targets[owner_name][network_name] and
		travelnet.targets[owner_name][network_name][station_name_target] then
		target_pos = travelnet.targets[owner_name][network_name][station_name_target].pos
	else
		-- error!
		return false
	end

	-- protected target with "(P) name"
--	if station_name_target and string.sub(station_name_target, 1, 3) == "(P)" then
		if travelnet.targets[owner_name] and travelnet.targets[owner_name][network_name] and
				travelnet.targets[owner_name][network_name][station_name_target] then

			minetest.load_area(target_pos)
			if minetest.is_protected(target_pos, player_name) then
				minetest.chat_send_player(player_name, "This station is protected!")
				return false
			end
		end
--	end

	-- check if player can teleport there
	local player = minetest.get_player_by_name(player_name)
--	local can_teleport, err_msg = pandorabox.can_teleport(player, target_pos)

	local err_msg
	if err_msg then
		minetest.chat_send_player(player_name, err_msg)
	end

--	return can_teleport
	return true

end



if travelnet.travelnet_enabled then
	-- register-functions for travelnet nodes
	mod_dofile("register_travelnet")
	-- default travelnet registrations
	mod_dofile("travelnet")
end
if travelnet.elevator_enabled then
	mod_dofile("elevator")  -- allows up/down transfers only
end
if travelnet.doors_enabled then
	-- doors that open and close automaticly when the travelnet or elevator is used
	mod_dofile("doors")
end

if travelnet.enable_abm then
	-- restore travelnet data when players pass by broken networks
	mod_dofile("restore_network_via_abm")
end

-- upon server start, read the savefile
travelnet.restore_data()
travelnet.player_formspec_data = nil


modcounter = modcounter + 1
-- from https://github.com/mt-mods/travelnet
print("[Mod] travelnet + (P)edit (a436c1b / 24.02.2022) - (" .. modcounter .. ") end with "..math.floor(collectgarbage("count")).." KB")
