resource.AddSingleFile("materials/ttt_dmgdirect/indicator.png")

util.AddNetworkString("ttt_dmgdirect")

local ttt_dmgdirect_indicators_ignore_silenced = CreateConVar(
	"ttt_dmgdirect_indicators_ignore_silenced", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
	"Don't show damage indicators for damage dealt by silenced weapons in TTT"
)

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

	if dmg <= 0.000001 then
		return
	end

	local attacker = dmginfo:GetAttacker()

	if util.WeaponFromDamage and IsValid(attacker) and attacker:IsPlayer() then
		local val = ttt_dmgdirect_indicators_ignore_silenced:GetInt()

		if val ~= 0 then
			local wep = util.WeaponFromDamage(dmginfo)

			if IsValid(wep)
				and wep.IsSilent
				and (val == 2 or dmginfo:IsBulletDamage())
			then
				return
			end
		end
	end

	local src, pos

	if dmginfo:IsDamageType(DMG_FALL + DMG_DROWN) then
		pos = victim:GetPos()
	else
		src = dmginfo:GetInflictor()

		if IsValid(src) and src:IsWeapon() then
			src = src:GetOwner()
		end

		if not IsValid(src) then
			src = dmginfo:GetAttacker()
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
