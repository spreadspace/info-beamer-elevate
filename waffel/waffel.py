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

from datetime import datetime, timedelta

import dateutil.parser
import dateutil.tz
import logging
import requests


logging.basicConfig()
logger = logging.getLogger(__file__)


class Waffel(object):

    def __init__(
            self,
            api_url,
            year,
            tracks,
            locations,
            min_delta=timedelta(minutes=10),
            max_delta=timedelta(hours=15),
            timezone=dateutil.tz.gettz('Europe/Vienna'),
            timeout=30):
        self.api_url = api_url
        self.year = year
        # tracks: Due to historic reasons music is named arts and arts is named
        #         ART_art in EIS.
        self.track_map = {it['eis_id']: it['id'] for it in tracks}
        self.location_map = {it['eis_id']: it['id'] for it in locations}
        self.min_delta = min_delta
        self.max_delta = max_delta
        self.timezone = timezone
        self.timeout = timeout
        self.headers = {'Accept': 'application/json; charset=utf-8'}

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

        except (requests.exceptions.RequestException, ValueError) as e:
            logger.error("fetching %s failed(%s): %s" % (objtype, type(e), e))
            return None

    def parse_date(self, dt):
        # the API returns timestamp in TZ Europe/Vienna
        return dateutil.parser.parse(dt).replace(tzinfo=dateutil.tz.gettz('Europe/Vienna'))

    def dt_to_epoch(self, dt):
        # https://stackoverflow.com/a/11743262/1337474
        epoch = datetime(1970, 1, 1).replace(tzinfo=dateutil.tz.gettz('UTC'))
        return int((dt - epoch).total_seconds())

    def dt_within(self, now, start, end):
        if (
            start > now + self.max_delta
            or end < now - self.min_delta
        ):
            return False
        return True

    def make_event(self, start, end, title, subtitle, track):
        # "start":     start-time in given timezone as HH:MM
        # "startts":   start-time as unix epoch timestamp
        # "end":       end-time in given timezone as HH:MM
        # "endts":     end-time as unix epoch timestamp
        # "title":     title of the event
        # "subtitle":  subtitle of the event (optional)
        # "track":     discourse, music or arts
        return {
            'start': start.astimezone(self.timezone).strftime('%H:%M'),
            'startts': self.dt_to_epoch(start),
            'end': end.astimezone(self.timezone).strftime('%H:%M'),
            'endts': self.dt_to_epoch(end),
            'title': title,
            'subtitle': subtitle,
            'track': track,
        }

    def get_events(self, now=datetime.utcnow().replace(tzinfo=dateutil.tz.gettz('UTC')), track=None):
        url = '%s?method=Event.detail&lang=en&year=%d' % (
            self.api_url,
            self.year
        )
        if track:
            url = '%s&track=%s' % (url, track)

        result = self.__fetch_objects("events", url)
        if not result:
            return None

        ret = {}
        missing_locations = []
        missing_tracks = {}
        for event in result:
            start = self.parse_date(event['begin'])
            end = self.parse_date(event['end'])
            if not self.dt_within(now, start, end):
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
                if 'apps' in event:
                    for appearance in event['apps']:
                        app_start = self.parse_date(appearance['begin'])
                        app_end = self.parse_date(appearance['end'])
                        if not self.dt_within(now, app_start, app_end):
                            continue
                        track = self.track_map.get(event['track'])
                        if not track:
                            missing_tracks[event['track']] = True
                        labels = []
                        if 'labels' in appearance:
                            for label in appearance['labels']:
                                labels.append(label['name'])
                        subtitle = ', '.join(labels)
                        if subtitle and 'country_code' in appearance and appearance['country_code']:
                            subtitle += '/' + appearance['country_code']
                        if subtitle:
                            subtitle = '(' + subtitle + ')'
                        events.append(self.make_event(
                            app_start,
                            app_end,
                            appearance['name'],
                            subtitle,
                            track,
                        ))
                else:
                    # at least in one case observerd so far there were no appearances linked to the event
                    # in this case the 'presented_by' field contained the best fitting event title
                    track = self.track_map.get(event['track'])
                    if not track:
                        missing_tracks[event['track']] = True
                    events.append(self.make_event(
                        start,
                        end,
                        event['presented_by'],
                        '',
                        track,
                    ))
            else:
                track = self.track_map.get(event['track'])
                if not track:
                    missing_tracks[event['track']] = True
                events.append(self.make_event(
                    start,
                    end,
                    event['title'],
                    event['subtitle'],
                    track,
                ))

            if not events:
                continue
            ret.setdefault(location, [])
            ret[location] += events

            if 'streaming' in event and 'is_livemedia' in event['streaming'] and event['streaming']['is_livemedia'] == '1':
                ret.setdefault('emc', [])
                ret['emc'] += events

        # sort by startts
        for key in ret.keys():
            ret[key].sort(key=lambda it: it['startts'])

        # some events of the discourse track have duplicates in other tracks - filter them out
        for location in ret:
            discourse_startts = [e['startts'] for e in ret[location] if e['track'] == 'discourse']
            if len(discourse_startts) == 0:
                continue
            filtered = []
            for i in range(len(ret[location])):
                if ret[location][i]['track'] == 'discourse':
                    filtered.append(ret[location][i])
                    continue
                if ret[location][i]['startts'] not in discourse_startts:
                    filtered.append(ret[location][i])
                    continue
                # print("location '%s': dropping duplicate event '%s'" % (location.encode('utf8'), ret[location][i]['title'].encode('utf-8')))
            ret[location] = filtered

        # merge concurrent music appearances
        for location in ret:
            merged = []
            prevmusic = None
            for i in range(len(ret[location])):
                if ret[location][i]['track'] != 'music':
                    merged.append(ret[location][i])
                    continue
                if not prevmusic:
                    prevmusic = ret[location][i]
                    continue
                if prevmusic['startts'] == ret[location][i]['startts']:
                    #print("location '%s': merging event '%s' with '%s'" % (location.encode('utf8'), ret[location][i]['title'].encode('utf8'), prevmusic['title'].encode('utf-8')))
                    prevmusic['title'] = prevmusic['title'] + ' & ' + ret[location][i]['title']
                    prevmusic['subtitle'] = ''  # prevmusic['subtitle'] + ' & ' + ret[location][i]['subtitle'] ### TODO: also merge subtitles??
                else:
                    merged.append(prevmusic)
                    prevmusic = ret[location][i]
            if prevmusic:
                merged.append(prevmusic)
            ret[location] = merged

        # some events (especial from arts track) have multiple 24hour slots - only show the first
        for location in ret:
            filtered = []
            last_start = ""
            last_title = ""
            for i in range(len(ret[location])):
                if ret[location][i]['start'] != last_start or ret[location][i]['title'] != last_title:
                    filtered.append(ret[location][i])
                    last_start = ret[location][i]['start']
                    last_title = ret[location][i]['title']
                    continue
                #print("location '%s': dropping duplicate event '%s'" % (location.encode('utf8'), ret[location][i]['title'].encode('utf-8')))
            ret[location] = filtered

        if missing_locations:
            logger.warn(
                'The following locations were not found in the location'
                ' mapping and their events thus not included (name (id)): %s' %
                ', '.join([
                    '%s (%s)' % (it[0], it[1])
                    for it in set(missing_locations)
                ])
            )

        if missing_tracks:
            logger.warn('The following tracks were not found in the track mapping: %s' % ', '.join(missing_tracks.keys()))

        return ret

    def get_locations(self, track=None):
        url = '%s?method=Location.detail&lang=en&year=%d' % (
            self.api_url,
            self.year
        )
        if track:
            url = '%s&track=%s' % (url, track)

        return self.__fetch_objects("locations", url)
