My company project is called Guardian and the relevant part of it is located in `~/dev/Guardian/provision/nix`.  Starting in `flake.nix` I define
several deployments, which are clusters of machines that are typically on a LAN in one location. Most of these deployments are physically located in West Texas. 

Currently we rely on a reverse ssh tunnel initiated by a service running on each guardian machine called `guardian-agent` or just `agent`.
However, that leaves the problem that if agent fails for any reason we cannot reach the boxes.
I want to set up a VPN that gives us connectivity at the system level using wireguard.

The way I have it configured now is as a hub-and-spoke topology.  There is one hub right now but we will probably add more.  The hub, or "relay"
 is a peer that has a publicly accessible endpoint and is peers with all of the other machines on the VPN.  It also runs a service called 
 `wireguard-endpoint-registry` that broadcasts over http (on the VPN) the endpoints of all machines that have connected with it, 
 allowing the machines to query it and update their peer endpoints via a service called `wireguard-endpoint-client`.

There are also currently two development machines that are part of the network but not guardian systems.  There may be more in the future but as of now 
they are my two machines `thinkpad` which is a roaming laptop whose ipv4 may change often, and a workstation in my home lab called `adder-ws`.  They are both nixos
machines whose configuration is located in `~/dev/PC/flake.nix`. These machines also run a variant of the `wireguard-endpoint-client` via a hard-linked module
in a file called `wg-endpoint-discovery-lib.nix`.
 
In addition, in my test lab I have a cluster of guardian machines as part of the 
`Efrem.Home` deployment. their hostnames are `t1`, `t2`, and `j1`.  These machines are on the same LAN as `adder-ws` and they all broadcast avahi names,
so you can always access them as `t1.local`, `t2.local`, and `j1.local`.

Currently it appears that the endpoint registry server is failing, causing the clients to fail.  This has something to do with code we introduced for ipv6 support.

At the same time, I am trying to get IPv6 working on my own systems and lab router.  It is an Orbi RBR850, and my ISP is Comcast.
 I recently enabled Ipv6 on the router and found that my machines on my home lab LAN were assigned ipv6 addresses. However, ipv6 functionality seems to be 
 buggy or perhaps we need to make some configuration tweaks.  Ideally I would like to use mostly ipv6, to avoid dealing with NAT traversal.  Tt is not enabled by 
 default on most routers but I want to get it working on my own system first, so that it will be ready when we start deplying to networks that support it.

For now I want to make our dual-stack vpn robust enough that services are not failing, and they manage to recover if they fail.
I think if you look at the codebases which are not huge, it will be self explanatory.  There is some outdated documentation in ~/dev/Guardian/docs, so don't let that
confuse you.

A slightly further goal is to accommodate multiple relays. Right now each relay would publish its own endpoint registry and they are not coordinated.