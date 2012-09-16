%if 0%{?fedora}%{?rhel} <= 6
    %global scl ruby193
    %global scl_prefix ruby193-
%endif
%{!?scl:%global pkg_name %{name}}
%{?scl:%scl_package rubygem-%{gem_name}}
%global gem_name swingshift-mongo-plugin
%global rubyabi 1.9.1

Summary:        SwingShift plugin for mongo auth service
Name:           rubygem-%{gem_name}
Version:        0.8.6
Release:        2%{?dist}
Group:          Development/Languages
License:        ASL 2.0
URL:            http://openshift.redhat.com
Source0:        rubygem-%{gem_name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires:       %{?scl:%scl_prefix}ruby(abi) = %{rubyabi}
Requires:       %{?scl:%scl_prefix}ruby
Requires:       %{?scl:%scl_prefix}rubygems
Requires:       %{?scl:%scl_prefix}rubygem(activeresource)
Requires:       %{?scl:%scl_prefix}rubygem(json)
Requires:       %{?scl:%scl_prefix}rubygem(mocha)
Requires:       rubygem(stickshift-common)
Requires:       stickshift-broker
Requires:  		selinux-policy-targeted
Requires:  		policycoreutils-python
Requires:       openssl
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
Provides a mongo auth service based plugin

%package doc
Summary:        SwingShift plugin for mongo auth service ri documentation

%description doc
SwingShift plugin for mongo auth service ri documentation

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
mkdir -p %{buildroot}%{_bindir}
cp -a ./%{_bindir}/* %{buildroot}%{_bindir}

mkdir -p %{buildroot}/var/www/stickshift/broker/config/environments/plugin-config
cat <<EOF > %{buildroot}/var/www/stickshift/broker/config/environments/plugin-config/swingshift-mongo-plugin.rb
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

echo "The following variables need to be set in your rails config to use swingshift-mongo-plugin:"
echo "auth[:salt]                    - salt for the password hash"
echo "auth[:privkeyfile]             - RSA private key file for node-broker authentication"
echo "auth[:privkeypass]             - RSA private key password"
echo "auth[:pubkeyfile]              - RSA public key file for node-broker authentication"
echo "auth[:mongo_replica_sets]      - List of replica servers or false if replicas is disabled eg: [[<host-1>, <port-1>], [<host-2>, <port-2>], ...]"
echo "auth[:mongo_host_port]         - Address of mongo server if replicas are disabled. eg: [\"localhost\", 27017]"
echo "auth[:mongo_user]              - Username to log into mongo"
echo "auth[:mongo_password]          - Password to log into mongo"
echo "auth[:mongo_db]                - Database name to store user login/password data"
echo "auth[:mongo_collection]        - Collection name to store user login/password data"

%files
%defattr(-,root,root,-)
%doc LICENSE COPYRIGHT Gemfile
%exclude %{gem_cache}
%{gem_instdir}
%{gem_spec}
%{_bindir}/*

%attr(0440,apache,apache) /var/www/stickshift/broker/config/environments/plugin-config/swingshift-mongo-plugin.rb

%files doc
%doc %{gem_docdir}

%changelog
* Mon Aug 20 2012 Brenton Leanhardt <bleanhar@redhat.com> 0.8.6-1
- gemspec refactorings based on Fedora packaging feedback (bleanhar@redhat.com)
- Providing a better error message for invalid broker iv/token
  (kraman@gmail.com)
- fix for cartridge-jenkins_build.feature cucumber test (abhgupta@redhat.com)
- Bug 836055 - Bypass authentication by making a direct request to broker with
  broker_auth_key (kraman@gmail.com)
- MCollective updates - Added mcollective-qpid plugin - Added mcollective-
  gearchanger plugin - Added mcollective agent and facter plugins - Added
  option to support ignoring node profile - Added systemu dependency for
  mcollective-client (kraman@gmail.com)
- Updated gem info for rails 3.0.13 (admiller@redhat.com)

* Wed May 30 2012 Krishna Raman <kraman@gmail.com> 0.8.5-1
- Fix for Bugz 825366, 825340. SELinux changes to allow access to
  user_action.log file. Logging authentication failures and user creation for
  OpenShift Origin (abhgupta@redhat.com)
- Raise auth exception when no user/password is provided by web browser. Bug
  815971 (kraman@gmail.com)
- Adding livecd build scripts Adding a text only minimal version of livecd
  Added ability to access livecd dns from outside VM (kraman@gmail.com)
- Merge pull request #19 from kraman/dev/kraman/bug/815971
  (dmcphers@redhat.com)
- Fix bug in mongo auth service where auth failure is returning nil instead of
  Exception (kraman@gmail.com)
- Adding a seperate message for errors returned by cartridge when trying to add
  them. Fixing CLIENT_RESULT error in node Removing tmp editor file
  (kraman@gmail.com)
- Added tests (kraman@gmail.com)
- BugZ# 817957. Adding rest api for creating a user in the mongo auth service.
  Rest API will be accessabel only from local host and will require login/pass
  of an existing user. (kraman@gmail.com)
- moving broker auth key and iv encoding/decoding both into the plugin
  (abhgupta@redhat.com)

* Thu Apr 26 2012 Krishna Raman <kraman@gmail.com> 0.8.4-1
- Added README for SwingShift-mongo plugin (rpenta@redhat.com)
- cleaning up spec files (dmcphers@redhat.com)
- decoding the broker auth key before returning from login in the auth plugin
  (abhgupta@redhat.com)

* Sat Apr 21 2012 Krishna Raman <kraman@gmail.com> 0.8.3-1
- new package built with tito
