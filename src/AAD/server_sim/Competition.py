from Contestant import Contestant
from datetime import datetime
import math
import time

class Competition():
    def __init__(self):
        self.contestants = []

        self.users = {
    "estuanatolia": {"password": "2Eqtm3v3ZJ", "team_number": 31},
    "team1": {"password": "team123", "team_number": 2},
    "1": {"password": "1", "team_number": 3}
}

    def circle_position(self, center_lat, center_lon, radius_m, angular_speed, phase=0.0):
        """
        radius_m: circle radius in meters
        angular_speed: rad/sec
        phase: initial angle offset
        """
        t = time.time()
        angle = angular_speed * t + phase

        # Earth approximations
        meters_per_deg_lat = 111_320
        meters_per_deg_lon = 111_320 * math.cos(math.radians(center_lat))

        dlat = (radius_m * math.cos(angle)) / meters_per_deg_lat
        dlon = (radius_m * math.sin(angle)) / meters_per_deg_lon

        return center_lat + dlat, center_lon + dlon


    def find_contestant(self, id):
        for index, a in enumerate(self.contestants):
            if a.id == id:
                return index
        return -1

    def update_contestant(self, id, json_data):
        id = json_data["takim_numarasi"]
        contestant_index = self.find_contestant(id)
        if contestant_index < 0:
            contestant = Contestant()
            contestant.update(json_data)
            self.contestants.append(contestant)
        else:
            self.contestants[contestant_index].update(json_data)

    def response_json(self):
        current_time = self.get_current_time()
        response_json = {
            "sunucusaati": current_time,
            "konum_bilgileri": []
        }

        # Enemy plane 1
        t = time.time()
        angle1 = 0.15 * t
        lat1, lon1 = self.circle_position(
            center_lat=-35.3629,
            center_lon=149.1644,
            radius_m=120,
            angular_speed=0.15
        )
        heading1 = (math.degrees(angle1) + 90) % 360

        # Enemy plane 2 (different center + phase, clockwise rotation)
        angle2 = -0.2 * t + math.pi
        lat2, lon2 = self.circle_position(
            center_lat=-35.3633,
            center_lon=149.1651,
            radius_m=80,
            angular_speed=-0.2,
            phase=math.pi
        )
        heading2 = (math.degrees(angle2) - 90) % 360  # Subtract 90° for clockwise motion

        enemy_planes = [
            {
                "takim_numarasi": 1, #
                "iha_enlem": lat1,
                "iha_boylam": lon1,
                "iha_irtifa": 90.0, #
                "iha_dikilme": -5.0,
                "iha_yonelme": heading1,
                "iha_yatis": 0.0,
                "iha_hizi": 20.0, #
                "zaman_farki": 0
            },
            {
                "takim_numarasi": 2,
                "iha_enlem": lat2,
                "iha_boylam": lon2,
                "iha_irtifa": 110.0,
                "iha_dikilme": -3.0,
                "iha_yonelme": heading2,
                "iha_yatis": 0.0,
                "iha_hizi": 18.0,
                "zaman_farki": 0
            }
        ]

        response_json["konum_bilgileri"].extend(enemy_planes)

        for contestant in self.contestants:
            response_json["konum_bilgileri"].append(contestant.get_info())

        return response_json

    def get_current_time(self):
        current_time = datetime.now()
        return {
            "gun": current_time.day,
            "saat": current_time.hour,
            "dakika": current_time.minute,
            "saniye": current_time.second,
            "milisaniye": current_time.microsecond // 1000
        }

    def get_hss_coordinates(self):
        hss_coordinates = [
            {
                "id": 0,
                "hssEnlem": -35.363125,
                "hssBoylam": 149.1642296,
                "hssYaricap": 50
            }
        ]
        return hss_coordinates

    def authenticate(self, user_name, password):
        # Check if the user exists in the mock database
        if user_name in self.users and self.users[user_name]["password"] == password:
            team_number = self.users[user_name]["team_number"]
            # Return a successful response with the team number
            return team_number
        else:
            # Return an error response if credentials are wrong
            return None
