# Add hugepage to AtomOS manually

## Initial setup

Run the `hugepage-adder.sh` script in you machine, it basically does 2 things:
 - Add hugepage support to GRUB
 - Add the needed mount point int `/etc/fstab` and in `/mnt/huge`
```bash
chmod +x hugepage-adder.sh
sudo ./hugepage-adder.sh
```

## Libvirt hooks

copy the file `qemu` in `/etc/libvirt/hooks/`
```bash
sudo mv qemu /etc/libvirt/hooks/qemu
```
copy the file `hugepage_resizer.sh` in `/opt/elemento`
```bash
sudo mv hugepage_resizer.sh /opt/elemento/hugepage_resizer.sh
sudo chmod +x /opt/elemento/hugepage_resizer.sh
```

## modify request actuator or vm xml
in the `<memoryBacking>` libvirt tag make sure to add the `<hugepages/>` tag

for example:
```xml
<memoryBacking>
    <access mode='shared'/>
    <hugepages/>
</memoryBacking>
```

or modify request actuator to automatically add the tag when creating the XML (the function is `getRAMXML`)