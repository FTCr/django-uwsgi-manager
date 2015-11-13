#!/bin/bash

g_cfg=""
g_virtualenv=""
g_project=""
g_settings=""
g_wsgi=""

stop()
{
	kill -9 $(cat "$g_cfg/uwsgi.pid")
	kill $(cat "$g_cfg/celeryd.pid")
}

start()
{
	cd "$g_virtualenv"
	source "bin/activate"

	cd "$g_project"
	./manage.py collectstatic --noinput --settings="$g_settings"
	./manage.py migrate --noinput --settings="$g_settings"

	touch "$g_cfg/reload"
	uwsgi -M -H "$g_virtualenv" --chdir "$g_project" \
		--pidfile "$g_cfg/uwsgi.pid" -s "$g_cfg/socket" -d "$g_cfg/uwsgi.log" \
		--touch-reload "$g_cfg/uwsgi.reload" --env "DJANGO_SETTINGS_MODULE=$g_settings" -w "$g_wsgi" \
		-i "$g_cfg/uwsgi.ini"
	./manage.py celeryd_detach -B --pidfile "$g_cfg/celeryd.pid" --logfile "$g_cfg/celeryd.log" --settings="$g_settings"
	post_office
}

restart()
{
	stop
	start
}

post_office()
{
	cd "$g_virtualenv"
	source "bin/activate"

	cd "$g_project"
	./manage.py send_queued_mail --settings="$g_settings"
}


init_global()
{
	g_cfg="$HOME/.$1"
	g_virtualenv="$HOME/$1"
	g_project="$HOME/$1/$1/src"
	g_settings="$2"
	g_wsgi="$3"
}

usage()
{
	echo "Usage: {start, stop, restart} {name} {settings} {wsgi}"
}

main()
{
	if [[ -z $2 || -z $3 || -z $4 ]]
		then
			usage
			exit
	fi
	init_global $2 $3 $4

	case $1 in
		start)
			start
		;;
		stop)
			stop
		;;
		restart)
			restart
		;;
		email)
			post_office
		;;
		*)
			echo "Bad argument: $1"
			usage
			exit
		;;
	esac
}

main $@
