from Contestant import Contestant
from datetime import datetime

class Competition():
    def __init__(self):
        self.contestants = []

        self.users = {
    "estuanatolia": {"password": "2Eqtm3v3ZJ", "team_number": 31},
    "team1": {"password": "team123", "team_number": 2},
    "1": {"password": "1", "team_number": 3}
}

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

        # Example: Add multiple enemy planes manually
        enemy_planes = [
            {
                "takim_numarasi": 23,
                "iha_enlem": -35.36294906,
                "iha_boylam": 149.1643906,
                "iha_irtifa": 90.0,
                "iha_dikilme": -8.0,
                "iha_yonelme": 90.0,
                "iha_yatis": 0.0,
                "iha_hizi": 20.0,
                "zaman_farki": 467
            },
            {
                "takim_numarasi": 2,
                "iha_enlem": -35.362520,
                "iha_boylam": 149.164950,
                "iha_irtifa": 95.0,
                "iha_dikilme": -5.0,
                "iha_yonelme": 135.0,
                "iha_yatis": 15.0,
                "iha_hizi": 20.0,
                "zaman_farki": 300
            },
            {
                "takim_numarasi": 3,
                "iha_enlem": -35.363180,
                "iha_boylam": 149.163880,
                "iha_irtifa": 110.0,
                "iha_dikilme": -10.0,
                "iha_yonelme": 150.0,
                "iha_yatis": 12.0,
                "iha_hizi": 20.0,
                "zaman_farki": 200
            },
            {
                "takim_numarasi": 4,
                "iha_enlem": -35.363400,
                "iha_boylam": 149.164420,
                "iha_irtifa": 90.0,
                "iha_dikilme": -8.0,
                "iha_yonelme": 127.0,
                "iha_yatis": 19.0,
                "iha_hizi": 20.0,
                "zaman_farki": 467
            },
            {
                "takim_numarasi": 5,
                "iha_enlem": -35.362700,
                "iha_boylam": 149.163700,
                "iha_irtifa": 95.0,
                "iha_dikilme": -5.0,
                "iha_yonelme": 135.0,
                "iha_yatis": 15.0,
                "iha_hizi": 20.0,
                "zaman_farki": 300
            },
            {
                "takim_numarasi": 6,
                "iha_enlem": -35.362300,
                "iha_boylam": 149.164100,
                "iha_irtifa": 110.0,
                "iha_dikilme": -10.0,
                "iha_yonelme": 150.0,
                "iha_yatis": 12.0,
                "iha_hizi": 20.0,
                "zaman_farki": 200
            }
        ]

        # Append enemy planes to the response
        response_json["konum_bilgileri"].extend(enemy_planes)

        # Include data from contestants (your own UAV)
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

    def authenticate(self, user_name, password):
        # Check if the user exists in the mock database
        if user_name in self.users and self.users[user_name]["password"] == password:
            team_number = self.users[user_name]["team_number"]
            # Return a successful response with the team number
            return team_number
        else:
            # Return an error response if credentials are wrong
            return None
