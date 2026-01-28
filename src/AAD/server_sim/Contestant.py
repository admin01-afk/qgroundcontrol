import time
from typing import Any

# some changes to make variables from json optional
class Contestant():
    def __init__(self):
        self.id = 0
        self.lat = 0
        self.lon = 0
        self.altitude = 0
        self.pitch = 0
        self.yaw = 0
        self.roll = 0
        self.speed = 0

    def update(self, json_data):
        field_map = {
            "takim_numarasi": "id",
            "iha_enlem": "lat",
            "iha_boylam": "lon",
            "iha_irtifa": "altitude",
            "iha_dikilme": "pitch",
            "iha_yatis": "roll",
            "iha_yonelme": "yaw",
            "iha_hiz": "speed",
            "iha_batarya": "battery",
            "iha_otonom": "otonom",
            "iha_kilitlenme": "kilitlenme",
            "hedef_merkez_X": "merkez_X",
            "hedef_merkez_Y": "merkez_Y",
            "hedef_genislik": "genislik",
            "hedef_yukseklik": "yukseklik",
        }

        for json_key, attr_name in field_map.items():
            if json_key in json_data:
                setattr(self, attr_name, json_data[json_key])

    def get_info(self):
        response = {
            "takim_numarasi": self.id,
            "iha_enlem": self.lat,
            "iha_boylam": self.lon,
            "iha_irtifa": self.altitude,
            "iha_dikilme": self.pitch,
            "iha_yonelme": self.yaw,
            "iha_yatis": self.roll,
            "iha_hizi": self.speed,
            "zaman_farki": 0,
        }
        return response
