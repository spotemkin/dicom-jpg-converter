# DICOM to JPG Converter

A powerful bash script for converting DICOM medical images to high-quality JPG format while preserving directory structure and extracting metadata.

## Features

- Converts DICOM files to high-quality JPG images
- Preserves original directory structure
- Extracts and saves detailed metadata for each DICOM file
- Multiple conversion methods for maximum compatibility
- Parallel processing for high performance
- Comprehensive error handling and reporting
- Creates summary reports of conversion process

## Requirements

- Linux/Unix/macOS environment with Bash
- DCMTK (DICOM Toolkit) for DICOM processing
- ImageMagick for image optimization
- Optional: GDCM (Grassroots DICOM) for additional conversion methods

### Installing Dependencies

On Debian/Ubuntu:

```bash
sudo apt-get install dcmtk imagemagick
# Optional:
sudo apt-get install gdcm
```

On macOS (using Homebrew):

```bash
brew install dcmtk imagemagick
# Optional:
brew install gdcm
```

## Usage

1. Place the script in a directory containing DICOM folders or subfolders
2. Make the script executable:
   ```bash
   chmod +x dicom-jpg-converter.sh
   ```
3. Run the script:
   ```bash
   ./dicom-jpg-converter.sh
   ```

### Command Line Options

```
Usage: ./dicom-jpg-converter.sh [OPTIONS]
Options:
  -f, --force       Force overwrite existing output directories
  -j, --jobs N      Number of parallel jobs (default: number of CPU cores)
  -h, --help        Display this help message
```

## How It Works

The script performs the following operations:

1. Identifies directories in the current location (non-recursive)
2. For each directory found, creates a corresponding directory with the "-jpg" suffix
3. Recursively finds all DICOM files within the source directory
4. For each DICOM file:
   - Extracts metadata and saves it to a corresponding .txt file
   - Attempts multiple conversion methods to create high-quality JPG images
   - Optimizes JPG images for clarity and detail
5. Creates a summary report in the output directory with conversion statistics

### Output Structure

For a source directory with this structure:

```
DICOM/
├── 20250517/
│   └── 23380000/
│       ├── 38490074/
│       │   ├── 59268817
│       │   ├── 59268830
│       │   └── ...
│       └── 38490075/
│           ├── 59269044
│           ├── 59269076
│           └── ...
```

The script will create:

```
DICOM-jpg/
├── 20250517/
│   └── 23380000/
│       ├── 38490074/
│       │   ├── 59268817.jpg
│       │   ├── 59268817.txt
│       │   ├── 59268830.jpg
│       │   ├── 59268830.txt
│       │   └── ...
│       └── 38490075/
│           ├── 59269044.jpg
│           ├── 59269044.txt
│           ├── 59269076.jpg
│           ├── 59269076.txt
│           └── ...
└── conversion_summary.txt
```

## Advanced Usage

### Processing Large Datasets

For large datasets, use the `-j` option to specify the number of parallel conversion processes:

```bash
./dicom-jpg-converter.sh -j 8
```

This will run 8 conversion processes in parallel, significantly improving performance on multi-core systems.

### Forcing Reprocessing

If you need to reprocess directories that have already been converted:

```bash
./dicom-jpg-converter.sh -f
```

This will overwrite any existing output directories.

## Troubleshooting

### Failed Conversions

If some DICOM files fail to convert, check the `conversion_summary.txt` file in the output directory for details about which files failed.

Common reasons for failed conversions:

- The file does not contain image data (e.g., it contains only metadata)
- The file is corrupted or uses an uncommon encoding
- The file requires special parameters for conversion

### Metadata Extraction

Even if image conversion fails, the script will still extract metadata to a text file, which can help diagnose issues or provide useful information.

## Issues and Support

If you encounter any issues, please create an issue in the GitHub repository or contact the author at prsl.ru@gmail.com.

## License

This script is provided under the MIT License. Feel free to use, modify, and distribute as needed.

## Acknowledgments

This tool uses the following open-source software:

- [DCMTK](https://dicom.offis.de/dcmtk.php.en) - DICOM Toolkit
- [ImageMagick](https://imagemagick.org/) - Image processing toolkit
- [GDCM](http://gdcm.sourceforge.net/) - Grassroots DICOM library (optional)
