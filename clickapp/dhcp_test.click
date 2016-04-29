
require(dhcp);


fdev :: FromDevice(en0);
tdev :: ToDevice(en0);

que :: Queue(1000);

udp_encap :: UDPIPEncap( 192.168.10.10, 67, 255.255.255.255, 68 );
icmp_encap :: ICMPPingEncap(192.168.10.10, 255.255.255.255) ;
eth_encap :: EtherEncap( 0x0800, 52:54:00:E5:33:17 , ff:ff:ff:ff:ff:ff);

cl_dhcp :: DHCPClassifier(discover
                        , request
                        , release
                        , -
                        );

dhcp_server :: LeasePool(11:22:33:44:55:66, 192.168.10.1, 192.168.10.0, START 192.168.10.10, END 192.168.10.250);
dhcp_offer :: DHCPServerOffer(dhcp_server);

ipcl :: IPClassifier(icmp type echo-reply
                   , -
                   );


// ============================

que -> tdev;


fdev
    -> Strip(14)
    -> Align(4, 0)
    -> CheckIPHeader(CHECKSUM true)
    -> CheckUDPHeader
    -> ipcl;

ipcl[0]
    -> [1]dhcp_offer;
ipcl[1]
    -> CheckDHCPMsg
    -> cl_dhcp;

cl_dhcp[0]
    -> [0]dhcp_offer;
cl_dhcp[1]
    -> DHCPServerACKorNAK(dhcp_server)
    -> udp_encap
    -> eth_encap
    -> que;
cl_dhcp[2]
    -> DHCPServerRelease(dhcp_server);
cl_dhcp[3]
    -> Discard;

dhcp_offer[0]
    -> udp_encap
    -> eth_encap
    -> que;
dhcp_offer[1]
    -> icmp_encap
//    -> DHCPICMPEncap(dhcp_offer.dhcp_icmp_ping_src, dhcp_offer.dhcp_icmp_ping_dst)
    -> que;



