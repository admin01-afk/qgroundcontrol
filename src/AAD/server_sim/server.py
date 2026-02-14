from flask import Flask, request, jsonify, session
import requests
import json
from Competition import Competition
import argparse
import time
import threading

app = Flask(__name__)
app.secret_key = 'your_secret_key'  # Required for Flask sessions

# Initialize a global session object for making HTTP requests
server_session = requests.Session()

@app.route('/api/giris', methods=['POST'])
def login():
    if 'team_number' in session:
        return jsonify({"message": "Already logged in", "takim_numarasi": session['team_number']}), 200
    json_data = request.get_json()
    username = json_data.get('kadi')
    password = json_data.get('sifre')

    team_number = competition.authenticate(username, password)
    if team_number is not None:
        session['team_number'] = team_number  # Store the team number in the session
        return jsonify({"takim_numarasi": team_number}), 200  # Return a JSON response with team number
    else:
        return jsonify({"error": "Invalid credentials"}), 401


@app.route('/api/telemetri_gonder', methods=['POST'])
def update_data():
    json_data = request.get_json()
    competition.update_contestant(json_data)
    response = competition.response_json()
    # Pretty-print the incoming JSON data
    json_str = json.dumps(json_data, indent=4, ensure_ascii=False)  # Ensure readable format
    print("Received Data:\n", json_str)
    return jsonify(response), 200


@app.route('/api/sunucusaati', methods=['GET'])
def get_server_time():
    # Add a method to get only the current time
    current_time = competition.get_current_time()
    return jsonify({"sunucusaati": current_time}), 200


@app.route('/api/hss_koordinatlari', methods=['GET'])
def hss_coordinates():
    hss_koordinatlari = {
        "sunucusaati": competition.get_current_time(),
        "hss_koordinat_bilgileri": competition.get_hss_coordinates()
    }
    return jsonify(hss_koordinatlari), 200


@app.route('/api/qr_koordinati', methods=['GET'])
def get_qr_coordinates():
    qr_latitude = -35.362218523393175
    qr_longtitude = 149.16507911931654
    qr_coordinates = {
        "qrEnlem": qr_latitude,
        "qrBoylam": qr_longtitude
    }
    return jsonify(qr_coordinates), 200


@app.route('/api/kilitlenme_bilgisi', methods=['POST'])
def kenetlenme_bilgisi_gonder():
    json_data = request.get_json()
    print(f"Received lock-on data: {json_data}")

    return jsonify({"status": "success"}), 200


@app.route('/api/kamikaze_bilgisi', methods=['POST'])
def get_qr_data():
    json_data = request.get_json()
    print(f"qr data: {json_data}")
    return jsonify({"qr data": json_data}), 200

def fake_plane_tick():
    while True:
        if competition.mode == "fake":
            # Force generation of fake planes
            competition.response_json()
        time.sleep(0.5)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-gui",
        action="store_true",
        help="Enable GUI mode"
    )
    parser.add_argument(
        "-mode",
        choices=["fake", "live"],
        default="fake",
        help="Contestant logic mode"
    )

    args = parser.parse_args()
    competition = Competition(mode=args.mode)
    tick_thread = threading.Thread(target=fake_plane_tick, daemon=True)
    tick_thread.start()

    if args.gui:
        from gui import ServerGUI

        gui = ServerGUI(competition)
        threading.Thread(target=app.run, kwargs={
            "debug": False,
            "use_reloader": False,
            "host": "127.0.0.1",
            "port": 5000
        }, daemon=True).start()

        gui.run()
    else:
        app.run(debug=True, use_reloader=False, host='127.0.0.1', port=5000)
