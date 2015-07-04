#!/bin/bash

CFG_FOLDER=$2
VIRTUALENV_FOLDER=$3
DJANGO_PROJECT_FOLDER=$4
DJANGO_SETTINGS=$5
UWSGI_MODULE=$6

stop()
{
	kill -9 $(cat "$CFG_FOLDER/uwsgi.pid")
	kill $(cat "$CFG_FOLDER/celeryd.pid")
}

start()
{
	cd "$VIRTUALENV_FOLDER"
	source "bin/activate"

	cd "$DJANGO_PROJECT_FOLDER"
	./manage.py collectstatic --noinput --settings="$DJANGO_SETTINGS"
	./manage.py migrate --noinput --settings="$DJANGO_SETTINGS"

	touch "$CFG_FOLDER/reload"
	uwsgi -M -H "$VIRTUALENV_FOLDER" --chdir "$DJANGO_PROJECT_FOLDER" \
		--pidfile "$CFG_FOLDER/uwsgi.pid" -s "$CFG_FOLDER/socket" -d "$CFG_FOLDER/uwsgi.log" \
		--touch-reload "$CFG_FOLDER/uwsgi.reload" --env "DJANGO_SETTINGS_MODULE=$DJANGO_SETTINGS" -w "$UWSGI_MODULE" \
		-i "$CFG_FOLDER/uwsgi.ini"

	./manage.py celeryd_detach -B --pidfile "$CFG_FOLDER/celeryd.pid" --logfile "$CFG_FOLDER/celeryd.log" --settings="$DJANGO_SETTIGNS"
}

restart()
{
	stop
	start
}

watch()
{
	fswatch -r "$DJANGO_PROJECT_FOLDER" -o | xargs -n1 -I {} touch "$CFG_FOLDER/uwsgi.reload"
}


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
	watch)
		watch
	;;
	*)
		exit
	;;
esac

