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

Of note, the industry is preparing for a migration to post-quantum cryptography
in the next 3-5 years, which will require new primary keys and new
cryptographic tokens/smart cards. In particular, the US government has mandated
that signature systems protecting high-value assets [plan for transition to
post-quantum cryptographic signatures by 2031](
https://www.whitehouse.gov/presidential-actions/2026/06/securing-the-nation-against-advanced-cryptographic-attacks/
) with software and firmware signing in particular [required to use
post-quantum algorithms for sensitive systems by 2030](
https://media.defense.gov/2025/May/30/2003728741/-1/-1/0/CSA_CNSA_2.0_ALGORITHMS.PDF
)
 and some companies like google are [planning to transition to post-quantum
cryptography by 2029](
https://blog.google/innovation-and-ai/technology/safety-security/cryptography-migration-timeline/
). While NIST standards have finalized recommendations for
[post-quantum asymmetric encryption (FIPS 204 (ML-KEM))](
https://csrc.nist.gov/pubs/fips/204/final) and
[post-quantum digital signatures (FIPS 204 (ML-DSA))](
https://csrc.nist.gov/pubs/fips/204/final), at the time of writing
standards are still evolving. While some standards such as [TLS](
https://datatracker.ietf.org/doc/draft-ietf-uta-pqc-app/) and
[OpenPGP](https://datatracker.ietf.org/doc/html/rfc9980) are actively
preparing support for both encryption and signature algorithms, others like
[OpenSSH](https://www.openssh.org/pq.html) and [LibrePGP](
https://datatracker.ietf.org/doc/draft-koch-librepgp/ ) are only defining
post-quantum encryption/key exchange algorithms for now (to protect against
harvest and decrypt later approaches), arguing that post-quantum signature
algorithms are less urgent while quantum computers are still in their infancy.
This makes the [OpenPGP/LibrePGP split](
https://www.gnupg.org/blog/20250117-aheinecke-on-sequoia.html ) particularly
painful. For example, companies needing to provide post-quantum signature
support for compliance purposes (e.g. [RedHat for supporting PQC signatures of
RPM packages](
https://developers.redhat.com/articles/2025/10/07/signing-rpm-packages-using-quantum-resistant-cryptography
) have been forced to migrate away from traditional tools like [GnuPG](
https://www.gnupg.org/) (LibrePGP-compliant) to tools like [Sequoia-PGP](
https://sequoia-pgp.org/) with incompatibility between the datastreams
of the new tools for some key types. Thus you should expect to need to generate
PQC keys in the next 5 years or so, but it may be better to wait to do so until
the ecosystem has stabilized and matured a bit more.

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
 4. Add additional UIDs to the key (i.e. email addresses) if needed.
    Replace `me@example.com` with the email address you entered in the
    previous step.
    ```
    gpg --expert --edit-key me@example.com
    ```
    Then for each additional email addresses you would like to associate with
    this key, enter the command `adduid` and answer the questions. You will
    likely want to designate a primary/preferred uid, which you can do by
    listing the uids with `list`, using the `uid` command to select the one
    you want to make primary (e.g. `uid 1`), and then running the `primary`
    command to select it as the primary uid. Finally type `save` to save and
    exit.
 5. Generate subkeys for authentication and signing and a primary encryption
    subkey. Replace `me@example.com` with the email address you entered in the
    previous step.
    ```
    gpg --expert --edit-key me@example.com
    ```
    First generate a signing key by running `addkey`, choose `ECC (sign only)`,
    `curve 25519` (the default), and pick an expiration date. While you could set
    this to never expire, it's probably safer to set this to something like two
    years (and extend it every year) in case you loose the key and revocation
    certificate. You can either share this subkey across all of your hardware
    tokens or repeat this process to generate additional signing keys until you
    have enough to dedicate one signing key to each token. The latter requires
    a bit more book keeping, but both limits the blast radius and simplifies
    forensics in the case of a loss or theft.\

    Next create an authentication key by running `addkey` again and choose
    `ECC (set your own capabilities)`, and toggle off sign and toggle on
    authenticate, and again choose `curve 25519`, and again choose an
    expiration date (e.g. 2 years). As above, you can repeat this command to
    generate enough subkeys to give each hardware token its own subkey.

    Now generate an master encryption key by running `addkey` again,
    choosing `ECC (encrypt only`, and `curve 25519` (the default) with the
    same expiration date as the prior subkeys (for convenience). This
    encryption subkey will be your offline software decryption key - we'll
    generate the encryption subkeys for the hardware tokens shortly.
    Finally type `save` to quit and save changes.

 6. Generate additional decryption subkeys.
    Encryption keys are a little tricker to maintain hardware-token-specific
    keys, as traditionally only the most recent encryption key would be used
    to encrypt a message (so only one hardware token would be able to decrypt
    it). Modern versions of GPG (GPG 2.2.42+ and 2.4.1+) have added a
    workaround called [Additional decryption subkeys (ADSKs)](
    https://www.gnupg.org/blog/20230321-adsk.html ) which can specify
    additional keys to encrypt for. Of note, this is a LibrePGP specification
    and is not (yet?) supported by OpenPGP tools like Sequoia-PGP, which will
    only encrypt to the primary encryption key by default. The offline
    encryption key provides some protection for this scenario, however, and
    allows you to later change strategies and use the existing offline key as
    a single-shared decryption key on all smartcards if seamless handling of
    OpenPGP encrypted data is found to be needed to minimize operational
    friction.

    The ADSK design assumption is that these are keys
    owned by other people, so we'll need to create them as subkeys of
    a different key. First run
    ```
    gpg --full-generate-key --expert
    ```
    and generate a key with a dummy email address (e.g. foo@example.com). The
    Certification/signing key properties don't matter for this (as we will
    throw them out shortly), so pick whatever you like.

    Now edit the key to add subkeys for each of your hardware tokens.
    ```
    gpg --expert --edit-key foo@example.com
    ```

    Next generate an encryption key by running `addkey` again,
    choosing `ECC (encrypt only`, and `curve 25519` (the default) with the
    same expiration date as the prior subkeys (for convenience). Repeat this
    once for each hardware key you'll be provisioning.

    Finally type `save` to quit and save changes.
 7. Add the additional decryption subkeys to the primary key.
    First list the existing keys with subkey fingerprints for the dummy key
    ```
    gpg -K --with-subkey-fingerprint foo@example.com
    ```
    Now, add the each of the encryption subkeys from the dummy account as
    additional decryption subkeys to the main key one by one, e.g.
    ```
    gpg --quick-add-adsk me@example.com 1234567890abcdef
    ```
    where `12134567890abcdef` is one of the fingerprints of one of the dummy
    key's encryption subkeys.
 8. Export the full key (in binary form and as ascii text), encrypted with the
    passphrase you chose on key creation.
    ```
    gpg --export-secret-keys me@example.com > gpg-master-secret-keys.gpg
    gpg --export-secret-keys --armor me@example.com > gpg-master-secret-keys.asc
    ```
 9. Export a temporary backup of the dummy key with the additional encrypted
    subkeys.
    ```
    gpg --export-secret-keys --armor foo@example.com > adsk-secret-keys.asc
    ```
10. Export the public key (as ascii text)
    ```
    gpg --export --armor me@example.com > gpg-public-key.asc
    ```
11. Generate a revocation certificate
    ```
    gpg --output revoke.asc --gen-revoke me@example.com
    ```
12. Prepare the hardware gpg cards/usb keys. Repeat the following steps
    for each of the hardware keys that will be used. Note that some of these
    steps (e.g. kdf-setup) must be run before the first secret key is added to
    the card.  Insert the usb key and run
    ```
    gpg --edit-card
    ```
    enter `admin` to enable admin commands, then `kdf-setup` to hash the pin
    before sending it (default admin pin is `12345678`), then (optional)
    `forcesig` (for key cards like certification cards to require a PIN for
    every signature instead of just the first one of a session),
    Next run `passwd` to set the admin and user pins.
    The initial default user pin is `123456` and initial default admin pin is
    `12345678`. You may want to set the PINs based on the type of key - a long
    PIN may make sense for an offline certification key that's only used a few
    times a year, while a short PIN may make sense for an online key that's
    used frequently for things like signing git commits.
    Once the PINs are set, you can `quit` from the card edit session.
13. Provision offline certification hardware keys. Setting up a few
    hardware keys to use to certify new subkeys allows you to do things like
    update subkey expiration dates without exposing your master certification
    keys to potential theft. Because the hardware keys can have counters on
    how many signatures they've created and require a touch per signature,
    this can allow you to update expiration dates without needing
    to use a live cd while still having reasonable confidence that the
    certification private key wasn't compromised during the signing procedure.
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
    selecting slot 1 when prompted. Type `save` to change the changes.
    You will probably want to require a physical touch to use the keys.

    You will probably want to require a physical touch to use the smart cards
    to make them difficult to use remotely by an attacker.
    This must be enabled after the keys have been exported to the smart card.
    Again use
    ```
    gpg --edit-card
    ```
    then `admin` to enable administrative commands, then `uif 1 permanent`
    to require a touch for signing, then `quit`.

    repeat all of these steps (including the clean gpg setup) for any
    remaining certification hardware keys you wish to provision.
14. Provision a cold decryption card. Over time, you may end up rotating
    smart cards (and their associated subkeys) out of circulation (e.g. due to
    damage) and later want to access an old backup that wasn't encrypted with
    any current smart-card's encryption key. Similarly, someone
    with a very old gpg client may encrypt something only to you primary
    decryption key. The offline software encryption-key stored with
    certification key provides the best assurance that you can still decrypt
    the data in these situations, but accessing should only be done from an
    offline computer and live OS, which is cumbersome. For convenience sake,
    it may be worth provisioning a smart card with the offline decryption key
    and keeping it with your backup of the offline encryption key. The card
    itself is much more convenient to use (since it's basically as safe to
    use in your regular network-connected computer as your day-to-day keys),
    but presumably is much less exposed to loss or damage than your normal
    keys (as it's generally kept in a safe place and rarely used).
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
    This time, first look over the list of subkeys to identify the (non-ADSK)
    encryption subkey and select it with the `key` command, e.g. `key 2` to
    select subkey two. Then run `keytocard` to transfer the subkey to the card,
    selecting the encryption slot when prompted. Then run `save` to save your
    changes and exit.

    You will probably want to require a physical touch to use the smart cards
    to make them difficult to use remotely by an attacker.
    This must be enabled after the keys have been exported to the smart card.
    Again use
    ```
    gpg --edit-card
    ```
    then `admin` to enable administrative commands, then `uif 2 permanent`
    to require a touch for decryption, then `quit`.

    repeat all of these steps (including the clean gpg setup) for any
    remaining cold decryption smartcards you wish to provision (or your
    daily use cards, if you want to use a single shared decryption key
    instead of a device-specific ADSK).
15. Provision hardware keys for daily use (without the certification key).
    All of the key-to-card steps will delete the software copy of the keys,
    so again it's easiest to just start with a clean gpg keyring.
    ```
    gpgconf --kill all # stop any existing gpg agent
    rm -rf ~/.gnupg
    gpg --import gpg-master-secret-keys.asc
    gpg --import adsk-secret-keys.asc
    ```
    Next insert the hardware key and run
    ```
    gpg --edit-key --expert me@example.com
    ```
    This time, first look over the list of subkeys to identify a signature
    subkey and select it with the `key` command, e.g. `key 3` to select subkey
    three. Then run `keytocard` to transfer the subkey to the card, selecting
    the signature slot when prompted. Then use the `key` command again with
    the same key number to deselect this subkey. Next use the `key` command
    to select an authentication subkey and `keytocard` to transfer it to the
    authentication slot on the card. Then run `save` to save your changes and
    exit.

    Next, export one of the encryption ADSKs to the hardware token using the
    same process. Start by editing the dummy key
    ```
    gpg --edit-key --expert foo@example.com
    ```
    As before, use the `key` command to select an encryption subkey, then
    `keytocard` to export it to the card, and then `save` when done.

    You will probably want to require a physical touch to use the smart cards
    to make them difficult to use remotely by an attacker.
    This must be enabled after the keys have been exported to the smart card.
    Again use
    ```
    gpg --edit-card
    ```
    then `admin` to enable administrative commands, then `uif 1 permanent`
    to require a touch for signing, `uif 2 permanent` to require a touch
    for decryption, and `uif 3 permanent` to require a touch for
    authentication, then `quit`.

    Now repeat this process with each of the remaining hardware tokens,
    choosing different subkeys each time. It may be easier not to reset the
    keyring between hardware keys, as the removal of the subkeys you've
    transferred to hardware keys may make it easier to keep track of which
    ones haven't been used yet.
16. Prepare the keys for archiving.
    We first move everything we want to save into a common directory.
    ```
    mkdir gpg-key-archive
    mv gpg-master-secret-keys.* gpg-public-key.asc revoke.asc gpg-key-archive
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
17. Create key backups on flash drives or sdcards (preferably SLC or pSLC flash
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
18. Create key backups on CDs/DVDs/BDs. Note that organic recording media
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
19. Print copies of a
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
    Then print it and the revocation certificate.
    Here I'm assuming a postscript compatible printer attached via usb.
    ```
    enscript --no-header --output=/dev/usb/lp0 paperkey.txt
    enscript --no-header --output=/dev/usb/lp0 revoke.txt
    ```
20. Copy the public key to the USB drive (the only media that should be
    considered safe to connect to a standard, internet-connected machine).
    ```
    sudo mount $(ls -1 /dev/sdX* | tail -1) /mnt
    sudo cp -v gpg-key-archive/gpg-public-key.asc /mnt
    sudo umount /mnt
    sync
    ```
21. Shutdown the machine, verify it's off and unplugged, and leave off for at
    least 20 seconds (to clear the RAM).
    ```
    sudo shutdown -h now
    ```

## Third boot (or a different machine) - publishing the keys

 1. First, import the new keys from the USB drive
    ```
    sudo mount $(ls -1 /dev/sdX* | tail -1) /mnt
    gpg --import /mnt/gpg-public-key.asc
    sudo umount /mnt
    ```
 2. List existing keys to find the fingerprint of the new key and any old keys
    that you wish to revoke.
    ```
    gpg --list-keys
    ```
 3. Revoke older keys that you are done with. If you still control the private
    key, this can be done by editing the key with
    ```
    gpg --edit-key <fingerprint of key to revoke>
    ```
    then typing `revkey` and following the instructions. You probably want to
    choose `superceeded` as the reason if you're migrating from this old key
    to the new one (which won't invalidate old signatures).
 4. For any keys of yours that you no longer control (e.g. have lost the
    passphrase of), you may still be able to revoke them if you have the
    revocation certificate. By default, GnuPG will create one and store it
    upon key generation, so if you don't have it saved elsewhere it might
    still be there:
    ```
    ls ~/.gnupg/openpgp-revocs.d/
    ```
    To apply the revocation certificate, just import it.
    ```
    gpg --import <revocation certificate filename>
    ```
 5. Upload the new and revoked keys to any keyservers you are using. It's
    probably worth uploading it to the current keyserver of choice,
    keys.openpgp.org:
    ```
    gpg --keyserver keys.openpgp.org --send-keys <new key fingerprint> \
        <revoked key fingerprints of any existing keys on this server>
    ```
    It may also be worth uploading it to the ubuntu keyserver (sometimes used
    by packaging tools).
    ```
    gpg --keyserver hkps://keyserver.ubuntu.com --send-keys \
        <new key fingerprint> \
        <revoked key fingerprints of any existing keys on this server>
    ```
 6. You will also want to add the new key to any forges you use (e.g. github,
    gitlab, etc) along with updating any newly-revoked keys. To export a key
    (either the new one or the old one you just revoked) as a file to upload
    to the forge you can use
    ```
    gpg --export --armor <key fingerprint> > <key fingerprint>.asc
    ```
