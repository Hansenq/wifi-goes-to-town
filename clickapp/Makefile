include $(TOPDIR)/rules.mk

PKG_NAME:=click
PKG_VERSION:=master
PKG_MINOR:=
PKG_RELEASE:=

PKG_SOURCE:=master.tar.gz
PKG_SOURCE_URL:=https://github.com/Hansenq/click/archive


include $(INCLUDE_DIR)/package.mk

define Package/click/Default
	URL:=https://github.com/Hansenq/click/archive/master.tar.gz
endef

define Package/click
	$(call Package/click/Default)
	SECTION:=net
	CATEGORY:=Base system
	TITLE:=Click modular router
	DEPENDS:=+libstdcpp
endef
define Package/click/description
	MIT's click modular router
endef

CONFIGURE_VARS += \
CXX="g++-uc+std" \
CXXFLAGS="$$$$CXXFLAGS -fno-rtti"

define Build/Configure
	( cd $(PKG_BUILD_DIR) ; \
	ARCH=mips; \
	./configure \
	--target=$(GNU_TARGET_NAME)\
	--host=$(GNU_TARGET_NAME) --build=$(GNU_HOST_NAME) --disable-linuxmodule \
	--enable-userlevel \
	--enable-wifi \
	--disable-bsdmodule \
	--disable-app \
	--enable-aqm \
	--enable-ethernet \
	--enable-etherswitch \
	--enable-icmp \
	--enable-ip \
	--enable-ip6 \
	--enable-local \
	--enable-simple \
	--enable-standard \
	--enable-tcpudp \
	--enable-test \
	--disable-threads \
	--enable-grid \
	--enable-tools=host \
	--enable-dmalloc \
	--prefix= ) ;


endef

define Package/click/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(STRIP) $(PKG_BUILD_DIR)/userlevel/click
	$(STRIP) $(PKG_BUILD_DIR)/tools/click-align/click-align
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/tools/click-align/click-align $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/userlevel/click $(1)/usr/bin/

endef

$(eval $(call BuildPackage,click))
