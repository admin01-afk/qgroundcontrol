from flask import Flask, request, jsonify, session
import requests
import json
from Competition import Competition

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
    competition.update_contestant(
        request.get_json('takim_numarasi'), json_data)
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
        "hss_koordinat_bilgileri": [
            {
                "id": 0,
                "hssEnlem": 39.820405,
                "hssBoylam": 30.535008,
                "hssYaricap": 50
            },
            {
                "id": 1,
                "hssEnlem": 39.820102,
                "hssBoylam": 30.533414,
                "hssYaricap": 50
            },
            {
                "id": 2,
                "hssEnlem": 39.818103,
                "hssBoylam": 30.533780,
                "hssYaricap": 75
            },
            {
                "id": 3,
                "hssEnlem": 39.819361,
                "hssBoylam": 30.538181,
                "hssYaricap": 150
            }
        ]
    }
    return jsonify(hss_koordinatlari), 200


@app.route('/api/qr_koordinati', methods=['GET'])
def get_qr_coordinates():
    qr_latitude = 39.82049542
    qr_longtitude = 30.53331232
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


if __name__ == '__main__':
    competition = Competition()
    app.run(debug=True, use_reloader=False, host='127.0.0.1', port=5000)
