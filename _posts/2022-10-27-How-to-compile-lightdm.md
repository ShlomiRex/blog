---
title: "How to compile lightdm (linux)"
published: true
layout: post
---

[lightdm](https://github.com/canonical/lightdm) is popular display manager used in linux distros. In my case, I want to use it to create my own greeter. A greeter is the 'login page' of the linux distro.

Let's get to it.

On Ubuntu 22.04 (server/desktop, doesn't matter):

`apt install build-essential autoconf gtk-doc-tools intltool libgcrypt20-dev libpam0g-dev libgtk-3-dev automake pkg-config fakeroot debhelper liblightdm-gobject-1-dev yelp-tools git`

Then clone the repo:

`git clone https://github.com/canonical/lightdm`

Compile:

`./autogen.sh`

`make`

Install lightdm:

`make install`

Configuration can be found at: `/usr/share/lightdm/lightdm.conf.d/`

> **_NOTE:_**  When you reboot, the greeter should not have changed; lightdm is only display manager, it doesn't provide greeter itself. When installing lightdm from apt directly, it installs lightdm, and lightdm-gtk-greeter.