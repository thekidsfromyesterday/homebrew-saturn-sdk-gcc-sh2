class SaturnSdkGccSh2 < Formula
  def arch
    "x86_64"
  end

  def osmajor
    `uname -r`.chomp
  end

  desc "GCC cross-compiler for Sega Saturn"
  homepage "https://segaxtreme.net/threads/another-saturn-sdk.23781/"
  head "https://github.com/thekidsfromyesterday/Saturn-SDK-GCC-SH2.git"

  depends_on "coreutils" => :build # for realpath
  depends_on "gcc@7" => :build

  # Versions
  ENV['BINUTILSVER'] = "2.31"
  ENV['GCCVER'] = "9.1.0"
  ENV['NEWLIBVER'] = "3.0.0"
  ENV['MPCVER'] = "1.1.0"
  ENV['MPFRVER'] = "4.0.2"
  ENV['GMPVER'] = "6.1.2"

  # All of these are normally downloaded by the download.sh script;
  # they're specified here as :nounzip resources so we can model and download them instead.
  resource "binutils" do
    url "https://ftp.gnu.org/gnu/binutils/binutils-#{ENV['BINUTILSVER']}.tar.bz2", :using => :nounzip
    sha256 "2c49536b1ca6b8900531b9e34f211a81caf9bf85b1a71f82b81ae32fcd8ffe19"
  end

  resource "gcc" do
    url "https://ftp.gnu.org/gnu/gcc/gcc-#{ENV['GCCVER']}/gcc-#{ENV['GCCVER']}.tar.xz", :using => :nounzip
    sha256 "79a66834e96a6050d8fe78db2c3b32fb285b230b855d0a66288235bc04b327a0"
  end

  resource "gmp" do
    url "https://gmplib.org/download/gmp/gmp-#{ENV['GMPVER']}.tar.bz2", :using => :nounzip
    sha256 "5275bb04f4863a13516b2f39392ac5e272f5e1bb8057b18aec1c9b79d73d8fb2"
  end

  resource "libmpc" do
    url "https://ftp.gnu.org/gnu/mpc/mpc-#{ENV['MPCVER']}.tar.gz", :using => :nounzip
    sha256 "6985c538143c1208dcb1ac42cedad6ff52e267b47e5f970183a3e75125b43c2e"
  end

  resource "newlib" do
    url "ftp://sourceware.org/pub/newlib/newlib-#{ENV['NEWLIBVER']}.tar.gz", :using => :nounzip
    sha256 "5b76a9b97c9464209772ed25ce55181a7bb144a66e5669aaec945aa64da3189b"
  end

  resource "mpfr" do
    url "https://ftp.gnu.org/gnu/mpfr/mpfr-#{ENV['MPFRVER']}.tar.bz2", :using => :nounzip
    sha256 "c05e3f02d09e0e9019384cdd58e0f19c64e6db1fd6f5ecf77b4b1c61ca253acc"
  end

  # ld: internal error: atom not found in symbolIndex(__ZN3vecINSt3__14pairIjPKcEE7va_heap6vl_ptrE7reserveEjb) for architecture x86_64
  fails_with :clang

  def install
    resources.each do |r|
      (buildpath/"download").install r
    end

    # At higher levels of parallelization, make race bugs have been observed
    ENV["MAKEFLAGS"] = "-j#{[2, Hardware::CPU.cores].min}"
    ENV["SRCDIR"] = "#{buildpath}/source"
    ENV["BUILDDIR"] = "#{buildpath}/build"
    ENV["TARGETMACH"] = "sh-elf"
    ENV["OBJFORMAT"] = "ELF"
    ENV["BUILDMACH"] = "x86_64-pc-linux-gnu"
    ENV["HOSTMACH"] = "x86_64-pc-linux-gnu"
    ENV["INSTALLDIR"] = prefix.to_s
    # Ensures the temporary cross-compiler doesn't get moved to
    # outside a sandbox-writeable directory
    ENV["INSTALLDIR_BUILD_TARGET"] = "#{buildpath}/build_target"
    ENV["SYSROOTDIR"] = "#{prefix}/sysroot"
    ENV["ROOTDIR"] = buildpath.to_s
    # we've already downloaded the resources
    ENV["SKIP_DOWNLOAD"] = "1"
    ENV["DOWNLOADDIR"] = "#{buildpath}/download"
    ENV["PROGRAM_PREFIX"] = "saturn-sh2-"

    ENV["BINUTILS_CFLAGS"] = "-s"
    ENV["GCC_BOOTSTRAP_FLAGS"] = "--with-cpu=m2"
    ENV["GCC_FINAL_FLAGS"] = "--with-cpu=m2 --with-sysroot=#{ENV['SYSROOTDIR']}"

    system "./build.sh"

    # The rest of the build is sandboxed appropriately, but this clashes with `gcc`
    (prefix/"share/gcc-#{ENV['GCCVER']}/python").rmtree
    (prefix/"share/info").rmtree
  end

  test do
    (testpath/"hello-c.c").write <<~EOS
      #include <stdio.h>
      int main()
      {
        puts("Hello, world!");
        return 0;
      }
    EOS
    system "#{bin}/saturn-sh2-elf-gcc", "-o", "hello-c", "hello-c.c"
    assert_match /hello-c: ELF 32-bit MSB executable/, shell_output("/usr/bin/file hello-c")

    (testpath/"hello-cc.cc").write <<~EOS
      #include <iostream>
      int main()
      {
        std::cout << "Hello, world!" << std::endl;
        return 0;
      }
    EOS
    system "#{bin}/saturn-sh2-elf-g++", "-o", "hello-cc", "hello-cc.cc"
    assert_match /hello-cc: ELF 32-bit MSB executable/, shell_output("/usr/bin/file hello-cc")
  end
end
