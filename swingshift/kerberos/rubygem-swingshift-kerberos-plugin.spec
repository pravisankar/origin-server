%if 0%{?fedora}%{?rhel} <= 6
    %global scl ruby193
    %global scl_prefix ruby193-
%endif
%{!?scl:%global pkg_name %{name}}
%{?scl:%scl_package rubygem-%{gem_name}}
%global gem_name swingshift-kerberos-plugin
%global rubyabi 1.9.1

Summary:        SwingShift plugin for kerberos auth service
Name:           rubygem-%{gem_name}
Version:        0.8.7
Release:        1%{?dist}
Group:          Development/Languages
License:        ASL 2.0
URL:            http://openshift.redhat.com
Source0:        rubygem-%{gem_name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires:       %{?scl:%scl_prefix}ruby(abi) = %{rubyabi}
Requires:       %{?scl:%scl_prefix}ruby
Requires:       %{?scl:%scl_prefix}rubygems
Requires:       %{?scl:%scl_prefix}rubygem(json)
Requires:       %{?scl:%scl_prefix}rubygem(krb5-auth)
Requires:       %{?scl:%scl_prefix}rubygem(mocha)
Requires:       rubygem(stickshift-common)
Requires:       stickshift-broker
Requires:  		selinux-policy-targeted
Requires:  		policycoreutils-python
%if 0%{?fedora}%{?rhel} <= 6
BuildRequires:  ruby193-build
BuildRequires:  scl-utils-build
%endif
BuildRequires:  %{?scl:%scl_prefix}ruby(abi) = %{rubyabi}
BuildRequires:  %{?scl:%scl_prefix}ruby 
BuildRequires:  %{?scl:%scl_prefix}rubygems
BuildRequires:  %{?scl:%scl_prefix}rubygems-devel
BuildArch:      noarch
Provides:       rubygem(%{gem_name}) = %version


%description
Provides a kerberos auth service based plugin

%package doc
Summary:        SwingShift plugin for kerberos auth service documentation

%description doc
Provides a kerberos auth service based plugin documentation

%prep
%setup -q

%build
%{?scl:scl enable %scl - << \EOF}
mkdir -p .%{gem_dir}
# Create the gem as gem install only works on a gem file
gem build %{gem_name}.gemspec

export CONFIGURE_ARGS="--with-cflags='%{optflags}'"
# gem install compiles any C extensions and installs into a directory
# We set that to be a local directory so that we can move it into the
# buildroot in %%install
gem install -V \
        --local \
        --install-dir .%{gem_dir} \
        --bindir ./%{_bindir} \
        --force \
        --rdoc \
        %{gem_name}-%{version}.gem
%{?scl:EOF}

%install
mkdir -p %{buildroot}%{gem_dir}
cp -a .%{gem_dir}/* %{buildroot}%{gem_dir}/

# If there were programs installed:
#mkdir -p %{buildroot}%{_bindir}
#cp -a ./%{_bindir}/* %{buildroot}%{_bindir}

mkdir -p %{buildroot}/var/www/stickshift/broker/config/environments/plugin-config
cat <<EOF > %{buildroot}/var/www/stickshift/broker/config/environments/plugin-config/swingshift-kerberos-plugin.rb
Broker::Application.configure do
  config.auth = {
    :salt => "ClWqe5zKtEW4CJEMyjzQ",
    :privkeyfile => "/var/www/stickshift/broker/config/server_priv.pem",
    :privkeypass => "",
    :pubkeyfile  => "/var/www/stickshift/broker/config/server_pub.pem",
  }
end
EOF

%clean
rm -rf %{buildroot}

%post
/usr/bin/openssl genrsa -out /var/www/stickshift/broker/config/server_priv.pem 2048
/usr/bin/openssl rsa    -in /var/www/stickshift/broker/config/server_priv.pem -pubout > /var/www/stickshift/broker/config/server_pub.pem

echo "The following variables need to be set in your rails config to use swingshift-kerberos-plugin:"
echo "auth[:salt]                    - salt for the password hash"
echo "auth[:privkeyfile]             - RSA private key file for node-broker authentication"
echo "auth[:privkeypass]             - RSA private key password"
echo "auth[:pubkeyfile]              - RSA public key file for node-broker authentication"

%files
%defattr(-,root,root,-)
%doc LICENSE COPYRIGHT Gemfile
%exclude %{gem_cache}
%{gem_instdir}
%{gem_spec}
#%{_bindir}/*

%attr(0440,apache,apache) /var/www/stickshift/broker/config/environments/plugin-config/swingshift-kerberos-plugin.rb

%files doc
%doc %{gem_docdir}

%changelog
* Thu Aug 16 2012 Brenton Leanhardt <bleanhar@redhat.com> 0.8.7-1
- new package built with tito

* Wed Aug 15 2012 Jason DeTiberus <jason.detiberus@redhat.com> 0.8.6-1
- kerberos auth plugin (jason.detiberus@redhat.com)

* Wed Aug 15 2012 Jason DeTiberus <jason.detiberus@redhat.com> 0.8.5-1
- new package built with tito

