# = Class: apache2
#
# Apache 2 control.
# 
# == Parameters:
#
# $greeting:: String to display as the header of the home page of the default website.
#
# == Requires:
# 
# Nothing.
#
# == Usage:
#
# class { apache2: $greeting = "To each, their own." }
#
class apache2 ($ensure = running, $greeting = "Hello, world.") {
  $ensure_allowed = [running, uninstalled]
  if !($ensure in $ensure_allowed) {
    fail("FAIL: $ensure = ${ensure}; expected one of ${ensure_allowed}.")
  }
  $installing = $ensure == running

  case $osfamily {
    'RedHat' : {
      $package_name = 'httpd'
      $service_name = 'httpd'
    }
    default: {
      fail("FAIL: This module does no (yet) support the OS family \"${osfamily}\".")
    }
  }

  $package_ensure = $installing ? {
    true  => installed,
    false => purged,
  }
  $file_ensure = $installing ? {
    true  => file,
    false => absent,
  }
  $directory_ensure = $installing ? {
    true  => directory,
    false => absent,
  }
  $service_ensure = $installing

  package { $package_name :
    ensure => $package_ensure,
  }

  file { 'httpd.conf' :
    ensure => $file_ensure,
    path   => '/etc/httpd/conf/httpd.conf',
    source => "puppet:///modules/apache2/httpd.conf",
  }

  # manage sub directories of the DocumentRoot directory.
  $documentroot_subdirs = ['/opt/root/','/opt/root/some', '/opt/root/some/path', '/opt/root/some/path/to']
  file { $documentroot_subdirs :
    ensure => $directory_ensure,
    force  => true,
    mode   => 755,
  }

  if $installing {
    file { 'DocumentRootDirectory' :
      ensure  => $directory_ensure,
      force   => true,
      mode    => 644,
      path    => '/opt/root/some/path/to/www',
      source  => "puppet:///modules/apache2/www",
      recurse => true,
    }
    file { 'index.html' :
      path    => '/opt/root/some/path/to/www/index.html',
      content => template("apache2/index.html.erb"),
      mode    => 644,
      require => File['DocumentRootDirectory'],
    }
  } else {
    # All files are purged when /opt/root is purged; it is redundant to specify the purged state of any contained files.
  }

  service { $service_name:
    ensure => $service_ensure,
  }

  if $installing {
    Package[$package_name] -> File['httpd.conf'] ~> Service[$service_name]
    File[$documentroot_subdirs] -> File['DocumentRootDirectory'] -> Service[$service_name]
  } else {
    Service[$service_name] -> File['httpd.conf'] -> File[$documentroot_subdirs] -> Package[$package_name]
  }
}
