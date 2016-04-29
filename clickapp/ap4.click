
AddressInfo(AP1 192.168.1.2 C0:56:27:72:A3:5B
          , AP3 192.168.1.4 C0:56:27:C9:0D:1C
          , AP4 192.168.1.5 14:91:82:29:45:53

          , MY_GATEWAY 192.168.1.1 00:0a:5e:55:a9:89
          , MY_CLIENT 192.168.1.135 a4:5e:60:ea:48:79
);

f_lan :: FromDevice(br-lan, SNIFFER true);
f_wlan1 :: FromDevice(wlan1, SNIFFER true);
t_wlan1 :: ToDevice(wlan1);
t_lan :: ToDevice(br-lan);

que_wlan1 :: Queue(1000);
que_lan :: Queue(1000);

ipcl_B :: IPClassifier(src host MY_GATEWAY && dst host AP4 && dst udp port 55001 && src udp port 55001
                     , -
                     );

uplink_tee :: Tee;
downlink_tee :: Tee;

que_wlan1 -> t_wlan1;
que_lan -> t_lan;

// DOWNLINK
// ==============================================

f_lan
    -> Strip(14)        // Strip Eth
    -> CheckIPHeader(VERBOSE false)
    -> ipcl_B;

ipcl_B[0]
    -> StripIPHeader    // Strip IP
    -> Strip(8)         // Strip UDP
    -> MarkMACHeader(0)
    -> uplink_tee
    -> que_wlan1;
ipcl_B[1]
    -> Discard;

uplink_tee[1]
    -> Strip(14)
    -> CheckIPHeader(VERBOSE true)
    -> IPPrint
    -> Discard;

// UPLINK
// ===============================================

f_wlan1
    -> Align(4, 0)
    -> downlink_tee
    -> UDPIPEncap(AP4, 55002, MY_GATEWAY, 55002)
    -> EtherEncap(0x0800, AP4, MY_GATEWAY)
    -> que_lan;

downlink_tee[1]
    -> Strip(14)
    -> chk_ip :: CheckIPHeader(VERBOSE true)
    -> Discard;


