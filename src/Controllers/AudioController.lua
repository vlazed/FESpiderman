local feSpiderman = script:FindFirstAncestor("FE-Spiderman")
local PlayerHelper = require(feSpiderman.PlayerHelper)

local AudioController = {}

local hrp

AudioController.WEB_SHOOT_AUDIO_TABLE = {
	"rbxassetid://9119459900",
	"rbxassetid://9119459893",
	"rbxassetid://9119460959",
	"rbxassetid://9119460711",
	"rbxassetid://9119460389",
	"rbxassetid://9119460972",
	"rbxassetid://9119460970",
	"rbxassetid://9119460132",
	"rbxassetid://9119460421",
	"rbxassetid://9119460140",
	"rbxassetid://9119461214",
}

AudioController.WEB_WHIP_AUDIO_TABLE = {
	"rbxassetid://9120629319",
	"rbxassetid://9120629327",
}

AudioController.WEB_IMPACT_AUDIO_TABLE = {
	"rbxassetid://9120628387",
	"rbxassetid://9120628197",
	"rbxassetid://9120627993",
	"rbxassetid://9120628153",
	"rbxassetid://9120628039",
	"rbxassetid://9120628150",
	"rbxassetid://9120628323",
	"rbxassetid://9120628319",
}

function AudioController:Play()

end


function AudioController:PlaySoundAtPart(id, part, volume)
	part = part or workspace
	volume = volume or 0.25

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = false
	sound.Volume = volume
	sound.Parent = part
	sound.PlayOnRemove = true
	sound:Destroy()
end


function AudioController:GrabRandomFromTable(tab)
    return tab[math.random(1, #tab)]
end


function AudioController:Update()
    local bassSound = hrp.Wind
	local trebleSound = hrp.Wind2
	if not bassSound.Playing then
		bassSound:Play()
		trebleSound:Play()
	end

    bassSound.Volume = (hrp.AssemblyLinearVelocity.Magnitude) / 384 + hrp.AssemblyAngularVelocity.Magnitude / 64
	bassSound.Pitch = hrp.AssemblyLinearVelocity.Magnitude^0.8 / 512 + hrp.AssemblyAngularVelocity.Magnitude / 128
	trebleSound.Pitch = hrp.AssemblyLinearVelocity.Magnitude^2 / 384^2 + hrp.AssemblyAngularVelocity.Magnitude / 16
	trebleSound.Volume = hrp.AssemblyLinearVelocity.Magnitude / 2048 + hrp.AssemblyAngularVelocity.Magnitude / 512
end


function AudioController:Init()
    hrp = PlayerHelper:getCharacterHumanoidRootPart()

    local windSound = hrp:FindFirstChild("Wind") or Instance.new("Sound")
	if windSound.Name ~= "Wind" then
		windSound.SoundId = "rbxassetid://9118747525"
		windSound.Volume = 0
		windSound.Pitch = 1
		windSound.Looped = true
		windSound.Name = "Wind"
		windSound.Parent = hrp
	end

	local windDetailedSound = hrp:FindFirstChild("Wind2") or Instance.new("Sound")
	if windDetailedSound.Name ~= "Wind2" then
		windDetailedSound.SoundId = "rbxassetid://5113213873"
		windDetailedSound.Volume = 0
		windDetailedSound.Pitch = 1
		windDetailedSound.Looped = true
		windDetailedSound.Name = "Wind2"
		windDetailedSound.Parent = hrp
	end

	local windReverb = windSound:FindFirstChild("Reverb") or Instance.new("ReverbSoundEffect")
	if windReverb.Name ~= "Reverb" then
		windReverb.Name = "Reverb"
		windReverb.Diffusion = 0
		windReverb.WetLevel = 10
		windReverb.DecayTime = 8
		windReverb.Parent = windSound
	end
	local windDetailedReverb = windDetailedSound:FindFirstChild("ReverbDetailed") or Instance.new("ReverbSoundEffect")
	if windDetailedReverb.Name ~= "ReverbDetailed" then
		windDetailedReverb.Name = "ReverbDetailed"
		windDetailedReverb.Density = 0.5
		windDetailedReverb.Diffusion = 1
		windDetailedReverb.WetLevel = 6
		windDetailedReverb.DecayTime = 8
		windDetailedReverb.Parent = windDetailedSound
	end
	local windDetailedEqual = windDetailedSound:FindFirstChild("EqualDetailed") or Instance.new("EqualizerSoundEffect")
	if windDetailedEqual.Name ~= "EqualDetailed" then
		windDetailedEqual.Name = "EqualDetailed"
		windDetailedEqual.MidGain = 5
		windDetailedEqual.LowGain = -10
		windDetailedEqual.HighGain = 10
		windDetailedEqual.Parent = windDetailedSound
	end
end

return AudioController