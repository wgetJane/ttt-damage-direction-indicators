resource.AddSingleFile("materials/ttt_dmgdirect/indicator.png")

util.AddNetworkString("ttt_dmgdirect")

hook.Add("OnDamagedByExplosion", "ttt_dmgdirect_OnDamagedByExplosion", function()
	return true
end)

local function percent2uint(a, b, c)
	return math.Clamp(math.floor(a / b * c + 0.5), 0, c)
end

hook.Add("PostEntityTakeDamage", "ttt_dmgdirect_PostEntityTakeDamage", function(victim, dmginfo)
	if not (IsValid(victim)
		and victim:IsPlayer()
		and victim:Alive()
	) then
		return
	end

	local dmg = dmginfo:GetDamage()

	if dmg <= 0 then
		return
	end

	local src, pos

	if bit.band(dmginfo:GetDamageType(), DMG_FALL + DMG_DROWN) > 0 then
		pos = victim:GetPos()
	else
		src = dmginfo:GetInflictor()

		if not IsValid(src) or src:IsWeapon() then
			src = src:GetOwner()

			if not IsValid(src) then
				src = dmginfo:GetAttacker()
			end
		end

		if IsValid(src) and not src:IsWorld() then
			pos = src:WorldSpaceCenter()
		end

		if not pos or pos:IsZero() then
			pos = dmginfo:GetDamagePosition()

			if pos:IsZero() then
				pos = victim:EyePos()
			end
		end
	end

	pos:Mul(-1)
	pos:Add(victim:EyePos())

	local len = percent2uint(pos:Length(), 1024, 1023)

	pos:Normalize()

	net.Start("ttt_dmgdirect")

	net.WriteUInt(len, 10)

	for i = 1, 3 do
		net.WriteUInt(percent2uint(pos[i] + 1, 2, 1023), 10)
	end

	net.WriteUInt(percent2uint(dmg, victim:GetMaxHealth(), 255), 8)

	net.Send(victim)
end)
