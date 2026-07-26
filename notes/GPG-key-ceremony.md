# Notes on creating a new GPG key

I need to create a new GPG key, so I wanted to document the process I took,
trying to follow best practices. Of note, these instructions include steps to
provision hardware keys (e.g. [yubikeys](https://www.yubico.com/),
[Nitrokeys](https://www.nitrokey.com/), [Solokeys](https://solokeys.com/),
or the equivalent), create durable backups on removable media (e.g. SLC or
pSLC SD cards and/or CDROM/M-Disks), and create paperkey backups for recovery
if even those methods fail. I'm a little dubious about how much security
some of these practices actually add, but given that this is something I
should only have to do every few years at most (and hopefully not before the
transition to post-quantum cryptographic algorithms in a few years), it seems
better to just do a little extra work to follow recommendations.

The following should provide good protection for most people who are not
actively being targeted by skilled hackers at the time of key generation, at
least in the absence of a large supply-chain attack on something like debian
or commodity hardware. If you think you are at risk of active surveillance by
state actors or something similar (e.g. if you are a journalist, politician,
or government worker with access to sensitive information) you'll need to be
more careful as the following steps do not protect against things like
firmware implants and root kits that might modify the USB drive, and you should
consult a computer security expert for further recommendations. As an example,
you could protect against compromise of the debian live USB drive by burning
multiple copies and then rolling a die to decide which one to use while
checking the hashes of all of the others on different machines that are
unlikely to be compromised together (e.g. a local library computer, a friend's
computer, etc), making it difficult for an attacker to silently modify the
correct debian live image without being caught by one of the computers they
do not control. Similarly, you could randomly buy a laptop at a thrift market,
remove any existing storage, and never connect it to the internet after
purchase to make it more difficult for a remote attacker to compromise it (only
connecting media with known trusted contents that had been vetted with the
die-rolling process above).

For most of us, however, our GPG key is unlikely to be the weakest point in our
digital security, and the following should be more than enough to ensure that
a successful attacker will likely break in via a different vector of attack.

## Create a Debian Live image

To minimize the risk that the new private key is leaked (e.g. via a swap file,
log file, or something similar), it's considered best practice to boot from a
live image without network connectivity. We use the debian live CD, but
something like [tails](https://tails.net) would also be a good option.

This assumes you are starting from a debian machine that you mostly trust;
obviously greater confidence could be achieved by trying this on multiple
machines and verifying the same USB contents were produced.

 1. [Download a debian live image](
    https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/) along
    along with the associated SHA256SUMS and SHA256SUMS.sign
    ```
    wget https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/SHA256SUMS
    wget https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/SHA256SUMS.sign
    wget https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/debian-live-13.6.0-amd64-standard.iso
    ```
 2. Check the gpg signature for the SHA256SUMS
    ```
    sudo apt install debian-keyring
    gpg -no-default-keyring \
        --keyring /usr/share/keyrings/debian-role-keys.gpg \
        --trust-model always \
        --verify SHA256SUMS.sign SHA256SUMS
    ```
    You should expect output similar to the following:
    ```
    gpg: Signature made Sat 11 Jul 2026 04:25:40 PM EDT
    gpg:                using RSA key DF9B9C49EAA9298432589D76DA87E80D6294BE9B
    gpg: Good signature from "Debian CD signing key <debian-cd@lists.debian.org>" [unknown]
    gpg: WARNING: Using untrusted key!
    ```
    In particular, check to make sure the email address is correct. This
    protects against a compromise of the debian cdimage site.
 3. Check to make sure the hash on the downloaded file matches the hash in the SHA256SUMS:
    ```
    rm -f expected.sha256
    for f in *.iso; do grep " $f$" SHA256SUMS >> expected.sha256; done
    sha256sum --check expected.sha256
    ```
    You should expect output like the following:
    ```
    debian-live-13.6.0-amd64-standard.iso: OK
    ```
    This protects against a compromise of the downloaded file.
 4. Insert a usb drive and burn the image to the USB drive. First, make sure
    you know the correct name (e.g. `/dev/sda`) for the USB drive (getting
    this wrong can destroy your data!):
    ```
    lsblk
    ```
    Then copy the iso image to that drive (replacing `/dev/sdX` with the USB
    drive's path)
    ```
    sudo dd if=debian-live-13.6.0-amd64-standard.iso of=/dev/sdX bs=4M \
        status=progress
    sync
    ```

## First boot: augment the debian live image with additional packages

We next boot from of the debian live image (on trusted hardware) with an
internet connection and download a few additional packages that we need for the
key-creation ceremony. This should be fairly secure as we're just using apt
which does signature verification, but this still introduces a risk of
a remote compromise despite the trusted root media (e.g.
[CVE-2019-3462](https://nvd.nist.gov/vuln/detail/CVE-2019-3462) ). Note that
you should be careful to avoid doing things with the live image that could
introduce additional vulnerabilities, however (e.g. opening a web browser).

This package install step could be avoided by building a reproducible live
image with the necessary packages from the beginning, but the build process
would have to be tested for reproducibility on many independent machines before
the reproducible build path would be more trustworthy than the signed
debian-live image + package install path.

 1. (optional) For usability purposes on a high DPI monitor, you may need to
    change the console font size:
    ```
    sudo dpkg-reconfigure console-setup
    ```
 2. Add a 8 GB working partition to the USB drive for storing packages
    and public keys and mount it on /mnt (again replacing sdX with the usb
    drive):
    ```
    echo "size=8GiB" | sudo sfdisk --append --force /dev/sdX
    sudo partx partx -a /dev/sdX
    sudo mkfs.ext4 $(ls -1 /dev/sdX* | tail -1)
    sudo mount $(ls -1 /dev/sdX* | tail -1) /mnt
    ```
 3. Download a number of packages that we may need to generate the key,
    install it on the usb HSMs, and copy it to multiple archival formats
    (including paper).
    ```
    sudo apt update
    sudo apt install --download-only \
        scdaemon pcscd libccid pcsc-tools usbutils pinentry-curses \
        paperkey enscript xorriso par2
    sudo cp -v /var/cache/apt/archives/*.deb /media/usb-state
    ```
 4. Shutdown the machine, verify it's off and unplugged, and leave off for at
    least 20 seconds (to clear the RAM).
    ```
    sudo umount /mnt
    sync
    sudo shutdown -h now
    ```

## Second boot: generating the keys

For the second boot, we will again boot off the USB live disk, but this time
physically disconnected from the network.

If you are being paranoid you could again create multiple copies of the USB
drive, roll a die to choose which one to keep air-gapped, and then use several
other mostly-trusted computers to verify that everything except the partition
table and the new partition match the previously-verified debian-live image,
and that all of the packages on the new partition are signed with the
appropriate debian archive key. You could also use a second trusted computer
for the air-gap computer (reducing the risk of a firmware implant being
remotely installed during the previous step). For most of us, however, both of
these would be a little silly to do.

 1. (optional) For usability purposes on a high DPI monitor, you may need to
    again change the console font size:
    ```
    sudo dpkg-reconfigure console-setup
    ```
 2. Mount the writable partition on the USB drive to /mnt (again replacing
    /dev/sdX with the path to the usb drive) and install the previously
    downloaded packages.
    ```
    sudo mount $(ls -1 /dev/sdX* | tail -1) /mnt
    sudo dpkg -i /mnt/*.deb
    sudo umount /mnt
    ```
 3. Generate the gpg keys in software. We start by generating the main key
    and encryption subkey.
    ```
    gpg --full-generate-key --expert
    ```
    Choose "ECC (set your own capabilities)", then toggle off the off the
    sign capability so it can only certify subkeys. Choose
    curve 25519 (the new default), and key does not expire (default).
    Enter your username and email address, but it's recommended to leave
    the comment option blank (as this can break some older email programs).
    Choose a long, secure and memorable (or paper-backed-up) passphrase.
    This provides protection if someone steals the offline software copies of
    the key, and you'll only need to type it in the rare occasions that you're
    using the software key. This may include trying to access your key backup
    years later, however, so plan accordingly.
 4. Generate subkeys for encryption, authentication, and signing. Replace
    `me@example.com` with the email address you entered in the previous step.
    ```
    gpg --expert --edit-key me@example.com
    ```
    First generate a signing key by running `addkey`, choose `ECC (sign only)`,
    `curve 25519` (the default), and pick an expiration date. While you could set
    this to never expire, it's probably safer to set this to something like two
    years (and extend it every year) in case you loose the key and revocation
    certificate. Next generate an encryption key by running `addkey` again,
    choosing `ECC (encrypt only`, and `curve 25519` (the default) with the
    same expiration date as the prior subkey (for convenience). Finally,
    create an authentication key by running `addkey` again and choose
    `ECC (set your own capabilities)`, and toggle off sign and toggle on
    authenticate, and again choose `curve 25519`. Finally choose `quit` and
    save changes.
 5. Export the full key (in binary form and as ascii text), encrypted with the
    passphrase you chose on key creation.
    ```
    gpg --export-secret-keys me@example.com > gpg-master-secret-keys.gpg
    gpg --export-secret-keys --armor me@example.com > gpg-master-secret-keys.asc
    ```
 7. Export the public key (as ascii text)
    ```
    gpg --export --armor me@example.com > gpg-public-key.asc
    ```
 8. Prepare the hardware gpg cards/usb keys. Repeat the following steps
    for each of the hardware keys that will be used. Note that some of these
    steps (e.g. kdf-setup) must be run before the first secret key is added to
    the card.  Insert the usb key and run
    ```
    gpg --edit-card
    ```
    enter `admin` to enable admin commands, then `kdf-setup` to hash the pin
    before sending it (default admin pin is `12345678`), then (optional)
    `forcesig` (for key cards like certification cards to require a PIN for
    every signature instead of just the first one of a session), and then
    `uif 1 permanent`, `uif 2 permenant`, and `uif 3 permanent` (to require a
    touch with every sign, decrypt, and authorization until the card undergoes
    a full factory-reset). Next run `passwd` to set the admin and user pins.
    The initial default user pin is `123456` and initial default admin pin is
    `12345678`. You may want to set the PINs based on the type of key - a long
    PIN may make sense for an offline certification key that's only used a few
    times a year, while a short PIN may make sense for an online key that's
    used frequently for things like signing git commits.
    Once the PINs are set, you can `quit` from the card edit session.
 9. Provision offline certification hardware keys. Setting up a few
    hardware keys to use to certify new subkeys allows you to do things like
    update subkey expiration dates without exposing your master certification
    keys to potential theft. Because the hardware keys can have counters on
    how many signatures they've created and require a touch per signature,
    this can allow you to update expiration dates without needing
    to use a live cd on an offline computer while still having confidence
    that the certification private key wasn't compromised during the signing
    procedure.
    All of the key-to-card steps will delete the software copy of the keys,
    so it's easiest to just start with a clean gpg keyring each time.
    ```
    gpgconf --kill all # stop any existing gpg agent
    rm -rf ~/.gnupg
    gpg --import gpg-master-secret-keys.asc
    ```
    Next insert the hardware key and run
    ```
    gpg --edit-key --expert me@example.com
    ```
    Then run `keytocard` to transfer the certification key to the card,
    selecting slot 1 when prompted. Finally type `save`, then
    repeat all of these steps (including the clean gpg setup) for any
    remaining certification hardware keys you wish to provision.
10. Provision hardware keys for daily use (without the certification key).
    All of the key-to-card steps will delete the software copy of the keys,
    so it's easiest to just start with a clean gpg keyring each time.
    ```
    gpgconf --kill all # stop any existing gpg agent
    rm -rf ~/.gnupg
    gpg --import gpg-master-secret-keys.asc
    ```
    Next insert the hardware key and run
    ```
    gpg --edit-key --expert me@example.com
    ```
    This time, first run `key 1` to select the signature subkey, then run
    `keytocard` to transfer the certification key to the card, selecting the
    signature slot when prompted. Then run `key 1` to deselect this subkey.
    Then repeat this sequence with key 2 (encryption) and key 3
    (authentication), choosing the matching key slots. Finally run `save`.
    then repeat all of these steps (including the clean gpg setup) for any
    remaining hardware keys you wish to provision.
11. Prepare the keys for archiving.
    We first move everything we want to save into a common directory.
    ```
    mkdir gpg-key-archive
    mv gpg-master-secret-keys.* gpg-public-key.asc gpg-key-archive
    ```
    While the multiple copies of the keys provides some protection against
    bit rot, we can further increase the likelihood of recovery by
    generating par2 parity files for all of the keys to store along with the
    keys.
    ```
    cd gpg-key-archive
    par2create -r30 recovery.par2 *.asc *.gpg
    cd ..
    ```
    Finally we create multiple copies (again, for bitrot protection)
    ```
    mkdir duplicated-gpg-key-archive
    for i in {01..20}; do \
        cp -rv gpg-key-archive duplicated-gpg-key-archive/copy$i; \
    done
    ```
12. Create key backups on flash drives or sdcards (preferably SLC or pSLC flash
    devices that have a long offline data retention rating, such as those
    available from Swissbit). Insert the drive and make sure you have the
    correct disk identified:
    ```
    lsblk
    ```
    Then format the drive
    ```
    echo "label: gpt" | sudo sfdisk /dev/mmcblkX
    echo ",," | sudo sfdisk --append /dev/mmcblkX
    sudo mkfs.ext4 /dev/mmcblkXp1
    ```
    Finally copy the data over
    ```
    sudo mount /dev/mmcblkXp1 /mnt
    sudo cp -rv duplicated-gpg-key-archive /mnt/
    sudo umount /mnt
    sync
    ```
    Repeat this for each flash drive/sd card backup you wish to create.
13. Create key backups on CDs/DVDs/BDs. Note that organic recording media
    has poor aging properties, so you may want to choose inorganic media
    like HTL or an M-disc that is better rated for archival purposes. First,
    create an iso image:
    ```
    xorriso -as mkisofs -r -o gpg-key-archive.iso duplicated-gpg-key-archive/
    ```
    Then connect a disk burner and burn (and label) as many copies as you like
    ```
    xorriso -as cdrecord -v dev=/dev/sr0 gpg-key-archive.iso
    ```
14. Print copies of a
    [paperkey](https://www.jabberwocky.com/software/paperkey/) that only
    contains the secret portions (still encrypted) that you can recombine with
    the public key to recreate the full key. The idea is that you can print
    this and manually type it back in if all other copies of the secret key
    are lost (e.g. to media failure).
    First create the paperkey
    ```
    paperkey --secret-key gpg-master-secret-keys.gpg \
        --output paperkey.txt
    ```
    Then print it.
    Here I'm assuming a postscript compatible printer attached via usb.
    ```
    enscript --no-header --output=/dev/usb/lp0 paperkey.txt
    ```
15. Copy the public key to the USB drive (the only media that should be
    considered safe to connect to a standard, internet-connected machine).
    ```
    sudo mount $(ls -1 /dev/sdX* | tail -1) /mnt
    sudo cp -v gpg-key-archive/gpg-public-key.asc /mnt
    sudo umount /mnt
    sync
    ```
16. Shutdown the machine, verify it's off and unplugged, and leave off for at
    least 20 seconds (to clear the RAM).
    ```
    sudo shutdown -h now
    ```
