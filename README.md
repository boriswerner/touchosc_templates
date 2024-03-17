# touchosc_templates

## mixxx_midi_sysex_display.tosc
Visualization of the data send by the mixxx controller script Trackdata_out_via_sysex.midi from https://github.com/Andymann/mixxx-controllers
Will not be updated! E.g. doesn't contain trackinfo lookup (Artist & Title via mixxx_midi_sysex_track_lookup.py)

## mixxx_midi_sysex_display_fretboard.tosc
Visualization of the data send by the mixxx controller script Trackdata_out_via_sysex.midi from https://github.com/Andymann/mixxx-controllers
Including a 4-string bass fretboard visualization of the matching notes from the minor/major scale of the currently playing key.
Scale script adapted from https://github.com/WetDesertRock/music.lua

## mixxx_midi_sysex_track_lookup.py
Python program to receive midi sysex send by the mixxx controller script Trackdata_out_via_sysex.midi from https://github.com/Andymann/mixxx-controllers use the duration, filebpm and filekey information to query the mixxx SQlite database (must be a copy of the senders mixxx database) for title and artist. 
Sends the information via OSC as /deck1_trackinfo and /deck2_trackinfo.
The midi device is remembered but currently not checked before starting midi (might crash the program). Especially if using TouchOSC (bridge) the devices may disappear.
Contains the code to start a receiving OSC server, although it is not used at the moment (but port needs to be configured to start osc)
Mixxx sqlite database under windows can be found at: %localappdata%/Mixxx/mixxxdb.sqlite
The retrieved info might not be unique, the program sends all matching tracks in one message, seperated by newlines!
Duplicates can be found by the following query (e.g using DB Browser (sqlite)):
```
select artist, title, cast(duration as int), round(bpm,1), key, anz_duplikate, duplikat_nummer
from (
	select cast(duration as int) as dur_sel, round(bpm,1) as bpm_sel, key as key_sel, count(*) as anz_duplikate, row_number() over (order by cast(duration as int), round(bpm,1), key) as duplikat_nummer
	from library
	where key is not null
	group by cast(duration as int), round(bpm,1), key
	having count(*)>1
	and (min(lower(artist)) <> max(lower(artist)) or min(lower(title))<>max(lower(title)))
) sel
left join library  on sel.dur_sel = cast(duration as int) and sel.bpm_sel=round(bpm,1) and sel.key_sel = key
order by cast(duration as int), round(bpm,1), key, artist, title
```

## ARM_view_fretboard.tosc
Visualization for Ardour Rehearsal Manager (https://github.com/boriswerner/ArdourRehearsalManager)
Including a 4-string bass fretboard visualization of the matching notes from the minor/major scale of the songs key. Can be changed to any other scale.
Scale script adapted from https://github.com/WetDesertRock/music.lua
