/*
 * hostapd / Wifi-Goes-To-Town
 * Copyright (c) 2016, Hansen Qian <hq@cs.princeton.edu>
 *
 * This software may be distributed under the terms of the BSD license.
 * See README for more details.
 */

#ifndef AP_WGTT
#define AP_WGTT

/*
 * Initializes a listener for station information sent from other
 * routers.
 */
int wgtt_listen();

int wgtt_poll(struct hostapd_data *hapd);

int wgtt_sta_add(struct hostapd_data *hapd,
            struct hostapd_sta_add_params *params,
            struct ieee80211_vht_capabilities *vht_capab);

int wgtt_test_socket();

#endif /* AP_WGTT */