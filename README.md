# ChiselPM

[![asciicast](https://asciinema.org/a/YvzTTnLylG92DJwcHNlQ9uvuJ.svg)](https://asciinema.org/a/YvzTTnLylG92DJwcHNlQ9uvuJ)
<small>Demonstration of ChiselPM in the terminal</small>

[![asciicast](https://asciinema.org/a/El5IEc2PJ0eRAM3wb9zJPRlHN.svg)](https://asciinema.org/a/El5IEc2PJ0eRAM3wb9zJPRlHN)
<small>Demonstration of the fix of the error in the above recording</small>

The CLI tool for managing your Minecraft server's mods

## Installation
All you need to do is install ChiselPM itself to the root of the minecraft server, and create a cpm.conf file. 

## Configuration
#### `ServerVersion`
Defines the minecraft version the server is running.

To specify the version, type it in after the =. For example;

```bash
ServerVersion="1.20.1"
```

#### `ServerSoftware`
Defines the mod loader the server is running.

To specify the loader, type it in after the =. For example;

```bash
ServerSoftware="fabric"
```

## Commands
To get the list of commands, run the "help" subcommand.