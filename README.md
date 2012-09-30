What?
=====

When writing modules you want to provide default data for things like per OS
package names, service names etc or just other default data.

This has been hard with Hiera since other than the Puppet backend it could not
load data from any modules.  And since that relied on the site specific
hierarchy module authors have no idea how their data in the module will be
called in production use.

This backend allows module authors to specify a module specific hierarchy and
provide module specific data.  The idea being that this should be the last
backend that gets loaded into the site hiera.

This allow module authors to supply completely custom data with a custom
hierarchy that will remain active regardless of site specific Hiera setup and
that can still be overridden by site administrators.

Additionally this includes and uses a generic file cache class for Hiera which
other file based modules can use to speed themselves up.

Configuring a module
--------------------

First your module need a specific hierarchy, else a default will be used.
Given a module as below:

    your_module
    ├── data
    │   ├── hiera.json
    │   └── osfamily
    │       ├── Debian.json
    │       └── RedHat.json
    └── manifests
        └── init.pp

The optional *hiera.json* can contain a hierarchy, something like:

    {"hierarchy": ["osfamily/%{osfamily}", "common"]}

This is the default hierarchy if none is specified in the module but you can
use any fact of course.

As you can see here we have RedHat and Debian specific data inside the module.

Writing a module and using the data
-----------------------------------

Given the class below in init.pp:

    class apache($package="apache") {
       package{$package: ensure => present}
    }

And data in *RedHat.json*:

    {"apache::package" : "httpd"}

...and in *Debian.json*:

    {"apache::package" : "apache2"}

This will install the right package on the right OS while still allowing users
to override the package name using their site specific hierarchy and data
sources.

Installation?
-------------

This works only with Puppet 3.0.0 and newer:

    # gem install hiera-module-json

And then configure your site wide hiera to use this backend using your *hiera.yaml*

    ---
    :backends: - json
               - module_json
    :hierarchy: - %{::fqdn}
                - common

Who?
----

R.I.Pienaar / rip@devco.net / @ripienaar / www.devco.net
