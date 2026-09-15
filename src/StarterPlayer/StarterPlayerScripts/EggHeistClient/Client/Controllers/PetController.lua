-- EggHeist | Client/Controllers/PetController.lua

local PetController = {}
local ctx = nil

function PetController.Init(context)
	ctx = context
end

function PetController.Equip(petUid)
	ctx.Net.Fire("EquipPet", petUid)
end

function PetController.Unequip(petUid)
	ctx.Net.Fire("UnequipPet", petUid)
end

function PetController.Sell(petUid)
	ctx.Net.Fire("SellPet", petUid)
end

function PetController.Delete(petUid)
	ctx.Net.Fire("DeletePet", petUid)
end

function PetController.Start()
end

return PetController
