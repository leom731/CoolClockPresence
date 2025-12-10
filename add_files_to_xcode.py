#!/usr/bin/env python3
"""
Script to add new Swift files to the CoolClockPresence Xcode project.
This modifies the project.pbxproj file to include the new world clock files.
"""

import sys
import uuid
import os

# Path to the project file
project_path = "/Users/leomanderico/Library/Mobile Documents/com~apple~CloudDocs/DEV/CoolClockPresence/CoolClockPresence.xcodeproj/project.pbxproj"

# New files to add
new_files = [
    "WorldClockLocation.swift",
    "WorldClockManager.swift",
    "WorldClockView.swift",
    "WorldClockPickerView.swift"
]

def generate_uuid():
    """Generate a UUID in the format used by Xcode (24 chars, uppercase hex)"""
    return uuid.uuid4().hex[:24].upper()

def add_files_to_project():
    """Add the new Swift files to the Xcode project"""

    if not os.path.exists(project_path):
        print(f"Error: Project file not found at {project_path}")
        return False

    # Read the project file
    with open(project_path, 'r') as f:
        content = f.read()

    # Generate UUIDs for each file (we need 2 per file: fileRef and buildFile)
    file_refs = {}
    build_files = {}
    for filename in new_files:
        file_refs[filename] = generate_uuid()
        build_files[filename] = generate_uuid()

    # Find the PBXFileReference section
    file_ref_marker = "/* Begin PBXFileReference section */"
    file_ref_end_marker = "/* End PBXFileReference section */"

    if file_ref_marker not in content:
        print("Error: Could not find PBXFileReference section")
        return False

    # Create fileReference entries
    file_ref_entries = []
    for filename in new_files:
        entry = f'\t\t{file_refs[filename]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n'
        file_ref_entries.append(entry)

    # Insert file references
    file_ref_section_start = content.index(file_ref_marker) + len(file_ref_marker)
    file_ref_section_end = content.index(file_ref_end_marker)

    new_content = (
        content[:file_ref_section_start] +
        "\n" + "".join(file_ref_entries) +
        content[file_ref_section_start:file_ref_section_end] +
        content[file_ref_section_end:]
    )
    content = new_content

    # Find the PBXBuildFile section
    build_file_marker = "/* Begin PBXBuildFile section */"
    build_file_end_marker = "/* End PBXBuildFile section */"

    # Create buildFile entries
    build_file_entries = []
    for filename in new_files:
        entry = f'\t\t{build_files[filename]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[filename]} /* {filename} */; }};\n'
        build_file_entries.append(entry)

    # Insert build files
    build_file_section_start = content.index(build_file_marker) + len(build_file_marker)
    build_file_section_end = content.index(build_file_end_marker)

    new_content = (
        content[:build_file_section_start] +
        "\n" + "".join(build_file_entries) +
        content[build_file_section_start:build_file_section_end] +
        content[build_file_section_end:]
    )
    content = new_content

    # Find the main group (CoolClockPresence folder)
    # Look for "children = (" after "CoolClockPresence" group
    main_group_marker = "CoolClockPresence */ = {"

    if main_group_marker in content:
        # Find the children array for the main group
        main_group_pos = content.index(main_group_marker)
        children_marker = "children = ("
        children_pos = content.index(children_marker, main_group_pos)
        children_end_pos = content.index(");", children_pos)

        # Add file references to children
        file_ref_in_children = []
        for filename in new_files:
            entry = f'\t\t\t\t{file_refs[filename]} /* {filename} */,\n'
            file_ref_in_children.append(entry)

        new_content = (
            content[:children_end_pos] +
            "".join(file_ref_in_children) +
            content[children_end_pos:]
        )
        content = new_content

    # Find the PBXSourcesBuildPhase section and add build files
    sources_phase_marker = "/* Sources */ = {"

    if sources_phase_marker in content:
        # Find the files array
        sources_pos = content.index(sources_phase_marker)
        files_marker = "files = ("
        files_pos = content.index(files_marker, sources_pos)
        files_end_pos = content.index(");", files_pos)

        # Add build file references
        build_file_in_sources = []
        for filename in new_files:
            entry = f'\t\t\t\t{build_files[filename]} /* {filename} in Sources */,\n'
            build_file_in_sources.append(entry)

        new_content = (
            content[:files_end_pos] +
            "".join(build_file_in_sources) +
            content[files_end_pos:]
        )
        content = new_content

    # Write the modified project file
    with open(project_path, 'w') as f:
        f.write(content)

    print(f"Successfully added {len(new_files)} files to the Xcode project:")
    for filename in new_files:
        print(f"  - {filename}")

    return True

if __name__ == "__main__":
    success = add_files_to_project()
    sys.exit(0 if success else 1)
