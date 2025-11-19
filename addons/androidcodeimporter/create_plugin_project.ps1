param(
    [Parameter(Mandatory=$true)]
    [string]$TargetFolder,
    
    [Parameter(Mandatory=$true)]
    [string]$PluginName,
    
    [Parameter(Mandatory=$true)]
    [string]$SourceFile,
    
    [Parameter(Mandatory=$false)]
    [string]$Description = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Author = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Version = "1.0",
    
    [Parameter(Mandatory=$true)]
    [string]$InstallFolder = "",
    
    [Parameter(Mandatory=$false)]
    [string[] ]$MavenDependencies = ""
)

function Pause-ForKey {
        Write-Host "`nPress any key..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}


# Constant for the git repository
$GitRepository = "https://github.com/m4gr3d/Godot-Android-Plugin-Template.git"

Write-Host "`nCreating Android plugin project..."
Write-Host "`nTarget Folder: $TargetFolder"
Write-Host "`nPlugin Name: $PluginName"
Write-Host "`nSource File: $SourceFile"

# Step 1: Clone the repository to the target folder
Write-Host "`nCloning repository to $TargetFolder ..."

Write-Host "`nWarning: "+(Test-Path $TargetFolder) "Target folder  exists?"

if (Test-Path $TargetFolder) {
    Write-Host "`nWarning: Target folder already exists. Removing it..."
    Remove-Item -Path $TargetFolder -Recurse -Force
}

git clone $GitRepository $TargetFolder --depth 1

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nFailed to clone repository"
    #Pause-ForKey
    exit 1
}


# Step 2: Replace "GodotAndroidPluginTemplate" with plugin name in specified files
Write-Host "`nReplacing plugin name in files..."

$filesToReplace = @(
    "$TargetFolder\settings.gradle.kts",
    "$TargetFolder\plugin\build.gradle.kts",
    "$TargetFolder\plugin\export_scripts_template\plugin.cfg",
    "$TargetFolder\plugin\export_scripts_template\export_plugin.gd"
)

foreach ($file in $filesToReplace) {
    if (Test-Path $file) {
        Write-Host "Processing: $file"
        $content = Get-Content -Path $file -Raw
        $content = $content -replace "GodotAndroidPluginTemplate", $PluginName
        Set-Content -Path $file -Value $content -NoNewline
    } else {
        Write-Warning "File not found: $file"
    }
}

# Update plugin.cfg with description, author, and version
Write-Host "`nUpdating plugin.cfg metadata..."
$pluginCfgFile = "$TargetFolder\plugin\export_scripts_template\plugin.cfg"
if (Test-Path $pluginCfgFile) {
    $content = Get-Content -Path $pluginCfgFile -Raw
    
    if ($Description) {
        $content = $content -replace "description\s*=.*", "description=`"$Description`""
    }
    if ($Author) {
        $content = $content -replace "author\s*=.*", "author=`"$Author`""
    }
    if ($Version) {
        $content = $content -replace "version\s*=.*", "version=`"$Version`""
    }
    
    Set-Content -Path $pluginCfgFile -Value $content -NoNewline
    Write-Host "Updated plugin.cfg metadata"
} else {
    Write-Warning "plugin.cfg not found"
}

# Step 3: Change package name in plugin/build.gradle.kts
Write-Host "`nUpdating package name..."
$packageName = $PluginName.ToLower()
$buildGradleFile = "$TargetFolder\plugin\build.gradle.kts"
if (Test-Path $buildGradleFile) {
    $content = Get-Content -Path $buildGradleFile -Raw
    $content = $content -replace "org\.godotengine\.plugin\.android\.template", "org.godotengine.plugin.android.generated.$packageName"
    
    # Add Maven dependencies if specified
    if ($MavenDependencies) {
        Write-Host "Adding Maven dependencies...$MavenDependencies"
        $deps = $MavenDependencies | ForEach-Object { $_.Trim() }
        $depLines = ""
        foreach ($dep in $deps) {
            if ($dep) {
                $depLines += "`n    implementation(`"$dep`")"
            }
        }
        # Insert dependencies after the dependencies { line
        $content = $content -replace "(dependencies\s*\{)", "`$1$depLines"
    }
    
    Set-Content -Path $buildGradleFile -Value $content -NoNewline
} else {
    Write-Host "build.gradle.kts not found"
    #Pause-ForKey
    exit 1
}

# Step 4: Delete everything under plugin/src/main/java
Write-Host "`nCleaning Java source directory..."
$javaDir = "$TargetFolder\plugin\src\main\java"
if (Test-Path $javaDir) {
    Remove-Item -Path "$javaDir\*" -Recurse -Force
    Write-Host "Cleaned: $javaDir"
} else {
    Write-Warning "Java directory not found: $javaDir"
    #Pause-ForKey
}

# Step 5: Copy the source code file to the new package location
Write-Host "`nCopying source file..."
$packageName = $PluginName.ToLower()
$targetJavaDir = "$TargetFolder\plugin\src\main\java\org\godotengine\plugin\android\generated\$packageName"
New-Item -Path $targetJavaDir -ItemType Directory -Force | Out-Null

if (Test-Path $SourceFile) {
    $sourceFileName = Split-Path -Leaf $SourceFile
    $targetFilePath = Join-Path $targetJavaDir $sourceFileName
    Copy-Item -Path $SourceFile -Destination $targetFilePath -Force
    Write-Host "Copied $SourceFile to $targetJavaDir"
    
    # Update package declaration in the copied source file
    Write-Host "Updating package declaration in source file..."
    $sourceContent = Get-Content -Path $targetFilePath -Raw
    $newPackage = "org.godotengine.plugin.android.generated.$packageName"
    $sourceContent = $sourceContent -replace "package\s+[\w.]+", "package $newPackage"
    Set-Content -Path $targetFilePath -Value $sourceContent -NoNewline
    Write-Host "Updated package to: $newPackage"
} else {
    Write-Host "Source file not found: $SourceFile"
    #Pause-ForKey
    exit 1
}

# Step 5.5: Update export_plugin.gd with Maven dependencies
if ($MavenDependencies) {
    Write-Host "`nUpdating export_plugin.gd with Maven dependencies..."
    $exportPluginFile = "$TargetFolder\plugin\export_scripts_template\export_plugin.gd"
    if (Test-Path $exportPluginFile) {
        $content = Get-Content -Path $exportPluginFile -Raw
        
        # Build the dependencies array string
        $deps = $MavenDependencies | ForEach-Object { $_.Trim() }
        $depArray = ($deps | ForEach-Object { "`"$_`"" }) -join ', '
        
        # Replace the return statement in _get_android_dependencies
        # Match the function and replace the empty array with dependencies
        $content = $content -replace '(?smi)(func\s+_get_android_dependencies.*?return\s+)PackedStringArray\(\[\]\)(.*?return\s+)PackedStringArray\(\[\]\)', "`${1}PackedStringArray([$depArray])`${2}PackedStringArray([$depArray])"
        
        Set-Content -Path $exportPluginFile -Value $content -NoNewline
        Write-Host "Updated export_plugin.gd with dependencies"
    } else {
        Write-Warning "export_plugin.gd not found at: $exportPluginFile"
    }
}

# Step 6: Run gradle assemble
Write-Host "`nRunning Gradle assemble..."
Push-Location $TargetFolder
try {
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
        .\gradlew.bat assemble
    } else {
        ./gradlew assemble
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nPlugin project created successfully!" -ForegroundColor Green
        Write-Host "Project location: $TargetFolder"
    } else {
        Write-Host "Gradle assemble failed with exit code: $LASTEXITCODE"
        #Pause-ForKey
        exit 1
    }
} finally {
    Pop-Location
}

# Step 7: Copy plugin to install folder if specified
if ($InstallFolder) {
    Write-Host "`nInstalling plugin..."
    $sourcePluginDir = "$TargetFolder\plugin\demo\addons\$PluginName"
    $destinationPluginDir = "$InstallFolder"
    
    if (Test-Path $sourcePluginDir) {
        if (Test-Path $destinationPluginDir) {
            Write-Host "Removing existing plugin at destination..."
            Remove-Item -Path $destinationPluginDir -Recurse -Force
        }
        
        Write-Host "Copying plugin from $sourcePluginDir to $destinationPluginDir"
        Copy-Item -Path $sourcePluginDir -Destination $destinationPluginDir -Recurse -Force
        Write-Host "Plugin installed successfully to: $destinationPluginDir" -ForegroundColor Green
    } else {
        Write-Warning "Plugin directory not found at: $sourcePluginDir"
    }
}

#Pause-ForKey
