
AddressInfo(AP1 192.168.1.2 C2:56:27:72:A3:5B
          , AP3 192.168.1.4 C2:56:27:C9:0D:1C

          , MY_GATEWAY 192.168.1.1 00:0a:5e:55:a9:89
          , MY_CLIENT 192.168.1.135 a4:5e:60:ea:48:79
);

f_lan :: FromDevice(br-lan, SNIFFER true);
f_wlan1 :: FromDevice(wlan1, SNIFFER true);
t_wlan1 :: ToDevice(wlan1);
t_lan :: ToDevice(br-lan);

que_wlan1 :: Queue(1000);
que_lan :: Queue(1000);

ipcl_B :: IPClassifier(dst host AP3 && dst udp port 55001
                     , -
                     );
ipcl_C :: IPClassifier(dst net 192.168.1.0 mask 255.255.255.0
                     , -
                     );

debug_tee :: Tee;

que_wlan1 -> t_wlan1;
que_lan -> t_lan;

// DOWNLINK
// ==============================================

f_lan
    -> Strip(14)
    -> CheckIPHeader(VERBOSE false)
    -> ipcl_B;

ipcl_B[0]
//    -> IPPrint
    -> StripIPHeader
    -> Strip(8)
    -> MarkMACHeader(0)
    -> debug_tee
    -> que_wlan1;
ipcl_B[1]
    -> Discard;

debug_tee[1]
    -> Strip(14)
    -> CheckIPHeader(VERBOSE true)
    -> IPPrint
    -> Discard;

// UPLINK
// ===============================================

f_wlan1
    -> ipcl_C;

ipcl_C[0]
    -> que_lan;
ipcl_C[1]
    -> IPPrint
    -> UDPIPEncap(AP3, 55001, MY_GATEWAY, 55001)
    -> EtherEncap(0x0800, MY_CLIENT, MY_GATEWAY)
    -> que_lan;
