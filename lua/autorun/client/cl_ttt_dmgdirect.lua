local indmat = Material("materials/ttt_dmgdirect/indicator.png", "mips smooth")

local cvarname = "ttt_dmgdirect_indicators"

local enabled = CreateConVar(
	cvarname, 1, FCVAR_ARCHIVE,
	"Display damage direction indicators"
):GetBool()

cvars.AddChangeCallback(cvarname, function(name, old, new)
	enabled = tonumber(new) == 1
end)

hook.Add("HUDShouldDraw", "ttt_dmgdirect_HUDShouldDraw", function(name)
	if enabled and name == "CHudDamageIndicator" then
		return false
	end
end)

local localply = LocalPlayer()

hook.Add("InitPostEntity", "ttt_dmgdirect_InitPostEntity", function()
	localply = LocalPlayer()
end)

local center_x, center_y = ScrW() / 2, ScrH() / 2

hook.Add("OnScreenSizeChanged", "ttt_dmgdirect_OnScreenSizeChanged", function()
	center_x, center_y = ScrW() / 2, ScrH() / 2
end)

local head, tail

local RealTime = RealTime

net.Receive("ttt_dmgdirect", function()
	if not enabled then
		return
	end

	local len = net.ReadUInt(10) / 1023 * 1024

	local pos = localply:EyePos()

	for i = 1, 3 do
		pos[i] = pos[i] - (net.ReadUInt(10) / (1023 * 0.5) - 1) * len
	end

	local ind = tail

	tail = {
		birth = RealTime(),
		pos = pos,
		dmg = net.ReadUInt(8) / 255,
	}

	if ind then
		ind.nxt = tail
	else
		head = tail
	end
end)

local OverrideBlend, SetMaterial = render.OverrideBlend, surface.SetMaterial
local SetDrawColor, DrawTexturedRectRotated = surface.SetDrawColor, surface.DrawTexturedRectRotated
local min, max = math.min, math.max
local rad, deg, pi = math.rad(1), math.deg(1), math.pi
local atan2, sin, cos = math.atan2, math.sin, math.cos

hook.Add("HUDPaint", "ttt_dmgdirect_HUDPaint", function()
	if not (head and IsValid(localply) and localply:Alive()) then
		return
	end

	local scale = center_y * (2 / 1080)

	local eyepos = localply:EyePos()
	local ex, ey, ez = eyepos[1], eyepos[2], eyepos[3]

	local eyeang = localply:EyeAngles()
	local epit, eyaw = eyeang[1] * rad, (eyeang[2] - 180) * rad

	OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)

	SetMaterial(indmat)

	local realtime = RealTime()

	local r, g, b, a = 255, 0, 0, 85

	local ind, prev = head

	::loop::

	local lifetime = realtime - ind.birth

	local dmg = ind.dmg

	local max_lifetime = 1 + 1 * dmg

	local nxt = ind.nxt

	if lifetime > max_lifetime then
		if prev then
			prev.nxt = nxt

			ind.nxt = nil
		else
			head = nxt

			if nxt then
				ind.nxt = nil
			else
				tail = nil

				goto brk
			end
		end
	else
		local lifeperc = lifetime / max_lifetime

		SetDrawColor(r, g, b,
			lifeperc > (2 / 3) and a * (3 - 3 * lifeperc) or a)

		local pos = ind.pos

		local x, y, z = ex - pos[1], ey - pos[2], ez - pos[3]

		local yaw = atan2(y, x) - eyaw

		local pitch = ((
				atan2(z, (x * x + y * y) ^ 0.5) - epit
			) + pi) % (pi * 2) - pi

		local w = dmg < 0.2 and 8 + 120 * dmg or 16 + 80 * dmg

		local h = 80 + 64 * min(max(pitch * (-1 / 1.57), -1), 1)

		local radius = 64
			+ 96 * min(eyepos:Distance(pos) * (1 / 1024), 1)
			+ h * 0.5
			+ (lifetime < 0.1 and 320 * (0.1 - lifetime) or 0)

		DrawTexturedRectRotated(
			center_x - radius * sin(yaw) * scale,
			center_y - radius * cos(yaw) * scale,
			w * scale, h * scale, yaw * deg
		)
	end

	prev, ind = ind, nxt

	if ind then
		goto loop
	end

	::brk::

	OverrideBlend(false)
end)
