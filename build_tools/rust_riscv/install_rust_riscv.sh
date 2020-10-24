#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Oct. 24 2020
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>

# require sudo
if [[ $UID != 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# exit when any command fails
set -e

BUILDFOLDER="install_rust_riscv"
VERSIONFILE="installed_version.txt"
LIBRARY="../libraries/library.sh"
# required tools
TOOLS="curl"
# available rust targets
DEFAULT_TARGETS="riscv32i-unknown-none-elf riscv32imac-unknown-none-elf \
riscv32imc-unknown-none-elf riscv64gc-unknown-linux-gnu \
riscv64gc-unknown-none-elf riscv64imac-unknown-none-elf"

source $LIBRARY

# install and upgrade tools
apt-get update
apt-get install -y $TOOLS
apt-get install --only-upgrade -y $TOOLS

# install rust
mkdir -p $BUILDFOLDER
pushd $BUILDFOLDER > /dev/null
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > 'rustup_installer.sh'
chmod +x './rustup_installer.sh'

# Install rust in the context of every logged in user
for RUST_USER in `who | cut -d' ' -f1`; do
    # check if rustup is installed
    RUSTUP_SCRIPT="$(pwd -P)/rustup_installer.sh"
    
    if ! runuser -l $RUST_USER -c "command -v rustup" &> /dev/null; then
        runuser -l $RUST_USER -c "$RUSTUP_SCRIPT -y"     
        RUSTUP="\$HOME/.cargo/bin/rustup"
    else
        RUSTUP=`runuser -l $RUST_USER -c "command -v rustup"`
    fi
    
    # update rust
    runuser -l $RUST_USER -c "$RUSTUP install stable"
    runuser -l $RUST_USER -c "$RUSTUP install nightly"
    runuser -l $RUST_USER -c "$RUSTUP update"
    runuser -l $RUST_USER -c "$RUSTUP update nightly"

    # add riscv target
    # scan for available targets first, if it fails use DEFAULT_TARGETS
    PRRT=`runuser -l $RUST_USER -c "$RUSTUP target list | grep riscv"`
    DEFAULT_TC=`runuser -l $RUST_USER -c "rustup default"`
    DEFAULT_TC="${DEFAULT_TC// (default)}"

    if [ -n "$PRRT" ]; then
        DEFAULT_TARGETS=`echo $PRRT`
    fi
    
    runuser -l $RUST_USER -c "$RUSTUP target add --toolchain ${DEFAULT_TC} ${DEFAULT_TARGETS// (installed)}"
    runuser -l $RUST_USER -c "$RUSTUP target add --toolchain nightly ${DEFAULT_TARGETS// (installed)}"

    # add some useful dev components
    runuser -l $RUST_USER -c "$RUSTUP component add --toolchain ${DEFAULT_TC} rls rustfmt rust-analysis clippy"
    runuser -l $RUST_USER -c "$RUSTUP component add --toolchain nightly rls rustfmt rust-analysis clippy"
done

# cleanup
popd > /dev/null
rm -r $BUILDFOLDER

VER_DEFAULT=`runuser -l $RUST_USER -c "$RUSTUP run ${DEFAULT_TC} rustc --version"`
VER_DEFAULT="${VER_DEFAULT//(*)}"
VER_DEFAULT="${VER_DEFAULT#rustc }"

VER_NIGHTLY=`runuser -l $RUST_USER -c "$RUSTUP run nightly rustc --version"`
VER_NIGHTLY="${VER_NIGHTLY//(*)}"
VER_NIGHTLY="${VER_NIGHTLY#rustc }"
echo -e "rustc (${DEFAULT_TC}, with riscv targets): ${VER_DEFAULT}\nrustc (nightly, with riscv targets): ${VER_NIGHTLY}" >> "$VERSIONFILE"

