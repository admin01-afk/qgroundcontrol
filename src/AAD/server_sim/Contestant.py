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
    """
    def update(self, json_data):
        self.id = json_data['takim_numarasi']
        self.lat = json_data['iha_enlem']
        self.lon = json_data['iha_boylam']
        self.altitude = json_data['iha_irtifa']
        self.pitch = json_data['iha_dikilme']
        self.roll = json_data['iha_yatis']
        self.yaw = json_data['iha_yonelme']
        self.speed = json_data['iha_hiz']
        self.battery = json_data['iha_batarya']
        self.otonom = json_data['iha_otonom']
        self.kilitlenme = json_data['iha_kilitlenme']
        self.merkez_X = json_data['hedef_merkez_X']
        self.merkez_Y = json_data['hedef_merkez_Y']
        self.genislik = json_data['hedef_genislik']
        self.yukseklik = json_data['hedef_yukseklik']
        time.sleep(1)
    """

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
