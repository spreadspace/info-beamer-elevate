import traceback
import urllib2
import calendar
import pytz
from operator import itemgetter
from datetime import timedelta

import dateutil.parser
import defusedxml.ElementTree as ET


def get_schedule(url, locations, schedule_tz):
    schedule = {'locations': locations, 'events': []}
    return schedule
