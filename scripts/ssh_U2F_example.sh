#!/bin/bash
set -e
set -x

# Run demo in a scratch directory for ease of cleanup
STARTING_DIR=$(pwd)
if [ -z $DEMO_DIR ]; then
    DEMO_DIR=$(mktemp -d)
    function cleanup {
        cd $STARTING_DIR
        rm -rf $DEMO_DIR
    }
    trap cleanup EXIT
fi
cd $DEMO_DIR


cat << EOF

------------------------------------------------------------------------------
Generate a new ssh key secured by a U2F token
------------------------------------------------------------------------------
You will probably need to touch the U2F token to generate the key NB: This
example specifies an empty password (via -N) and does not require touching the
token each time you use the key (via -O no-require-touch), but you will usually
want a password and require a touch for use for keys that need a higher level
of security.

EOF
KEY_FILE=$(pwd)/my-ssh-key
ssh-keygen -t ed25519-sk -f $KEY_FILE -N "" -O no-touch-required
cat $KEY_FILE.pub


cat << EOF

------------------------------------------------------------------------------
Example of an authorized_keys entry for a touchless key
------------------------------------------------------------------------------
By default, SSH doesn't allow connecting with keys set to no-touch-required.
You can explicitly enable a no-touch-required key by adding this option to the
key in the ~/.ssh/authorized_keys file, as shown below.

EOF
SSH_AUTHORIZED_KEYS_FILE=authorized_keys.touchless_example
printf "no-touch-required " >> $SSH_AUTHORIZED_KEYS_FILE
cat $KEY_FILE.pub >> $SSH_AUTHORIZED_KEYS_FILE
cat $SSH_AUTHORIZED_KEYS_FILE


cat << EOF

------------------------------------------------------------------------------
Example of an allowed signers file for ssh signatures
------------------------------------------------------------------------------
Verifying a signature (e.g. of a file or git commit) requires a list of
public keys whose signatures we trust. For ssh this takes the form of an
allowed signers file that we can then reference from the ssh command line
tools or git.  Here's an example file with a single key (the one we just
created):

EOF
ALLOWED_SIGNERS_FILE=$(pwd)/allowed-signers
SIGNING_KEY_NAME=my-signing-key
PUBLIC_KEY=$(cat $KEY_FILE.pub | cut -f1,2 -d ' ')
cat << EOF | tee $ALLOWED_SIGNERS_FILE
$SIGNING_KEY_NAME namespaces="file,git" $PUBLIC_KEY
EOF


cat << EOF

------------------------------------------------------------------------------
Example of signing a file and verifying a signature
------------------------------------------------------------------------------
Signing a file generates a <filename>.sig signature file. The file and its
signature can then be verified against either a specific public key in an
allowed signers file, or more generally to any key in the given file. Note
the key will need to have the "file" namespace in the allowed signers file
to be valid for signing files.

EOF
FILE_NEEDING_SIGNATURE=sign-me
echo "important stuff" > $FILE_NEEDING_SIGNATURE
ssh-keygen -Y sign -f $KEY_FILE -n "file" $FILE_NEEDING_SIGNATURE
printf "# Verify with a specific key:\n"
ssh-keygen -Y verify -f $ALLOWED_SIGNERS_FILE -I $SIGNING_KEY_NAME \
    -n "file" -s $FILE_NEEDING_SIGNATURE.sig < $FILE_NEEDING_SIGNATURE
printf "# Verify with any key in the file:\n"
ssh-keygen -Y verify -f $ALLOWED_SIGNERS_FILE \
    -I $(ssh-keygen -Y find-principals -s $FILE_NEEDING_SIGNATURE.sig \
        -f $ALLOWED_SIGNERS_FILE) \
    -n "file" -s $FILE_NEEDING_SIGNATURE.sig < $FILE_NEEDING_SIGNATURE


cat << EOF

------------------------------------------------------------------------------
Example of an ~/.gitconfig file for ssh signing
------------------------------------------------------------------------------
Git signing requires turning on signatures and configuring the location of
the private key file and allowed signers file. Normally you'd do this in your
global .gitconfig in your home directory, but for this demo we avoid changing
the user's global config file by creating a local example gitconfig file and
setting \$GIT_CONFIG_GLOBAL to point to it.

EOF
GIT_CONFIG_FILE=$(pwd)/gitconfig
cat << EOF > $GIT_CONFIG_FILE
[user]
  email = primate@example.com
  name = primate
  signingkey = $KEY_FILE
[init]
  defaultBranch = main
[commit]
  gpgsign = true
[gpg]
  format = ssh
[gpg "ssh"]
  allowedSignersFile = $ALLOWED_SIGNERS_FILE
EOF
cat $GIT_CONFIG_FILE
export GIT_CONFIG_GLOBAL=$GIT_CONFIG_FILE


cat << EOF

------------------------------------------------------------------------------
Example of creating and verifying git commits with ssh signatures
------------------------------------------------------------------------------
Once all of this has been set up, signing git commits happens pretty-much
automatically.  Verifying commits requires passing a --show-signature option
to commands such as git log.

EOF
printf "#  signatures\n"
# For this demo we're using a local gitconfig file rather than ~/.gitconfig
git init
git commit --allow-empty --message "first commit"
git commit --allow-empty --message "second commit"
git log --show-signature

cat << EOF

------------------------------------------------------------------------------
Demo completed successfully!
------------------------------------------------------------------------------

EOF
