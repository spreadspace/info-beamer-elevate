# -*- coding: utf-8 -*-
from waffel.waffel import Waffel


def get_schedule(api_url, tracks, locations, devices, schedule_tz):
    waffel = Waffel(api_url, tracks, locations, schedule_tz)
    schedule = waffel.get_events()
    return schedule
