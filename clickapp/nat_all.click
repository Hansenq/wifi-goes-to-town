require(dhcp);

AddressInfo(LOOPBACK 127.0.0.1
          , MY_ETH0 128.112.94.43 00:25:64:a8:c0:78
          , MY_ETH3 192.168.1.1 00:0a:5e:55:a9:89

          , AP1 192.168.1.2 C0:56:27:72:A3:5B
          , AP3 192.168.1.4 C0:56:27:C9:0D:1C
          , AP4 192.168.1.5 14:91:82:29:45:53

          , MY_GATEWAY 128.112.94.1 78:ac:c0:25:af:00
          , SUBNET_MASK 255.255.255.0

          , MY_CLIENT 192.168.1.135 a4:5e:60:ea:48:79
)

// =====================================================
// Elements:
// =====================================================

f_eth0 :: FromDevice(eth0, SNIFFER false);
t_eth0 :: ToDevice(eth0);
f_eth3 :: FromDevice(eth3, SNIFFER false);
t_eth3 :: ToDevice(eth3);

//fheth0 :: FromHost(eth0);
//theth0 :: ToHost(eth0);
//fheth0 :: FromHost(eth0);
//theth3 :: ToHost(eth3);

que_eth3 :: Queue(1000);
que_eth0 :: Queue(1000);

aq_eth0 :: ARPQuerier(MY_ETH0);
aq_eth3 :: ARPQuerier(MY_ETH3);
ar_eth0 :: ARPResponder(MY_ETH0);
ar_eth3 :: ARPResponder(MY_ETH3);

encap_eth_gw :: EtherEncap(0x0800, MY_ETH0, MY_GATEWAY);
encap_eth_client :: EtherEncap(0x0800, MY_ETH3, MY_CLIENT);

encap_tun1 :: UDPIPEncap(MY_ETH3, 55001, AP1, 55001);
encap_tun3 :: UDPIPEncap(MY_ETH3, 55001, AP3, 55001);
encap_tun4 :: UDPIPEncap(MY_ETH3, 55001, AP4, 55001);
//encap_alg :: UDPIPEncapTun(MY_ETH3, 55001, AP1, 55001);


cl_A :: Classifier(12/0806 20/0001     // ARP Requests
                 , 12/0806 20/0002     // ARP Replies
                 , 12/0800
                 , -
                 );
ipcl_K :: IPClassifier(dst host MY_ETH3 && dst udp port 55002 && src udp port 55002
                     , -
                     );
cl_L :: Classifier(12/0806 20/0001     // ARP Requests
                 , 12/0806 20/0002     // ARP Replies
                 , 12/0800
                 , -
                 );
ipcl_B :: IPClassifier(tcp
                     , udp
                     , -
                     );
ipcl_C :: IPClassifier(dst host MY_ETH3
                     , dst net 192.168.1.0 mask 255.255.255.0
                     , -
                     );
ipcl_I :: IPClassifier(icmp type != 255
                     , -
                     );
ipcl_D :: IPClassifier(dst net 128.112.94.0 mask 255.255.255.0
                     , -
                     );
cl_E :: Classifier(12/0806 20/0001     // ARP Requests
                 , 12/0806 20/0002     // ARP Replies
                 , 12/0800
                 );
ipcl_F :: IPClassifier(dst port < 49152
                     , -
                     );
ipcl_J :: IPClassifier(icmp type != 255
                     , -
                     );
ipcl_G :: IPClassifier(dst host MY_CLIENT
                     , -
                     );

tcp_dedup :: DeDupTCPPacket;
udp_dedup :: DeDupUDPPacket;

icmpping_rewriter :: ICMPPingRewriter(pattern MY_ETH0 1024-65535 - - 0 1);
ip_rewriter :: IPRewriter(pattern MY_ETH0 1024-65535 - - 0 1);

tee_lan :: Tee;
tee_A :: Tee;
tee_B :: Tee;

// ======================================================
// Flows:
// ======================================================

// Helpful Flows:
// ======================================================

que_eth0 -> t_eth0;
que_eth3 -> t_eth3;

aq_eth0[0]
    -> que_eth0;
aq_eth0[1]
    -> que_eth0;
aq_eth3[0]
    -> que_eth3;
aq_eth3[1]
    -> tee_A
    -> que_eth3;
ar_eth0[0]
    -> que_eth0;
ar_eth0[1]
    -> Discard;
ar_eth3[0]
    -> tee_B
    -> que_eth3;
ar_eth3[1]
    -> tee_B;

// Send eth3 ARP req/resp to client
tee_A[1] -> tee_lan;
tee_B[1] -> tee_lan;


//tee_arp_eth0[1]
//    -> theth0;
//tee_arp_eth3[1]
//    -> theth3;

// Main Flows:
// ======================================================

f_eth3 -> cl_A;
f_eth0 -> cl_E;

// Uplink:
// ===========================

cl_A[0]         // ARP Requests
    -> ar_eth3;
cl_A[1]         // ARP Replies
    -> [1]aq_eth3;
cl_A[2]         // IP Packets
    -> Strip(14)
    -> CheckIPHeader
    -> ipcl_K;
cl_A[3]         // Other Packets
    -> Discard;

//ipcl_K[0]       // Packets tunnelled from AP
//    -> [1]encap_alg;
ipcl_K[1]       // Other packets
    -> ipcl_B;

//encap_alg[1]
ipcl_K[0]
    -> StripIPHeader
    -> Strip(8)
    -> MarkMACHeader
    -> cl_L;

cl_L[0]         // ARP Requests
    -> ar_eth3;
cl_L[1]         // ARP Replies
    -> [1]aq_eth3;
cl_L[2]         // IP Packets
    -> Strip(14)
    -> CheckIPHeader
    -> ipcl_B;
cl_L[3]         // Other Packets
    -> Discard;

ipcl_B[0]       // TCP
    -> CheckTCPHeader
    -> tcp_dedup
    -> ipcl_C;
ipcl_B[1]       // UDP
    -> CheckUDPHeader
    -> udp_dedup
    -> ipcl_C;
ipcl_B[2]
    -> ipcl_C;

ipcl_C[0]       // To this host
    -> Discard;
ipcl_C[1]       // To LAN
    -> aq_eth3;
ipcl_C[2]       // Packets to NAT
    -> ipcl_I;

ipcl_I[0]       // ICMP Packet
    -> [0]icmpping_rewriter;
ipcl_I[1]       // IP Packet
    -> [0]ip_rewriter;

icmpping_rewriter[0]    // Entering WAN
    -> ipcl_D;

ip_rewriter[0]     // Packets entering WAN
    -> ipcl_D;

ipcl_D[0]       // Packets to this subnet
    -> aq_eth0;
ipcl_D[1]       // Packets sent out to gateway
    -> encap_eth_gw
    -> que_eth0;


// DOWNLINK:
// ==========================

cl_E[0]       // ARP Requests
    -> ar_eth0;
cl_E[1]       // ARP Replies
    -> [1]aq_eth0;
cl_E[2]       // IP Packets
    -> Strip(14)
    -> CheckIPHeader
    -> ipcl_F;

ipcl_F[0]       // To this host
    -> Discard;
ipcl_F[1]       // Packets to be rewritten
    -> ipcl_J;

ipcl_J[0]       // ICMP Packet
    -> [0]icmpping_rewriter;
ipcl_J[1]       // IP Packet
    -> [0]ip_rewriter;

icmpping_rewriter[1]    // Entering LAN
    -> ipcl_G;
ip_rewriter[1]     // Packets entering LAN
    -> ipcl_G;

ipcl_G[0]       // Packets to Client
    -> encap_eth_client
    -> tee_lan;
//    -> [0]encap_alg;
ipcl_G[1]       // Packets to other devices
    -> aq_eth3;

tee_lan[0]
    -> encap_tun1
    -> aq_eth3;
tee_lan[1]
    -> encap_tun3
    -> aq_eth3;
tee_lan[2]
    -> encap_tun4
    -> aq_eth3;

//encap_alg[0]
//    -> aq_eth3;
