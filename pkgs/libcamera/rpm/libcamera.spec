Name:           libcamera
Version:        0.7.1
Release:        1
Summary:        Camera support library for Linux (pipa OV13B10 / HI846)
License:        LGPL-2.1-or-later AND GPL-2.0-or-later
URL:            https://libcamera.org/
Source0:        libcamera.tar.gz

# Prebuilt aarch64 binaries; host brp-strip is x86 and must not run.
%global __strip /bin/true
%global debug_package %{nil}

%description
libcamera with the simple pipeline handler (CAMSS-friendly) and IPA tuning
for Xiaomi Pad 6 sensors: rear OV13B10 and front HI846.

%package ipa
Summary:        IPA modules and proxy for libcamera
Requires:       %{name} = %{version}-%{release}

%description ipa
Image Processing Algorithm modules and helpers for libcamera.

%package tools
Summary:        Camera tools (libcamerify, optional cam)
Requires:       %{name} = %{version}-%{release}
Requires:       %{name}-ipa = %{version}-%{release}

%description tools
Command-line tools: libcamerify (V4L2 compatibility shim) and cam when
libevent was available at build time.

%package devel
Summary:        Development files for libcamera
Requires:       %{name} = %{version}-%{release}

%description devel
Headers and pkg-config for building against libcamera.

%package -n gstreamer1.0-plugin-libcamera
Summary:        GStreamer libcamerasrc plugin
Requires:       %{name} = %{version}-%{release}
Requires:       %{name}-ipa = %{version}-%{release}

%description -n gstreamer1.0-plugin-libcamera
GStreamer element libcamerasrc for capturing via libcamera.

%prep
%setup -q -n destdir

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a . %{buildroot}/
# Drop docs / unused bits
rm -rf %{buildroot}/usr/share/doc \
       %{buildroot}/usr/share/man \
       %{buildroot}/usr/share/gtk-doc || true

%files
%defattr(-,root,root,-)
/usr/lib64/libcamera.so*
/usr/lib64/libcamera-base.so*
/usr/share/libcamera/

%files ipa
%defattr(-,root,root,-)
/usr/lib64/libcamera/
/usr/libexec/libcamera/

%files tools
%defattr(-,root,root,-)
/usr/bin/cam
/usr/bin/libcamerify
/usr/bin/libcamera-bug-report


%files devel
%defattr(-,root,root,-)
/usr/include/libcamera
/usr/lib64/pkgconfig/libcamera.pc
/usr/lib64/pkgconfig/libcamera-base.pc

%files -n gstreamer1.0-plugin-libcamera
%defattr(-,root,root,-)
/usr/lib64/gstreamer-1.0/libgstlibcamera.so

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.7.1-1
- Initial Sailfish package with pipa OV13B10/HI846 sensor helpers
- Build cam only when libevent_pthreads is available; always ship libcamerify
