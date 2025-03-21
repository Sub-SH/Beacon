# Beacon
Beacon is an offline Raspberry Pi project to serve Wiki sites, maps, and other important data in scenarios that internet is not available. The RPi will be configured with a Wifi hotspot that clients can connect to and access data using FQDNs through a web browser rather than any special apps. 

## Recommendations and Considerations
❗ The RPi must be a fresh install, and must be hardwired into internet during setup as the script configures the wlan controller. The initial instructions set you up to be able to SSH in if the RPi is running headless, however, you could use a monitor, mouse, and keyboard if you wish.

⚠️ Using an SSD is strongly recommended for the increased read speeds due to resource-intensive nature of serving maps, especially if more than one client will be accessing data at a time. This project was developed and tested on a Raspberry Pi 4B with 8GB RAM and a Kingston SATA SSD connected via USB to SATA adapter.

⚠️ Ubuntu Server 24.04.2 LTS is used for the OS, so the configuration script is built around the nuances of it. Debian or Raspberry Pi OS could most likely be used with minimal changes, but other distros would likely require manual configuration tailored to that distro.

A Linux workstation was used when creating this project, so the initial steps to format the RPi are from a Linux perspective. It is on the roadmap to provide instructions for the initial setup using Windows, which is probably very easy using the official Raspberry Pi imaging tool.   

## Getting Started

### Formatting the SSD
Download Ubuntu Server LTS for Raspberry Pi from [Canonical’s website](https://ubuntu.com/download/raspberry-pi).

Connect the SSD to your workstation and identify the device’s name. If you connect the SSD via a USB adapter, it will most likely show up as sdx, where “x” will be unique to you depending on how many devices you have connected. To identify it, open a terminal and use these commands:

```
# Quickly view connected storage devices and their size:
lsblk

# If you’re unable to identify which device it is using lsblk, you can use fdisk to provide additional information such as the disk model:
sudo fdisk -l
```

Once you’ve identified the name of the drive, format the disk with the downloaded Ubuntu Server image. Change the path to the image and device to reflect your environment:

```
sudo dd if=path/to/ubuntu-24.04.X.img of=/dev/sdX bs=4M status=progress conv=fsync
```

This process should only take a few moments to complete. Once finished, do not unplug the drive as we need to make configuration changes before it boots up for the first time.

### Pre-boot configuration

If your OS didn’t automatically mount the drive partitions after finishing the format, you’ll need to do so manually. You can use the Disks utility, `mount` via terminal, or whatever utility your OS comes with. Make sure you mount both the `system-boot` and `writable` partitions. 

First, we’re going to specify the name of the default user information that you want to create by editing the `cloud.cfg` file. You can either do this by browsing to it in a file manager GUI and editing it, or using a cli tool such as `vim`, `nano`, etc. 

NOTE: Editing this file requires sudo permissions

Edit ../writable/etc/cloud/cloud.cfg
```
# Scroll down until you see default_user: and change the following:
name: <username>
lock_passwd: false
gecos: <Full Name>
sudo: [“ALL=(ALL) ALL”]
```

Save the file and exit. 

Next, we will edit the hostname, require a password change*, and allow SSH password authentication** by editing `user-data`. 

*Requiring a password change rather than specifying the desired password is best practice as the initial password can be found in config files and system logs.\
**While using SSH keys is vastly preferred over password auth, ensuring the keys are on any device that you may potentially need to administrate the RPi in an emergency situation could be a hindrance.  

NOTE: Do NOT use sudo permissions when editing these files

Edit ../system-boot/user-data
```
# Scroll down until you see chpasswd: and edit the following:
- name: <same username you specified in the cloud.cfg file>
password: <a temp password that’s easy to remember, or just leave it as it is>

# Scroll down until you see #hostname: ubuntu and uncomment it. Change it to:
hostname: <hostname>

# Scroll down until you see ssh_pwauth: false and change it to:
ssh_pwauth: true
```

Finally, we’ll enable SSH by creating an empty file called SSH

```touch ../system-boot/ssh```

We’re now ready to boot up the RPi for the first time. Unmount the partitions, disconnect the SSD, plug it into your RPi, and boot it up. Once it’s booted up, find the IP address it was assigned (you may have to log into your router and look at DHCP leases) and SSH into it:
`ssh <user>@<ip>

You will be prompted to change your password. Re-enter the current temporary password, then enter a new password. After successfully changing the password, your SSH session will be terminated. SSH in again using the previous command.   

## Run the config script
The configuration script can now be run. To do so:

```
wget https://raw.githubusercontent.com/Sub-SH/Beacon/main/beacon.sh
chmod +x ./beacon.sh
sudo ./beacon.sh

```

The script will take several minutes to run, primarily due to updating the system. Once it completes, the system will automatically reboot.

Note: At this point, the Wiki and Map servers are not yet running. You must get the desired Wiki sites and maps, then put them in the appropriate directories before starting up the Docker apps.

## Obtaining and transferring Wiki sites and map tiles
### Wiki Sites
Due to the slow direct download speed of Wiki sites from the Kiwix library, it is highly recommended to download them to your workstation via the torrent option first, then transfer them to the RPi. To do so:

1. Browse to the [Kiwix Library](https://library.kiwix.org) on your workstation
2. Find the desired Wiki sites, click the “Download” button, and choose either the magnet link or torrent file to download them
3. Once all downloaded, transfer them to your RPi using the following command:

```rsync -rvz path/to/wiki_files/*.zim <user>@<ip>:/opt/kiwix/data```

Alternatively, you can use `wget` to download them directly to `/opt/kiwix/data`, however, the download speed will be significantly slower (about 8 hours for just Wikipedia).

### Map Tiles
tileserver-gl-lite does not support rendered tiles, so your tiles must be vector tiles. This version of tileserver-gl was chosen for increased performance on a RPi. To obtain a dataset that contains streets, buildings, lakes, and trails for the full world, you can follow these steps:

1. Browse to [maptiler website](https://data.maptiler.com/downloads/planet/) and download the OpenStreetMap vector tiles. You will need to create an account first.
2. Once downloaded, transfer the maptile file over to the RPi using the following command:

```rsync -rvz path/to/map_tiles/<filename>.mbtiles <user>@<ip>:/opt/tileserver/data/map.mbtiles```

⚠️ We want to ensure that the file ends up on the RPi with a specific filename so that it is recognized by tileserver-gl. While you'll need to change the filename in the rsync command to that of what you have downloaded to your workstation, **do not** change *output name* (which is the very last portion of the command, ie `:/opt/tileserver/data/map.mbtiles`).

## Starting the Docker apps
Once the desired map tiles and wiki sites are in the appropriate directories, the Docker apps are ready to be started. To do so:

SSH back into the RPi:

```ssh <user>@<ip>```

Start the map server:

```
cd /opt/tileserver/
docker compose up -d
```

Start the Wiki server:

```
cd /opt/mapserver/
docker compose up -d
```

That’s it! Both services should be up and running. The services will automatically start back up after reboots as long as you do not manually bring the docker containers down. 

## Accessing the Wikis and Maps
To access the services:
1. Connect to the RPi WiFi hotspot
2. Using a browser, navigate to http://192.168.2.1:8080 for the Wikis
3. Using a browser, navigate to http://192.168.2.1:8081 for the Maps

## Roadmap
I plan to continue improving this project. Here are some of the items on the roadmap:

**Reverse Proxy w/ FQDNs:** I plan to stick the services behind a reverse proxy (Caddy) so that the services can be accessed using FQDN such as http://maps.beacon.com and http://wiki.beacon.com. This also provides some additional benefits such as only exposing one external port and easy SSL/HTTPS. 

**Windows Instructions:** These instructions were created from the steps I took while using a Linux workstation. Translating them to work from a Windows workstation should be easy enough.

**Cyberdeck w/ GUI:** Rather than a hotspot for devices to connect to, I would like to make a ‘cyberdeck’ version with a screen and keyboard that uses a GUI to interact with everything.

