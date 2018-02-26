#!/usr/bin/python
#
#  Fetch Event Info from EIS
#
#
#  Copyright (C) 2018 Christian Pointner <equinox@elevate.at>
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

import requests


class Waffel(object):
    # due to historic reasons music is named arts and arts is named campus in EIS  # noqa
    TRACK_NAME_MAP = {"art": "music", "campus": "arts"}

    def __init__(self, api_url, timeout=30):
        self.api_url = api_url
        self.timeout = timeout
        self.headers = []

    def __fetch_objects(self, objtype, url):
        try:
            r = requests.get(url, headers=self.headers, timeout=self.timeout)
            r.raise_for_status()
            ret = r.json()
            if ret['status'] != 'ok':
                print("fetching %s failed, API returned status: %s" % (objtype, ret['status']))
                return None
            return ret['result']

        except requests.exceptions.RequestException as e:
            print("fetching %s failed: %s" % (objtype, e))
            return None

    def get_events(self, year, track=None):
        url = '%s?method=Event.detail&lang=en&year=%d' % (self.api_url, year)
        if track:
            url = '%s&track=%s' % (url, track)

        return self.__fetch_objects("events", url)

    def get_locations(self, year, track=None):
        url = '%s?method=Location.detail&lang=en&year=%d' % (self.api_url, year)
        if track:
            url = '%s&track=%s' % (url, track)

        return self.__fetch_objects("locations", url)


#***************************************
# Main

if __name__ == '__main__':
    import sys
    import traceback
    import json

    ret = 0
    try:
        main = Waffel("https://eis.elevate.at/API/rest/index")
        eis_locs = main.get_locations(2018)
        locs = {}
        for eis_loc in eis_locs:
            locs[eis_loc['id']] = eis_loc

        eis_es = main.get_events(2018)
        es = {}
        for eis_e in eis_es:
            e = {}
            e['id'] = eis_e['id']
            e['title'] = eis_e['title']
            e['subtitle'] = eis_e['subtitle']
            e['track'] = eis_e['track']
            if e['track'] in Waffel.TRACK_NAME_MAP:
                e['track'] = Waffel.TRACK_NAME_MAP[e['track']]
            e['location_id'] = eis_e['location_id']
            e['location'] = locs[e['location_id']]['name']
            e['begin'] = eis_e['begin']
            e['end'] = eis_e['end']

            if e['track'] not in es:
                es[e['track']] = [e]
            else:
                es[e['track']].append(e)

        for track in es:
            es[track] = sorted(es[track], key=lambda k: k['begin'])
        print(json.dumps(es))

        # prog = {}
        # for ev in evs:
        #     t = ev['track']
        #     if t not in prog:
        #         prog[t] = {'locations': {}}

        #     lid = ev['location_id']
        #     if lid not in prog[t]['locations']:
        #         prog[t]['locations'][lid] = {'name': ev['location']['name']}
        #         prog[t]['locations'][lid]['events'] = []

        #     e = {'begin': ev['begin'], 'end': ev['end']}
        #     e['title'] = ev['title']
        #     e['shortcode'] = ev['shortcode']
        #     e['hashtag'] = ev['hashtag']
        #     e['live_stream'] = ev['streaming']['is_livemedia']
        #     prog[t]['locations'][lid]['events'].append(e)

        # print(json.dumps(prog))

    except Exception as e:
        print("ERROR: while running waffel: %s" % e)
        print(traceback.format_exc())
        sys.exit(1)

    sys.exit(ret)
