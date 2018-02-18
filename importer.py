import traceback
import urllib2
import calendar
import pytz
from datetime import datetime, timedelta

import dateutil.parser


def get_schedule(api_url, tracks, locations, devices, schedule_tz):
    schedule = {}

    def __hour_min(t):
        return t.strftime("%H:%M")

    def __unix_ts(t):
        return int(t.strftime("%s"))

    def __new_event(title, track, start, end):
        e = {'title':  title, 'track': track}
        e['start'] = __hour_min(start)
        e['startts'] = __unix_ts(start)
        e['end'] = __hour_min(end)
        e['endts'] = __unix_ts(end)
        return e

    now = datetime.now(schedule_tz).replace(minute=0, second=0)
    now_1h = now + timedelta(hours=1)
    now_2h = now + timedelta(hours=2)
    now_3h = now + timedelta(hours=3)
    now_4h = now + timedelta(hours=4)

    e1 = __new_event("Eroeffnungsshow", 'discourse', now, now_1h)
    e1['subtitle'] = "Welcome to the Elevate Festival 2018"
    e2 = __new_event("Bernhard Fleischmann & Band", 'music', now_2h, now_3h)
    schedule['orpheum'] = [e1, e2]

    e3 = __new_event("Meeting of the Secret-Society", 'discourse', now, now_2h)
    e3['subtitle'] = "don't tell Donald Trump!!!!"
    e4 = __new_event("Nothing to see here!", 'arts', now_2h, now_3h)
    e4['subtitle'] = "this subtitle left intentionally blank"
    e5 = __new_event("Ist das Kunst?", 'arts', now_3h, now_4h)
    e5['subtitle'] = "... oder kann das Weg?"
    schedule['forum'] = [e3, e4, e5]

    return schedule
