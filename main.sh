#!/bin/bash

#export ServerVersion
echo "-- The ChiselPM executable code is designed to be at the root of your server's folder. Setting ServerRoot to $(dirname "$0")"
# shellcheck disable=SC2155
export ServerRoot=$(dirname "$0")
# shellcheck disable=SC1091
source "$ServerRoot"/cpm.conf

if [[ $ServerModFolder == "" ]]; then
    export ServerModFolder=${ServerRoot}/mods/
fi



#txtblk=$(tput setaf 0) # Black
 txtred=$(tput setaf 1) # Red
 txtgrn=$(tput setaf 2) # Green
 txtylw=$(tput setaf 3) # Yellow
 txtblu=$(tput setaf 4) # Blue
 txtpur=$(tput setaf 5) # Purple
 txtcyn=$(tput setaf 6) # Cyan
#txtwht=$(tput setaf 7) # White
 txtreg=$(tput sgr0)    # Normal


function Main() {
    command -v wget>/dev/null || LogFail "Command wget not found."
    command -v less>/dev/null || LogFail "Command less not found."
    command -v jq  >/dev/null || LogFail "Command jq not found."
    case $1 in 
        install)
            InstallPackage "$2" "$3"
        ;;
        install-fabric)
            GetFabric "$2" "$3" "$4"
        ;;
        remove|uninstall)
            RemovePackage "$2"
        ;;
        init)
            InitialiseChiselServer "$2" "$3"
        ;;
        info)
            SelectedPackage=$2
            GetPackageInformation
        ;;
        versions)
            SelectedPackage=$2
            GetPackageVersions
        ;;
        dependencies)
            SelectedPackage=$2
            GetPackageDependencies
        ;;
        search)
            SearchPackage "${*:2}"
        ;;
        search-slug)
            SearchPackageName "${*:2}"
        ;;
        help|"--help")
            echo "Commands:
cpm install (package) (version) - Installs package to $ServerModFolder
cpm uninstall (package) - Uninstalls package from $ServerModFolder
cpm install-fabric (minecraft-version) (loader-version) (installer-version) - Installs Fabric Server to the root of the server. If unsure on an argument/option, use \"\" to skip it. 
cpm info (package) - Gets information about package in JSON format
cpm init - Initialises a ChiselPM configuration in your server
cpm versions (package) - Gets list of the package's versions in JSON format
cpm dependencies (package) - Gets list of the package's dependencies
cpm search (query) - Searches for packages matching query (USE QUOTES!)
cpm search-slug (query) - Same as above, but instead more precisely returns package names
cpm help/--help - Show this help message
"
        ;;
        *)
            LogFail "No such command as $1. Run cpm help or --help for command list."
    esac
}

function SearchPackage {
    local query="${*// /%20}"
    curl "https://api.modrinth.com/v2/search?query=${query}" | jq -r ".hits[]" | less
}

function SearchPackageName {
    local query="${*// /%20}"
    curl "https://api.modrinth.com/v2/search?query=${query}" | jq -r ".hits[].slug"
}

function GetFabric {
    MinecraftVersion=$1
    FabricLoaderVersion=$2
    FabricInstallerVersion=$3
    while [[ $MinecraftVersion == "" ]]; do
        read -rp "Enter a valid Minecraft version: (type h for a list of versions): " MinecraftVersion
        case $MinecraftVersion in
            h)
                curl https://meta.fabricmc.net/v2/versions/game/ | jq -r ".[].version" | less
                unset MinecraftVersion
            ;;
            *)
                curl https://meta.fabricmc.net/v2/versions/game/ | jq -r ".[].version" | grep "$MinecraftVersion" || unset MinecraftVersion
                if [[ -z $MinecraftVersion ]]; then
                    read -rp "Please select a valid Minecraft version. Press enter to continue. " NOTHING
                    echo "$NOTHING">/dev/null
                else
                    MCVVerified=true
                fi
            ;;
        esac
    done

    while [[ $FabricLoaderVersion == "" ]]; do
        read -rp "Enter a valid Fabric Loader version: (type h for a list of versions): " FabricLoaderVersion
        case $FabricLoaderVersion in
            h)
                curl https://meta.fabricmc.net/v2/versions/loader/ | jq -r ".[].version" | less
                unset FabricLoaderVersion
            ;;
            *)
                curl https://meta.fabricmc.net/v2/versions/loader/ | jq -r ".[].version" | grep "$FabricLoaderVersion" || unset FabricLoaderVersion
                if [[ -z $MinecraftVersion ]]; then
                    read -rp "Please select a valid Fabric Loader version. Press enter to continue. " NOTHING
                    echo "$NOTHING">/dev/null
                else
                    FLVVerified=true
                fi
            ;;
        esac
    done

    while [[ $FabricInstallerVersion == "" ]]; do
        read -rp "Enter a valid Fabric Installer version: (type h for a list of versions): " FabricInstallerVersion
        case $FabricInstallerVersion in
            h)
                curl https://meta.fabricmc.net/v2/versions/installer/ | jq -r ".[].version" | less
                unset FabricInstallerVersion
            ;;
            *)
                curl https://meta.fabricmc.net/v2/versions/installer/ | jq -r ".[].version" | grep "$FabricInstallerVersion" || unset FabricInstallerVersion
                if [[ -z $MinecraftVersion ]]; then
                    read -rp "Please select a valid Fabric Installer version. Press enter to continue. " NOTHING
                    echo "$NOTHING">/dev/null
                else
                    FIVVerified=true
                fi
            ;;
        esac
    done

    if [[ $MCVVerified != "true" ]]; then
        Log i FabricMC p "Verifying if Minecraft version $MinecraftVersion exists..."
        curl https://meta.fabricmc.net/v2/versions/game/ | jq -r ".[].version" | grep "$MinecraftVersion" || LogFail "Minecraft version $MinecraftVersion supporting FabricMC does NOT exist!"
    elif [[ $FLVVerified != "true" ]]; then
        Log i FabricMC p "Verifying if Fabric loader version $FabricLoaderVersion exists..."
        curl https://meta.fabricmc.net/v2/versions/loader/ | jq -r ".[].version" | grep "$FabricLoaderVersion" || LogFail "Fabric loader $FabricLoaderVersion does NOT exist!"
    elif [[ $FIVVerified != "true" ]]; then
        Log i FabricMC p "Verifying if Fabric installer version $FabricInstallerVersion exists..."
        curl https://meta.fabricmc.net/v2/versions/installer/ | jq -r ".[].version" | grep "$FabricInstallerVersion" || LogFail "Fabric installer $FabricInstallerVersion does NOT exist!"
    else
        Log i "FabricMC" o "Checks complete! Downloading FabricMC fabric-server-mc.$MinecraftVersion-loader.$FabricLoaderVersion-launcher.$FabricInstallerVersion.jar next!"
    fi

    Log i "FabricMC" p "Please wait as we're downloading the file..."

    curl -OJ https://meta.fabricmc.net/v2/versions/loader/"$MinecraftVersion"/"$FabricLoaderVersion"/"$FabricInstallerVersion"/server/jar -o "$ServerRoot"/ || LogFail  "Failed either getting file, or writing it to the server root."

    Log i "FabricMC" o "Finished downloading Fabric!"
}

function InitialiseChiselServer {
    ServerVersion=$1
    ServerSoftware=$2

    read -rp "This command is going to create a symlink of $ServerRoot/mods at $ServerRoot/plugins, and overwrite any file named cpm.conf. Are you sure? (y/n) " yn
    if [[ $yn == "y" ]]; then
        true
    else
        LogFail "Cancelled operation"
    fi

    if [[ -f $ServerRoot/cpm.conf ]]; then
        LogFail "Chisel is already here."
    fi

    if [[ $ServerVersion == "" ]]; then
        read -rp "Enter your preferred Minecraft version (e.g. 1.20.1): " ServerVersion
    else
        true
    fi

    if [[ $ServerSoftware == "" ]]; then
        read -rp "Enter your preferred loader (e.g. fabric, quilt, forge, neoforge etc.): " ServerSoftware
    else
        true
    fi

    case $ServerSoftware in 
        "fabric"|"forge"|"quilt"|"neoforge")
            mkdir "$ServerRoot"/mods/
            ln -sf "$ServerRoot"/mods "$ServerRoot"/plugins
        ;;
        "paper"|"spigot"|"")
            mkdir "$ServerRoot"/plugins/
            ln -sf "$ServerRoot"/plugins "$ServerRoot"/mods
        ;;
        *)
            LogFail "UNSUPPORTED LOADER $ServerSoftware !"
        ;;
    esac

    mkdir -pv "$ServerRoot"/world/datapacks

    printf "ServerVersion=%s\nServerSoftware=%s\n" "$ServerVersion" "$ServerSoftware" > "$ServerRoot"/cpm.conf
    echo "-- Generated config. Modify cpm.conf and change the values accordingly, if you want to make any tweaks."
}


function InstallPackage {
    IsRunningInServer                     || LogFail "You are not running ChiselPM inside of a server that has the ChiselPM configuration file." 
    SelectedPackage=$1
    SelectedVersion=$2

    if [[ $2 == "" ]]; then
        SelectedVersion=$(GetLatestPackageVersion)
    fi

    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi

#   if [[ $SelectedVersion == "" ]]; then
#       LogFail "Please specify a package version. You can see the package versions with the \"versions\" subcommand."
#   fi

    if [[ $(PackageExists "$SelectedPackage") != "NONEXISTENT" ]]; then # If it is confirmed
        LogFail "Package $SelectedPackage already exists"
    fi
    GET>/dev/null;
    PackageWorksOnServer                  || LogFail "The package requested does not work on servers." 
    PackageIsCompatibleWithServer         || LogFail "The package requested is not compatible with the server version."
    PackageVersionIsCompatibleWithServer  || LogFail "The version requested is not compatible with the server version."
    PackageIsCompatibleWithServerSoftware || LogFail "The package requested is not compatible with the server software."

    SelectedPackage=$1
    SelectedVersion=$2
    
    if [[ $2 == "" ]]; then
        SelectedVersion=$(GetLatestPackageVersion)
    fi
    
    IsDatapack=true
    PackageIsDatapack || export IsDatapack=false

    DependencyInstaller
    Log i "$SelectedPackage" p "Downloading package"

    if [[ $IsDatapack == "true" ]]; then
        wget "$(GetPackageFileURLGivenVersion)" -qO "$ServerRoot"/world/datapacks/"${SelectedPackage}"_"${SelectedVersion}".zip || LogFail "Failed either getting file, or writing it to the world/datapacks/ folder."
    else
        wget "$(GetPackageFileURLGivenVersion)" -qO "$ServerModFolder"/"${SelectedPackage}"_"${SelectedVersion}".jar || LogFail "Failed either getting file, or writing it to the mods folder."
    fi
    Log i "$SelectedPackage" o "Package $SelectedPackage is now installed."
}


function InstallDependency {
    IsRunningInServer || LogFail "You are not running ChiselPM inside of a server that has the ChiselPM configuration file." 
    local SelectedPackage=$1
    local SelectedVersion=$2
    local IsDatapack=false

    if [[ $2 == "" ]]; then
        SelectedVersion=$(GetLatestPackageVersion)
    fi

    if [[ -z $SelectedVersion ]]; then
        Log i "$SelectedPackage" w "No latest version compatible with server version found. Installing latest absolute version, assuming it works."
        SelectedVersion=$(curl https://api.modrinth.com/v2/project/load-my-resources/version | jq -r --arg loader "$ServerSoftware" '.[] | select(.loaders[] == $loader) | .version_number' | head -n1)
    fi

    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi

#   if [[ $SelectedVersion == "" ]]; then
#       LogFail "Please specify a package version. You can see the package versions with the \"versions\" subcommand."
#   fi

    if [[ $(PackageExists "$SelectedPackage") != "NONEXISTENT" ]]; then # If it is confirmed
        Log i "$SelectedPackage" w "-- Dependency $SelectedPackage is already installed"
    fi
    GET>/dev/null;
    PackageWorksOnServer
    PackageIsCompatibleWithServer
    PackageVersionIsCompatibleWithServer
    PackageIsCompatibleWithServerSoftware || SKIP_PKG=true
    if [[ $SKIP_PKG = true ]]; then
        Log i "$SelectedPackage" w "This dependency does not support your server software. Skipping..."
    else
        DependencyInstaller
        Log i "$SelectedPackage" p "Downloading dependency"
        wget "$(GetPackageFileURLGivenVersion)" -qO "$ServerModFolder"/"${SelectedPackage}"_"${SelectedVersion}".jar || LogFail "Failed either getting file, or writing it to the mods folder."
        Log i "$SelectedPackage" o "Dependency $SelectedPackage is now installed."
    fi
}

function DependencyInstaller {
    for word in $(GetPackageDependencies); do
        InstallDependency "$word" || Log i "$SelectedPackage" e "Failed to install dependency, as it may already be installed or unavailable."
    done
}

function RemovePackage {
    SelectedPackage=$1
    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi
    IsRunningInServer || LogFail "You are not running ChiselPM inside of a server that has the ChiselPM configuration file." 
    PackageExists "$SelectedPackage" || LogFail "Package $SelectedPackage does not exist."
    echo "File(s) to be removed from $ServerModFolder:
        $(ls "$ServerModFolder" "$ServerRoot/world/datapacks/" | grep "${SelectedPackage}"_)"
    read -rp "Are you sure you want to remove $SelectedPackage from the server? (y/n) " UninstallConfirmation
    case $UninstallConfirmation in
        "y"|"Y"|"yes"|"YES")
            true
        ;;
        *)
            LogFail "User denied"
        ;;
    esac
    Log r "$SelectedPackage" p "Deleting file"
    RemoveFileAltogether() {
        rm -v "$ServerRoot"/mods/"${SelectedPackage}"_*.jar || rm -v "$ServerRoot"/world/datapacks/"${SelectedPackage}"_*.zip || LogFail "Failed to remove file(s)"
    }
    RemoveFileAltogether
    Log r "$SelectedPackage" o "File deleted."
}

function RemovePackage.Update {
    SelectedPackage=$1
    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi
    IsRunningInServer || LogFail "You are not running ChiselPM inside of a server that has the ChiselPM configuration file." 
    PackageExists "$SelectedPackage" || LogFail "Package $SelectedPackage does not exist."
    echo "File(s) to be removed from $ServerModFolder:
        $(ls "$ServerModFolder" | grep "${SelectedPackage}"_)"
    Log u "with $SelectedPackage" p "Deleting file"
    rm -v "$ServerRoot"/mods/"${SelectedPackage}"_*.jar
    Log u "with $SelectedPackage" o "File deleted."
}

function GET {
    curl https://api.modrinth.com/v2/project/"$SelectedPackage" || LogFail "Failed to GET to server, either the package does not exist or a connection to the server couldn't be made."
}

function GetPackageFileURLGivenVersion {
    curl https://api.modrinth.com/v2/project/"$SelectedPackage"/version/"$SelectedVersion" | jq -r ".files[].url"
}

function PackageIsDatapack {
    curl https://api.modrinth.com/v2/project/"$SelectedPackage" | jq -r ".loaders[]" | grep "datapack"
}

function PackageWorksOnServer {
    case $(curl https://api.modrinth.com/v2/project/"$SelectedPackage" | jq -r .server_side) in
        "required"|"optional")
            true
        ;;
        *)
            false
        ;;
    esac
}

function PackageIsCompatibleWithServer {
    curl https://api.modrinth.com/v2/project/"$SelectedPackage" | jq -r ".game_versions[]" | grep "$ServerVersion"
}

function PackageVersionIsCompatibleWithServer {
    curl https://api.modrinth.com/v2/project/"$SelectedPackage"/version | jq -r ".[].game_versions[]" | grep "$ServerVersion"
}

function PackageIsCompatibleWithServerSoftware {
    curl https://api.modrinth.com/v2/project/"$SelectedPackage" | jq -r ".loaders[]" | grep "$ServerSoftware"
}

function PackageExists {
    ls "$ServerModFolder" "$ServerRoot/world/datapacks/" | grep -E "^${1}_[^_]+\.(jar|zip)$" || echo "NONEXISTENT"
}

function GetPackageInformation {
    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi
    curl https://api.modrinth.com/v2/project/"$SelectedPackage" | jq -r | less
}

function GetPackageVersions {
    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi
    curl https://api.modrinth.com/v2/project/"$SelectedPackage"/version | jq -r | less
}

function GetLatestPackageVersion {
    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi

    if [[ $IsDatapack == "true" ]]; then    
        curl https://api.modrinth.com/v2/project/"$SelectedPackage"/version | jq -r --arg version "$ServerVersion" '.[] | select(.game_versions[] == $version) | .version_number' | head -n1
    else
        curl https://api.modrinth.com/v2/project/"$SelectedPackage"/version | jq -r --arg version "$ServerVersion" --arg loader "$ServerSoftware" '.[] | select(.game_versions[] == $version) | select(.loaders[] == $loader) | .version_number' | head -n1
    fi
}

function GetPackageDependencies {
    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi
    curl https://api.modrinth.com/v2/project/"$SelectedPackage"/dependencies | jq -r ".projects[].slug"
}

function IsRunningInServer {
    test -f "$ServerRoot"/cpm.conf
}

Log() {
    case $1 in
        s)
            lmsg_one="STAGE"
        ;;
        i)
            lmsg_one="Installing package"
        ;;
        r)
            lmsg_one="Removing package"
        ;;
        u)
            lmsg_one="Updating server state"
        ;;
    esac
    lmsg_two=$2
    case $3 in
        i)
            lmsg_three="${txtblu}INFO"
        ;;
        w)
            lmsg_three="${txtylw}WARN"
        ;;
        e)            
            lmsg_three="${txtred}ERRR"
        ;;
        o)            
            lmsg_three="${txtgrn}OKAY"
        ;;
        p)            
            lmsg_three="${txtpur}WAIT"
        ;;
        *)
            lmsg_three=$3
        ;;
    esac
    echo -e "[ChiselPM/${txtcyn}${lmsg_one} ${lmsg_two}${txtreg}/${lmsg_three}${txtreg}]: $4"
}

LogFail() { 
    echo -e "${txtred}Error:${txtreg} ${1}"; exit 1 
}

Main "$@"
