Name:           mesa-pipa
Version:        24.1.7
Release:        4
Summary:        Mesa freedreno/msm for Xiaomi Pad 6 (Sailfish OS aarch64)
License:        MIT
URL:            https://www.mesa3d.org/
Source0:        mesa-pipa-tree.tar.gz
# Prebuilt aarch64 libs from Platform SDK; host rpmbuild must not strip them.
%global __strip /bin/true
%global debug_package %{nil}
AutoReqProv:    no

# Replace stock Mesa (SFOS ships llvmpipe-named packages; no freedreno/msm).
Provides:       mesa-dri-drivers = %{version}
Provides:       mesa-libEGL = %{version}
Provides:       mesa-libGLESv1 = %{version}
Provides:       mesa-libGLESv2 = %{version}
Provides:       mesa-libgbm = %{version}
Provides:       mesa-libglapi = %{version}
Provides:       libEGL = %{version}
Provides:       libGLESv2 = %{version}
Provides:       mesa-llvmpipe-libEGL = %{version}
Provides:       mesa-llvmpipe-libGLESv1 = %{version}
Provides:       mesa-llvmpipe-libGLESv2 = %{version}
Provides:       mesa-llvmpipe-libgbm = %{version}
Provides:       mesa-llvmpipe-libglapi = %{version}
Provides:       mesa-llvmpipe-libGL = %{version}
Provides:       mesa-llvmpipe-dri-drivers = %{version}
Provides:       libEGL.so.1()(64bit)
Provides:       libGLESv1_CM.so.1()(64bit)
Provides:       libGLESv2.so.2()(64bit)
Provides:       libgbm.so.1()(64bit)
Provides:       libglapi.so.0()(64bit)

Obsoletes:      mesa-dri-drivers < %{version}-%{release}
Obsoletes:      mesa-libEGL < %{version}-%{release}
Obsoletes:      mesa-libGLESv1 < %{version}-%{release}
Obsoletes:      mesa-libGLESv2 < %{version}-%{release}
Obsoletes:      mesa-libgbm < %{version}-%{release}
Obsoletes:      mesa-libglapi < %{version}-%{release}
Obsoletes:      mesa-llvmpipe-libEGL
Obsoletes:      mesa-llvmpipe-libGLESv1
Obsoletes:      mesa-llvmpipe-libGLESv2
Obsoletes:      mesa-llvmpipe-libgbm
Obsoletes:      mesa-llvmpipe-libglapi
Obsoletes:      mesa-llvmpipe-libGL
Obsoletes:      mesa-llvmpipe-dri-drivers
# No Conflicts: — Conflicts + Requires from UI patterns can make mic keep
# stock mesa-llvmpipe and skip mesa-pipa. Obsoletes alone is enough to replace.

# Runtime deps (libdrm, wayland, zlib, expat) come from SFOS base + pattern.

%description
Mesa 24.1.7 with gallium freedreno (msm KMD) and swrast, built for Sailfish OS
aarch64 (glibc 2.30) for Xiaomi Pad 6 (Adreno 650 / SM8250). Replaces stock
mesa-llvmpipe-* packages.

%prep
%setup -q -n destdir

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a . %{buildroot}/
# Drop devel files from the runtime package
rm -rf %{buildroot}/usr/include \
       %{buildroot}/usr/lib64/pkgconfig \
       %{buildroot}/usr/lib/pkgconfig || true

%files
%defattr(-,root,root,-)
/usr

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 24.1.7-4
- Drop Conflicts on mesa-llvmpipe so mic can replace stock Mesa via Obsoletes
* Fri Jul 17 2026 Porter <porter@local> - 24.1.7-3
- Provide Mesa sonames required by Qt and system GL users
* Fri Jul 17 2026 Porter <porter@local> - 24.1.7-2
- Provide/Obsolete/Conflict mesa-llvmpipe-* so mic can replace stock Mesa
* Thu Jul 16 2026 Porter <porter@local> - 24.1.7-1
- Package pipa freedreno Mesa tarball for adaptation repo
