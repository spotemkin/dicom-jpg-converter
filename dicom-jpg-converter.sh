#!/bin/bash
# dicom-jpg-converter.sh

# Check if required packages are installed
command -v dcmj2pnm >/dev/null 2>&1 || { echo "dcmtk package is required, install it with 'apt-get install dcmtk' or equivalent command"; exit 1; }
command -v convert >/dev/null 2>&1 || { echo "ImageMagick package is required, install it with 'apt-get install imagemagick' or equivalent command"; exit 1; }
command -v dcmdump >/dev/null 2>&1 || { echo "dcmdump (part of dcmtk) is required, make sure dcmtk is fully installed"; exit 1; }

# Script directory - where the script is located
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR"

# Find all directories in the current folder that might contain DICOM files
# excluding directories that already have -jpg suffix
find . -maxdepth 1 -type d -not -path "*/\.*" -not -name "*-jpg" | while read -r source_dir; do
    # Skip the current directory
    if [ "$source_dir" = "." ]; then
        continue
    fi

    # Get directory name without path
    dir_name=$(basename "$source_dir")

    # Create output directory with -jpg suffix
    output_dir="${dir_name}-jpg"
    mkdir -p "$output_dir"

    echo "Processing directory: $dir_name"
    echo "Output directory: $output_dir"

    # Counter for processed files - using a file to store count
    count_file=$(mktemp)
    echo "0" > "$count_file"

    # Find all regular files in the deepest directories
    find "$source_dir" -type f | while read -r file; do
        # Check if file is a DICOM file using file command
        if file "$file" | grep -i "dicom\|medical image" >/dev/null 2>&1; then
            # Get the relative path within the source directory
            rel_path="${file#$source_dir/}"
            dir_path=$(dirname "$rel_path")

            # Create the same directory structure in output directory
            target_dir="$output_dir/$dir_path"
            mkdir -p "$target_dir"

            # Create output jpg filename - use original filename
            filename=$(basename "$file")
            output_file="$target_dir/${filename}.jpg"
            metadata_file="$target_dir/${filename}.txt"

            echo "Processing DICOM file: $file"

            # First, extract metadata for all DICOM files and save to txt
            echo "Extracting metadata to: $metadata_file"
            echo "DICOM Metadata for: $filename" > "$metadata_file"
            echo "===============================================" >> "$metadata_file"

            # Extract important DICOM metadata tags and format them
            dcmdump "$file" | grep -E "(0008,0020)|(0008,0030)|(0008,0060)|(0008,0070)|(0008,1030)|(0010,0010)|(0010,0020)|(0018,0050)|(0018,0080)|(0018,0081)|(0018,0087)|(0018,0088)|(0018,0095)|(0018,1020)|(0018,1030)|(0018,1314)|(0020,0010)|(0020,0011)|(0020,0012)|(0020,0013)|(0020,0032)|(0020,0037)|(0028,0010)|(0028,0011)|(0028,0030)|(0028,0100)|(0028,0101)|(0028,0102)|(0028,0103)|(0028,0106)|(0028,0107)|(0028,1050)|(0028,1051)|(0028,1052)|(0028,1053)" | while read -r line; do
                # Extract tag and value
                tag=$(echo "$line" | grep -o "(.*)" | tr -d '()')
                value=$(echo "$line" | sed 's/.*\[//' | sed 's/\].*//')

                # Map common DICOM tags to human-readable names
                case "$tag" in
                    "0008,0020") echo "Study Date: $value" >> "$metadata_file" ;;
                    "0008,0030") echo "Study Time: $value" >> "$metadata_file" ;;
                    "0008,0060") echo "Modality: $value" >> "$metadata_file" ;;
                    "0008,0070") echo "Manufacturer: $value" >> "$metadata_file" ;;
                    "0008,1030") echo "Study Description: $value" >> "$metadata_file" ;;
                    "0010,0010") echo "Patient Name: $value" >> "$metadata_file" ;;
                    "0010,0020") echo "Patient ID: $value" >> "$metadata_file" ;;
                    "0018,0050") echo "Slice Thickness: $value mm" >> "$metadata_file" ;;
                    "0018,0080") echo "Repetition Time (TR): $value ms" >> "$metadata_file" ;;
                    "0018,0081") echo "Echo Time (TE): $value ms" >> "$metadata_file" ;;
                    "0018,0087") echo "Magnetic Field Strength: $value T" >> "$metadata_file" ;;
                    "0018,0088") echo "Spacing Between Slices: $value mm" >> "$metadata_file" ;;
                    "0018,0095") echo "Pixel Bandwidth: $value Hz/pixel" >> "$metadata_file" ;;
                    "0018,1020") echo "Software Version: $value" >> "$metadata_file" ;;
                    "0018,1030") echo "Protocol Name: $value" >> "$metadata_file" ;;
                    "0018,1314") echo "Flip Angle: $value degrees" >> "$metadata_file" ;;
                    "0020,0010") echo "Study ID: $value" >> "$metadata_file" ;;
                    "0020,0011") echo "Series Number: $value" >> "$metadata_file" ;;
                    "0020,0012") echo "Acquisition Number: $value" >> "$metadata_file" ;;
                    "0020,0013") echo "Instance Number: $value" >> "$metadata_file" ;;
                    "0020,0032") echo "Image Position: $value" >> "$metadata_file" ;;
                    "0020,0037") echo "Image Orientation: $value" >> "$metadata_file" ;;
                    "0028,0010") echo "Rows: $value" >> "$metadata_file" ;;
                    "0028,0011") echo "Columns: $value" >> "$metadata_file" ;;
                    "0028,0030") echo "Pixel Spacing: $value mm" >> "$metadata_file" ;;
                    "0028,0100") echo "Bits Allocated: $value" >> "$metadata_file" ;;
                    "0028,0101") echo "Bits Stored: $value" >> "$metadata_file" ;;
                    "0028,0102") echo "High Bit: $value" >> "$metadata_file" ;;
                    "0028,0103") echo "Pixel Representation: $value" >> "$metadata_file" ;;
                    "0028,0106") echo "Smallest Value: $value" >> "$metadata_file" ;;
                    "0028,0107") echo "Largest Value: $value" >> "$metadata_file" ;;
                    "0028,1050") echo "Window Center: $value" >> "$metadata_file" ;;
                    "0028,1051") echo "Window Width: $value" >> "$metadata_file" ;;
                    "0028,1052") echo "Rescale Intercept: $value" >> "$metadata_file" ;;
                    "0028,1053") echo "Rescale Slope: $value" >> "$metadata_file" ;;
                esac
            done

            echo "" >> "$metadata_file"
            echo "Full metadata dump:" >> "$metadata_file"
            echo "===============================================" >> "$metadata_file"
            dcmdump "$file" >> "$metadata_file"

            echo "Converting DICOM to JPG..."

            # Try multiple conversion methods, starting with the most aggressive
            if dcmtk-dcmj2pnm --write-jpeg --render-all-frames --min-max-window --compr-quality 100 --use-pixel-spacing --scaling-factor 2.0 "$file" "$output_file" 2>/dev/null; then
                # Update counter
                count=$(<"$count_file")
                count=$((count + 1))
                echo "$count" > "$count_file"

                # Optimize the JPG with ImageMagick to ensure high quality
                convert "$output_file" -auto-level -normalize -quality 100 -density 300 "$output_file.tmp" && mv "$output_file.tmp" "$output_file"

                echo "Successfully converted to: $output_file (method 1)"
            elif gdcm2pnm -i "$file" -o "$output_file" --jpeg 2>/dev/null; then
                # Update counter - using GDCM if installed
                count=$(<"$count_file")
                count=$((count + 1))
                echo "$count" > "$count_file"

                # Optimize
                convert "$output_file" -auto-level -normalize -quality 100 -density 300 "$output_file.tmp" && mv "$output_file.tmp" "$output_file"

                echo "Successfully converted to: $output_file (method 2 - GDCM)"
            elif dcmj2pnm +Wm +oj "$file" "$output_file" 2>/dev/null; then
                # Update counter
                count=$(<"$count_file")
                count=$((count + 1))
                echo "$count" > "$count_file"

                # Optimize
                convert "$output_file" -auto-level -normalize -quality 100 -density 300 "$output_file.tmp" && mv "$output_file.tmp" "$output_file"

                echo "Successfully converted to: $output_file (method 3)"
            else
                # Last resort - force conversion with ImageMagick directly
                convert "$file" -auto-level -normalize -quality 100 -density 300 "$output_file" 2>/dev/null

                if [ -f "$output_file" ] && [ -s "$output_file" ]; then
                    # Update counter
                    count=$(<"$count_file")
                    count=$((count + 1))
                    echo "$count" > "$count_file"

                    echo "Successfully converted to: $output_file (method 4 - ImageMagick direct)"
                else
                    echo "WARNING: Could not convert $file to JPG after multiple attempts"
                    echo "WARNING: This DICOM file may not contain image data"
                    echo "Note: Metadata has been extracted to $metadata_file"
                fi
            fi
        else
            # Debug output to see what files we're finding
            echo "Skipping non-DICOM file: $file"
        fi
    done

    # Get final count
    total_converted=$(<"$count_file")
    rm "$count_file"

    echo "Completed processing directory: $dir_name"
    echo "Total images converted: $total_converted"
    echo "------------------------------------"
done

echo "All conversions completed!"
