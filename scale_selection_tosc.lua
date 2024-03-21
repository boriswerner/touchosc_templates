---root script

NOTENAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
SCALES = {"Major", "Minor", "Harmonic Minor", "Melodic Minor", "Dorian", "Phrygian", "Lydian", "Mixolydian", "Aeolian", "Locrian"}

-- handles
local gridScaleLabel = root.children.gridScaleLabel
local groupnotes = root.children.groupnotes

local music = {}
music.scales = {}
music.scales.dorian =   {2,1,2,2,2,1}
music.scales.phrygian = {1,2,2,2,1,2}
music.scales.lydian = {2,2,2,1,2,2}
music.scales.mixolydian = {2,2,1,2,2,1}
music.scales.aeolian = {2,1,2,2,1,2}
music.scales.locrian = {1,2,2,1,2,2}

music.scales.major = {2,2,1,2,2,2}
music.scales.minor = music.scales.aeolian
music.scales.harmonicminor = {2,1,2,2,1,3}
music.scales.melodicminor = {2,1,2,2,2,2}

music.scales.wholetone = {2,2,2,2,2}

MAJORCHORD = {1,4,5}
MINORCHORD = {1,3,5}

local NOTES = {
		C = 0,
		D = 2,
		E = 4,
		F = 5,
		G = 7,
		A = 9,
		B = 11
}

local NOTE_INTS = {
		'C',
		'C#',
		'D',
		'D#',
		'E',
		'F',
		'F#',
		'G',
		'G#',
		'A',
		'A#',
		'B'
}

function music.noteToInt(note)
		local basenote = note:sub(0,1)
		local modifications = note:sub(2)

		--assert(NOTES[basenote] ~= nil,"Invalid note name: "..note)

		local notenum = NOTES[basenote]

		if (modifications == "#" or modifications == "#m") then
				notenum = notenum + 1
		elseif modifications == "♭" then
				notenum = notenum - 1
		end

		if notenum < 0 then
				notenum = notenum + 12
		elseif notenum > 11 then
				notenum = notenum - 12
		end
		
		return(notenum)
end

function music.intToNote(note)
		note = math.floor(note % 12) -- Idiot proofing.
		return NOTE_INTS[note+1]
end


function music.scale(key,scale)
		local tonic
		if type(key) == "string" then
				tonic = music.noteToInt(key)
		else
				tonic = key
		end

		local retscale = {tonic}
		for _,v in ipairs(scale) do
				tonic = tonic + v
				if tonic > 11 then tonic = tonic - 12 end
				table.insert(retscale,tonic)
		end

		return retscale
end

function init()
  for i = 1, #gridScaleLabel.children do
      gridScaleLabel.children[i].values.text = SCALES[i]
  end
end
function onReceiveNotify(source, string)
  print(string.." from "..source)
  
  print('onValueChanged')
  if(string=='note activated') then
    print(tonumber(source) .. " it is1")
    print(NOTENAMES[tonumber(source)] .. " it is")
    for i = 1, #groupnotes.children do
        if source ~= groupnotes.children[i].name then
          groupnotes.children[i].values.x = 0
        else
          print(music.scale(music.intToNote(tonumber(source)), music.scales.major))
          --groupnotes.children[i].values.x = 1
        end
    end
  end
end




---script for gridScale

local gridScale = root.children.gridScale
function onValueChanged(key)
  print('onValueChanged')
  print('\t', key, '=', self.values[key])
  if(key=='x' and self.values[key]==1) then
    for i = 1, #gridScale.children do
        if self.name ~=  "" .. i then
          gridScale.children[i].values.x = 0
        end
    end
  end
end

---script for note buttons

function onValueChanged(key)
  if  key == 'x' and self.values[key] > 0 then
    self.notify(root, self.name, "note activated")
  end
end
