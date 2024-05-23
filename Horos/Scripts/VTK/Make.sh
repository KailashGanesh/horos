#!/bin/sh

set -e; set -o xtrace

# Define the directories
source_dir="$PROJECT_DIR/$TARGET_NAME"
cmake_dir="$TARGET_TEMP_DIR/CMake"
install_dir="$TARGET_TEMP_DIR/Install"

# Ensure the install directory is prepared
[ -d "$install_dir" ] && [ ! -f "$install_dir/.incomplete" ] && exit 0

mkdir -p "$install_dir"
touch "$install_dir/.incomplete"

echo "========= DEBUG ========="
echo "PROJECT_DIR is set to: $PROJECT_DIR"
echo "TARGET_NAME is set to: $TARGET_NAME"
echo "source_dir is set to: $source_dir"
echo "install_dir is set to: $install_dir"
echo "cmake_dir = $cmake_dir"
echo "========= DEBUG ========="

# Copy all files from the external VTK install directory
rsync -av /Users/goiya/Music/VTK-install/ "$install_dir/"

# Ensure missing tiff headers are copied over
mkdir -p "$install_dir/include/vtktiff/libtiff"
find "$source_dir/ThirdParty/tiff/vtktiff/libtiff" -name '*.h' -exec rsync {} "$install_dir/include/vtktiff/libtiff/" \;
rsync "$cmake_dir/ThirdParty/tiff/vtktiff/libtiff/tiffconf.h" "$install_dir/include/vtktiff/libtiff/"

# Wrap the libraries into one (if necessary)
mkdir -p "$install_dir/wlib"
ars=$(find "$install_dir/lib" -name '*.a' -type f)
libtool -static -o "$install_dir/wlib/lib$PRODUCT_NAME.a" $ars

# Clean up the incomplete marker
rm -f "$install_dir/.incomplete"

exit 0
