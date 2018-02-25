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

#***************************************
# App
import requests


class Waffel:
    # due to historic reasons music is named arts and arts is named campus in EIS
    TRACK_NAME_MAP = {"art": "music", "campus": "arts"}

    def __init__(self, api_url, timeout=30):
        self.api_url = api_url
        self.timeout = timeout

    def get_events(self, year, track=None):
        url = '%s?method=Event.detail&lang=en&year=%d' % (self.api_url, year)
        if track:
            url = '%s&track=%s' % (url, track)

        headers = []
        try:
            r = requests.get(url, headers=headers, timeout=self.timeout)
            r.raise_for_status()
            ret = r.json()
            if ret['status'] != 'ok':
                print("fetching events failed, API returned status: %s" % (ret['status']))
                return None
            return ret['result']

        except requests.exceptions.RequestException as e:
            print("fetching events failed: %s" % (e))
            return None

#***************************************
# Main

if __name__ == '__main__':
    import sys
    import traceback
    import json

    ret = 0
    try:
        main = Waffel("https://eis.elevate.at/API/rest/index")
        eis_es = main.get_events(2018)
        es = []
        for eis_e in eis_es:
            e = {}
            e['id'] = eis_e['id']
            e['title'] = eis_e['title']
            e['subtitle'] = eis_e['subtitle']
            e['track'] = eis_e['track']
            if e['track'] in Waffel.TRACK_NAME_MAP:
                e['track'] = Waffel.TRACK_NAME_MAP[e['track']]
            e['location_id'] = eis_e['location_id']
            e['begin'] = eis_e['begin']
            e['end'] = eis_e['end']
            es.append(e)

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
