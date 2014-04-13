# from: https://script.google.com/macros/s/AKfycbxZALVtOKKTOortis-_O_wmDzBfCWnlkoNto-xcVUgcVYLAFulH/exec
# a google script written to pull data from the spreadsheet
json_file = 'json/raw-import.json'

fs		= require 'fs'
sqlite3	= require('sqlite3').verbose()
db 		= new sqlite3.Database 'phish.sqlite3'

jam_leader_alias = "Full-Band": "Full Band", "take turns": "Taking Turns"
placement_alias = "2nd Set Opener": "Set 2 Opener", "Mid-3rd Set": "Mid 3rd Set",
				  "Mid Set": "Mid-set", "Mid-Set": "Mid-set",
				  "3rd Set Opener": "Set 3 Opener", "3rd Set Closer": "Set 3 Closer"
song_alias = "Down with Disease": "Down With Disease"

db.serialize ->
	smt = db.prepare """
			INSERT INTO shows
				(
					researcher, `date`, location, song, placement,
					time, type, genre, species, style,
					coloration, jam_leader, jam_elements,
					notes, notes_time
				)

				VALUES (
					$researcher, $date, $location, $song, $placement,
					$time, $type, $genre, $species, $style,
					$coloration, $jam_leader, $jam_elements,
					$notes, $notes_time
				)
				"""

	json = JSON.parse fs.readFileSync json_file

	for year, shows of json
		has_researcher = false
		notes_index = 15
		notes_timing_index = 16
		jam_elements_indexes = []
		jam_leader_index = 11
		coloration_index = 10

		for show, i in shows
			if i is 0
				notes_index = show.indexOf 'Additional Notes'
				jam_leader_index = show.indexOf 'Jam Leader'
				coloration_index = show.indexOf 'Coloration'

				idx = show.indexOf 'Jam Elements'
				while idx isnt -1
					jam_elements_indexes.push idx
					idx = show.indexOf 'Jam Elements', idx + 1

				if show[0] is "Researcher"
					has_researcher = true
				
				continue

			offset = 0
			if has_researcher
				offset = 1

			date = show[offset + 0].trim().split '/'
			times = show[offset + 5].trim().split(':')[0...2].map (v) -> parseInt v

			jam_elements = []

			for jei in jam_elements_indexes
				if show[jei].trim() isnt ""
					jam_elements.push show[jei].trim()

			jam_leader = show[jam_leader_index].trim()
			placement = show[offset + 4].trim()
			song = show[offset + 3].trim()

			r = {
				$researcher 			: if has_researcher and show[0].trim() isnt "" then show[0].trim() else "UNKNOWN"
				$date 					: if date.length is 3 then "#{date[2]}/#{date[0]}/#{date[1]}" else ""
				$location 				: show[offset + 2].trim()
				$song 					: if song_alias[song] then song_alias[song] else song
				$placement 				: if placement_alias[placement] then placement_alias[placement] else placement
				$time 					: times[0] * 60 + times[1]
				$type 					: show[offset + 6].trim()
				$genre 					: show[offset + 7].trim()
				$species 				: show[offset + 8].trim()
				$style 					: show[offset + 9].trim()
				$coloration 			: if coloration_index > -1 then show[coloration_index].trim() else ""
				$jam_leader 			: if jam_leader_alias[jam_leader] then jam_leader_alias[jam_leader] else jam_leader
				$jam_elements 			: JSON.stringify(jam_elements)
				$notes 					: show[notes_index].trim()
				$notes_time 			: if notes_timing_index is -1 then "" else show[notes_timing_index].trim()
			}

			# validate row

			valid = r.$date isnt "" and r.$song isnt "" and r.$type isnt ""

			if valid
				smt.run r

	smt.finalize()


db.close()
