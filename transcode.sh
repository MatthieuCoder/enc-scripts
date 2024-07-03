#!/bin/bash

mkdir -p {output/,temp/}
rm -rf temp/*
for filename in source/*.mkv; do
    [ -e "$filename" ] || continue
    file="output/$(basename -- "$filename")"
    HandBrakeCLI --preset-import-file profile.json --comb-detect permissive -d -i "$filename" -o "$file"
    fullpath=$(realpath "$file")

    # List all subtitle tracks
    subtitles_tracks=$(mkvmerge -i "$fullpath" | grep VobSub | sed 's/[^0-9]*//g')

    # Stripe the subtitles from the mkv file
    mkvmerge -o "temp/current.mkv" --no-subtitles "$fullpath"
    for track in $subtitles_tracks
    do
        # Extract idx and sub files from the mkv file
        mkvextract tracks "$fullpath" $track:temp/subtitles$track.vob
        echo "Extracted track $track in $(realpath temp/subtitles$track.vob)"

        # Convert idx and sub files to srt
        vobsub2srt "temp/subtitles$track"
        rm temp/subtitles$track.{idx,sub}

        # Language codes extraction
        lang=$(mkvmerge -J "$fullpath" | jq -r ".tracks[] | select(.type == \"subtitles\") | select(.id == $track) | .properties.language")
        # Add the srt file to the mkv
        mkvmerge -o temp/output.mkv "temp/current.mkv" --language 0:$lang "$(realpath temp/subtitles$track.srt)"
        mv temp/output.mkv "temp/current.mkv"

        # Cleanup
        rm temp/subtitles$track.srt
    done
    rm "$fullpath"
    mv "temp/current.mkv" "$fullpath"
done
