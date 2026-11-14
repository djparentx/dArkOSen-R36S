#!/bin/bash

bg_path="/roms/themes/es-theme-retrodark/_inc/images"
bg_src="$bg_path/1280_background.png"
# copy theme bg_paths
sudo cp -f "$bg_src" "$bg_path/background.png" &&
sudo cp -f "$bg_src" "$bg_path/background_basic.png" &&
sudo cp -f "$bg_src" "$bg_path/background_video.png" &&

# copy loading image
sudo cp -f /roms/launchimages/1280_loading.jpg /roms/launchimages/loading.jpg &&
sudo touch "$bg_path/.done"

if [[ -f "$bg_path/.done" ]]; then
	sudo rm -f "$0"
fi