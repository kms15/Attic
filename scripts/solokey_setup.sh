#!/bin/bash

if [ $# -ne 1 ] ; then
    echo "Usage:"
    echo "  $0 SSH_KEY_PREFIX"
    exit 1
fi
SSH_KEY_PREFIX=$1

#if ! [ -e venv-solo1 ] ; then
#    python3 -m venv venv-solo1
#    venv-solo1/bin/pip3 install solo1
#fi
if ! [ -e solo1-cli ] ; then
    # TODO: should switch back to upstream
    # (https://github.com/solo-keys/solo1-cli.git) once upstream is fixed
    git clone https://github.com/kms15/solo1-cli.git
    make -C ./solo1-cli init
fi

# update the firmware if the major version is less than 4
if [ $(./solo1-cli/venv/bin/solo1 key version | cut -f 1 -d . ) -lt 4 ] ; then
    # often need to run twice; I'm not sure why.
    ./solo1-cli/venv/bin/solo1 key update \
        || ./solo1-cli/venv/bin/solo1 key update
fi

# generate a key with touch as password
echo "################################################################"
echo "# Generating high-security key '${SSH_KEY_PREFIX}'"
echo "# that requires touch and password."
echo "################################################################"
ssh-keygen -t ed25519-sk -f ${SSH_KEY_PREFIX} \
    -C "$USER@$(hostname) ${SSH_KEY_PREFIX}"

echo "################################################################"
echo "# Generating mid-security key '${SSH_KEY_PREFIX}_notouch'"
echo "# that only requires password (and key to be plugged in)."
echo "################################################################"
ssh-keygen -t ed25519-sk -f ${SSH_KEY_PREFIX}_notouch \
    -O no-touch-required \
    -C "$USER@$(hostname) ${SSH_KEY_PREFIX}_notouch"

echo "################################################################"
echo "# Generating script key '${SSH_KEY_PREFIX}_notouch_nopassword'"
echo "# that only requires the key to be plugged in."
echo "################################################################"
ssh-keygen -t ed25519-sk -f ${SSH_KEY_PREFIX}_notouch_nopassword \
    -N "" -O no-touch-required \
    -C "$USER@$(hostname) ${SSH_KEY_PREFIX}_notouch_nopassword"
