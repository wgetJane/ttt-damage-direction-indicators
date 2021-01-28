resource.AddSingleFile("materials/ttt_dmgdirect/indicator.png")

util.AddNetworkString("ttt_dmgdirect")

hook.Add("OnDamagedByExplosion", "ttt_dmgdirect_OnDamagedByExplosion", function()
	return true
end)

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

	local pos

	if bit.band(dmginfo:GetDamageType(), DMG_FALL + DMG_DROWN) > 0 then
		pos = victim:GetPos()
	else
		pos = dmginfo:GetInflictor()

		if not IsValid(pos) or pos:IsWeapon() then
			pos = dmginfo:GetAttacker()

			if not IsValid(pos) then
				pos = victim
			end
		end

		if pos:IsWorld() then
			pos = dmginfo:GetDamagePosition()
		else
			pos = pos:WorldSpaceCenter()
		end

		if pos:IsZero() then
			pos = victim:EyePos()
		end
	end

	net.Start("ttt_dmgdirect")
	net.WriteVector(pos)
	net.WriteUInt(math.Clamp(math.floor(dmg / victim:GetMaxHealth() * 255 + 0.5), 0, 255), 8)
	net.Send(victim)
end)
