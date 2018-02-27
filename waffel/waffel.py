#!/usr/bin/python
#
#  Fetch Event Info from EIS
#
#
#  Copyright (C) 2018 Christian Pointner <equinox@elevate.at>
#                     Johannes Raggam <thetetet@gmail.com>
#
#  This file is part of eis-waffel.
#
#  eis-waffel is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  any later version.
#
#  eis-waffel is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with eis-waffel. If not, see <http://www.gnu.org/licenses/>.
#

# ***************************************

from datetime import datetime
from datetime import timedelta

import dateutil.parser
import logging
import requests


logging.basicConfig()  # TODO: changed print to logging.
logger = logging.getLogger(__file__)


class Waffel(object):

    def __init__(
            self,
            api_url,
            tracks,
            locations,
            timezone='Europe/Vienna',
            timeout=30):
        self.api_url = api_url
        # tracks: Due to historic reasons music is named arts and arts is named
        #         campus in EIS.
        self.track_map = {it['eis_id']: it['id'] for it in tracks}
        self.location_map = {it['eis_id']: it['id'] for it in locations}
        self.timezone = timezone
        self.timeout = timeout
        self.year = datetime.now().year
        self.headers = {'Accept': 'application/json; charset=utf-8'}
        self.min_delta = timedelta(minutes=30)
        self.max_delta = timedelta(hours=12)

    def __fetch_objects(self, objtype, url):
        try:
            r = requests.get(url, headers=self.headers, timeout=self.timeout)
            r.raise_for_status()
            ret = r.json()
            if ret['status'] != 'ok':
                logger.error(
                    "fetching %s failed, API returned status: %s" % (
                        objtype,
                        ret['status']
                    )
                )
                return None
            return ret['result']

        except requests.exceptions.RequestException as e:
            logger.error("fetching %s failed: %s" % (objtype, e))
            return None

    def parse_date(self, dt):
        return dateutil.parser.parse(dt)

    def dt_to_epoch(self, dt):
        # https://stackoverflow.com/a/11743262/1337474
        return int((dt - datetime(1970, 1, 1)).total_seconds())

    def dt_within(self, start, end):
        now = datetime.now()
        #now = datetime(2018, 3, 2, 18, 0)  # TODO: use/change this to test
        if (
            start > now + self.max_delta
            or end < now - self.min_delta
        ):
            return False
        return True

    def make_event(self, start, end, title, subtitle, track_id):
        # "start":     Startzeit in der gegebenen Zeitzone als HH:MM
        # "startts":   Startzeit als unix epoch timestamp
        # "end":       Endzeit in der gegebenen Zeitzone als HH:MM
        # "endts":     Endzeit als unix epoch timestamp
        # "title":     Titel des Event
        # "subtitle":  Untertitel des Event (optional)
        # "track":     discourse, music oder arts
        #
        # TODO: check, if timezone-naive is really OK
        #       converting to timezone-aware datetimes shouldn't make a
        #       difference.
        return {
            'start': start.strftime('%H:%M'),
            'startts': self.dt_to_epoch(start),
            'end': end.strftime('%H:%M'),
            'endts': self.dt_to_epoch(end),
            'title': title,
            'subtitle': subtitle,
            'track': self.track_map.get(track_id),
        }

    def get_events(self, track=None):
        url = '%s?method=Event.detail&lang=en&year=%d' % (
            self.api_url,
            self.year
        )
        if track:
            url = '%s&track=%s' % (url, track)

        result = self.__fetch_objects("events", url)

        ret = {}
        missing_locations = []
        for event in result:
            start = self.parse_date(event['begin'])
            end = self.parse_date(event['end'])
            if not self.dt_within(start, end):
                continue
            location = self.location_map.get(event['location_id'], None)
            if not location:
                missing_locations.append((
                    event['location_id'],
                    event['location']['name']
                ))
                continue

            events = []
            if event['track'] in ('art',):
                # a event in art (actually music) is a whole stage for a whole
                # evening. each artist/slot appears in event['apps'] list.
                # if there are any more tracks than 'art' which behave like
                # this one, add it to the tuple above.
                for appearance in event['apps']:
                    app_start = self.parse_date(appearance['begin'])
                    app_end = self.parse_date(appearance['end'])
                    if not self.dt_within(app_start, app_end):
                        continue
                    events.append(self.make_event(
                        app_start,
                        app_end,
                        appearance['name'],
                        appearance['name_add'],  # TODO: name_add ok? type could also be of interest.  # noqa
                        appearance['track'],
                    ))
            else:
                events.append(self.make_event(
                    start,
                    end,
                    event['title'],
                    event['subtitle'],
                    event['track'],
                ))

            if not events:
                continue
            ret.setdefault(location, [])
            ret[location] += events

        # Sort for startts
        for key in ret.keys():
            ret[key].sort(key=lambda it: it['startts'])

        if missing_locations:
            logger.warn(
                'The following locations were not found in the location'
                ' mapping and their events thus not included (name (id)): %s' %
                ', '.join([
                    '%s (%s)' % (it[0], it[1])
                    for it in set(missing_locations)
                ])
            )

        return ret

    def get_locations(self, track=None):
        url = '%s?method=Location.detail&lang=en&year=%d' % (
            self.api_url,
            self.year
        )
        if track:
            url = '%s&track=%s' % (url, track)

        return self.__fetch_objects("locations", url)
