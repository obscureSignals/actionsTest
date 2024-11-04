#define Version Trim(FileRead(FileOpen("..\VERSION")))
#define ProjectName GetEnv('PROJECT_NAME')
#define ProductName GetEnv('PRODUCT_NAME')
#define Publisher GetEnv('COMPANY_NAME')
#define Year GetDateTimeString("yyyy","","")

; 'Types': What gets displayed during the setup
[Types]
Name: "full"; Description: "Full installation"

; Components are used inside the script and can be composed of a set of 'Types'
[Components]
Name: "vst3"; Description: "VST3 plugin"; Types: full

[Setup]
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64
AppName={#ProductName}
OutputBaseFilename={#ProductName}-{#Version}-Windows
AppCopyright=Copyright (C) {#Year} {#Publisher}
AppPublisher={#Publisher}
AppVersion={#Version}
DefaultDirName="{commoncf64}\VST3\{#ProductName}.vst3"
DisableDirPage=yes

; MAKE SURE YOU READ THE FOLLOWING!
LicenseFile="EULA"

; MSVC adds a .ilk when building the plugin. Let's not include that.
[Files]
Source: "..\Builds\{#ProjectName}_artefacts\Release\VST3\{#ProductName}.vst3\*"; DestDir: "{commoncf64}\VST3\{#ProductName}.vst3\"; Excludes: *.ilk; Flags: ignoreversion recursesubdirs; Components: vst3
Source: "factoryPresets\*"; DestDir: "{commonappdata}\{#ProductName}\factoryPresets\"; Excludes: *.ilk; Flags: ignoreversion recursesubdirs; Components: vst3

