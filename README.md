# Beacon
Beacon is an offline Raspberry Pi project to serve Wiki sites, maps, and other important data in scenarios that internet is not available. The RPi will be configured with a Wifi hotspot that clients can connect to and access data using FQDNs through a web browser rather than any special apps. 

## Recommendations and Considerations
Using an SSD is strongly recommended for the increased read speeds due to resource-intensive nature of serving maps, especially if more than one client will be accessing data at a time. This project was developed and tested on a Raspberry Pi 4B with 8GB RAM and a Kingston SATA SSD connected via USB to SATA adapter.

Ubuntu Server 24.04.2 LTS is used for the OS, so the configuration script is built around the nuances of it. Debian or Raspberry Pi OS could most likely be used with minimal changes, but other distros would likely require manual configuration tailored to that distro.

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
`touch ../system-boot/ssh`
