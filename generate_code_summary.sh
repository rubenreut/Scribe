#!/bin/bash

OUTPUT_FILE="scribe_code_summary.txt"
PROJECT_DIR="/Users/rubenreut/Scribe"

# Initialize the output file
> "$PROJECT_DIR/$OUTPUT_FILE"

# Find all Swift files except those in test directories
find "$PROJECT_DIR" -name "*.swift" \
    -not -path "*/ScribeTests/*" \
    -not -path "*/ScribeUITests/*" | sort | while read -r file; do
    
    # Get relative path for cleaner output
    relative_path=${file#"$PROJECT_DIR/"}
    
    # Add file separator with file name
    echo -e "\n\n######## $relative_path ########\n" >> "$PROJECT_DIR/$OUTPUT_FILE"
    
    # Append file contents
    cat "$file" >> "$PROJECT_DIR/$OUTPUT_FILE"
done

echo "Code summary generated at: $PROJECT_DIR/$OUTPUT_FILE"