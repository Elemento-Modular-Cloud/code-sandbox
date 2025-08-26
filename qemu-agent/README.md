# QEMU AGENT - USEFULL STUFF

## adding a new channel to a running VM

1️⃣ search for the VM domain

```bash 
[root@orbital-purple ~] virsh list --all
 Id    Name                                   State
--------------------------------------------------------
 157   e5d8966b-4646-4ec8-b649-8ddd62a0490d   running
 -     qemu-agent-testing                     shut off
```

2️⃣ create an xml file for the device <br>
create a file with this content:
```xml
<channel type='unix'>
  <target type='virtio' name='org.qemu.guest_agent.0'/>
</channel>
```

3️⃣ attach the device to the VM

```bash
virsh attach-device <vm_domain>  <file_to_the_agent_xml> 
```

```bash
[root@orbital-purple xmls] virsh attach-device e5d8966b-4646-4ec8-b649-8ddd62a0490d  agent.xml 
Device attached successfully
```

4️⃣ reboot the VM

5️⃣ install and run the agent inside the VM

## `agent-caller.sh` usage
This little tool maps some common calls that is possibile to do using the qemu agent to the VM.
Copy it on your host and make it executable (`chmod +x agent-caller.sh`)

### usage examples
#### Help and usage
```bash
# help

[root@orbital-purple scripts] ./qemu-agent.sh -h
Usage: ./qemu-agent.sh -d <domain> -c <command> [-- args for exec]

Options:
  -d, --domain   VM domain name
  -c, --command  Command to run
  -h, --help     Show this help

Commands:
  ping        - Check if agent is alive
  shutdown    - Shutdown guest cleanly
  reboot      - Reboot guest cleanly
  hostname    - Get guest hostname
  info        - Get guest OS/kernel info
  time        - Get guest time
  set-time    - Sync guest time with host
  ip          - Get guest IP addresses
  fsinfo      - Get filesystem info
  fsfreeze    - Freeze filesystems
  fsthaw      - Thaw filesystems
  exec -- <cmd...>  - Run command inside guest
  ```

#### ping
```bash
# verify if the agent is present and is working
[root@orbital-purple scripts] ./qemu-agent.sh -d e5d8966b-4646-4ec8-b649-8ddd62a0490d -c ping
{
  "return": {
  }
}
```

#### hostname
```bash
# ask for the vm hostname
[root@orbital-purple scripts] ./qemu-agent.sh -d e5d8966b-4646-4ec8-b649-8ddd62a0490d -c hostname
{
  "return": {
    "host-name": "ionia"
  }
}
```

#### other possbile options

| Command   | Description                  |
|-----------|------------------------------|
| ping      | Check if agent is alive      |
| shutdown  | Shutdown guest cleanly       |
| reboot    | Reboot guest cleanly         |
| hostname  | Get guest hostname           |
| info      | Get guest OS/kernel info     |
| time      | Get guest time               |
| set-time  | Sync guest time with host    |
| ip        | Get guest IP addresses       |
| fsinfo    | Get filesystem info          |
| fsfreeze  | Freeze filesystems           |
| fsthaw    | Thaw filesystems             |