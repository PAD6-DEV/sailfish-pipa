Name:           mesa-pipa
Version:        24.1.7
Release:        1
Summary:        Mesa freedreno/msm for Xiaomi Pad 6 (Sailfish OS aarch64)
License:        MIT
URL:            https://www.mesa3d.org/
Source0:        mesa-pipa-tree.tar.gz
# Prebuilt aarch64 libs from Platform SDK; host rpmbuild must not strip them.
%global __strip /bin/true
%global debug_package %{nil}
AutoReqProv:    no

# Replace stock Mesa (no freedreno/msm on SFOS) with this port.
Provides:       mesa-dri-drivers = %{version}
Provides:       mesa-libEGL = %{version}
Provides:       mesa-libGLESv1 = %{version}
Provides:       mesa-libGLESv2 = %{version}
Provides:       mesa-libgbm = %{version}
Provides:       libEGL = %{version}
Provides:       libGLESv2 = %{version}
Obsoletes:      mesa-dri-drivers < %{version}-%{release}
Obsoletes:      mesa-libEGL < %{version}-%{release}
Obsoletes:      mesa-libGLESv1 < %{version}-%{release}
Obsoletes:      mesa-libGLESv2 < %{version}-%{release}
Obsoletes:      mesa-libgbm < %{version}-%{release}

# Runtime deps (libdrm, wayland, zlib, expat) come from SFOS base + pattern.

%description
Mesa 24.1.7 with gallium freedreno (msm KMD) and swrast, built for Sailfish OS
aarch64 (glibc 2.30) for Xiaomi Pad 6 (Adreno 650 / SM8250).

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
* Thu Jul 16 2026 Porter <porter@local> - 24.1.7-1
- Package pipa freedreno Mesa tarball for adaptation repo
