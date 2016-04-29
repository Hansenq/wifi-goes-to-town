require(dhcp);

AddressInfo(LOOPBACK 127.0.0.1
          , MY_ETH0 128.112.94.43 00:25:64:a8:c0:78
          , MY_ETH3 192.168.1.1 00:0a:5e:55:a9:89

          , AP1 192.168.1.2 C2:56:27:72:A3:5B
          , AP3 192.168.1.4 C2:56:27:C9:0D:1C

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
//encap_eth_client :: EtherEncap(0x0800, MY_ETH3, MY_CLIENT);

encap_udpip_dhcp :: UDPIPEncap(MY_ETH3, 67, 255.255.255.255, 68);
encap_icmp_dhcp :: ICMPPingEncap(MY_ETH3, 255.255.255.255);
encap_eth_dhcp :: EtherEncap(0x0800, MY_ETH3, ff:ff:ff:ff:ff:ff);

//encap_tun1 :: UDPIPEncap(MY_ETH3, 55001, AP1, 55001);
//encap_tun3 :: UDPIPEncap(MY_ETH3, 55001, AP3, 55001);



cl_A :: Classifier(12/0806 20/0001
                 , 12/0806 20/0002
                 , 12/0800
                 , -
                 );
ipcl_B :: IPClassifier(tcp
                     , udp
                     , -
                     );
ipcl_C :: IPClassifier(dst MY_ETH3
                     , -
                     );
ipcl_D :: IPClassifier(dst net 128.112.94.0 mask 255.255.255.0
                     , -
                     );
cl_E :: Classifier(12/0806 20/0001
                 , 12/0806 20/0002
                 , 12/0800
                 );
ipcl_F :: IPClassifier(dst port < 49152
                     , -
                     );
ipcl_G :: IPClassifier(dst host MY_CLIENT
                     , -
                     );
ipcl_H :: IPClassifier(icmp type echo-reply
                     , -
                     );
dhcpcl_I :: DHCPClassifier(discover
                         , request
                         , release
                         , -
                         );

dhcp_server :: LeasePool(MY_ETH3, 192.168.1.10, 255.255.255.0, START 192.168.1.10, END 192.168.1.250);
dhcp_offer :: DHCPServerOffer(dhcp_server);
dhcp_check_msg :: CheckDHCPMsg;

tcp_dedup :: DeDupTCPPacket;
udp_dedup :: DeDupUDPPacket;

rewriter :: IPRewriter(pattern MY_ETH0 49152-65535# - - 0 1);

//tee_lan :: Tee;
//tee_arp_eth3 :: Tee;
//tee_arp_eth0 :: Tee;

// ======================================================
// Flows:
// ======================================================

// Helpful Flows:
// ======================================================

que_eth0 -> t_eth0;
que_eth3 -> t_eth3;

aq_eth0[0] -> que_eth0;
aq_eth0[1] -> que_eth0;
aq_eth3[0] -> que_eth3;
aq_eth3[1] -> que_eth3;
ar_eth0[0] -> que_eth0;
ar_eth0[1] -> Discard;
ar_eth3[0] -> que_eth3;
ar_eth3[1] -> Discard;


//tee_arp_eth0[1]
//    -> theth0;
//tee_arp_eth3[1]
//    -> theth3;

// Main Flows:
// ======================================================

f_eth3 -> cl_A;
f_eth0 -> cl_E;

cl_A[0]         // ARP Replies
    -> [1]aq_eth3;
cl_A[1]         // ARP Requests
    -> ar_eth3
cl_A[2]         // IP Packets
    -> Strip(14)
    -> CheckIPHeader
    -> ipcl_B;
cl_A[3]         // Other Packets
    -> Discard;

ipcl_B[0]       // TCP
    -> CheckTCPHeader
    -> tcp_dedup
    -> ipcl_C;
ipcl_B[1]       // UDP
    -> CheckUDPHeader
    -> udp_dedup
    -> ipcl_H;
ipcl_B[2]
    -> ipcl_C;

ipcl_C[0]       // To this host
//    -> EtherEncap(0x0800, )
// TODO: Need to fix this. Probably just not do it.
    -> Discard;
ipcl_C[1]       // Packets to NAT
    -> [0]rewriter;

rewriter[0]     // Packets entering WAN
    -> ipcl_D;
rewriter[1]     // Packets entering LAN
    -> ipcl_G;

ipcl_D[0]       // Packets to this subnet
    -> aq_eth0;
ipcl_D[1]       // Packets sent out to gateway
    -> encap_eth_gw
    -> que_eth0;

cl_E[0]       // ARP Replies
    -> [1]aq_eth0;
cl_E[1]       // ARP Requests
    -> ar_eth0;
cl_E[2]       // IP Packets
    -> Strip(14)
    -> CheckIPHeader
    -> ipcl_F;

ipcl_F[0]       // Packets on normal ports
    -> Discard;
ipcl_F[1]       // Packets to be rewritten
    -> [0]rewriter;

ipcl_G[0]       // Packets to be tunnelled
    -> aq_eth3; // Just forward all packets for now
//    -> EtherEncap(0x800, MY_ETH3, MY_CLIENT)
//    -> tee_lan;
ipcl_G[1]       // Packets to other devices
    -> aq_eth3;

ipcl_H[0]
    -> [1]dhcp_offer;
ipcl_H[1]
    -> dhcp_check_msg;

dhcp_check_msg[0]
    -> dhcpcl_I;
dhcp_check_msg[1]
    -> ipcl_C;

dhcpcl_I[0]
    -> [0]dhcp_offer;
dhcpcl_I[1]
    -> DHCPServerACKorNAK(dhcp_server)
    -> encap_udpip_dhcp;
dhcpcl_I[2]
    -> DHCPServerRelease(dhcp_server);
dhcpcl_I[3]
    -> Discard;

dhcp_offer[0]
    -> encap_udpip_dhcp;
dhcp_offer[1]
    -> encap_icmp_dhcp
//    -> DHCPICMPEncap(dhcp_offer.dhcp_icmp_ping_src, dhcp_offer.dhcp_icmp_ping_dst)
    -> que_eth3;

encap_udpip_dhcp
    -> encap_eth_dhcp
    -> que_eth3;

//tee_lan[0]
//    -> encap_tun1
//    -> que_eth3;
//tee_lan[1]
//    -> encap_tun3
//    -> que_eth3;


