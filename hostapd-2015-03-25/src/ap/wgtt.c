/*
 * hostapd / Wifi-Goes-To-Town
 * Copyright (c) 2016, Hansen Qian <hq@cs.princeton.edu>
 *
 * This software may be distributed under the terms of the BSD license.
 * See README for more details.
 */

#include "utils/includes.h"
#include "utils/list.h"
#include "utils/common.h"
#include "common/defs.h"
#include "common/ieee802_11_defs.h"
#include "common/hw_features_common.h"
#include "wps/wps.h"
#include "p2p/p2p.h"
#include "hostapd.h"
#include "ieee802_11.h"
#include "ieee802_11_auth.h"
#include "sta_info.h"
#include "ap_config.h"
#include "p2p_hostapd.h"
#include "hs20.h"
#include "ap_drv_ops.h"
#include "drivers/nl80211_copy.h"
#include "drivers/driver.h"
#include "wpa_auth.h"

/* Needed for sockets */
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <netdb.h>
#include <netinet/in.h>
#include <signal.h>
#include <sys/fcntl.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/unistd.h>
#include <sys/wait.h>

#define PORT_SEND "1244"
#define PORT_LISTEN 1244

#define DEFAULT_IP "192.168.1.1"
#define IF_NAME "eth0"

#define COMP_IP "128.112.94.34"
#define WRT1900_L1_IP "128.112.94.31"
#define WRT1200_L1_IP "128.112.94.35"
#define WRT1200_L2_IP "128.112.94.36"
#define WRT1200_L3_IP "128.112.94.38"

#define LAN_IP_1 "192.168.1.1"
#define LAN_IP_2 "192.168.1.2"
#define LAN_IP_4 "192.168.1.4"
#define LAN_IP_5 "192.168.1.5"

#define BACKLOG_SIZE 10

#define MAX_PAYLOAD_SIZE 256

static u32 MAGIC_NUM = 0x5a3c9fe5;

/* See src/drivers/driver.h */
struct hostapd_sta_add_params_deref {
    u32 magic;
    u8 addr_deref[ETH_ALEN];
    u16 aid;
    u16 capability;

    u8 supp_rates_deref[WLAN_SUPP_RATES_MAX];
    size_t supp_rates_len;
    u16 listen_interval;

    struct ieee80211_ht_capabilities ht_capabilities_deref; /* can be local (handle_assoc_cb()) */

    struct ieee80211_vht_capabilities vht_capabilities_deref; /* can be local (handle_assoc_cb())*/
    int vht_opmode_enabled;
    u8 vht_opmode;
    u32 flags;
    u32 flags_mask;
#ifdef CONFIG_MESH
    enum mesh_plink_state plink_state;
#endif /* CONFIG_MESH */
    int set;
    u8 qosinfo;

    u8 ext_capab_deref;
    size_t ext_capab_len;

    u8 supp_channels_deref;
    size_t supp_channels_len;

    u8 supp_oper_classes_deref;
    size_t supp_oper_classes_len;
};

void params_to_deref(struct hostapd_sta_add_params *source,
        struct hostapd_sta_add_params_deref *dest)
{
    wpa_printf(MSG_INFO, "WGTT: %s %s():%d;", __FILE__, __FUNCTION__, __LINE__);
    os_memset(dest, 0, sizeof(*dest));

    dest->magic = MAGIC_NUM;

    if (source->addr != NULL) {
        os_memcpy(&(dest->addr_deref), source->addr, ETH_ALEN);
    }
    dest->aid = source->aid;
    dest->capability = source->capability;

    if (source->supp_rates != NULL) {
        os_memcpy(&(dest->supp_rates_deref), source->supp_rates, WLAN_SUPP_RATES_MAX);
    }
    dest->supp_rates_len = source->supp_rates_len;
    dest->listen_interval = source->listen_interval;

    if (source->ht_capabilities != NULL) {
        os_memcpy(&(dest->ht_capabilities_deref), source->ht_capabilities, sizeof(*(source->ht_capabilities)));
    }
    if (source->vht_capabilities != NULL) {
        os_memcpy(&(dest->vht_capabilities_deref), source->vht_capabilities, sizeof(*(source->vht_capabilities)));
    }
    dest->vht_opmode_enabled = source->vht_opmode_enabled;
    dest->vht_opmode = source->vht_opmode;
    dest->flags = source->flags;
    dest->flags_mask = source->flags_mask;
#ifdef CONFIG_MESH
    dest->plink_state = source->plink_state;
#endif /* CONFIG_MESH */
    dest->set = source->set;
    dest->qosinfo = source->qosinfo;

    if (source->ext_capab != NULL) {
        /* TODO: Ensure that the variables above are only u8 (see addr, supp_rates) */
        dest->ext_capab_deref = *(source->ext_capab);
    }
    dest->ext_capab_len = source->ext_capab_len;

    if (source->supp_channels != NULL) {
        dest->supp_channels_deref = *(source->supp_channels);
    }
    dest->supp_channels_len = source->supp_channels_len;

    if (source->supp_oper_classes != NULL) {
        dest->supp_oper_classes_deref = *(source->supp_oper_classes);
    }
    dest->supp_oper_classes_len = source->supp_oper_classes_len;
}

int deref_to_params(struct hostapd_sta_add_params_deref *source,
        struct hostapd_sta_add_params *dest,
        const u8 *addr, const u8 *supp_rates,
        const struct ieee80211_ht_capabilities *ht_capabilities,
        const struct ieee80211_vht_capabilities *vht_capabilities,
        const u8 *ext_capab, const u8 *supp_channels, const u8 *supp_oper_classes)
{
    wpa_printf(MSG_INFO, "WGTT: %s %s():%d;", __FILE__, __FUNCTION__, __LINE__);
    os_memset(dest, 0, sizeof(dest));

    dest->addr = addr;
    dest->aid = source->aid;
    dest->capability = source->capability;
    dest->supp_rates = supp_rates;
    dest->supp_rates_len = source->supp_rates_len;
    dest->listen_interval = source->listen_interval;
    dest->ht_capabilities = ht_capabilities;
    dest->vht_capabilities = vht_capabilities;
    dest->vht_opmode_enabled = source->vht_opmode_enabled;
    dest->vht_opmode = source->vht_opmode;
    dest->flags = source->flags;
    dest->flags_mask = source->flags_mask;
#ifdef CONFIG_MESH
    dest->plink_state = source->plink_state;
#endif /* CONFIG_MESH */
    dest->set = source->set;
    dest->qosinfo = source->qosinfo;
    dest->ext_capab = ext_capab;
    dest->ext_capab_len = source->ext_capab_len;
    dest->supp_channels = supp_channels;
    dest->supp_channels_len = source->supp_channels_len;
    dest->supp_oper_classes = supp_oper_classes;
    dest->supp_oper_classes_len = source->supp_oper_classes_len;
    return 0;
}

void sigchld_handler(int s)
{
    // waitpid() might overwrite errno, so we save and restore it:
    int saved_errno = errno;
    while(waitpid(-1, NULL, WNOHANG) > 0);
    errno = saved_errno;
}

// get sockaddr, IPv4 or IPv6:
void *get_in_addr(struct sockaddr *sa)
{
    if (sa->sa_family == AF_INET) {
        return &(((struct sockaddr_in*)sa)->sin_addr);
    }
    return &(((struct sockaddr_in6*)sa)->sin6_addr);
}

/* Currently UNUSED.
 * destAddr must be of size INET_ADDRSTRLEN
 */
int get_ip_address(char *destAddr, char *ifName, socklen_t length, struct sockaddr *addrPtr) {
    int err;
    struct ifaddrs *ifList, *ifa;
    struct sockaddr_in *addr;

    wpa_printf(MSG_INFO, "WGTT: %s %s():%d\n", __FILE__, __FUNCTION__, __LINE__);

    err = getifaddrs(&ifList);
    if (err != 0) {
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d; get_ip_address error: %s\n",
            __FILE__, __FUNCTION__, __LINE__, gai_strerror(err));
        return -1;
    }


    /* Print out all interface names */
    /*for (ifa = ifList; ifa != NULL; ifa = ifa->ifa_next) {
        wpa_printf(MSG_INFO, "WGTT %s, %s(): %d IF_NAME: %s", __FILE__, __FUNCTION__, __LINE__, ifa->ifa_name);
        addr = (struct sockaddr_in *) ifa->ifa_addr;
        inet_ntop(AF_INET, &addr->sin_addr, destAddr, length);
        wpa_printf(MSG_INFO, "WGTT %s, %s(): %d IP_ADDR: %s\n", __FILE__, __FUNCTION__, __LINE__, destAddr);
        wpa_printf(MSG_INFO, "WGTT %s, %s(): %d PORT: %s\n", __FILE__, __FUNCTION__, __LINE__, ntohs(addr->sin_port));
        if (strcmp(destAddr, WRT1200_L3_IP) == 0) {
            os_memcpy(addrPtr, addr, sizeof(struct sockaddr));
        }
        os_memset(destAddr, 0, length);
    }*/
    /* walk through the list of interfaces and pick the one that matches ifName*/
    for (ifa = ifList; ifa != NULL; ifa = ifa->ifa_next) {
        if (strcmp(ifa->ifa_name, ifName) == 0) {
            break;
        }
    }
    if (ifa == NULL) {
        freeifaddrs(ifList);
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d; get_ip_address error: %s\n",
            __FILE__, __FUNCTION__, __LINE__, "ifa is null");
        return -1;
    }

    addr = (struct sockaddr_in *) ifa->ifa_addr;
    if (addr == NULL) {
        freeifaddrs(ifList);
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d; get_ip_address error: %s\n",
            __FILE__, __FUNCTION__, __LINE__, "ifa_addr is null");
        return -1;
    }

    inet_ntop(AF_INET, &addr->sin_addr, destAddr, length);
    wpa_printf(MSG_INFO, "WGTT %s, %s(): %d Retrieved IP Address: %s\n", __FILE__, __FUNCTION__, __LINE__, destAddr);
    freeifaddrs(ifList);
    return 0;
}

int wgtt_listen()
{
    int err = 0;
    struct sigaction sa;
    int sockfd;
    int bytes_sent;
    struct sockaddr listenSockAddr;
    struct sockaddr_in *sockAddrPtr;
    int optval1 = 1;
    char *optval2 = "br-lan";

    wpa_printf(MSG_INFO, "WGTT: %s %s():%d\n", __FILE__, __FUNCTION__, __LINE__);

    /* Create sockAddr struct pertaining to port 1244, IPv4 */
    /* Don't forget to allow traffic to port 1244 in firewall! */
    os_memset(&listenSockAddr, 0, sizeof(listenSockAddr));
    sockAddrPtr = (struct sockaddr_in *) &listenSockAddr;
    sockAddrPtr->sin_family = AF_INET;
    sockAddrPtr->sin_port = htons(PORT_LISTEN);
    sockAddrPtr->sin_addr.s_addr = INADDR_ANY;  /* bind to all addresses */

    sockfd = socket(PF_INET, SOCK_STREAM, 0);
    err = setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &optval1, sizeof(int));
    err = setsockopt(sockfd, SOL_SOCKET, SO_BINDTODEVICE, optval2, sizeof(optval2));
    err = bind(sockfd, &listenSockAddr, sizeof(listenSockAddr));
    if (err != 0) {
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d; bind() failed.", __FILE__, __FUNCTION__, __LINE__);
        close(sockfd);
        return -1;
    }

    err = listen(sockfd, BACKLOG_SIZE);
    if (err < 0) {
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d; listen() failed.", __FILE__, __FUNCTION__, __LINE__);
        close(sockfd);
        return -1;
    }

    /* Reap all dead processes created through fork() */
    sa.sa_handler = sigchld_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    if (sigaction(SIGCHLD, &sa, NULL) == -1) {
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d; sigaction() failed.", __FILE__, __FUNCTION__, __LINE__);
        close(sockfd);
        return -1;
    }

    /* Set to non-blocking */
    fcntl(sockfd, F_SETFL, O_NONBLOCK);

    /* Don't forget to close sockfd, somewhere else! */
    return sockfd;
}

int wgtt_send(char *ip_addr, char *port, void *data, int data_len)
{
    int err;
    struct addrinfo hints;
    struct addrinfo *firstInfo;
    struct addrinfo *addrInfo;
    int sockfd;
    int bytes_sent;
    struct timeval timeout;

    wpa_printf(MSG_INFO, "WGTT: %s %s():%d\n", __FILE__, __FUNCTION__, __LINE__);

    if (data_len > MAX_PAYLOAD_SIZE) {
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d Payload is too big! %d", __FILE__, __FUNCTION__, __LINE__, data_len);
        return -1;
    }

    os_memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;        /* Don't care if v4 or v6 */
    hints.ai_socktype = SOCK_STREAM;    /* TCP */

    timeout.tv_sec = 10;
    timeout.tv_usec = 0;

    /* Get information about the remote host! */
    err = getaddrinfo(ip_addr, port, &hints, &firstInfo);
    if (err != 0) {
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d; getaddrinfo error: %s\n",
            __FILE__, __FUNCTION__, __LINE__, gai_strerror(err));
        return -1;
    }

    /* Pick the right one for our needs */
    for (addrInfo = firstInfo; addrInfo != NULL; addrInfo = addrInfo->ai_next) {
        sockfd = socket(addrInfo->ai_family, addrInfo->ai_socktype, addrInfo->ai_protocol);
        if (sockfd < 0) {
            wpa_printf(MSG_INFO, "WGTT: %s %s(): socket() failed.", __FILE__, __FUNCTION__);
            continue;
        }
        /* Set socket options */
        err = setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout, sizeof(timeout));
        if (err == -1) {
            wpa_printf(MSG_INFO, "WGTT: %s %s(): setsockopt() failed.", __FILE__, __FUNCTION__);
            close(sockfd);
            continue;
        }
        /* Connect to remote host */
        /* WARNING: Will hang (for 90 sec) if the host exists, but the port isn't open */
        err = connect(sockfd, addrInfo->ai_addr, addrInfo->ai_addrlen);
        if (err != 0) {
            wpa_printf(MSG_INFO, "WGTT: %s %s():%d; connect error", __FILE__, __FUNCTION__, __LINE__);
            close(sockfd);
            continue;
        }
        break;
    }
    freeaddrinfo(firstInfo);
    if (addrInfo == NULL) {
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d; Failed", __FILE__, __FUNCTION__, __LINE__);
        close(sockfd);
        return -1;
    }

    /* Set to non-blocking */

    /* Send message */
    wpa_printf(MSG_INFO, "WGTT: %s %s():%d; will send %d bytes", __FILE__, __FUNCTION__, __LINE__, data_len);
    bytes_sent = send(sockfd, data, data_len, 0);
    if (bytes_sent == -1) {
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d; send error", __FILE__, __FUNCTION__, __LINE__);
        close(sockfd);
        return -1;
    }
    wpa_printf(MSG_INFO, "WGTT: %s %s():%d; sent %d bytes out of %d bytes:",
        __FILE__, __FUNCTION__, __LINE__, bytes_sent, data_len);

    close(sockfd);
    return 0;
}

int wgtt_poll(struct hostapd_sta_add_params_deref *params_deref,
        int sockfd)
{
    struct sockaddr_storage their_addr;
    socklen_t sin_size;
    int new_fd;
    char strbuf[INET6_ADDRSTRLEN];
    char data[MAX_PAYLOAD_SIZE];
    int bytes_recv;

    sin_size = sizeof(struct sockaddr_storage);
    if (sockfd == -1) {
        return -1;
    }

    new_fd = accept(sockfd, (struct sockaddr *) &their_addr, &sin_size);
    if (new_fd == -1) {
        /* If there is nothing to accept, or an error occurs */
        return -1;
    }

    os_memset(strbuf, 0, INET6_ADDRSTRLEN);
    inet_ntop(their_addr.ss_family, get_in_addr((struct sockaddr *)&their_addr), strbuf, INET6_ADDRSTRLEN);
    wpa_printf(MSG_INFO, "WGTT: %s %s():%d accept(): connected to addr: %s", __FILE__, __FUNCTION__, __LINE__, strbuf);

    os_memset(&data, 0, MAX_PAYLOAD_SIZE);

    bytes_recv = recv(new_fd, &data, sizeof(struct hostapd_sta_add_params_deref), 0);
    if (bytes_recv < 0) {
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d recv() error.", __FILE__, __FUNCTION__, __LINE__);
        close(new_fd);
        return -1;
    }
    if (bytes_recv == 0) {
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d recv() connection closed.", __FILE__, __FUNCTION__, __LINE__);
        close(new_fd);
        return -1;
    }
    wpa_printf(MSG_INFO, "WGTT: %s %s():%d recv() %d bytes.", __FILE__, __FUNCTION__, __LINE__, bytes_recv);
    if (bytes_recv != sizeof(*params_deref)) {
        close(new_fd);
        return -1;
    }
    wpa_printf(MSG_INFO, "WGTT: %s %s():%d Converting to struct", __FILE__, __FUNCTION__, __LINE__);

    os_memset(params_deref, 0, sizeof(*params_deref));
    os_memcpy(params_deref, &data, sizeof(*params_deref));

    if (params_deref->magic != MAGIC_NUM) {
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d; corrupted hostapd_sta_add_params!", __FILE__, __FUNCTION__, __LINE__);
        return -1;
    }
    close(new_fd);

    return 0;
}

/* See handle_auth() and handle_assoc() for what we are putting into sta.
 */
struct sta_info *wgtt_sta_info(struct hostapd_data *hapd,
        struct ieee80211_mgmt *mgmt,
        struct hostapd_sta_add_params_deref *params_deref)
{
    int res, i;
    struct sta_info *sta;
    u8 *addr;
    u16 auth_alg;
    u16 seq_ctrl = 0x6eb0;

    wpa_printf(MSG_INFO, "WGTT: %s %s():%d\n", __FILE__, __FUNCTION__, __LINE__);

    /* Normally done in handle_auth() */
    /* Should be a call to hostapd_allowed_address() here, but we assume
       the proper ACL lists are checked already. Everything it sets
       should be NULL (reflected below). */
    auth_alg = WLAN_AUTH_OPEN;

    addr = (u8 *) &(params_deref->addr_deref);
    sta = ap_get_sta(hapd, addr);
    if (!sta) {
        sta = ap_sta_add(hapd, addr);
        if (!sta) {
            /* WLAN_STATUS_AP_UNABLE_TO_HANDLE_NEW_STA */
            return NULL;
        }
    }
    os_memcpy(&(sta->supported_rates), &(params_deref->supp_rates_deref), WLAN_SUPP_RATES_MAX);

    wpa_printf(MSG_INFO, "WGTT: %s %s():%d\n", __FILE__, __FUNCTION__, __LINE__);
    /*sta->last_seq_ctrl = seq_ctrl; REPLACE*/
    sta->last_subtype = WLAN_FC_STYPE_AUTH;
    sta->psk = NULL;
    sta->identity = NULL;
    sta->radius_cui = NULL;
    sta->flags &= ~WLAN_STA_PREAUTH;
    ieee802_1x_notify_pre_auth(sta->eapol_sm, 0);
    sta->acct_interim_interval = 0;
    ap_sta_no_session_timeout(hapd, sta);

    sta->flags |= WLAN_STA_AUTH;
    wpa_auth_sm_event(sta->wpa_sm, WPA_AUTH);
    sta->auth_alg = auth_alg;
    mlme_authenticate_indication(hapd, sta);


    wpa_printf(MSG_INFO, "WGTT: %s %s():%d\n", __FILE__, __FUNCTION__, __LINE__);
    /* Normaly done in handle_auth_cb() */
    sta->flags |= WLAN_STA_AUTH;


    wpa_printf(MSG_INFO, "WGTT: %s %s():%d\n", __FILE__, __FUNCTION__, __LINE__);
    /* Normally done in handle_assoc() */
    sta->last_subtype = WLAN_FC_STYPE_ASSOC_REQ;

    /* followed by SSID and Supported rates; and HT capabilities if 802.11n
     * is used
    check_assoc_ies(hapd, sta, pos, left, 0);
    Stuff that hcheck_assoc_ies does but that we can't call right now*/
    sta->flags |= WLAN_STA_WMM;
    sta->flags |= WLAN_STA_HT;

    sta->capability = params_deref->capability;
    sta->listen_interval = params_deref->listen_interval;

    if (hapd->iface->current_mode->mode == HOSTAPD_MODE_IEEE80211G)
        sta->flags |= WLAN_STA_NONERP;
    for (i = 0; i < sta->supported_rates_len; i++) {
        if ((sta->supported_rates[i] & 0x7f) > 22) {
            sta->flags &= ~WLAN_STA_NONERP;
            break;
        }
    }
    if (sta->flags & WLAN_STA_NONERP && !sta->nonerp_set) {
        sta->nonerp_set = 1;
        hapd->iface->num_sta_non_erp++;
        if (hapd->iface->num_sta_non_erp == 1)
            ieee802_11_set_beacons(hapd->iface);
    }
    if (!(sta->capability & WLAN_CAPABILITY_SHORT_SLOT_TIME) &&
        !sta->no_short_slot_time_set) {
        sta->no_short_slot_time_set = 1;
        hapd->iface->num_sta_no_short_slot_time++;
        if (hapd->iface->current_mode->mode ==
            HOSTAPD_MODE_IEEE80211G &&
            hapd->iface->num_sta_no_short_slot_time == 1)
            ieee802_11_set_beacons(hapd->iface);
    }

    if (sta->capability & WLAN_CAPABILITY_SHORT_PREAMBLE)
        sta->flags |= WLAN_STA_SHORT_PREAMBLE;
    else
        sta->flags &= ~WLAN_STA_SHORT_PREAMBLE;

#ifdef CONFIG_IEEE80211N
    update_ht_state(hapd, sta);
#endif /* CONFIG_IEEE80211N */

    /* Station will be marked associated, after it acknowledges AssocResp
     */
    sta->flags |= WLAN_STA_ASSOC_REQ_OK;
    /* Make sure that the previously registered inactivity timer will not
     * remove the STA immediately. */
    sta->timeout_next = STA_NULLFUNC;


    wpa_printf(MSG_INFO, "WGTT: %s %s():%d\n", __FILE__, __FUNCTION__, __LINE__);
    /* Normally done in handle_assoc_cb() */
    hostapd_logger(hapd, sta->addr, HOSTAPD_MODULE_IEEE80211,
               HOSTAPD_LEVEL_DEBUG,
               "sta_info received from networked AP.");
    wpa_printf(MSG_INFO, "WGTT: Station Addr now at %p.", sta->addr);
    sta->flags |= WLAN_STA_ASSOC;
    sta->flags &= ~WLAN_STA_WNM_SLEEP_MODE;
    if ((!hapd->conf->ieee802_1x && !hapd->conf->wpa && !hapd->conf->osen) ||
        sta->auth_alg == WLAN_AUTH_FT) {
        /*
         * Open, static WEP, or FT protocol; no separate authorization
         * step.
         */
        ap_sta_set_authorized(hapd, sta, 1);
        wpa_printf(MSG_INFO, "WGTT: %s:%d Set to Authorized. \n", __FUNCTION__, __LINE__);
    }
    /* Stuff in sta we should send over the wire:
     * flags
     * ht_capab (requires support by STA and AP)
     * vht_capab
     * seq_ctrl
     */
    mlme_associate_indication(hapd, sta);


    /* Fill out the rest of sta from params */
    sta->qosinfo = params_deref->qosinfo;
    sta->vht_opmode = params_deref->vht_opmode;

    return sta;
}

int wgtt_get_params_deref(struct hostapd_sta_add_params *params,
        struct hostapd_sta_add_params_deref *params_deref,
        struct sta_info *sta,
        struct ieee80211_ht_capabilities *ht_capabilities_ptr,
        struct ieee80211_vht_capabilities *vht_capabilities_ptr,
        u8 *ext_capab_ptr,
        u8 *supp_channels_ptr,
        u8 *supp_oper_classes_ptr)
{
    size_t max_size = (sizeof(*ht_capabilities_ptr) > sizeof(*vht_capabilities_ptr)) ? sizeof(*ht_capabilities_ptr) : sizeof(*vht_capabilities_ptr);
    char zeroes[max_size];
    int ht_cap_exists = FALSE;

    wpa_printf(MSG_INFO, "WGTT: %s %s():%d", __FILE__, __FUNCTION__, __LINE__);

    os_memset(&zeroes, 0, max_size);

    if (os_memcmp(&(params_deref->ht_capabilities_deref),
            zeroes, sizeof(struct ieee80211_ht_capabilities)) != 0) {
        os_memcpy(ht_capabilities_ptr, &(params_deref->ht_capabilities_deref),
            sizeof(*ht_capabilities_ptr));
    } else {
        ht_capabilities_ptr = NULL;
    }
    if (os_memcmp(&(params_deref->vht_capabilities_deref),
            zeroes, sizeof(struct ieee80211_vht_capabilities)) != 0) {
        os_memcpy(vht_capabilities_ptr, &(params_deref->vht_capabilities_deref),
            sizeof(*vht_capabilities_ptr));
    } else {
        vht_capabilities_ptr = NULL;
    }
    if (params_deref->ext_capab_deref != 0) {
        *ext_capab_ptr = params_deref->ext_capab_deref;
    } else {
        ext_capab_ptr = NULL;
    }
    if (params_deref->supp_channels_deref != 0) {
        *supp_channels_ptr = params_deref->supp_channels_deref;
    } else {
        supp_channels_ptr = NULL;
    }
    if (params_deref->supp_oper_classes_deref != 0) {
        *supp_oper_classes_ptr = params_deref->supp_oper_classes_deref;
    } else {
        supp_oper_classes_ptr = NULL;
    }

    deref_to_params(params_deref, params,
            sta->addr, sta->supported_rates,
            ht_capabilities_ptr, vht_capabilities_ptr,
            ext_capab_ptr, supp_channels_ptr,
            supp_oper_classes_ptr);
}

int wgtt_recv(struct hostapd_data *hapd,
        struct ieee80211_mgmt *mgmt)
{
    struct sta_info *sta;
    int err;
    int new_assoc = 1;
    struct hostapd_sta_add_params params;
    struct hostapd_sta_add_params_deref params_deref;
    struct ieee80211_ht_capabilities ht_capabilities;
    struct ieee80211_vht_capabilities vht_capabilities;
    u8 ext_capab;
    u8 supp_channels;
    u8 supp_oper_classes;

    err = wgtt_poll(&params_deref, hapd->iface->interfaces->wgtt_listen_sockfd);
    if (err != 0) {
        return -1;
    }

    sta = wgtt_sta_info(hapd, mgmt, &params_deref);
    if (!sta) {
        return -1;
    }

    err = wgtt_get_params_deref(&params, &params_deref, sta, &ht_capabilities,
            &vht_capabilities, &ext_capab, &supp_channels, &supp_oper_classes);
    if (err != 0) {
        return -1;
    }

    if (sta->flags & WLAN_STA_ASSOC) {
        /* Not a reassociation */
        new_assoc = 0;
    }

    hostapd_drv_sta_remove(hapd, sta->addr);

    err = hapd->driver->sta_add(hapd->drv_priv, &params);
    if (err != 0) {
        wpa_printf(MSG_INFO, "WGTT: %s %s():%d Unsuccessfully added params to driver.", __FILE__, __FUNCTION__, __LINE__);
    }

    /* See handle_assoc_cb() */
    wpa_printf(MSG_INFO, "WGTT: %s %s():%d Flags in wgtt.c: %x.", __FILE__, __FUNCTION__, __LINE__, sta->flags);
    wpa_printf(MSG_INFO, "WGTT: %s %s():%d auth_alg in wgtt.c: %x.", __FILE__, __FUNCTION__, __LINE__, sta->auth_alg);

    hostapd_set_sta_flags(hapd, sta);

    if (sta->auth_alg == WLAN_AUTH_FT) {
        wpa_auth_sm_event(sta->wpa_sm, WPA_ASSOC_FT);
    } else {
        /* This is the one that is called */
        wpa_auth_sm_event(sta->wpa_sm, WPA_ASSOC);
    }
    hapd->new_assoc_sta_cb(hapd, sta, !new_assoc);

    ieee802_1x_notify_port_enabled(sta->eapol_sm, 1);

    wpa_printf(MSG_INFO, "WGTT: %s %s():%d Successfully added params to driver.", __FILE__, __FUNCTION__, __LINE__);
    return err;
}

int wgtt_sta_add(struct hostapd_data *hapd,
            struct hostapd_sta_add_params *params)
{
    struct hostapd_sta_add_params_deref params_deref;
    int ret = 0;

    wpa_printf(MSG_INFO, "WGTT: %s %s():%d", __FILE__, __FUNCTION__, __LINE__);

    params_to_deref(params, &params_deref);

    /*
    ret += wgtt_send(COMP_IP, PORT_SEND, (void *) &params_deref, sizeof(params_deref));
    ret += wgtt_send(WRT1200_L1_IP, PORT_SEND, (void *) &params_deref, sizeof(params_deref));
    ret += wgtt_send(WRT1200_L2_IP, PORT_SEND, (void *) &params_deref, sizeof(params_deref));
    ret += wgtt_send(WRT1200_L3_IP, PORT_SEND, (void *) &params_deref, sizeof(params_deref));
    ret += wgtt_send(LAN_IP_1, PORT_SEND, (void *) &params_deref, sizeof(params_deref));
    */
    /*ret += wgtt_send(LAN_IP_2, PORT_SEND, (void *) &params_deref, sizeof(params_deref));*/
    ret += wgtt_send(LAN_IP_4, PORT_SEND, (void *) &params_deref, sizeof(params_deref));
    ret += wgtt_send(LAN_IP_5, PORT_SEND, (void *) &params_deref, sizeof(params_deref));


    return ret;
}


