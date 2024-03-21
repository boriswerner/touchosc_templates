SYSEX_MSG_START = "0xF0";
SYSEX_MSG_END = "0xF7";
SYSEX_ID_BPM = "0x7F 0x01 0x1";        -- 5 Bytes, Digit by digit, decimal representation, real-time value
SYSEX_ID_KEY = "0x7F 0x01 0x2";        -- 1 Byte, real-time value
SYSEX_ID_ISPLAYING = "0x7F 0x01 0x3";  -- 1 Byte
SYSEX_ID_CROSSFADER = "0x7F 0x01 0x4"; -- 1 Byte
SYSEX_ID_DURATION = "0x7F 0x02 0x1";   -- 4 Bytes
SYSEX_ID_FILEBPM = "0x7F 0x02 0x2";    -- 5 Bytes (27h max), digit by digit, decimal representation, constant value
SYSEX_ID_FILEKEY = "0x7F 0x02 0x3";    -- 1 Byte, constant value
SYSEX_ID_COLOR = "0x7F 0x02 0x4";    -- Decimal representation of 3 Bytes: 8 digits. 0..16777215, constant value

NOTENAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B", "Cm", "C#m", "Dm", "D#m", "Em", "Fm", "F#m", "Gm", "G#m", "Am", "A#m", "Bm"}
STRING_NOTES = {"G", "G#", "A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B", "C", "C#", "D", "A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "E", "F", "F#", "G", "G#", "A", "A#", "B", "C", "C#", "D", "D#", "E"}

-- handles
local hdl_fretboard1 = root.children.fretboard1
local hdl_fretboard2 = root.children.fretboard2
local hdl_deck_1_bpm    = root.children.deck_1_bpm
local hdl_deck_2_bpm    = root.children.deck_2_bpm
local hdl_deck_1_key    = root.children.deck_1_key
local hdl_deck_2_key    = root.children.deck_2_key
local hdl_deck_1_playbutton    = root.children.deck_1_playbutton
local hdl_deck_2_playbutton    = root.children.deck_2_playbutton
local hdl_deck_1_lbl    = root.children.deck_1_lbl
local hdl_deck_2_lbl    = root.children.deck_2_lbl
local hdl_deck_1_trackinfo    = root.children.deck1_trackinfo
local hdl_deck_2_trackinfo   = root.children.deck2_trackinfo
local hdl_deck_1_filebpm    = root.children.deck_1_filebpm
local hdl_deck_2_filebpm    = root.children.deck_2_filebpm
local hdl_deck_1_filekey    = root.children.deck_1_filekey
local hdl_deck_2_filekey    = root.children.deck_2_filekey
local hdl_deck_1_duration    = root.children.deck_1_duration
local hdl_deck_2_duration    = root.children.deck_2_duration
--local hdl_deck_1_color    = root.children.deck_1_color
--local hdl_deck_2_color    = root.children.deck_2_color
local hdl_crossfader    = root.children.crossfader

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

function onReceiveMIDI(message, connections)
  loop_condition = true
  print('onReceiveMIDI')
  print('\t message     =', table.unpack(message))
  if(message[1] == 0xF0 and message[2] == 0x7F) then
    print('sysex mixxx')
    index = 3;
    while(loop_condition) do
      print("while start " .. index)
      --bpm
      if(message[index] == 0x01 and (message[index+1] == 0x11 or message[index+1] == 0x12 or message[index+1] == 0x10) ) then
        print("bpm")         
        bpm_deck = (
          tonumber(message[index+2]) .. 
          tonumber(message[index+3]) .. 
          tonumber(message[index+4]) .. "." .. 
          tonumber(message[index+5]) .. 
          tonumber(message[index+6])
        ) 
        if(message[index+1] == 0x11) then 
          print("Deck 1 BPM: " .. bpm_deck)
          hdl_deck_1_bpm.values.text = bpm_deck 
        end if(message[index+1] == 0x12) then
          print("Deck 2 BPM: " .. bpm_deck)
          hdl_deck_2_bpm.values.text = bpm_deck 
        end
        index = index + 7
      
      --key
      elseif(message[index] == 0x01 and (message[index+1] == 0x21 or message[index+1] == 0x22 or message[index+1] == 0x20) ) then
        key = NOTENAMES[tonumber(message[index+2])]
        --Minor or Major scale
        local scale = music.scales.major
        local keyChar2 = key:sub(2)
        local keyChar3 = key:sub(3)
        if(keyChar2 == "m" or keyChar3 == "m") then
          scale = music.scales.minor
          print("Minor: "..keyChar2.." "..keyChar3)
        else 
          print("Major: "..keyChar2.." "..keyChar3)
        end
  
        local scaleTable = {}
        for _,n in ipairs(music.scale(key,scale)) do
            scaleTable[n] = true;
        end
        
        local terz = music.noteToInt(key)+4
        if(scale == music.scales.minor) then
          terz = music.noteToInt(key)+3
        end
        if terz > 11 then terz = terz - 12 end
        local quinte = music.noteToInt(key)+7
        if quinte > 11 then quinte = quinte - 12 end
        
        if(message[index+1] == 0x21) then 
          print("Deck 1 Key: " .. key)
          hdl_deck_1_key.values.text = key 

          for i = 1, #hdl_fretboard1.children do
          local noteInt = music.noteToInt(STRING_NOTES[i]);
            if(scaleTable[noteInt]) then
              print("Note: "..music.intToNote(noteInt).. " int: " .. noteInt .. " key: "..key.." int: "..music.noteToInt(key))
                hdl_fretboard1.children[i].values.text = STRING_NOTES[i]
              if(noteInt == music.noteToInt(key)) then
                hdl_fretboard1.children[i].color = Color.fromHexString('0000FFFF');
              elseif(noteInt == terz or noteInt == quinte) then
                hdl_fretboard1.children[i].color = Color.fromHexString('00FFFFFF');
              else
                hdl_fretboard1.children[i].color = Color.fromHexString('11FF36FF');
              end
            else 
              hdl_fretboard1.children[i].values.text = ""
              hdl_fretboard1.children[i].color = Color.fromHexString('FF0000FF');
            end
          end
        end if(message[index+1] == 0x22) then
          print("Deck 2 Key: " .. key)
          hdl_deck_2_key.values.text = key 
          
          for i = 1, #hdl_fretboard2.children do
          local noteInt = music.noteToInt(STRING_NOTES[i]);
            if(scaleTable[noteInt]) then
              print("Note: "..music.intToNote(noteInt).. " int: " .. noteInt .. " key: "..key.." int: "..music.noteToInt(key))
                hdl_fretboard2.children[i].values.text = STRING_NOTES[i]
              if(noteInt == music.noteToInt(key)) then
                hdl_fretboard2.children[i].color = Color.fromHexString('0000FFFF');
              elseif(noteInt == terz or noteInt == quinte) then
                hdl_fretboard2.children[i].color = Color.fromHexString('00FFFFFF');
              else
                hdl_fretboard2.children[i].color = Color.fromHexString('11FF36FF');
              end
            else 
              hdl_fretboard2.children[i].values.text = ""
              hdl_fretboard2.children[i].color = Color.fromHexString('FF0000FF');
            end
          end
        end
        index = index + 3
      
      --isplaying
      elseif(message[index] == 0x01 and (message[index+1] == 0x31 or message[index+1] == 0x32 or message[index+1] == 0x30) ) then
        print("isplaying" .. message[index+2])
        if (message[index+1] == 0x31) then
          if (message[index+2] == 0x01) then 
            hdl_deck_1_playbutton.visible = true 
            hdl_deck_1_lbl.color =      Color.fromHexString('11FF36FF')
            hdl_deck_1_trackinfo =      Color.fromHexString('11FF36FF')
            hdl_deck_1_bpm.color =      Color.fromHexString('11FF36FF')
            hdl_deck_1_key.color =      Color.fromHexString('11FF36FF')
            hdl_deck_1_filebpm.color =  Color.fromHexString('11FF36FF')
            hdl_deck_1_filekey.color =  Color.fromHexString('11FF36FF')           
            hdl_deck_1_duration.color = Color.fromHexString('11FF36FF')
          else 
            hdl_deck_1_playbutton.visible = false
            hdl_deck_1_lbl.color =      Color.fromHexString('FF0000FF')
            hdl_deck_1_trackinfo =      Color.fromHexString('FF0000FF')
            hdl_deck_1_bpm.color =      Color.fromHexString('FF0000FF')
            hdl_deck_1_key.color =      Color.fromHexString('FF0000FF')
            hdl_deck_1_filebpm.color =  Color.fromHexString('FF0000FF')
            hdl_deck_1_filekey.color =  Color.fromHexString('FF0000FF')           
            hdl_deck_1_duration.color = Color.fromHexString('FF0000FF')
          end
        elseif (message[index+1] == 0x32) then
          if (message[index+2] == 0x01) then 
            hdl_deck_2_playbutton.visible = true 
            hdl_deck_2_lbl.color =      Color.fromHexString('11FF36FF')
            hdl_deck_2_trackinfo =      Color.fromHexString('11FF36FF')
            hdl_deck_2_bpm.color =      Color.fromHexString('11FF36FF')
            hdl_deck_2_key.color =      Color.fromHexString('11FF36FF')
            hdl_deck_2_filebpm.color =  Color.fromHexString('11FF36FF')
            hdl_deck_2_filekey.color =  Color.fromHexString('11FF36FF')           
            hdl_deck_2_duration.color = Color.fromHexString('11FF36FF')
          else 
            hdl_deck_2_playbutton.visible = false 
            hdl_deck_2_lbl.color =      Color.fromHexString('FF0000FF')
            hdl_deck_2_trackinfo =      Color.fromHexString('FF0000FF')
            hdl_deck_2_bpm.color =      Color.fromHexString('FF0000FF')
            hdl_deck_2_key.color =      Color.fromHexString('FF0000FF')
            hdl_deck_2_filebpm.color =  Color.fromHexString('FF0000FF')
            hdl_deck_2_filekey.color =  Color.fromHexString('FF0000FF')           
            hdl_deck_2_duration.color = Color.fromHexString('FF0000FF')
          end
        end
        index = index + 3
      
      --crossfader
      elseif(message[index] == 0x01 and (message[index+1] == 0x41 or message[index+1] == 0x42 or message[index+1] == 0x40)) then
        print("crossfader" .. tonumber(message[index+2]))
        hdl_crossfader.values.x = message[index+2]/127
        index = index + 3
      
      --duration
      elseif(message[index] == 0x02 and (message[index+1] == 0x11 or message[index+1] == 0x12 or message[index+1] == 0x10) ) then
        print("duration")
        duration = (
          tonumber(message[index+2]) .. 
          tonumber(message[index+3]) .. 
          tonumber(message[index+4]) ..
          tonumber(message[index+5]) .. 
          tonumber(message[index+6])
        ) 
        if(tonumber(duration) < 3600) then
          duration_string = string.format("%.2d:%.2d", duration/60%60, duration%60)
        else 
          duration_string = string.format("%.2d:%.2d:%.2d", duration/(60*60), duration/60%60, duration%60)
        end
        
        if(message[index+1] == 0x11) then 
          print("Deck 1 duration: " .. duration_string)
          hdl_deck_1_duration.values.text = duration_string 
        end if(message[index+1] == 0x12) then
          print("Deck 2 duration: " .. duration_string)
          hdl_deck_2_duration.values.text = duration_string 
        end
        index = index + 7
      
      --filebpm
      elseif(message[index] == 0x02 and (message[index+1] == 0x21 or message[index+1] == 0x22 or message[index+1] == 0x20) ) then
        print("filebpm")
        filebpm = (
          tonumber(message[index+2]) .. 
          tonumber(message[index+3]) .. 
          tonumber(message[index+4]) .. "." .. 
          tonumber(message[index+5]) .. 
          tonumber(message[index+6])
        ) 
        if(message[index+1] == 0x21) then 
          print("Deck 1 filebpm: " .. filebpm)
          hdl_deck_1_filebpm.values.text = filebpm 
        end if(message[index+1] == 0x22) then
          print("Deck 2 filebpm: " .. filebpm)
          hdl_deck_2_filebpm.values.text = filebpm 
        end
        index = index + 7
      
      
      --filekey
      elseif(message[index] == 0x02 and (message[index+1] == 0x31 or message[index+1] == 0x32 or message[index+1] == 0x30) ) then
        print("filekey")
        filekey = NOTENAMES[tonumber(message[index+2])]
        if(message[index+1] == 0x31) then 
          print("Deck 1 filekey: " .. filekey)
          hdl_deck_1_filekey.values.text = filekey 
        end if(message[index+1] == 0x32) then
          print("Deck 2 filekey: " .. filekey)
          hdl_deck_2_filekey.values.text = filekey 
        end
        index = index + 3
      
      
      --color
      elseif(message[index] == 0x02 and (message[index+1] == 0x41 or message[index+1] == 0x42 or message[index+1] == 0x40) ) then
        print("color")
        color = (
          tonumber(message[index+2]) .. 
          tonumber(message[index+3]) .. 
          tonumber(message[index+4]) .. 
          tonumber(message[index+5]) .. 
          tonumber(message[index+6]) .. 
          tonumber(message[index+7]) .. 
          tonumber(message[index+8]) .. 
          tonumber(message[index+9])
        ) 
        print("Color: " .. color)
        index = index + 10
      
      --no match
      else 
        loop_condition=false
        break
      end
      
      
      --end loop check
      if(loop_condition and message[index] == 0x7F) then 
        loop_condition=true
        index = index + 1
      else loop_condition=false
      end
    print("while end" .. tostring(loop_condition) .. " " .. message[index])
    end
  end
end