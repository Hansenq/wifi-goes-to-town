// forward.click

AddressInfo(
    // The address of a machine and a network segment.
    // This machine will route packets for the network via FromHost,
    // using the host address as source.
    TEST_NETWORK 18.1.1.1/8

    // This host's real address.
    , MY_ADDR 128.112.94.46 00:0a:5e:55:a9:89

    // The address of APs
    , AP1_ADDR 128.112.94.35
    , AP3_ADDR 128.112.94.38
    , MY_GATEWAY 128.112.94.1 78:ac:c0:25:af:00
    , SUBNET_MASK 255.255.255.0
)

elementclass FixChecksums {
    // fix the IP checksum, and any embedded checksums that include data
    // from the IP header (TCP and UDP in particular)
    input -> SetIPChecksum
        -> ipc :: IPClassifier(tcp, udp, -)
        -> SetTCPChecksum
        -> output;
    ipc[1] -> SetUDPChecksum -> output;
    ipc[2] -> output
}

// Install a kernel filter to redirect all packets to here
fdev :: FromDevice(eth3, SNIFFER false);
tdev :: ToDevice(eth3);

que :: Queue;

//fhost :: FromHost();
//thost :: ToHost(eth3);

aq :: ARPQuerier(MY_ADDR);

ar :: ARPResponder(MY_ADDR);

// Outputs ARP Packets, IP Packets, other
src_cl :: Classifier(12/0806 20/0001,
                     12/0806 20/0002,
                     12/0800,
		     -);

src_ip_cl :: IPClassifier(dst MY_ADDR
			  , -);
//ip_cl_dstunrch :: IPClassifier((icmp type 3) or (tcp[13] 20) or (tcp[13] 4), -);
ip_cl_tcpudp :: IPClassifier(tcp, udp, -);
ip_cl_locrem :: IPClassifier(dst net 128.112.94.0 mask 255.255.255.0
			     , -);

// 0 and 1 (FOUTPUT, ROUTPUT) are the output ports to connect your flow
// diagram. 0 outputs packets matching forwards, 1 outputs packets
// matching backwards
ipr_NAT :: IPRewriter(pattern MY_ADDR 49152-65535# - - 0 1);


// Make sure that SRC IP and DST IP are the same before calling this!
dedup_tcp :: DeDupTCPPacket;
dedup_udp :: DeDupUDPPacket;
//dedup_ip :: DeDupIPPacket;

// Send downlink to both routers
split :: Tee;

// Helpful stuff

que
    -> tdev;
aq[0]
    -> que;
aq[1]
    -> que;

ar[0]
    -> que;
ar[1]
    -> ARPPrint
    -> Discard;


// Custom Code

fdev -> src_cl

// Handle ARP requests
src_cl[0]
    -> ar;

// Handle ARP Replies
src_cl[1]
    -> [1]aq;                               // Send ARP responses into AQ

// Handle IP Packets
src_cl[2]                                   // IP Packets
    -> Strip(14)                            // Remove ethernet header (see StripEtherVlanHeader)
    -> MarkIPHeader(0)
    -> src_ip_cl;

// Handle all other packets
src_cl[3]
    -> StoreEtherAddress(MY_GATEWAY, dst)
    -> que

// Downlink IP Packets sent to this computer.
// We want to rewrite them and forward to the right router.
src_ip_cl[0]
    -> [0]ipr_NAT;

// Uplink IP Packets
src_ip_cl[1]
//    -> ip_cl_dstunrch;
    -> ip_cl_tcpudp;

// Drop all ICMP-Destination Unrecheable packets
//ip_cl_dstunrch[0]
//    -> IPPrint
//    -> Discard;
//ip_cl_dstunrch[1]
//    -> ip_cl_tcpudp;

// TCP
ip_cl_tcpudp[0]
    -> dedup_tcp
    -> [0]ipr_NAT;

// UDP and IP can handle duplicate packets just fine.
// UDP
ip_cl_tcpudp[1]
    -> dedup_udp
    -> [0]ipr_NAT;

// Other IP
ip_cl_tcpudp[2]
//    -> dedup_ip
    -> [0]ipr_NAT;


// Uplink Packets
ipr_NAT[0]
    -> FixChecksums
    -> ip_cl_locrem;

// Downlink Packets
ipr_NAT[1]
    -> split;

// ============================================
// THIS DOESNT WORK BECAUSE THE PORT ISNT OPEN!
// ============================================
ipr_ap3 :: IPRewriter(pattern - - AP3_ADDR - 0 1);
split[0]
    -> [0]ipr_ap3;
ipr_ap3[0]
    -> FixChecksums
    -> ip_cl_locrem;
ipr_ap1 :: IPRewriter(pattern - - AP1_ADDR - 0 1);
split[1]
    -> [0]ipr_ap1;
ipr_ap1[0]
    -> FixChecksums
    -> ip_cl_locrem;

ipr_ap1[1] -> Discard;
ipr_ap3[1] -> Discard;

// Packet is sent to local network (128.112.94.x)
ip_cl_locrem[0]
    -> aq;

// Packet is sent to gateway for remote network
ip_cl_locrem[1]
    -> EtherEncap(0x0800, MY_ADDR, MY_GATEWAY)
    -> que;
