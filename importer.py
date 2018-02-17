import traceback
import urllib2
import calendar
import pytz
from datetime import datetime, timedelta

import dateutil.parser


def get_schedule(api_url, locations, devices, schedule_tz):
    schedule = {}

    now = datetime.now(schedule_tz).replace(minute=0, second=0)
    now_1h = now + timedelta(hours=1)
    now_2h = now + timedelta(hours=2)
    now_3h = now + timedelta(hours=3)
    now_4h = now + timedelta(hours=4)

    e1 = {'title': 'Eroeffnungsshow', 'track': 'discourse'}
    e1['start'] = now.strftime('%s')
    e1['end'] = now_1h.strftime('%s')
    e2 = {'title': 'Bernhard Fleischmann & Band', 'track': 'music'}
    e2['start'] = now_2h.strftime('%s')
    e2['end'] = now_3h.strftime('%s')
    schedule['orhpeum'] = [e1, e2]

    e3 = {'title': 'Meeting of the Secret-Society', 'track': 'discourse'}
    e3['start'] = now.strftime('%s')
    e3['end'] = now_2h.strftime('%s')
    e4 = {'title': 'Nothing to see here!', 'track': 'arts'}
    e4['start'] = now_3h.strftime('%s')
    e4['end'] = now_4h.strftime('%s')
    schedule['forum'] = [e3, e4]

    return schedule
