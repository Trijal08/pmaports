maintainer="Trijal Saha <trijalsaha2012@gmail.com>"
pkgname=linux-postmarketos-zumapro
pkgver=7.0.0
pkgrel=1
pkgdesc="Google zumapro (Pixel 9 Series) close-to-mainline kernel"
arch="aarch64"
_carch="arm64"
_flavor="postmarketos-zumapro"
url="https://kernel.org"
license="GPL-2.0-only"
options="!strip !check !tracedeps pmb:cross-native pmb:kconfigcheck-community"
makedepends="
	bison
	clang
	findutils
	flex
	lld
	llvm
	lz4
	openssl-dev
	perl
	zstd
	clang-dev
	rust
	rust-bindgen
	rust-src
	rustfmt
	rust-clippy
	dwarf-tools
"

# Source
_owner="Trijal08"
_repository="kernel-mainline"
_commit="zumapro-google-caimito"
_config="config-$_flavor.$arch"
source="
	$pkgname-$_commit.tar.gz::https://github.com/$_owner/$_repository/archive/$_commit.tar.gz
	$_config
"
builddir="$srcdir/$_repository-$_commit"
_outdir="out"

prepare() {
	default_prepare
	cp "$srcdir/config-$_flavor.$CARCH" .config
}

build() {
	unset LDFLAGS
	make ARCH="$_carch" LLVM=1 \
		KBUILD_BUILD_VERSION="$((pkgrel + 1 ))-postmarketOS"
}

package() {
	mkdir -p "$pkgdir"/boot

	make Image.lz4 modules_install dtbs_install \
		ARCH="$_carch" \
		LLVM=1 \
		INSTALL_PATH="$pkgdir"/boot \
		INSTALL_MOD_PATH="$pkgdir" \
		INSTALL_MOD_STRIP=1 \
		INSTALL_DTBS_PATH="$pkgdir"/boot/dtbs
	rm -f "$pkgdir"/lib/modules/*/build "$pkgdir"/lib/modules/*/source

	install -D "$builddir"/include/config/kernel.release \
		"$pkgdir"/usr/share/kernel/$_flavor/kernel.release

	install -Dm644 "$builddir/arch/$_carch/boot/Image.lz4" \
		"$pkgdir/boot/vmlinuz"
}

sha512sums="
e2d59786be5b28168db9f7e3a2ad9b1e58807e65be8ae02176d6ad816ed6bfceffc7ff7f7b71f83d5030898e74a40a05220f72d5243909843f80e2d472a1b469  linux-postmarketos-zumapro-zumapro-google-caimito.tar.gz
c95837dfccf4ecbaf733712c6132819bdab0e8399d600c8418231125b0dac986b68e1f56b46880380f390768ae7a6daedd6746192f75a2e1dce55a7ab373e937  config-postmarketos-zumapro.aarch64
"
