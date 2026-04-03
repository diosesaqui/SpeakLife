#!/bin/bash

# Function to add Swift files to Xcode project
add_swift_files() {
    echo "🔍 Looking for untracked Swift files..."
    
    # Get untracked Swift files
    untracked_swift_files=$(git ls-files --others --exclude-standard | grep '\.swift$' | grep '^SpeakLife/')
    
    if [ -z "$untracked_swift_files" ]; then
        echo "✅ No untracked Swift files found"
        return 0
    fi
    
    echo "📁 Found untracked Swift files:"
    echo "$untracked_swift_files" | sed 's/^/  - /'
    
    echo ""
    echo "⚠️  These files need to be manually added to Xcode:"
    echo "1. Open Xcode"
    echo "2. Right-click on the appropriate folder in the navigator"
    echo "3. Select 'Add Files to SpeakLife'"
    echo "4. Navigate to and select these files:"
    echo "$untracked_swift_files" | sed 's/^/   • /'
    echo ""
    echo "Or install xcodeproj gem and run: ruby auto_add_files.rb"
    echo "  gem install xcodeproj (may need sudo)"
}

# Run the function
add_swift_files