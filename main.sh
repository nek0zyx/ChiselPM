#!/bin/bash

#export ServerVersion
export ServerRoot=$(dirname $0)
source $ServerRoot/cpm.conf

if [[ ServerModFolder == "" ]]; then
    export ServerModFolder=$ServerRoot/mods/
fi



txtblk=$(tput setaf 0) # Black
txtred=$(tput setaf 1) # Red
txtgrn=$(tput setaf 2) # Green
txtylw=$(tput setaf 3) # Yellow
txtblu=$(tput setaf 4) # Blue
txtpur=$(tput setaf 5) # Purple
txtcyn=$(tput setaf 6) # Cyan
txtwht=$(tput setaf 7) # White
txtreg=$(tput sgr0)    # Normal


function Main() {
    command -v wget>/dev/null || LogFail "Command wget not found."
    command -v less>/dev/null || LogFail "Command less not found."
    case $1 in 
        install)
            InstallPackage $2 $3
        ;;
        remove|uninstall)
            RemovePackage $2
        ;;
        init)
            InitialiseChiselServer
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
        help|"--help")
            echo "Commands:
cpm install (package) (version) - Installs package to $ServerModFolder
cpm uninstall (package) - Uninstalls package from $ServerModFolder
cpm info (package) - Gets information about package in JSON format
cpm init - Initialises a ChiselPM configuration in your server
cpm versions (package) - Gets list of the package's versions in JSON format
cpm dependencies (package) - Gets list of the package's dependencies
cpm help/--help - Show this help message
"
        ;;
        *)
            LogFail "No such command as $1. Run cpm help or --help for command list."
    esac
}

function GetFabric {
    echo "Not implemented yet"
}

function InitialiseChiselServer {
    if [[ -f $ServerRoot/cpm.conf ]]; then
        LogFail "Chisel is already here."
        exit 1
    fi
    printf "ServerVersion=\nServerSoftware=\n" > $ServerRoot/cpm.conf
    echo "-- Modify cpm.conf and change the values accordingly."
}

function InstallPackage {
    IsRunningInServer                     || LogFail "You are not running ChiselPM inside of a server that has the ChiselPM configuration file." 
    SelectedPackage=$1
    SelectedVersion=$2
    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi

    if [[ $SelectedVersion == "" ]]; then
        LogFail "Please specify a package version. You can see the package versions with the \"versions\" subcommand."
    fi

    if [[ $(PackageExists $SelectedPackage) != "NONEXISTENT" ]]; then # If it is confirmed
        LogFail "Package $SelectedPackage already exists"
    fi
    GET>/dev/null;
    PackageWorksOnServer                  || LogFail "The package requested does not work on servers." 
    PackageIsCompatibleWithServer         || LogFail "The package requested is not compatible with the server version."
    PackageVersionIsCompatibleWithServer  || LogFail "The version requested is not compatible with the server version."
    PackageIsCompatibleWithServerSoftware || LogFail "The package requested is not compatible with the server software."
    for word in $(GetPackageDependencies); do
        InstallPackage $word || Log i $SelectedPackage "Failed to install dependency, as it may already be installed or unavailable."
    done
    Log i $SelectedPackage "Downloading package"
    wget $(GetPackageFileURLGivenVersion) -qO $ServerModFolder/${SelectedPackage}_${SelectedVersion}.jar || LogFail "Failed either getting file, or writing it to the mods folder."
    Log i $SelectedPackage "Package $SelectedPackage is now installed."
}

function RemovePackage {
    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi
    IsRunningInServer || LogFail "You are not running ChiselPM inside of a server that has the ChiselPM configuration file." 
    SelectedPackage=$1
    PackageExists $SelectedPackage || LogFail "Package $SelectedPackage does not exist."
    echo "File(s) to be removed from $ServerModFolder:
        $(ls $ServerModFolder | grep ${SelectedPackage}_)"
    read -p "Are you sure you want to remove $SelectedPackage from the server? (y/n) " UninstallConfirmation
    case $UninstallConfirmation in
        "y"|"Y"|"yes"|"YES")
            true
        ;;
        *)
            LogFail "User denied"
        ;;
    esac
    Log r $SelectedPackage "Deleting file"
    rm -v "$ServerRoot"/mods/"${SelectedPackage}"_*.jar
    Log r $SelectedPackage "File deleted."
}

function GET {
    curl https://api.modrinth.com/v2/project/$SelectedPackage || LogFail "Failed to GET to server, either the package does not exist or a connection to the server couldn't be made."
}

function GetPackageFileURLGivenVersion {
    curl https://api.modrinth.com/v2/project/$SelectedPackage/version/$SelectedVersion | jq -r ".files[].url"
}

function PackageWorksOnServer {
    case $(curl https://api.modrinth.com/v2/project/$SelectedPackage | jq -r .server_side) in
        "required"|"optional")
            true
        ;;
        *)
            false
        ;;
    esac
}

function PackageIsCompatibleWithServer {
    curl https://api.modrinth.com/v2/project/$SelectedPackage | jq -r ".game_versions[]" | grep $ServerVersion
}

function PackageVersionIsCompatibleWithServer {
    curl https://api.modrinth.com/v2/project/$SelectedPackage/version | jq -r ".[].game_versions[]" | grep $ServerVersion
}

function PackageIsCompatibleWithServerSoftware {
    curl https://api.modrinth.com/v2/project/$SelectedPackage | jq -r ".loaders[]" | grep $ServerSoftware
}

function PackageExists {
    ls $ServerModFolder | grep -E "^${1}_[^_]+\.jar$" || echo "NONEXISTENT"
}

function GetPackageInformation {
    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi
    curl https://api.modrinth.com/v2/project/$SelectedPackage | jq -r | less
}

function GetPackageVersions {
    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi
    curl https://api.modrinth.com/v2/project/$SelectedPackage/version | jq -r | less
}

function GetPackageDependencies {
    if [[ $SelectedPackage == "" ]]; then
        LogFail "Please specify a package."
    fi
    curl https://api.modrinth.com/v2/project/$SelectedPackage/dependencies | jq -r ".projects[].slug"
}

function IsRunningInServer {
    test -f $ServerRoot/cpm.conf
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
