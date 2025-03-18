local indmat = Material("materials/ttt_dmgdirect/indicator.png", "mips smooth")
indmat:SetInt("$flags", 16 + 32 + 128)

local cvarname = "ttt_dmgdirect_indicators"

local enabled = CreateConVar(
	cvarname, "1", FCVAR_ARCHIVE,
	"Display damage direction indicators"
):GetBool()

cvars.AddChangeCallback(cvarname, function(name, old, new)
	enabled = (tonumber(new) or 0) ~= 0
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

local pool_size, pool = 0

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

	local push
	if pool then
		push = pool

		pool = push.nxtpool

		pool_size = pool_size - 1
	else
		push = {0, 0, 0}
	end

	push.birth = RealTime()
	push.dmg = net.ReadUInt(8) / 255
	push[1], push[2], push[3] = pos.x, pos.y, pos.z

	tail = push

	if ind then
		ind.nxt = tail
	else
		head = tail
	end
end)

local SetMaterial, SetDrawColor, DrawTexturedRectRotated =
	surface.SetMaterial, surface.SetDrawColor, surface.DrawTexturedRectRotated
local min, max, atan2, sin, cos =
	math.min, math.max, math.atan2, math.sin, math.cos

hook.Add("HUDPaint", "ttt_dmgdirect_HUDPaint", function()
	if not head then
		return
	end

	if not (IsValid(localply) and localply:Alive()) then
		local ind = head
		head, tail = nil, nil

		::clear::

		if pool_size < 8 then
			ind.nxtpool = pool

			pool = ind

			pool_size = pool_size + 1
		else
			ind.nxtpool = nil
		end

		local nxt = ind.nxt

		if nxt then
			ind.nxt = nil

			ind = nxt

			goto clear
		end

		return
	end

	local realtime = RealTime()

	local r, g, b, a = 255, 0, 0, 85

	local scale = center_y * (2 / 1080)

	local eyepos = localply:EyePos()
	local ex, ey, ez = eyepos[1], eyepos[2], eyepos[3]

	local eyeang = localply:EyeAngles()
	local epit, eyaw = eyeang[1], (eyeang[2] - 180) * 0.017453292519943

	SetMaterial(indmat)

	local ind, prev = head

	::loop::

	local lifetime = realtime - ind.birth

	local dmg = ind.dmg

	local max_lifetime = 1 + 1 * dmg

	local nxt = ind.nxt

	if lifetime > max_lifetime then
		if pool_size < 8 then
			ind.nxtpool = pool

			pool = ind

			pool_size = pool_size + 1
		else
			ind.nxtpool = nil
		end

		ind.nxt = nil

		prev, ind = ind, prev

		if prev == head then
			head = nxt

			if not nxt then
				tail = nil

				return
			end
		else
			ind.nxt = nxt
		end
	else
		local lifeperc = lifetime / max_lifetime

		SetDrawColor(r, g, b,
			lifeperc > (2 / 3) and a * (3 - 3 * lifeperc) or a)

		local x, y, z = ex - ind[1], ey - ind[2], ez - ind[3]
		local dist2dsq = x * x + y * y
		local dist3dsq = dist2dsq + z * z

		local yaw = atan2(y, x) - eyaw

		local pitch = (
			180 - epit + atan2(z, dist2dsq ^ 0.5) * 57.295779513082
		) % 360 - 180

		local w = dmg < 0.2 and 8 + 120 * dmg or 16 + 80 * dmg

		local h = 80 + 64 * min(max(pitch * (-1 / 90), -1), 1)

		local radius = 64
			+ 96 * min(dist3dsq ^ 0.5 * (1 / 1024), 1)
			+ h * (425 / 512 * 0.5)
			+ (lifetime < 0.1 and 320 * (0.1 - lifetime) or 0)

		DrawTexturedRectRotated(
			center_x - radius * sin(yaw) * scale,
			center_y - radius * cos(yaw) * scale,
			w * scale, h * scale * (512 / 425), yaw * 57.295779513082
		)
	end

	prev, ind = ind, nxt

	if ind then
		goto loop
	end
end)
