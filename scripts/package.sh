# Go to build dir
cd build

# Create package dir
mkdir -p package/addons/sourcemod/plugins
mkdir -p package/addons/sourcemod/configs
mkdir -p package/addons/sourcemod/gamedata

# Copy all required stuffs to package
cp -r addons/sourcemod/plugins/bounce.smx package/addons/sourcemod/plugins
cp -r ../configs/bounce package/addons/sourcemod/configs
cp -r ../gamedata/bounce.txt package/addons/sourcemod/gamedata
cp -r ../LICENSE package