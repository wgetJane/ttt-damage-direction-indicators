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

local head, tail

local RealTime = RealTime

net.Receive("ttt_dmgdirect", function()
	if not enabled then
		return
	end

	local ind = tail

	tail = {
		false,
		RealTime(),
		net.ReadVector(),
		net.ReadUInt(8) / 255,
	}

	if ind then
		ind[1] = tail
	else
		head = tail
	end
end)

local ScrW, ScrH, render, surface = ScrW, ScrH, render, surface

local rad, deg, pi, min, max, atan2, sin, cos =
	math.rad(1), math.deg(1), math.pi, math.min, math.max, math.atan2, math.sin, math.cos

hook.Add("HUDPaint", "ttt_dmgdirect_HUDPaint", function()
	if not (head and IsValid(localply) and localply:Alive()) then
		return
	end

	local scrw, scrh = ScrW(), ScrH()

	local scale = scrh / 1080

	local eyepos = localply:EyePos()
	local ex, ey, ez = eyepos[1], eyepos[2], eyepos[3]

	local eyeang = localply:EyeAngles()
	local epit, eyaw = eyeang[1] * rad, (eyeang[2] - 180) * rad

	render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)

	surface.SetMaterial(indmat)

	local realtime = RealTime()

	local r, g, b, a = 255, 0, 0, 85

	local prev
	local ind = head
	while ind do
		local lifetime = realtime - ind[2]

		local dmg = ind[4]

		local max_lifetime = 1 + 1 * dmg

		local nxt = ind[1]

		if lifetime > max_lifetime then
			if ind == head then
				head = nxt

				if nxt then
					ind[1] = false
				else
					tail = nil
					break
				end
			else
				prev[1] = nxt

				ind[1] = false
			end
		else
			local lifeperc = lifetime / max_lifetime

			surface.SetDrawColor(r, g, b,
				lifeperc > 0.66 and a * (3 - 3 * lifeperc) or a)

			local pos = ind[3]

			local x, y, z = ex - pos[1], ey - pos[2], ez - pos[3]

			local yaw = atan2(y, x) - eyaw

			local pitch = ((
					atan2(z, (x * x + y * y) ^ 0.5) - epit
				) + pi) % (pi * 2) - pi

			local w = dmg < 0.2 and 8 + 120 * dmg or 16 + 80 * dmg

			local h = 80 + 64 * min(max(pitch * -0.64, -1), 1)

			local radius = 64
				+ 96 * min(eyepos:Distance(pos) * 0.0009765625, 1)
				+ h * 0.5
				+ (lifetime < 0.1 and 320 * (0.1 - lifetime) or 0)

			surface.DrawTexturedRectRotated(
				scrw * 0.5 - radius * sin(yaw) * scale,
				scrh * 0.5 - radius * cos(yaw) * scale,
				w * scale, h * scale, yaw * deg
			)
		end

		prev = ind
		ind = nxt
	end

	render.OverrideBlend(false)
end)
