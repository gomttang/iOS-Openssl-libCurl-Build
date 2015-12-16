#!/bin/bash

# This script downlaods and builds the Mac, iOS and tvOS libcurl libraries with Bitcode enabled

# Credits:
#
# Felix Schwarz, IOSPIRIT GmbH, @@felix_schwarz.
#   https://gist.github.com/c61c0f7d9ab60f53ebb0.git
# Bochun Bai
#   https://github.com/sinofool/build-libcurl-ios
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL 

set -e

usage ()
{
	echo "usage: $0 [iOS SDK version (defaults to latest)] [tvOS SDK version (defaults to latest)]"
	exit 127
}

if [ $1 -e "-h" ]; then
	usage
fi

if [ -z $1 ]; then
	IOS_SDK_VERSION="9.1" #"9.1"
	IOS_MIN_SDK_VERSION="5.1.1"
	
	TVOS_SDK_VERSION="9.0" #"9.0"
	TVOS_MIN_SDK_VERSION="9.0"
else
	IOS_SDK_VERSION=$1
	TVOS_SDK_VERSION=$2
fi

CURL_VERSION="curl-7.45.0"
OPENSSL="${PWD}/../openssl"  
OPENSSL_PATH="${OPENSSL}/iOS/lib"
DEVELOPER=`xcode-select -print-path`
CERT_PATH="${PWD}/ca.crt"

IPHONEOS_DEPLOYMENT_TARGET="5.1.1"


buildIOS()
{
	ARCH=$1

	pushd . > /dev/null
	cd "${CURL_VERSION}"
  
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
	fi
  
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_SDKROOT="${CROSS_TOP}/SDKs/${PLATFORM}${IOS_SDK_VERSION}.sdk"

	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -arch ${ARCH}"
	export CFLAGS="-arch ${ARCH} -pipe -no-cpp-precomp -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} -fembed-bitcode"
	export LDFLAGS="-Os -arch ${ARCH} -Wl,-dead_strip -miphoneos-version-min=7.0 -L${BUILD_SDKROOT}/usr/lib -L${OPENSSL}/iOS/lib"
   	export CPPFLAGS="${CFLAGS} -I${BUILD_SDKROOT}/usr/include"
	export CXXFLAGS="${CPPFLAGS}"	
	echo "Building ${CURL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"



#	if [[ "${ARCH}" == "arm64" ]]; then
#		./configure -prefix="/tmp/${CURL_VERSION}-iOS-${ARCH}" -disable-shared --enable-static -with-random=/dev/urandom --with-ssl=${OPENSSL}/iOS --host="arm-apple-darwin" &> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log"
#	else
#		./configure -prefix="/tmp/${CURL_VERSION}-iOS-${ARCH}" -disable-shared --enable-static -with-random=/dev/urandom --with-ssl=${OPENSSL}/iOS --host="${ARCH}-apple-darwin" &> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log"
#	fi


	if [ "${ARCH}" == "arm64" ]; then
		./configure --host=aarch64-apple-darwin -prefix="/tmp/${CURL_VERSION}-iOS-${ARCH}" --enable-static --enable-shared --with-ssl=${OPENSSL}/iOS --with-zlib --disable-manual --disable-ftp --disable-file --disable-ldap --disable-ldaps --disable-rtsp --enable-proxy --disable-dict --disable-telnet --disable-tftp --disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-sspi --enable-ipv6 --disable-smb
	else
		./configure --host=${ARCH}-apple-darwin -prefix="/tmp/${CURL_VERSION}-iOS-${ARCH}" --enable-static --enable-shared --with-ssl=${OPENSSL}/iOS --with-zlib --disable-manual --disable-ftp --disable-file --disable-ldap --disable-ldaps --disable-rtsp --enable-proxy --disable-dict --disable-telnet --disable-tftp --disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-sspi --enable-ipv6 --disable-smb
	fi

	make -j8 >> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log" 2>&1
	make install >> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log" 2>&1
	make clean >> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log" 2>&1
	popd > /dev/null
}


echo "Cleaning up"
rm -rf include/curl/* lib/*
mkdir -p lib
mkdir -p include/curl/
rm -rf "/tmp/${CURL_VERSION}-*"
rm -rf "/tmp/${CURL_VERSION}-*.log"
rm -rf "${CURL_VERSION}"
if [ ! -e ${CURL_VERSION}.tar.gz ]; then
	echo "Downloading ${CURL_VERSION}.tar.gz"
	curl -O http://curl.haxx.se/download/${CURL_VERSION}.tar.gz
else
	echo "Using ${CURL_VERSION}.tar.gz"
fi
echo "Unpacking curl"
tar xfz "${CURL_VERSION}.tar.gz"

# iOS Build for each architecture
buildIOS "armv7"
buildIOS "armv7s"
buildIOS "arm64"
buildIOS "x86_64"
buildIOS "i386"

echo "Building iOS libraries"
lipo \
	"/tmp/${CURL_VERSION}-iOS-armv7/lib/libcurl.a" \
	"/tmp/${CURL_VERSION}-iOS-armv7s/lib/libcurl.a" \
	"/tmp/${CURL_VERSION}-iOS-i386/lib/libcurl.a" \
	"/tmp/${CURL_VERSION}-iOS-arm64/lib/libcurl.a" \
	"/tmp/${CURL_VERSION}-iOS-x86_64/lib/libcurl.a" \
	-create -output lib/libcurl_iOS.a


echo "Cleaning up"
rm -rf /tmp/${CURL_VERSION}-*
rm -rf ${CURL_VERSION}

echo "Checking libraries"
xcrun -sdk iphoneos lipo -info lib/*.a

echo "Done"
