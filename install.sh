#!/bin/bash

statsdir=/var/spool/placky
webdir=/var/www
placky_user=placky
modules='JSON::XS CGI'

if [ ! -d $statsdir ]; then
	mkdir -p $statsdir
fi

if [ ! -f $webdir/placky.html ]; then
	cp placky.html $webdir
fi
if [ ! -f $webdir/placky.pl ]; then
	cp placky.pl $webdir
fi

if grep $placky_user /etc/passwd; then
	chown $placky_user: $statsdir $webdir/placky.html $webdir/placky.pl
else
	echo "Supplied username '$placky_user' does not exists on this machine"
fi

sed -i "s|/var/spool/traffstats|${statsdir}|" $webdir/placky.pl

for module in $modules; do
	if ! perl -M$module -e 1; then
		perl -MCPAN -e "install $module"
	fi
done
