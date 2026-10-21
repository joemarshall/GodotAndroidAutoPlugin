#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: create_plugin_project.sh -TargetFolder PATH -PluginName NAME \
    -SourceFile PATH -InstallFolder PATH [options]

Options:
  -Description TEXT
  -Author TEXT
  -Version TEXT                 (default: 1.0)
  -MavenDependencies VALUE      (comma- or newline-separated coordinates)
  -InterfaceScript PATH
EOF
}

target_folder=""
plugin_name=""
source_file=""
install_folder=""
description=""
author=""
version="1.0"
maven_dependencies=""
interface_script=""

while (($#)); do
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        exit 0
    fi
    if (($# < 2)); then
        printf 'Missing value for argument: %s\n' "$1" >&2
        usage >&2
        exit 2
    fi
    key="$1"
    value="$2"
    shift 2
    case "$key" in
        -TargetFolder|--target-folder) target_folder="$value" ;;
        -PluginName|--plugin-name) plugin_name="$value" ;;
        -SourceFile|--source-file) source_file="$value" ;;
        -InstallFolder|--install-folder) install_folder="$value" ;;
        -Description|--description) description="$value" ;;
        -Author|--author) author="$value" ;;
        -Version|--version) version="$value" ;;
        -MavenDependencies|--maven-dependencies) maven_dependencies="$value" ;;
        -InterfaceScript|--interface-script) interface_script="$value" ;;
        *)
            printf 'Unknown argument: %s\n' "$key" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ -z "$target_folder" || -z "$plugin_name" || -z "$source_file" ]]; then
    printf 'TargetFolder, PluginName, and SourceFile are required.\n' >&2
    usage >&2
    exit 2
fi

git_repository="https://github.com/m4gr3d/Godot-Android-Plugin-Template.git"
printf '\nCreating Android plugin project...\n'
printf '\nTarget Folder: %s\n' "$target_folder"
printf '\nPlugin Name: %s\n' "$plugin_name"
printf '\nSource File: %s\n' "$source_file"

printf '\nCloning repository to %s ...\n' "$target_folder"
if [[ -e "$target_folder" ]]; then
    printf '\nWarning: Target folder already exists. Reverting tracked git changes...\n'
    git -C "$target_folder" checkout -- . || {
        printf '\nFailed to reset target folder\n' >&2
        exit 1
    }
else
    git clone "$git_repository" "$target_folder" --depth 1 || {
        printf '\nFailed to clone repository\n' >&2
        exit 1
    }
fi

settings_file="$target_folder/settings.gradle.kts"
build_gradle_file="$target_folder/plugin/build.gradle.kts"
plugin_cfg_file="$target_folder/plugin/export_scripts_template/plugin.cfg"
export_plugin_file="$target_folder/plugin/export_scripts_template/export_plugin.gd"

printf '\nReplacing plugin name in files...\n'
for file in "$settings_file" "$build_gradle_file" "$plugin_cfg_file" "$export_plugin_file"; do
    if [[ -f "$file" ]]; then
        printf 'Processing: %s\n' "$file"
        PLUGIN_NAME="$plugin_name" perl -0pi -e 's/GodotAndroidPluginTemplate/$ENV{PLUGIN_NAME}/g' "$file"
    else
        printf 'Warning: File not found: %s\n' "$file" >&2
    fi
done

printf '\nUpdating plugin.cfg metadata...\n'
if [[ -f "$plugin_cfg_file" ]]; then
    DESCRIPTION="$description" AUTHOR="$author" VERSION="$version" perl -0pi -e '
        s/^description\s*=.*$/description="$ENV{DESCRIPTION}"/mi if length $ENV{DESCRIPTION};
        s/^author\s*=.*$/author="$ENV{AUTHOR}"/mi if length $ENV{AUTHOR};
        s/^version\s*=.*$/version="$ENV{VERSION}"/mi if length $ENV{VERSION};
    ' "$plugin_cfg_file"
    printf 'Updated plugin.cfg metadata\n'
else
    printf 'Warning: plugin.cfg not found\n' >&2
fi

package_name="$(printf '%s' "$plugin_name" | tr '[:upper:]' '[:lower:]')"
new_package="org.godotengine.plugin.android.generated.$package_name"
printf '\nUpdating package name...\n'
if [[ -f "$build_gradle_file" ]]; then
    NEW_PACKAGE="$new_package" MAVEN_DEPENDENCIES="$maven_dependencies" perl -0pi -e '
        s/org\.godotengine\.plugin\.android\.template/$ENV{NEW_PACKAGE}/g;
        my @deps = grep { length } map { s/^\s+|\s+$//gr } split /[,\n]/, $ENV{MAVEN_DEPENDENCIES};
        if (@deps) {
            my $lines = join "", map { "\n    implementation(\"$_\")" } @deps;
            s/(dependencies\s*\{)/$1$lines/;
        }
    ' "$build_gradle_file"
    if [[ -n "$maven_dependencies" ]]; then
        printf 'Adding Maven dependencies...%s\n' "$maven_dependencies"
    fi
else
    printf 'build.gradle.kts not found\n' >&2
    exit 1
fi

java_dir="$target_folder/plugin/src/main/java"
printf '\nCleaning Java source directory...\n'
if [[ -d "$java_dir" ]]; then
    find "$java_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    printf 'Cleaned: %s\n' "$java_dir"
else
    printf 'Warning: Java directory not found: %s\n' "$java_dir" >&2
fi

printf '\nCopying source file...\n'
target_java_dir="$java_dir/org/godotengine/plugin/android/generated/$package_name"
mkdir -p "$target_java_dir"
if [[ -f "$source_file" ]]; then
    cp -f -- "$source_file" "$target_java_dir/"
    target_file_path="$target_java_dir/$(basename "$source_file")"
    printf 'Copied %s to %s\n' "$source_file" "$target_java_dir"
    printf 'Updating package declaration in source file...\n'
    NEW_PACKAGE="$new_package" perl -0pi -e 's/package\s+[\w.]+/package $ENV{NEW_PACKAGE}/' "$target_file_path"
    printf 'Updated package to: %s\n' "$new_package"
else
    printf 'Source file not found: %s\n' "$source_file" >&2
    exit 1
fi

if [[ -n "$maven_dependencies" ]]; then
    printf '\nUpdating export_plugin.gd with Maven dependencies...\n'
    if [[ -f "$export_plugin_file" ]]; then
        DEPENDENCIES="$maven_dependencies" perl -0pi -e '
            my @deps = grep { length } map { s/^\s+|\s+$//gr } split /[,\n]/, $ENV{DEPENDENCIES};
            for (@deps) { s/\\/\\\\/g; s/"/\\"/g; }
            my $array = join ", ", map { "\"$_\"" } @deps;
            s/(func\s+_get_android_dependencies.*?return\s+)PackedStringArray\(\[\]\)(.*?return\s+)PackedStringArray\(\[\]\)/$1.PackedStringArray([$array]).$2.PackedStringArray([$array])/smi;
        ' "$export_plugin_file"
        printf 'Updated export_plugin.gd with dependencies\n'
    else
        printf 'Warning: export_plugin.gd not found at: %s\n' "$export_plugin_file" >&2
    fi
fi

printf '\nRunning Gradle assemble...\n'
if [[ -x "$target_folder/gradlew" ]]; then
    gradle_wrapper="$target_folder/gradlew"
else
    gradle_wrapper="$target_folder/gradlew.bat"
fi
if [[ "$gradle_wrapper" == *.bat ]]; then
    (cd "$target_folder" && cmd.exe /c gradlew.bat assemble --no-daemon)
else
    (cd "$target_folder" && "$gradle_wrapper" assemble --no-daemon)
fi || {
    status=$?
    printf 'Gradle assemble failed with exit code: %s\n' "$status" >&2
    exit "$status"
}
printf '\nPlugin project created successfully!\n'
printf 'Project location: %s\n' "$target_folder"

if [[ -n "$install_folder" ]]; then
    printf '\nInstalling plugin...\n'
    source_plugin_dir="$target_folder/plugin/demo/addons/$plugin_name"
    destination_plugin_dir="$install_folder"
    if [[ -d "$source_plugin_dir" ]]; then
        if [[ -e "$destination_plugin_dir" ]]; then
            printf 'Removing existing plugin at destination...\n'
            rm -rf -- "$destination_plugin_dir"
        fi
        mkdir -p "$(dirname "$destination_plugin_dir")"
        cp -R -- "$source_plugin_dir" "$destination_plugin_dir"
        printf 'Plugin installed successfully to: %s\n' "$destination_plugin_dir"

        if [[ -n "$interface_script" && -f "$interface_script" ]]; then
            target_interface_path="$destination_plugin_dir/$(basename "$interface_script")"
            cp -f -- "$interface_script" "$target_interface_path"
            awk '
                /# BEGIN_ANDROID_PLUGIN_INCLUDE/ { in_section = 1; next }
                /# END_ANDROID_PLUGIN_INCLUDE/ { in_section = 0; next }
                in_section && /^[[:space:]]*#[[:space:]]*.+$/ {
                    sub(/^[[:space:]]*#[[:space:]]?/, "")
                    print
                    next
                }
                { print }
            ' "$target_interface_path" > "$target_interface_path.tmp"
            mv "$target_interface_path.tmp" "$target_interface_path"
            printf 'Copied and uncommented InterfaceScript at %s\n' "$target_interface_path"
        fi
    else
        printf 'Warning: Plugin directory not found at: %s\n' "$source_plugin_dir" >&2
    fi
fi