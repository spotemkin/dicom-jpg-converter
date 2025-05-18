#!/bin/bash
# dicom-jpg-converter.sh

# Display help message
show_help() {
    echo "DICOM to JPG Converter"
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -f, --force       Force overwrite existing output directories"
    echo "  -j, --jobs N      Number of parallel jobs (default: number of CPU cores)"
    echo "  -h, --help        Display this help message"
    echo ""
    echo "This script converts DICOM files in the current directory to JPG format,"
    echo "preserving directory structure and extracting metadata to text files."
    exit 0
}

# Parse command line arguments
FORCE_OVERWRITE=false
PARALLEL_JOBS=$(nproc 2>/dev/null || echo 1)  # Default to number of CPU cores or 1 if nproc not available

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force)
            FORCE_OVERWRITE=true
            shift
            ;;
        -j|--jobs)
            if [[ $2 =~ ^[0-9]+$ ]]; then
                PARALLEL_JOBS=$2
                shift 2
            else
                echo "Error: --jobs requires a numeric argument"
                exit 1
            fi
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Check if required packages are installed
command -v dcmj2pnm >/dev/null 2>&1 || { echo "dcmtk package is required, install it with 'apt-get install dcmtk' or equivalent command"; exit 1; }
command -v convert >/dev/null 2>&1 || { echo "ImageMagick package is required, install it with 'apt-get install imagemagick' or equivalent command"; exit 1; }
command -v dcmdump >/dev/null 2>&1 || { echo "dcmdump (part of dcmtk) is required, make sure dcmtk is fully installed"; exit 1; }
command -v xargs >/dev/null 2>&1 || { echo "xargs is required for parallel processing"; exit 1; }

# For gdcm2pnm, just check and notify, don't exit
if ! command -v gdcm2pnm >/dev/null 2>&1; then
    echo "Note: gdcm2pnm not found. Install GDCM package for additional conversion methods."
fi

# Script directory - where the script is located
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR"

echo "DICOM to JPG Converter"
echo "======================"
echo "Using $PARALLEL_JOBS parallel jobs"
if [ "$FORCE_OVERWRITE" = true ]; then
    echo "Force overwrite mode enabled"
fi
echo ""

# Function to process a single DICOM file
process_dicom_file() {
    local file="$1"
    local source_dir="$2"
    local output_dir="$3"

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

    # Try multiple conversion methods with appropriate scale
    conversion_success=false

    # Method 1
    if dcmj2pnm --write-jpeg --render-all-frames --min-max-window --compr-quality 100 --use-pixel-spacing --scaling-factor 1.0 "$file" "$output_file" 2>/dev/null; then
        # Optimize the JPG with ImageMagick to ensure high quality
        convert "$output_file" -auto-level -normalize -quality 100 -density 300 "$output_file.tmp" && mv "$output_file.tmp" "$output_file"

        echo "Successfully converted to: $output_file (method 1)"
        conversion_success=true
    fi

    # Method 2
    if [ "$conversion_success" = false ] && command -v gdcm2pnm >/dev/null 2>&1; then
        if gdcm2pnm -i "$file" -o "$output_file" --jpeg 2>/dev/null; then
            # Optimize
            convert "$output_file" -auto-level -normalize -quality 100 -density 300 "$output_file.tmp" && mv "$output_file.tmp" "$output_file"

            echo "Successfully converted to: $output_file (method 2 - GDCM)"
            conversion_success=true
        fi
    fi

    # Method 3
    if [ "$conversion_success" = false ]; then
        if dcmj2pnm +Wm +oj "$file" "$output_file" 2>/dev/null; then
            # Optimize
            convert "$output_file" -auto-level -normalize -quality 100 -density 300 "$output_file.tmp" && mv "$output_file.tmp" "$output_file"

            echo "Successfully converted to: $output_file (method 3)"
            conversion_success=true
        fi
    fi

    # Method 4 - Last resort
    if [ "$conversion_success" = false ]; then
        convert "$file" -auto-level -normalize -quality 100 -density 300 "$output_file" 2>/dev/null

        if [ -f "$output_file" ] && [ -s "$output_file" ]; then
            echo "Successfully converted to: $output_file (method 4 - ImageMagick direct)"
            conversion_success=true
        else
            echo "WARNING: Could not convert $file to JPG after multiple attempts"
            echo "WARNING: This DICOM file may not contain image data"
            echo "Note: Metadata has been extracted to $metadata_file"
            # Return failure status
            return 1
        fi
    fi

    # Return success status
    return 0
}

# Export the function for use in subshells
export -f process_dicom_file

# Process each directory
find . -maxdepth 1 -type d -not -path "*/\.*" -not -name "*-jpg" | while read -r source_dir; do
    # Skip the current directory
    if [ "$source_dir" = "." ]; then
        continue
    fi

    # Get directory name without path
    dir_name=$(basename "$source_dir")

    # Create output directory with -jpg suffix
    output_dir="${dir_name}-jpg"

    # Skip this directory if corresponding -jpg directory already exists and force is not enabled
    if [ -d "$output_dir" ] && [ "$FORCE_OVERWRITE" = false ]; then
        echo "Skipping directory $dir_name - output directory $output_dir already exists"
        continue
    elif [ -d "$output_dir" ] && [ "$FORCE_OVERWRITE" = true ]; then
        echo "Force overwrite mode: recreating output directory $output_dir"
        rm -rf "$output_dir"
        mkdir -p "$output_dir"
    else
        mkdir -p "$output_dir"
    fi

    echo "Processing directory: $dir_name"
    echo "Output directory: $output_dir"

    # Create temporary files for tracking
    successful_conversions=$(mktemp)
    failed_conversions=$(mktemp)
    failed_files=$(mktemp)

    echo "0" > "$successful_conversions"
    echo "0" > "$failed_conversions"

    # Find DICOM files and process them in parallel
    echo "Starting parallel processing with $PARALLEL_JOBS jobs..."

    find "$source_dir" -type f | while read -r file; do
        # Check if file is a DICOM file using file command
        if file "$file" | grep -i "dicom\|medical image" >/dev/null 2>&1; then
            echo "$file"
        fi
    done | xargs -n1 -P"$PARALLEL_JOBS" -I{} bash -c '
        # Call the processing function with the file
        if process_dicom_file "{}" "'"$source_dir"'" "'"$output_dir"'"; then
            # If successful, increment the counter
            count=$(<"'"$successful_conversions"'")
            count=$((count + 1))
            echo "$count" > "'"$successful_conversions"'"
        else
            # If failed, increment the counter and log the file
            count=$(<"'"$failed_conversions"'")
            count=$((count + 1))
            echo "$count" > "'"$failed_conversions"'"
            echo "{}" >> "'"$failed_files"'"
        fi
    '

    # Get final counts
    total_converted=$(<"$successful_conversions")
    total_failed=$(<"$failed_conversions")
    total_files=$((total_converted + total_failed))

    # Create summary file
    summary_file="$output_dir/conversion_summary.txt"
    echo "DICOM to JPG Conversion Summary" > "$summary_file"
    echo "===============================" >> "$summary_file"
    echo "Date: $(date)" >> "$summary_file"
    echo "Source directory: $dir_name" >> "$summary_file"
    echo "Output directory: $output_dir" >> "$summary_file"
    echo "" >> "$summary_file"
    echo "Total DICOM files found: $total_files" >> "$summary_file"
    echo "Successfully converted: $total_converted" >> "$summary_file"
    echo "Failed conversions: $total_failed" >> "$summary_file"
    echo "" >> "$summary_file"

    if [ "$total_failed" -gt 0 ]; then
        echo "Files that failed to convert:" >> "$summary_file"
        echo "----------------------------" >> "$summary_file"
        cat "$failed_files" >> "$summary_file"
    fi

    echo "Completed processing directory: $dir_name"
    echo "Total DICOM files found: $total_files"
    echo "Successfully converted: $total_converted"
    echo "Failed conversions: $total_failed"
    if [ "$total_failed" -gt 0 ]; then
        echo "Details about failed conversions can be found in: $summary_file"
    fi
    echo "------------------------------------"

    # Clean up temp files
    rm "$successful_conversions" "$failed_conversions" "$failed_files"
done

echo "All conversions completed!"
