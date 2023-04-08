#!/bin/bash
#version=1.1.0

#Config settings
#SERVER="http://pi-update.docker.corp.jabil.org"
SERVER=$3

if [ -a "/boot/updater/server.txt" ];then
  SERVER="`cat /boot/updater/server.txt | egrep -v '^#'`"
fi

SIGNED_BY_CA="/usr/share/ca-certificates/jabil/Jabil_Enterprise_Root.crt"

#Platform specific config
DD_CMD="dd"
BASE64_DECODE_CMD="base64 -d"


#BEGIN
MANIFEST_CONTENT="`cat \"$1\"`"
REBUILD_TO_DEVICE="$2"


#Declare some functions that we'll use for parsing the manifest.
NL=$'\n'
#Extract a named section from the manifest, echo it out (which can then be captured)
#Parameters:
#1. While contents of the manifest file
#2. The name of the section to pull ie: "IMAGE DIGEST" to pull the section with the header "-----BEGIN IMAGE DIGEST-----"
extract_section(){
  FOUND_SECTION=0
  #TODO, returning inside of here causes broken pipe messages to be displayed - they don't hurt anything, but look bad...
  echo "$1" |while read line;
  do
    if [ "$FOUND_SECTION" = "0" -a "$line" = "-----BEGIN $2-----" ]; then
      #entry point of part manifest, start processing
      FOUND_SECTION=1

    elif [ "$FOUND_SECTION" = "1" -a "$line" = "-----END $2-----" ]; then
      #if we return here, it will give a nice named pipe error.  So don't do that.
      FOUND_SECTION=0

    elif [ "$FOUND_SECTION" = "1" ]; then
      echo "$line"
    fi
  done

}

#Check the signature before doing anything.
EXPECTED_IMAGE_DIGEST="`extract_section \"$MANIFEST_CONTENT\" \"IMAGE DIGEST\"`"
RSA_SIGNED_IMAGE_DIGEST="`extract_section \"$MANIFEST_CONTENT\" \"RSA SIGNED IMAGE DIGEST\"`"
SIGNING_CERTIFICATE="`extract_section \"$MANIFEST_CONTENT\" \"SIGNING CERTIFICATE\"`"
SIGNING_CERTIFICATE_CHAIN="`extract_section \"$MANIFEST_CONTENT\" \"SIGNING CERTIFICATE CHAIN\"`"

echo "$SIGNING_CERTIFICATE" >signed_by.pem
echo "$SIGNING_CERTIFICATE_CHAIN" >signed_by_chain.pem
#Check if signed_by.pem is signed by our approved CAs for code signing
VERIFY_MSG="`openssl verify -CAfile \"$SIGNED_BY_CA\" -untrusted signed_by_chain.pem signed_by.pem`"
VERIFY_RESULT=$?

if [ "$VERIFY_RESULT" -ne "0" ]; then
  rm signed_by.pem signed_by_chain.pem
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Singing Certificate check failed: $VERIFY_MSG"
  exit 10
fi

#If we got here, it's trusted by our pre-defined CA.
#Is the certificate have code signing listed as a purpose?
CODE_SIGNING_CHECK="`openssl x509 -in signed_by.pem -text |grep -A 1 'X509v3 Extended Key Usage:'|grep 'Code Signing'`"
if [ -z "$CODE_SIGNING_CHECK" ]; then
  rm signed_by.pem signed_by_chain.pem
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] The Certificate that signed this manifest is not approved for code signing."
  exit 10
fi



#Now verify the signature of the digest
SIGNED_DIGEST="`echo -n \"$RSA_SIGNED_IMAGE_DIGEST\" |$BASE64_DECODE_CMD  |openssl rsautl -verify -certin -inkey signed_by.pem -keyform PEM |base64`"
SIGNED_DIGEST_RESULT=$?

rm signed_by.pem signed_by_chain.pem #we finally don't need these anymore...

if [ "$SIGNED_DIGEST_RESULT" -eq "0" -a "$EXPECTED_IMAGE_DIGEST" == "$SIGNED_DIGEST" ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Manifest Signature is valid.  Beginning Rebuild."
else
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Signature does not match digest."
  exit 10
fi


#Now start the extraction


CURRENT_PART_NUMBER=0

#TODO, this should be part of the manifest
PART_SIZE=$((1024 * 1024))
extract_section "$MANIFEST_CONTENT" "PART MANIFEST" | while read line;
do
  SUM="$line"
  FILEPATH="parts/`echo $SUM|cut -c 1`/`echo $SUM|cut -c 2`/`echo $SUM|cut -c 3`/`echo $SUM|cut -c 4`/$SUM"

  #Check if the block is already this sum, and therefore nothing needs to be done
  CURRENT_SUM="`$DD_CMD status=none \"if=$REBUILD_TO_DEVICE\" \"bs=$PART_SIZE\" count=1 skip=$CURRENT_PART_NUMBER  |shasum -a 256 |cut -d\  -f 1`"
  #echo "Current Sum is $CURRENT_SUM  Expected $SUM"
  if [ "$CURRENT_SUM" != "$SUM" ]; then
    #if the sum is the special case 30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58 - create a part sized block of zero (this is a speed tweak, that SHA256 sum is the sum for an arbitrary block of null ;)
    if [ "$SUM" == "30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58" ]; then
      $DD_CMD if=/dev/zero of=curPart "bs=$PART_SIZE" count=1 status=none
    else
      curl -sL "${SERVER}/${FILEPATH}" |gzip -d >curPart
    fi

    PARTSUM="`shasum -a 256 curPart |cut -d\  -f 1`"
    if [ "$SUM" != "$PARTSUM" ]; then
    echo ""
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR Part sum Mismatch on part Expected: [${SUM}] was: [${PARTSUM}], aborting!"
    exit 1;
    fi

    $DD_CMD if=curPart "of=$REBUILD_TO_DEVICE" "bs=$PART_SIZE" count=1 seek=$CURRENT_PART_NUMBER status=none
    echo -n "D"
    rm curPart
  else
    echo -n "R"
  fi

  CURRENT_PART_NUMBER=$((CURRENT_PART_NUMBER + 1))
done

echo ""
echo -n "[$(date -u +"%Y-%m-%d %H:%M:%S")] Download Complete, checking consistency: "

FINAL_DIGEST="`shasum -a 256 "$REBUILD_TO_DEVICE" |cut -d\  -f 1`"

if [ "$FINAL_DIGEST" != "$EXPECTED_IMAGE_DIGEST" ]; then
  echo "ERROR, Digest of $REBUILD_TO_DEVICE [$FINAL_DIGEST] does not match expected digest from the manifest [$EXPECTED_IMAGE_DIGEST]"
  exit 1
else
  echo "Done"
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] $REBUILD_TO_DEVICE successfully updated"
  exit 0
fi
